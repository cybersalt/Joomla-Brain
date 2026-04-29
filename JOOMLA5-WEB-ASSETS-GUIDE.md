# Joomla 5/6 Web Asset Manager (WAM) Guide

How to register, declare, and use CSS and JavaScript assets in Joomla 5/6 extensions. The Web Asset Manager replaced `JHtml::_('script', ...)` and `JHtml::_('stylesheet', ...)` as the recommended pattern — and it has subtleties (URI auto-resolution rules, vendor-asset paths, inline content) that bite the first time around.

> Why this matters for security: WAM-registered assets get versioned URLs and dependency declarations, which means the right CSP-friendly inclusion order is enforced automatically. Hand-rolled `<script>` tags from PHP `echo` statements are how XSS payloads sneak in via injected user content. Use the asset manager.

---

## The two layers

WAM has two parts you'll touch:

1. **`joomla.asset.json`** — a static declaration file shipped with the extension that registers every asset by name. Lives at `media/com_yourcomponent/joomla.asset.json` (or the equivalent path for modules / plugins / templates).
2. **The runtime API** — `$document->getWebAssetManager()` (`$wa`) — used in your views/layouts to actually *use* a registered asset, plus to register and use ad-hoc assets that aren't in the JSON file.

The static declaration is the preferred pattern. Use the runtime registration only for vendor libraries and dynamic content.

---

## `joomla.asset.json` schema

Place at `media/com_mycomponent/joomla.asset.json`:

```json
{
  "$schema": "https://developer.joomla.org/schemas/json-schema/web_assets.json",
  "name": "com_mycomponent",
  "version": "1.0.0",
  "assets": [
    {
      "name": "com_mycomponent.admin",
      "type": "style",
      "uri": "com_mycomponent/admin.css"
    },
    {
      "name": "com_mycomponent.admin.script",
      "type": "script",
      "uri": "com_mycomponent/admin.js",
      "dependencies": ["core"]
    },
    {
      "name": "com_mycomponent.list",
      "type": "script",
      "uri": "com_mycomponent/list.js",
      "dependencies": ["com_mycomponent.admin.script", "core"],
      "attributes": {
        "defer": true
      }
    }
  ]
}
```

Key fields:

- **`name`** — the asset name your views will reference. Convention: `com_yourcomponent.<descriptor>`. Use dots to namespace.
- **`type`** — `style` for CSS, `script` for JS. WAM uses this to decide how to render the tag.
- **`uri`** — see auto-resolution rules in the next section.
- **`dependencies`** — array of asset names that must load before this one. `"core"` is Joomla's built-in core JS bundle. Always include it for scripts that use `Joomla.*` globals.
- **`attributes`** — HTML attributes to land on the rendered tag. Use this for `defer`, `async`, `nomodule`, `crossorigin`, etc. **`defer` belongs here, NOT in the asset metadata.** This is the same lesson as in [`JOOMLA5-UI-PATTERNS.md` §9](JOOMLA5-UI-PATTERNS.md): putting `defer` in the wrong key silently drops it.

The manifest XML must declare the `joomla.asset.json` file in the `<media>` block:

```xml
<media destination="com_mycomponent" folder="media">
    <filename>joomla.asset.json</filename>
    <folder>css</folder>
    <folder>js</folder>
</media>
```

---

## Using a registered asset (in views/layouts)

```php
/** @var \Joomla\CMS\WebAsset\WebAssetManager $wa */
$wa = $this->getDocument()->getWebAssetManager();
$wa->useStyle('com_mycomponent.admin');
$wa->useScript('com_mycomponent.admin.script');
```

`useStyle()` / `useScript()` are idempotent — calling them twice just keeps the asset in the active set, no duplicate tags. Safe to call from any layout that needs the asset.

---

## URI auto-resolution rules (the critical detail)

In `joomla.asset.json`, the `uri` field is **resolved by Joomla against `media/`** with implicit `css/` or `js/` injection based on the asset `type`. This means:

```json
{
  "name": "com_mycomponent.admin",
  "type": "style",
  "uri": "com_mycomponent/admin.css"
}
```

