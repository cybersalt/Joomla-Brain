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

---

## 10. Modal-trigger fields (`modal_article`, `modal_contact`, etc.) and `showon` don't mix

The `modal_*` family of core fields — `modal_article`, `modal_contact`, `modal_menu`, `modal_user`, etc. — render an input plus a **Select** button that opens a Joomla modal browser. The button-to-modal wiring is done by JavaScript that runs **once at page load** against the rendered DOM.

`showon="some_field:value"` hides a field at page load with `display:none`. The HTML is in the DOM, but the field is invisible. For plain inputs (`text`, `list`, `radio`, `textarea`) this is fine — the browser shows the field instantly when `showon` flips it visible, and there's no JS init to break.

For modal-trigger fields, it's broken: the trigger JS runs against the hidden field at page load and never re-binds when `showon` reveals it. The field becomes visible but the Select button does nothing — visually it looks like an empty input area with no usable picker. The user thinks the field is broken (they're not entirely wrong).

### Symptom

> *"When I switch the dropdown to Article, the description says 'Pick a published article' but there's nothing to pick — no input, no button, nothing."*

### Don't do this

```xml
<field
    name="redirect_type"
    type="list"
    default="url"
>
    <option value="url">URL</option>
    <option value="article">Article</option>
</field>

<field
    name="redirect_url"
    type="text"
    showon="redirect_type:url"
/>

<!-- ❌ Select button never wires up — picker looks empty -->
<field
    name="redirect_article"
    type="modal_article"
    select="true"
    clear="true"
    showon="redirect_type:article"
/>
```

### Do this

Drop `showon` from the modal-trigger field. Render all the conditional fields together in a visually-grouped block (use `<field type="spacer" hr="true" />` to separate the block) and start each description with *"Used when X is …"*. Only the field matching the user's choice is read at runtime.

```xml
<field
    name="redirect_type"
    type="list"
    default="url"
>
    <option value="url">URL</option>
    <option value="article">Article</option>
</field>

<field name="spacer_dest" type="spacer" hr="true" />

<field
    name="redirect_url"
    type="text"
    description="Used when destination type is &quot;URL&quot;..."
/>

<!-- ✅ Always-rendered, Select button works -->
<field
    name="redirect_article"
    type="modal_article"
    select="true"
    clear="true"
    description="Used when destination type is &quot;Article&quot;. Click the Select button to open the article browser..."
/>

<field name="spacer_msg" type="spacer" hr="true" />
```

### Why this is the right tradeoff

The alternative — keeping `showon` and re-initializing the modal trigger after `display` changes — would require shipping JavaScript that listens for showon visibility events and re-runs the modal-trigger init. Joomla doesn't expose a stable API for that, so it's both fragile and a maintenance burden. The cost of "one extra always-visible field" is small; the cost of "the field looks broken" is large.

If you have many modal-trigger fields driven by one selector and the always-visible form gets unwieldy, a fieldset-per-choice with a `subform` or a tab layout is a better escape hatch than per-field `showon`.

### Real bug this caught

cs-registration-redirect v1.1.1 shipped with `showon="redirect_type:article"` on a `modal_article` field. The picker rendered with no Select button. Fixed in v1.1.2 by dropping `showon` from all three destination fields — *but the modal_article picker was still broken because of the next gotcha.*

---

## 11. Article picker in plugin settings: use `type="sql"`, NOT `type="modal_article"`

The `modal_article` field family — `modal_article`, `modal_contact`, `modal_menu`, `modal_user`, etc. — works in module configuration (rendered by `com_modules`) and in article edit forms (rendered by `com_content`), but **silently fails to render its Select button in plugin settings (`com_plugins`)** on Joomla 5/6. The PHP side emits the `<input>`, but the modal-trigger button + browse modal never wire up because `com_plugins` doesn't load the layout/JS bundle these fields depend on.

You see a label, a description, and a useless empty input. No error, no warning. cs-registration-redirect v1.1.2 hit this on Joomla 6.1.

### The reliable workaround: `type="sql"`

The `sql` field is context-agnostic — it just renders a `<select>` populated by a database query:

```xml
<field
    name="redirect_article"
    type="sql"
    label="PLG_..._ARTICLE_LABEL"
    description="PLG_..._ARTICLE_DESC"
    default="0"
    query="SELECT a.id, CONCAT(IFNULL(c.title, '–'), ' / ', a.title) AS title
           FROM #__content AS a
           LEFT JOIN #__categories AS c ON c.id = a.catid
           WHERE a.state = 1
           ORDER BY c.title, a.title"
    key_field="id"
    value_field="title"
>
    <option value="0">- Select an article -</option>
</field>
```

The `IFNULL(c.title, '–')` guards against articles in deleted categories. Prefixing with category title makes the dropdown navigable even with hundreds of articles. For sites with thousands, scope further:

