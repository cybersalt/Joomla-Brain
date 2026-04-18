# Joomla 5/6 Edge-Case Scenarios

A catalog of environmental and third-party conditions that can break a Joomla extension's normal operation — and the patterns for detecting and handling them gracefully.

This is a living reference. When you ship an extension that interacts with hosting, filesystem operations, or other extensions, consult this list to see which conditions you should detect and how to handle them.

---

## Why a dedicated guide for this

Extensions that do real work (backups, deploys, syncs, migrations, cloning) don't fail in isolation — they fail against **combinations of**:
- Particular hosting setups (shared hosts, CDN layers, symlinks, non-standard paths)
- Particular security extensions (Admin Tools, Sucuri, mod_security rules)
- Particular third-party extensions (Joomlatools Fileman, custom gallery plugins, anything that stores absolute filesystem paths in the database)
- Particular user configurations (unusual log paths, RewriteBase values, subdirectory installs)

Each edge case is individually rare, but collectively **some** edge case will affect almost every customer site over time. A good extension handles these gracefully — detecting, explaining, and offering a fix — rather than failing with a confusing error.

---

## The pre-flight dialog pattern

The reusable pattern across all the scenarios below:

### 1. Detection (lightweight AJAX call before the destructive operation)

A `preflight` AJAX endpoint runs fast checks (filesystem tests, table queries, config reads) and returns a JSON response:

```json
{
  "jdata": {
    "issue1_detected": 1,
    "issue1_preference": "ask",
    "issue1_debug_path": "/where/we/looked",
    "issue2_detected": 0,
    "issue2_preference": "ask"
  }
}
```

Each `issue_detected` flag is set only when the condition actually applies to *this* site.

### 2. Resolution

For each detected issue, resolve the decision:

- If `preference === 'fix'` → apply silently (user previously said "always do it")
- If `preference === 'skip'` → skip silently (user previously said "never do it")
- If `preference === 'ask'` → include this issue in the dialog

### 3. Dialog (single modal, conditional sections)

One dialog, N sections. Only the sections corresponding to detected issues with `preference === 'ask'` are shown. Each section has:

- **Explanatory copy** (what's wrong, why it matters, what the fix does)
- **A "Fix it" checkbox** (opt-in)
- **A "Remember my choice on this site" checkbox** (so the user doesn't get asked again)
- **Acknowledgement list** (the consequences of checking "fix", plus any blame-shifting "you accept responsibility" language for changes that modify live data)

One shared **Cancel / Proceed** button pair at the bottom handles all sections.

### 4. Persistence

On Proceed:

- For each section where the user checked "Remember my choice", save the preference (`fix` or `skip`) to the component's persistent params.
- For each section where "Remember" is NOT checked, send a per-run flag in the URL of the actual destructive operation (e.g. `?issue1_fix=1`).

### 5. Application in the destructive operation

During the actual deploy/sync/whatever:

- If the component param says `fix`, apply silently.
- If the per-run flag is set (`?issue1_fix=1`), apply once.
- If neither, skip.

For operations that span multiple AJAX chunks (like StageIt's chunked deploy), persist the per-run flag in a marker file (`$logDir/issue1-pending.txt`) at the init step so later steps can still see it.

### 6. Reversibility on the opposite operation

If the fix modifies data that will later be copied back (like when StageIt rewrites staging DB rows that will be synced back to live), the opposite operation MUST reverse the modification before the copy-back happens. Use **string-replace-based reversibility**: if deploy does `A → B`, sync does `B → A`. Both are the same function called with swapped arguments.

### 7. Audit log

Every application of a fix (and every skip via `remember my choice = skip`) writes to a dedicated always-on audit log (see "Audit Log Pattern" below).

---

## Audit log pattern

When an extension modifies data as a fix for an edge case, keep a **separate** always-on log that the user can't turn off. This is distinct from their normal operations/debug log.

### Why a separate log

- Operations log level may be "off" for user preference (they don't want noise).
- Debug log may be "off" because they're not debugging.
- But a record of "we modified .htaccess at 2026-04-17 14:32:05 and restored it at 14:32:07" must ALWAYS exist, because it's a security-relevant event.

### Implementation

```php
const AUDIT_HEADER = "<?php die('Forbidden.'); ?>\n";

public static function _audit($msg = '') {
    if (!self::$audit_log) {
        $audit_file = self::_getLogDir() . '/myext-audit.log.php';
        $newFile = !file_exists($audit_file);
        self::$audit_log = @fopen($audit_file, 'a+');
        if (!self::$audit_log) return;
        if ($newFile) {
            @fwrite(self::$audit_log, self::AUDIT_HEADER);
        }
    }
    // Empty string = blank separator line, no timestamp/prefix
    if ($msg === '') {
        @fwrite(self::$audit_log, "\r\n");
        return;
    }
    $msg = date('Y-m-d H:i:s') . " [AUDIT] {$msg}\r\n";
    @fwrite(self::$audit_log, $msg);
}
```

### File properties

- **Filename ends in `.log.php`** and starts with `<?php die('Forbidden.'); ?>\n` so that direct HTTP access to the file returns a blank response. Prevents a curious visitor from downloading your audit log.
- **Download through the admin UI**: provide a Download button that reads the file, strips the PHP die() header, and serves as text/plain.
- **Store in the resolved log directory** (not hardcoded) so it follows Joomla's configured `log_path`.

### What to log

Log **everything** about a modification:
- Section start/end markers with double blank lines for scannability
- Why the modification is happening (user opted in via dialog / via persistent config)
- Exact before/after values
- Absolute paths affected
- Success / failure status
- Duration of any unprotected window

A sample entry:

```
===== AKEEBA INSTALLERS .HTACCESS BYPASS SESSION STARTED =====

User explicitly opted in via the pre-flight dialog to temporarily bypass the
Akeeba Admin Tools .htaccess protection on the Akeeba Backup installers folder
(/administrator/components/com_akeebabackup/installers/) so that the three
installer files (brs.jpa, brs-joomla.jpa, brs-generic.jpa) can be copied to
the staging site.

RENAMING: /home/user/public_html/.../.htaccess -> .htaccess.stageit-bypass
Rename successful. The installers/ folder is now temporarily unprotected.
COPIED brs.jpa (962,691 bytes) to staging site - SUCCESS
COPIED brs-joomla.jpa (58,193 bytes) to staging site - SUCCESS
COPIED brs-generic.jpa (1,185 bytes) to staging site - SUCCESS
All 3 installer files copied successfully.
Restoring protection now.
RESTORING: .htaccess.stageit-bypass -> .htaccess
Restore successful. The installers/ folder is protected again.

===== BYPASS SESSION ENDED — total unprotected duration: 2.1 seconds =====
```

### Self-heal

For any fix that temporarily modifies state (rename, disable, etc.), include a self-heal check at extension init time. If the temporary state is detected on startup, it means the previous run was interrupted — restore automatically and log the self-heal.

---

## Cataloged scenarios

### Scenario: Akeeba Admin Tools hardened `.htaccess` blocks file copy

**Trigger condition**: Site has Akeeba Backup AND Akeeba Admin Tools is active with the standard server-hardening `.htaccess` in `administrator/components/com_akeebabackup/installers/`.

**Symptom**: Any extension that tries to read the three `.jpa` installer files (`brs.jpa`, `brs-joomla.jpa`, `brs-generic.jpa`) gets `is_readable() === false` even though filesystem permissions are normal. Akeeba Backup does NOT function on a subdirectory staging copy because those files weren't copied.

**Detection**:
```php
$htaccess = JPATH_ROOT . '/administrator/components/com_akeebabackup/installers/.htaccess';
if (!file_exists($htaccess)) return FALSE;
$contents = @file_get_contents($htaccess);
return (stripos($contents, 'Deny from all') !== FALSE
     || stripos($contents, 'Require all denied') !== FALSE);
```

**Fix**: Rename `.htaccess` → `.htaccess.stageit-bypass`, perform the copy, rename back. Total unprotected window: 1-3 seconds. Include self-heal for interrupted runs.

**Key doc**: [Akeeba .htaccess Maker](https://www.akeeba.com/documentation/admin-tools-joomla/htaccess-maker.html)

---

### Scenario: `.htaccess` `RewriteBase` directive in subdirectory staging

**Trigger condition**: Live site has an uncommented `RewriteBase X` line in its root `.htaccess` (common on GoDaddy, shared hosts, and any Joomla install in a subdirectory).

**Symptom**: After StageIt-style subdirectory staging copy, frontend SEF URLs on the staging site rewrite back to the LIVE site's `index.php` instead of the staging copy's. Admin works, frontend doesn't.

**Detection**: Parse live `.htaccess` line by line, look for a non-comment line matching `^RewriteBase\s+\S+\s*$` and capture the value.

**Fix**: Rewrite the staging copy's `.htaccess` so `RewriteBase X` becomes `RewriteBase X/stageit/` (or whatever the staging folder is). Works with any X — `/` becomes `/stageit/`, `/myapp/` becomes `/myapp/stageit/`.

**Reversal**: Not needed on sync-to-live, because StageIt skips the root `.htaccess` during sync by design. Live file is never overwritten.

---

### Scenario: Joomlatools Files/Fileman asset folder not in core copy list

**Trigger condition**: Site has Joomlatools Files, Fileman, or DOCman installed AND has attachments/content stored at the default `joomlatools-files/` path at the site root.

**Symptom**: Viewing an article with a Fileman attachment on the staging copy throws `UnexpectedValueException: Invalid folder:` (with `$state->folder` NULL). Caused by: the `#__files_containers` table's `path` column stores relative paths like `joomlatools-files/fileman-attachments`, which resolve against `JPATH_ROOT` at runtime. Most subdirectory-staging tools' default copy list (`administrator`, `components`, `images`, etc.) doesn't include `joomlatools-files/`, so the folder doesn't exist at `JPATH_ROOT/joomlatools-files/` on staging and the lookup fails.

**Detection**:
```php
// Check the live DB's #__files_containers for any path whose top-level
// folder is not in the standard core folder copy list.
$sql = "SELECT DISTINCT path FROM " . $liveTable;
$paths = $db->loadColumn();
$coreFolders = array_flip(stageIt::_getCoreFolders());
foreach ($paths as $path) {
    $top = explode('/', trim($path, '/'))[0];
    if (!isset($coreFolders[$top]) && is_dir(JPATH_ROOT . '/' . $top)) {
        return TRUE;  // found one
    }
}
```

**Fix**: Recursively copy the extra top-level folders from live to staging during deploy.

**Reversal**: Not needed on sync-to-live. Live folder stays intact (we don't delete or overwrite it).

---

### Scenario: Composer autoloader hash mismatch after size-only file copy

**Trigger condition**: Tool copies files using `filesize()` as the only "skip if unchanged" heuristic. Composer regenerates its autoloader with a new hash (`ComposerAutoloaderInitXXXXX`) on every install/update, and the new `autoload.php` often happens to be the exact same byte size as the old one.

**Symptom**: After copy, `libraries/vendor/autoload.php` references `ComposerAutoloaderInitAAAA` but `autoload_real.php` defines `ComposerAutoloaderInitBBBB`. PHP fatal: class not found. 500 error on every page.

**Fix**: Include `filemtime()` in the skip-check, not just `filesize()`. If either differs, re-copy. String-based approach (update the class name across all three files) is fragile; the mtime fix is cleaner.

```php
if (filesize($target) === $filesize($source)
    && filemtime($target) >= filemtime($source)) {
    return TRUE;  // safe to skip
}
```

---

### Scenario: Non-standard log directory configured in Joomla

**Trigger condition**: User or their host has set Joomla's `log_path` to something outside the standard `administrator/logs/` location (`/home/user/public_html/logs`, `/var/log/custom-app`, etc.).

**Symptom**: Extension hardcodes `JPATH_ADMINISTRATOR . '/logs/'` as the log path, tries to open a file there, gets `false` from `fopen()`, then passes the `false` handle to `fwrite()` → fatal `Argument #1 must be of type resource, false given`.

**Fix**: Resolve the log directory at runtime respecting Joomla's configuration. Fallback chain:
1. Use `Factory::getConfig()->get('log_path')` if set AND writable
2. Else `JPATH_ADMINISTRATOR . '/logs'` if writable (create if missing)
3. Else `JPATH_ROOT . '/tmp'` as last resort

Warn the user on the dashboard when a non-standard location is in use so they know where their logs went.

---

### Scenario: CDN caching breaks asset updates

**Trigger condition**: Site is behind a CDN (CloudFlare, GoDaddy's edge cache, etc.) and uses static version strings (`?v=5.6.7`) for CSS/JS cache busting. When you update a file without bumping the version string, the CDN continues serving the old file.

**Symptom**: You FTP-update `stageit.js`, reload the page, and see no change because the CDN returns the cached version keyed on `?v=5.6.7`.

**Fix**: Use `filemtime()` as the cache-bust token. URL becomes `?v=1776470371` which changes every time the file is modified on disk. CDN has no cache entry for the new URL → fetches fresh from origin.

```php
$jsPath = JPATH_ROOT . '/administrator/components/com_xxx/resources/js/script.js';
$jsVersion = file_exists($jsPath) ? filemtime($jsPath) : '1.0.0';
$document->addScript('components/com_xxx/resources/js/script.js?v=' . $jsVersion);
```

---

### Scenario: Joomla loads language from system location, not component-bundled

**Trigger condition**: Developer hot-patches a component's language file via FTP/API by editing only the component-bundled copy (`administrator/components/com_xxx/language/{tag}/`).

**Symptom**: Translations don't update despite the file change.

**Fix**: Update the system location (`administrator/language/{tag}/`), not the bundled one, or update both. At install time, package install copies bundled files to the system location. Runtime loads come from the system location.

---

## How to add a new scenario to an existing extension

When you discover a new edge case in customer support, follow this flow:

1. **Create a helper class**: `stg{ScenarioName}.class.php` (or equivalent naming) with methods:
   - `_isNeeded()` / `_detect()` — lightweight check
   - `_apply()` — the fix
   - `_reverse()` (if applicable) — reverse the fix for the opposite operation
   - `_selfHeal()` (if applicable) — recover from interrupted `_apply`

2. **Extend the preflight AJAX endpoint**: add detection fields to the response, and handle the new preference in the `savePreference` action.

3. **Add a section to the modal**: one block of explanatory copy + fix checkbox + remember checkbox. Show conditionally based on detection.

4. **Add a config option**: persistent preference dropdown (`ask | fix | skip`) under the "Advanced / Edge Case Settings" fieldset.

5. **Wire the fix into the operation**: call `_apply()` at the appropriate point in your deploy/sync/operation flow, gated on the preference + runtime flag.

6. **Add audit log entries**: start marker, per-step details, end marker with outcome.

7. **Add English language strings**: dialog copy, checkbox labels, acknowledgement list, config dropdown labels.

8. **Defer translation**: only translate to all 14 languages after the feature is validated and copy is stable. During development, English-only is fine — untranslated keys fall back to English in Joomla.

9. **Document in this guide**: add a new "Scenario" section with detection code snippet, symptom, fix approach, and reversal notes.

---

## Related docs

- `JOOMLA5-LANGUAGE-FILES-GOTCHAS.md` — how Joomla actually loads language files (matters for the dialog copy and config labels)
- `JOOMLA5-UI-PATTERNS.md` — modal dialog implementation, fieldset layout, cache-busting, dark mode
- `COMPONENT-TROUBLESHOOTING.md` — general component loading/installation diagnostics
