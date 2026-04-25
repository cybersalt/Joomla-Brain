# Joomla 5/6 Template Overrides — `#__template_overrides` Schema and Path Resolution

Reference for any extension that reads or acts on the override-tracker rows Joomla maintains under **Templates → "Changes found"**. Lessons from the cs-template-integrity build (April 2026), confirmed against a live Joomla 6.1 site.

---

## Schema (unchanged since 2018)

```sql
CREATE TABLE `#__template_overrides` (
    `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `template`        VARCHAR(50)  NOT NULL,
    `hash_id`         VARCHAR(255) NOT NULL,
    `extension_id`    INT          NOT NULL,
    `state`           TINYINT      NOT NULL,
    `action`          TINYINT      NOT NULL,
    `client_id`       TINYINT      NOT NULL,
    `created_date`    DATETIME     NOT NULL,
    `modified_date`   DATETIME     NOT NULL,
    PRIMARY KEY (`id`)
);
```

Columns: `id, template, hash_id, extension_id, state, action, client_id, created_date, modified_date`.

`client_id` is **0 for site, 1 for admin**.

---

## `hash_id` is NOT a hash — it's a base64-encoded relative path

The column name is misleading. Decode it as base64 and you get the relative path of the override file beginning with `/html/`:

```
L2h0bWwvbGF5b3V0cy9qb29tbGEvc3lzdGVtL21lc3NhZ2UucGhw
  → /html/layouts/joomla/system/message.php

L2h0bWwvY29tX2NvbnRlbnQvZmVhdHVyZWQvZGVmYXVsdF9saW5rcy5waHA=
  → /html/com_content/featured/default_links.php

L2h0bWwvbW9kX21lbnUvZGVmYXVsdC5waHA=
  → /html/mod_menu/default.php
```

PHP:

```php
$relative = base64_decode($row->hash_id, true);  // strict mode
// $relative is now e.g. "/html/com_content/featured/default_links.php"
```

There is no actual hashing involved anywhere. The base64 encoding is simply how Joomla stores variable-length paths in a fixed-width column.

---

## Resolving the override file path

The override file always lives under the template's `html/` folder, with `client_id` deciding site vs admin:

```php
$root = $row->client_id === 1 ? JPATH_ADMINISTRATOR : JPATH_SITE;
$relative = base64_decode($row->hash_id, true);
$overridePath = $root . '/templates/' . $row->template . $relative;
```

Examples:
- Site: `JPATH_SITE/templates/cassiopeia/html/com_content/featured/default_links.php`
- Admin: `JPATH_ADMINISTRATOR/templates/atum/html/layouts/joomla/system/message.php`

---

## Resolving the corresponding core file

Strip the leading `/html/`, then map the first path segment to its core source location.

| First segment | Core source location |
|---|---|
| `layouts/<rest>` | `<clientRoot>/layouts/<rest>` |
| `com_<comp>/<view>/<file>` | `<clientRoot>/components/com_<comp>/tmpl/<view>/<file>` |
| `mod_<mod>/<file>` | `<clientRoot>/modules/mod_<mod>/tmpl/<file>` |
| `plg_<group>_<el>/<file>` | `JPATH_PLUGINS/<group>/<el>/tmpl/<file>` |

`<clientRoot>` is `JPATH_ADMINISTRATOR` when `client_id=1`, `JPATH_SITE` when `client_id=0`.

`plg_*` overrides always resolve under `JPATH_PLUGINS` regardless of client_id (plugins live in one place; the front/admin distinction doesn't apply to them).

Reference implementation:

```php
public static function corePath(string $hashId, int $clientId): ?string
{
    $relative = base64_decode($hashId, true);
    if ($relative === false || !str_starts_with($relative, '/html/')) {
        return null;
    }
    $viewPath = substr($relative, strlen('/html/'));
    $segments = explode('/', $viewPath, 2);
    if (count($segments) !== 2) {
        return null;
    }
    [$first, $rest] = $segments;
    $clientRoot = $clientId === 1 ? JPATH_ADMINISTRATOR : JPATH_SITE;

    if ($first === 'layouts') {
        return $clientRoot . '/layouts/' . $rest;
    }
    if (str_starts_with($first, 'com_')) {
        return $clientRoot . '/components/' . $first . '/tmpl/' . $rest;
    }
    if (str_starts_with($first, 'mod_')) {
        return $clientRoot . '/modules/' . $first . '/tmpl/' . $rest;
    }
    if (str_starts_with($first, 'plg_')) {
        $remainder = substr($first, 4);
        $parts = explode('_', $remainder, 2);
        if (count($parts) !== 2) {
            return null;
        }
        [$group, $element] = $parts;
        return JPATH_PLUGINS . '/' . $group . '/' . $element . '/tmpl/' . $rest;
    }
    return null;
}
```

Working code: [cs-template-integrity/packages/com_cstemplateintegrity/admin/src/Helper/PathResolver.php](https://github.com/cybersalt/cs-template-integrity).

---

## Writing back to override files: hard-won safety guards

When applying a fix to an override file (writing patched contents back to disk), three checks belong on every path that calls `file_put_contents()`:

### 1. Separator-anchored containment check (NOT `strpos`)

The obvious-looking guard is wrong:

```php
// ❌ Bypassable when JPATH_ROOT has a sibling whose path starts with the same prefix
//   e.g. /var/www/joomla and /var/www/joomla-bak
$parentReal = realpath(\dirname($absolute));
$rootReal   = realpath(JPATH_ROOT);
if (strpos($parentReal, $rootReal) !== 0) {
    throw new \RuntimeException('Outside root');
}
```

Use a separator-anchored compare instead:

```php
// ✅ Trailing DIRECTORY_SEPARATOR rules out prefix collisions
$rootSep   = rtrim($rootReal, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
$parentSep = $parentReal . DIRECTORY_SEPARATOR;
if (!str_starts_with($parentSep, $rootSep)) {
    throw new \RuntimeException('Outside root');
}
```

### 2. PHP-extension whitelist

Override files are the **only** legitimate place an integrity tool writes `.php` to. Anywhere else under `JPATH_ROOT` is either misconfiguration or attack:

```php
$ext = strtolower(pathinfo($absolute, PATHINFO_EXTENSION));
$phpExts = ['php', 'phtml', 'phar', 'pht'];
if (in_array($ext, $phpExts, true)) {
    $normalized = str_replace('\\', '/', $absolute);
    $isSite  = (bool) preg_match('#/templates/[^/]+/html/.+\.\w+$#', $normalized);
    $isAdmin = (bool) preg_match('#/administrator/templates/[^/]+/html/.+\.\w+$#', $normalized);
    if (!$isSite && !$isAdmin) {
        throw new \RuntimeException('Refusing PHP write outside templates/.../html/');
    }
}
```

### 3. opcache invalidate after the write

A PHP file that's already in OPcache won't pick up the new bytes until the cache slot is invalidated. Forget this and the next request runs the old code:

```php
file_put_contents($absolute, $newContents);
if (function_exists('opcache_invalidate')) {
    @opcache_invalidate($absolute, true);
}
```

---

## The Web Services API auth gotcha applies here too

If your extension exposes an API for reading override data, requests need:

```
X-Joomla-Token: <token>
Accept: application/vnd.api+json
```

`Authorization: Bearer …` returns 401. See `JOOMLA5-WEB-SERVICES-API-GUIDE.md`.

---

## Reference

- Working implementation: [cs-template-integrity](https://github.com/cybersalt/cs-template-integrity) — exposes overrides + per-file content + apply-fix via Web Services API
- Live test confirmation: against Joomla 6.1 at j53.basicjoomla.com, April 2026