- `LIMIT 500` plus `ORDER BY a.created DESC` — recent articles only
- `WHERE a.featured = 1` — featured articles only
- A separate text-input field where the admin can paste an arbitrary article ID, used as a fallback when the dropdown doesn't include the target

### The same trick for menu items, contacts, users

If `modal_menu`, `modal_contact`, `modal_user` ever fail the same way in plugin settings, swap to `sql` with a query against the corresponding core table:

| Modal field | Replacement query |
|---|---|
| `modal_menu` | `SELECT id, title FROM #__menu WHERE published = 1 AND client_id = 0 ORDER BY title` |
| `modal_contact` | `SELECT id, name FROM #__contact_details WHERE published = 1 ORDER BY name` |
| `modal_user` | `SELECT id, name FROM #__users WHERE block = 0 ORDER BY name` |

Note: `type="menuitem"` is a separate field type from `modal_menu` and DOES work in plugin settings — use that for menu item selection. The table above is for the modal variants.

---

## 12. Cybersalt action-button palette (Tim's preferred colors)

Established on `cs-template-integrity` v2.1 after several rounds of "this button doesn't read right." When pairing two primary actions on an admin dashboard (e.g. "Method 1 / Method 2", or "Manual / Automated"), Tim's preferred combo is **Cybersalt orange + Bootstrap blue** — reads well in both light and dark mode, doesn't read as a warning, and the two colors don't compete with each other.

| Role | Class | Color | Notes |
|---|---|---|---|
| Primary action A (always available, no precondition) | custom `.csti-method-1-btn` | `#dc6b1a` solid + white text | "Cybersalt orange". Hover: `#b85614`. Tim explicitly prefers this over `btn-warning` because yellow reads as caution, not action. |
| Primary action B (preferred path when ready) | `btn-primary` | Bootstrap blue + white text | When the action requires precondition (e.g. saved API key) AND it's met, use solid `btn-primary`. |
| Primary action B (precondition not met) | `btn-outline-secondary` | Gray outline | Stays clickable so the link can still anchor-jump to the explanation card. Tooltip says what's missing. |
| Navigation ("go fetch data") | `btn-secondary` | Gray | Sessions, Backups, Site Templates, Action log — anything that's just a link to another view. Tim specifically does NOT want these to be `btn-primary` / `btn-warning` / `btn-light` — they shouldn't compete with the primary actions or look like warnings. |
| Destructive / "you sure?" rebuilds | custom `.csti-rescan-btn` | Mode-aware (see below) | Things like Rescan, Reset, Rebuild. |
| Diagnostics / info modal trigger | `btn-info` | Cyan | One-off "open the diag panel" — fine as `btn-info`. |

### Avoid

- `btn-warning` (yellow solid) for non-warning primary actions — Tim explicitly disliked this. Yellow reads as caution.
- `btn-outline-warning` for buttons that need to read in **light** mode — yellow text on white background is unreadable. Outline-warning works fine in dark mode (yellow-on-black) but flips to bad contrast in light mode.
- `btn-light` in admin dashboards — Atum dark mode renders it as a tinted blue-gray with dark text; the contrast is poor. Use `btn-secondary` instead for neutral nav buttons.

### Mode-aware Rescan button (the `.csti-rescan-btn` recipe)

For destructive/rebuild actions you want to read as a warning in dark mode but stay readable in light mode:

```css
.btn.csti-rescan-btn {
    background-color: var(--bs-warning, #ffc107);
    border-color: var(--bs-warning, #ffc107);
    color: #212529;
}
[data-bs-theme="dark"] .btn.csti-rescan-btn,
[data-color-scheme="dark"] .btn.csti-rescan-btn {
    background-color: transparent;
    color: var(--bs-warning, #ffc107);
    border-color: var(--bs-warning, #ffc107);
}
```

Light mode = solid yellow with default dark text (high contrast, reads as warning).
Dark mode = outline look, yellow text on near-black background (high contrast, reads as warning, matches Atum's "danger zone" aesthetic).

Joomla's Atum admin uses `[data-bs-theme="dark"]` AND `[data-color-scheme="dark"]` — target both selectors so the rule fires regardless of which attribute the active template applies.

### Cybersalt orange button (the `.csti-method-1-btn` recipe)

```css
.btn.csti-method-1-btn {
    background-color: #dc6b1a;
    border-color: #dc6b1a;
    color: #ffffff;
}
.btn.csti-method-1-btn:hover,
.btn.csti-method-1-btn:focus,
.btn.csti-method-1-btn:active {
    background-color: #b85614;
    border-color: #b85614;
    color: #ffffff;
}
.btn.csti-method-1-btn:focus-visible {
    box-shadow: 0 0 0 0.25rem rgba(220, 107, 26, 0.35);
}
```

Specificity: prefix the selector with `.btn` (so it's `.btn.csti-method-1-btn`, two classes) so it wins over Bootstrap's `.btn` defaults without needing `!important`.
