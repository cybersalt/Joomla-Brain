# Joomla 5/6 UI Patterns

UI patterns that work reliably in Joomla 5/6 admin views. These come from shipping production extensions, not theory.

---

## 1. Cache-busting CSS/JS with `filemtime()`

Hardcoded asset versions (e.g. `?v=5.6.7`) look fine but cause real problems:

- Browser and CDN caches key on the URL. If you update `stageit.js` but keep `?v=5.6.7`, users and CDN edges continue serving the old file.
- GoDaddy, CloudFlare, and other edge caches are aggressive. Hard-refreshing doesn't help; the edge still serves the cached response.

**Fix:** use the file's modification time as the cache-bust token. Every time you edit the file on disk, the timestamp changes, the URL changes, every cache is invalidated automatically:

```php
$cssPath = JPATH_ROOT . '/administrator/components/com_xxx/resources/css/style.css';
$jsPath  = JPATH_ROOT . '/administrator/components/com_xxx/resources/js/script.js';
$cssVersion = file_exists($cssPath) ? filemtime($cssPath) : '1.0.0';
$jsVersion  = file_exists($jsPath)  ? filemtime($jsPath)  : '1.0.0';
$document->addStyleSheet('components/com_xxx/resources/css/style.css?v=' . $cssVersion);
$document->addScript('components/com_xxx/resources/js/script.js?v=' . $jsVersion);
```

The fallback literal (`'1.0.0'`) is there only in the unlikely case the file itself is missing at runtime.

---

## 2. Modal dialog pattern (no template dependency)

Joomla admin templates vary. The Atum default template bundles Bootstrap 5, but some staff-facing tasks run inside third-party templates where Bootstrap can't be assumed. For anything you want to show reliably, build a self-contained modal with CSS scoped to your component's body class:

```css
body.admin.com_xxx .stg-modal-overlay {
    position: fixed;
    top: 0; left: 0; width: 100%; height: 100%;
    background: rgba(0,0,0,0.6);
    z-index: 10000;
}
body.admin.com_xxx .stg-modal {
    position: fixed;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    width: 90%; max-width: 720px;
    max-height: 90vh; overflow-y: auto;
    background: var(--bs-body-bg, #fff);
    color: var(--bs-body-color, #000);
    border-radius: 6px;
    box-shadow: 0 10px 40px rgba(0,0,0,0.4);
    z-index: 10001;
}
```

The `var(--bs-body-bg, #fff)` pattern lets Bootstrap's CSS variables take effect when present and falls back to sane colors when they aren't.

For dark mode support, add overrides keyed on Joomla's theme attributes:

```css
html[data-bs-theme="dark"] body.admin.com_xxx .stg-modal,
html[data-color-scheme="dark"] body.admin.com_xxx .stg-modal {
    background: #1e1e1e !important;
    color: #e4e4e4 !important;
}
```

Joomla 5 uses `data-color-scheme`; earlier Atum uses `data-bs-theme`. Cover both.

---

## 3. Show/hide modal with jQuery — use `.css('display', 'block')` not `.show()`

`jQuery.show()` removes inline `display:none` by setting `display: ''`, which relies on the default CSS display value for that element. If there's any CSS higher in specificity forcing `display: none`, `.show()` silently fails.

**Safer pattern:**

```js
jQuery('#my_modal').css('display', 'block');
```

Explicit. Overrides inline styles. Always works.

---

## 4. Config page sections: visually distinct fieldsets

Long Joomla admin config pages are hard to scan. Break them into clearly separated fieldsets with labeled legends:

```php
<fieldset class="stg_fieldset">
  <legend><?php echo Text::_('COM_XXX_CONFIG_COMMON_SECTION'); ?></legend>
  <!-- common settings -->
</fieldset>

<fieldset class="stg_fieldset stg_fieldset_advanced">
  <legend><?php echo Text::_('COM_XXX_CONFIG_ADVANCED_SECTION'); ?></legend>
  <p class="stg_section_intro"><?php echo Text::_('COM_XXX_CONFIG_ADVANCED_INTRO'); ?></p>
  <!-- advanced / edge-case settings -->
</fieldset>
```

With styling:

```css
body.admin.com_xxx .stg_fieldset_advanced {
    margin-top: 36px;
    padding-top: 16px;
    border-top: 2px solid rgba(247,144,52,0.25);
}
body.admin.com_xxx .stg_fieldset legend,
body.admin.com_xxx .stg_fieldset_advanced legend {
    color: #f79034;
    font-weight: 600;
    font-size: 1.1em;
}
```

The intro paragraph inside the advanced fieldset gives users context about when/why they'd touch those settings.

---

## 5. Long-label column alignment

If one field label wraps to two lines or stretches far to the right, it pushes its select/input sideways and breaks visual column alignment. Keep labels short — move context into the description (info popover) underneath the field. For example:

- Bad: `<label>Htaccess RewriteBase Adjustment</label>`
- Good: `<label>RewriteBase Adjustment</label>`, with the description text explaining it's specifically for `.htaccess`.

---

## 6. Pre-flight dialog pattern (opt-in fixes before a destructive operation)

For extensions that perform large operations (backups, deploys, syncs), any detectable environmental condition that would break the operation should prompt the user *before* work starts, not surface as a silent post-hoc warning.

Pattern:

1. **Detection endpoint**: an AJAX endpoint that runs lightweight checks and returns a JSON response with per-issue flags (`issue1_detected`, `issue1_preference`, etc.).
2. **Dialog**: a single modal that shows only the sections corresponding to detected issues. Each section has its own "fix it" checkbox plus a "remember my choice on this site" checkbox.
3. **Preference storage**: per-issue, per-site preferences stored in component params (`ask | fix | skip`). `ask` (default) triggers the dialog each run; the other values run silently.
4. **Save preference endpoint**: a separate AJAX action under the same task that accepts GET params like `?issue1=fix&issue2=skip` and writes to the params file.
5. **Runtime opt-in**: when the user checks "fix" without "remember", the deploy proceeds with a URL parameter flag (`?issue1_fix=1`). The server-side deploy init step writes a marker file to signal the later step (finaliseStage, etc.) to apply the fix.

This keeps destructive/irreversible automatic behavior gated behind explicit consent, while also giving users a clean "set and forget" option for sites that always need the same treatment.

---

## 7. Joomlatools Files / Fileman: gotcha with container paths

If an article with Fileman attachments throws `UnexpectedValueException: Invalid folder:` on a staging site:

- The `#__files_containers` table stores container paths as **relative** (e.g. `joomlatools-files/fileman-attachments`), not absolute.
- The path resolves against JPATH_ROOT at runtime.
- The top-level folder (typically `joomlatools-files/`) is NOT part of Joomla core, so subdirectory-staging tools (like StageIt) skip copying it unless explicitly told to.

**Fix:** read the `#__files_containers` table's `path` column, extract unique top-level folder names, check each against your tool's default copy list, and copy any extras recursively from live to staging.

---

## 8. `Invoke-RestMethod` silently fails on Joomla API PATCH

Joomla Web Services API PATCH requests via PowerShell's `Invoke-RestMethod` return `status=200` but don't actually update the article. Likely a content-type or encoding quirk.

**Workaround:** use `curl` with `-d @file.json` for large payloads. The required headers depend on which auth plugin is enabled:

```
Content-Type: application/json
Accept: application/vnd.api+json
X-Joomla-Token: <token>      # Joomla's built-in token auth — preferred
```

For the **Joomla API Token** auth (the default since 4.0), use `X-Joomla-Token: <token>` — `Authorization: Bearer <token>` returns `401 Forbidden`. For **HTTP Basic Auth** the form is `Authorization: Basic base64(user:pass)`. Full reference: `JOOMLA5-WEB-SERVICES-API-GUIDE.md`.

And the Joomla article content field is called `introtext`, NOT `articletext` or `text` — the GET response shows a `text` field (introtext+fulltext concatenated), which misleads many API consumers. Use `introtext` for writes.

---

## 9. `HTMLHelper::_('script', ...)` silently drops `defer` from the `$options` array

`HTMLHelper::_('script', $url, $options, $attribs)` has four arguments and an unforgiving distinction between options and attribs:

- `$options` (3rd) — Joomla-internal flags only: `relative`, `version`, `pathOnly`, `detectBrowser`, `detectDebug`. **Anything else is silently dropped.**
- `$attribs` (4th) — actual HTML attributes that land on the `<script>` tag.

`defer` is an HTML attribute, not a Joomla option. Putting it in `$options` does nothing — no error, no warning, the script just loads without `defer`. Symptom: race conditions where a downstream script runs before the deferred one has parsed the file.

```php
// ❌ defer silently dropped — script loads without it
HTMLHelper::_('script', 'com_x/x.js', [
    'relative' => true,
    'version'  => 'auto',
    'defer'    => true,            // ← in $options, ignored
]);

// ✅ defer in $attribs — actually lands on the tag
HTMLHelper::_(
    'script',
    'com_x/x.js',
    ['relative' => true, 'version' => 'auto'],   // $options
    ['defer' => true]                            // $attribs
);
```

Web Asset Manager's `registerAndUseScript($name, $url, $options, $attribs)` has the same shape, so the rule applies there too.

Belt and braces: if your script genuinely depends on a library (e.g. `window.hljs`), don't trust `defer` ordering across all browsers — also poll for the dependency in the consumer with a short timeout before giving up. Defer is a hint, not a guarantee.
