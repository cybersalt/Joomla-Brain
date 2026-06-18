# J5 → J6 mod_articles tmpl restore

## What this fixes

A PHP **out-of-memory error** (typically 1.9 GB+) in `modules/mod_articles/tmpl/default.php` at the line:

```php
require ModuleHelper::getLayoutPath('mod_articles', $params->get('layout', 'default') . $layoutSuffix);
```

The error trace looks like this (one repeated line, ending in fatal OOM):

```
Fatal error: Out of memory (allocated 1948254208 bytes) (tried to allocate 1060864 bytes)
  in /home/.../modules/mod_articles/tmpl/default.php on line 48
```

## When this happens

After upgrading a Joomla 5 site to Joomla 6, on a site that uses ANY `mod_articles_*` module (news, latest, category, categories, archive, popular, etc.) — which in J6 all delegate layout rendering through the consolidated `mod_articles` module's `tmpl/` folder.

## Root cause

The canonical Joomla 6.1.1 `modules/mod_articles/tmpl/default.php` initializes a terminating suffix:

```php
$layoutSuffix = $params->get('title_only', 0) ? '_titles' : '_items';
```

The recursive `require` is then supposed to resolve to a sibling partial — `default_items.php` (8,237 bytes) or `default_titles.php` (1,425 bytes) — which actually renders the items and does NOT recurse.

In some J5 → J6 upgrades, one or both sibling partials are **missing from the deployed filesystem** (the upgrade extraction was incomplete — partial download, write-permission glitch on those specific files, or some other extraction interruption). When `ModuleHelper::getLayoutPath()` can't find the requested partial, it falls back to `default.php` — which re-initializes `$layoutSuffix`, recurses, falls back again. Infinite loop until PHP exhausts memory.

This affects every page that renders any mod_articles_* module — not just the page the offending module is assigned to.

## What's in the fix

`file_modarticles_tmplfix.zip` is a tiny (~4 KB) Joomla "file" type extension package that installs the canonical Joomla 6.1.1 versions of:

- `modules/mod_articles/tmpl/default.php` (1,408 bytes)
- `modules/mod_articles/tmpl/default_items.php` (8,237 bytes)
- `modules/mod_articles/tmpl/default_titles.php` (1,425 bytes)

The files are exact copies from the official `joomla/joomla-cms` GitHub repository, tag `6.1.1`.

The package manifest declares `type="file"` `method="upgrade"`, so installing it cleanly overwrites the three target paths without touching anything else.

## How to use it

### Option A — via cs-mcp-for-j (programmatic)

```sh
TOKEN="<bearer token for the affected site>"
URL="https://<affected-site>/api/index.php/v1/mcp"
ZIP_URL="https://raw.githubusercontent.com/cybersalt/Joomla-Brain/main/fix-kits/j5-to-j6-mod_articles-restore/file_modarticles_tmplfix.zip"

curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -H "Accept: application/vnd.api+json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"install_extension\",\"arguments\":{\"url\":\"$ZIP_URL\"}}}" \
  "$URL"
```

### Option B — via Joomla admin

Joomla admin → System → Install → Extensions → Install from URL, paste:
`https://raw.githubusercontent.com/cybersalt/Joomla-Brain/main/fix-kits/j5-to-j6-mod_articles-restore/file_modarticles_tmplfix.zip`

### Option C — manual SFTP/SSH

Download the zip, unpack, copy the three files in `modules/mod_articles/tmpl/` to the matching path on the affected site.

## Verification after install

Reload any page that was OOM'ing. The error should clear immediately (no cache flush needed — these are runtime-loaded layout files, not compiled).

If the OOM persists, the install didn't take or the problem is elsewhere — diff the deployed files against the ones in this zip to confirm.

## Discovered

2026-06-18 on `elevatebusinesscoaching.com/stageit/` after a StageIt-cloned J5 site was upgraded to J6 6.1.1 for testing. Initial misdiagnosis chased StageIt clone-completeness (wrong tree); the real cause was incomplete J5→J6 core file extraction. See also `JOOMLA6-CHECKLIST.md` for the J5→J6 migration gotcha index entry.