…is auto-resolved to `media/com_mycomponent/css/admin.css`. So your file goes at:

```
media/com_mycomponent/css/admin.css
```

NOT at `media/com_mycomponent/admin.css`.

### The trap

If you include the subdirectory in the URI:

```json
{
  "uri": "com_mycomponent/css/admin.css"   ← WRONG
}
```

Joomla resolves this to `media/com_mycomponent/css/css/admin.css` (double `css/`) → 404.

**Rule:** in `joomla.asset.json`, never include `css/` or `js/` in the URI for type `style` or `script` assets. Joomla injects the correct subdirectory based on type.

---

## Non-standard paths (vendor libraries)

Vendor assets stored outside the standard `media/com_yourcomponent/` structure — e.g., a third-party library installed at `media/vendor/fancybox/` — **cannot use auto-resolution**. Register them via the runtime API with a full literal path:

```php
$wa = $this->getDocument()->getWebAssetManager();
$wa->registerAndUseScript('vendor.fancybox', 'media/vendor/fancybox/fancybox.umd.js');
$wa->registerAndUseStyle('vendor.fancybox', 'media/vendor/fancybox/fancybox.css');
```

The path here is taken literally — Joomla doesn't auto-inject anything. This works for `media/vendor/`, `media/system/`, or any other location.

You can still pass options and attributes:

```php
$wa->registerAndUseScript(
    'vendor.fancybox',
    'media/vendor/fancybox/fancybox.umd.js',
    ['version' => 'auto'],          // $options — Joomla-internal
    ['defer' => true]               // $attribs — HTML attributes (defer goes here!)
);
```

Same options/attribs distinction as `HTMLHelper::_('script', ...)` — see [`JOOMLA5-UI-PATTERNS.md` §9](JOOMLA5-UI-PATTERNS.md) for why `defer` in `$options` silently disappears.

---

## Inline assets

For dynamic CSS (CSS custom properties built from PHP variables) or scripts that need server-rendered data, use the inline asset methods:

### Inline CSS

```php
$brandColor = $params->get('brand_color', '#fa6400');
$wa->addInlineStyle(":root { --brand-color: {$brandColor}; }");
```

### Inline script

A heredoc keeps multi-line scripts readable:

```php
$baseUrl = Uri::root();
$itemId  = (int) $item->id;
$token   = Session::getFormToken();

$wa->addInlineScript(<<<JS
    const MyComponentConfig = {
        baseUrl: '{$baseUrl}',
        itemId:  {$itemId},
        token:   '{$token}'
    };
JS);
```

### Security warning

**Never interpolate user-supplied data into inline scripts without escaping.** XSS lives here. For user-derived strings:

```php
// Use json_encode for safe JS string injection — it handles quotes, newlines, unicode
$safeName = json_encode($user->name);
$wa->addInlineScript("const userName = {$safeName};");
```

`json_encode($string)` produces a properly-escaped JS string literal, including the surrounding quotes. This is the safe pattern. **Do NOT** wrap a raw `$user->name` in PHP single-quoted strings — a name containing `'` or `</script>` will break out.

For user-supplied numeric IDs, `(int)` cast is sufficient and fastest:

```php
$wa->addInlineScript("const itemId = " . (int) $itemId . ";");
```

For inline CSS that includes user data (e.g., user-chosen brand colors), validate against a whitelist or hex-pattern regex before interpolating. Don't trust the raw value:

```php
$brandColor = $params->get('brand_color', '#fa6400');
if (!preg_match('/^#[0-9a-fA-F]{3,8}$/', $brandColor)) {
    $brandColor = '#fa6400'; // safe fallback
}
$wa->addInlineStyle(":root { --brand-color: {$brandColor}; }");
```

---

## Dependencies

Always declare dependencies explicitly. WAM uses them to:

1. Order the rendered tags correctly.
2. Auto-load dependencies that aren't already active. (You don't have to call `useScript('core')` separately — declaring `"dependencies": ["core"]` and using your script pulls core in.)

Common dependency names:

| Dependency | What it gives you |
|---|---|
| `core` | `Joomla.*` globals, jQuery is NOT included by default in J5/6 — see below |
| `bootstrap.es5` | Bootstrap 5 JS bundle |
| `bootstrap.dropdown` | Just the dropdown component |
| `bootstrap.modal` | Just the modal component |
| `webcomponent.joomla-toolbar` | The admin toolbar web component |
| `keepalive` | The session keep-alive script |

**jQuery is NOT in `core` on Joomla 5/6.** If your script needs jQuery (legacy code, third-party plugin reliance), explicitly add `jquery` to dependencies:

```json
{
  "dependencies": ["core", "jquery"]
}
```

But the right move long-term is to remove the jQuery dependency. Joomla 6 may eventually drop the jQuery bundle from the default install.

---

## Versioning

Two ways to version asset URLs for cache-busting:

1. **`"version"` in `joomla.asset.json`** — applies to all assets in the file. URL becomes `?...&v=1.0.0`. Bump on release.
2. **`'version' => 'auto'` in runtime API** — Joomla uses the file's `filemtime()`. Best for development and for vendor assets that change between releases without an extension version bump.

For Cybersalt extensions, the standard is: bump the `joomla.asset.json` `version` field at every release alongside the manifest version. For vendor assets registered at runtime, use `'auto'`.

See [`JOOMLA5-UI-PATTERNS.md` §1](JOOMLA5-UI-PATTERNS.md) for `filemtime()` cache-busting on hand-rolled `addStyleSheet()` / `addScript()` calls (still used in templates that don't use WAM).

---

## Dark mode and asset choices

Joomla 5+ admin uses Bootstrap 5.3 with `data-bs-theme="dark"` on `<html>`. When writing CSS for admin views:

- **Avoid `bg-light`** — it stays white in dark mode and looks wrong.
- **Avoid `btn-outline-*`** — very low contrast against dark backgrounds. Use solid `btn-primary`, `btn-secondary`, etc.
- **Use color-adaptive classes**: `bg-body-secondary`, `bg-body-tertiary`, `border rounded`.
- **Replace `text-muted` with `text-body-secondary`** — `text-muted` is deprecated in BS 5.3.
- **Test in both modes** before shipping.

For non-Bootstrap-keyed CSS in admin templates, use the `var(--bs-body-bg, #fff)` pattern and add an explicit override keyed on `html[data-bs-theme="dark"]` — see [`JOOMLA5-UI-PATTERNS.md` §2](JOOMLA5-UI-PATTERNS.md) for the modal-dialog example.

---

## Common WAM mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| `uri` includes `css/` or `js/` | 404 on the asset | Drop the subdirectory — Joomla injects it from `type` |
| `defer` in `$options` (3rd arg of `registerAndUseScript`) | Script loads without `defer`, race conditions | Move `defer` to `$attribs` (4th arg) |
| Vendor asset declared in `joomla.asset.json` with non-standard path | 404 | Use `registerAndUseScript()` with full literal path instead |
| Inline script interpolates user data without escaping | XSS | Use `json_encode()` for strings, `(int)` for numbers |
| Forgot `"core"` in dependencies | `Joomla is not defined` errors in console | Add `"core"` to the asset's dependencies |
| Forgot to declare `joomla.asset.json` in manifest `<media>` block | Asset name not registered, `useStyle()` warns or silently does nothing | Add `<filename>joomla.asset.json</filename>` to the `<media>` block |

---

## Related

- [`JOOMLA5-UI-PATTERNS.md`](JOOMLA5-UI-PATTERNS.md) — `HTMLHelper` script options/attribs distinction (same `defer` lesson), inline cache-busting with `filemtime()`, dark-mode CSS variable patterns
- [`JOOMLA5-MODULE-GUIDE.md`](JOOMLA5-MODULE-GUIDE.md) — module-side asset registration including the custom CSS tab pattern
- [`JOOMLA-CODING-STANDARDS.md`](JOOMLA-CODING-STANDARDS.md) — ESLint config that should pass before assets ship
