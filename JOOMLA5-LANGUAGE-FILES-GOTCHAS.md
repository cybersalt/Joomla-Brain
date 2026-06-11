# Joomla 5/6 Language File Gotchas

Hard-won lessons about how Joomla actually loads language files at runtime vs. where you put them at install time. If your translations aren't showing, start here.

---

## 1. Where Joomla ACTUALLY loads component language files from

Joomla looks for component language files in **two** places. The priority order matters:

1. **System location (preferred)**: `administrator/language/{tag}/{tag}.com_yourcomponent.ini`
2. **Component-bundled location**: `administrator/components/com_yourcomponent/language/{tag}/{tag}.com_yourcomponent.ini`

When you install a package, Joomla copies the component's bundled language files **into the system location**. The system location is what actually gets loaded at runtime. The component-bundled copies become effectively dormant reference files.

**The gotcha:** if you manually push updated language files to a site via FTP during development, updating only the component-bundled copy will do nothing. You must update the system copy (`administrator/language/{tag}/`) — or both.

For `com_xxx` component extensions:
- Runtime load path: `administrator/language/{tag}/{tag}.com_xxx.ini`
- Sys/Extension Manager display path: `administrator/language/{tag}/{tag}.com_xxx.sys.ini`

Always update both `.ini` and `.sys.ini` copies in the system folder when hot-patching.

---

## 2. Plugin language files need BOTH `.ini` AND `.sys.ini`

A common shipping bug: plugin's name and description show as raw language keys (`PLG_SYSTEM_XYZ`, `PLG_SYSTEM_XYZ_DESCRIPTION`) in Extensions → Manage.

Cause: the plugin manifest XML did not declare the `.sys.ini` file, so Joomla had nothing to load when rendering the Extensions Manager list.

**Fix:** your plugin's `stageit.xml` (or similar) needs both language files declared:

```xml
<languages folder="language">
    <language tag="en-GB">en-GB/en-GB.plg_system_xxx.ini</language>
    <language tag="en-GB">en-GB/en-GB.plg_system_xxx.sys.ini</language>
</languages>
```

And both files must exist inside the plugin directory at `plugins/system/xxx/language/{tag}/`. At install time, Joomla copies them to `administrator/language/{tag}/`.

---

## 2b. Plugin field labels shown in OTHER edit screens: call `$this->loadLanguage()` in `onContentPrepareForm`

**Symptom:** the plugin's field labels render correctly on the plugin's own settings screen (System &rarr; Plugins &rarr; *Edit*), but the same constants render as raw `PLG_SYSTEM_XYZ_FIELD_FOO_LABEL` placeholders when the plugin injects fields into a *different* component's edit form. Common case: a system plugin that uses `onContentPrepareForm` to add a tab to `com_menus.item`, `com_content.article`, `com_modules.module`, etc. The fields appear, but the labels are constants.

**Cause:** Joomla loads a plugin's language files automatically when *the plugin itself is being rendered* (its own settings screen, or when the plugin executes at runtime). When the plugin's `onContentPrepareForm` event fires inside another component's edit screen, the *other* component's language is loaded — `com_menus`, `com_content`, `com_modules` — but the plugin's own `.ini` / `.sys.ini` are NOT auto-loaded in that context. So the injected fields' label constants resolve to nothing.

**Fix:** call `$this->loadLanguage()` inside the `onContentPrepareForm` handler before you inject the form. `CMSPlugin::loadLanguage()` loads both the `.ini` and `.sys.ini` for the plugin in the current language. One line, fixes the whole thing:

```php
public function onContentPrepareForm(Event $event): void
{
    $form = $event->getArgument('0');
    if (!$form instanceof Form) {
        return;
    }
    if ($form->getName() !== 'com_menus.item') {
        return;
    }

    // Other component's edit screen does NOT auto-load this plugin's
    // language; without this call, every injected field label renders
    // as its raw PLG_SYSTEM_XYZ_FIELD_*_LABEL constant.
    $this->loadLanguage();

    Form::addFormPath(__DIR__ . '/../Form/forms');
    $form->loadFile('menuitem', false);
}
```

**Belt-and-braces:** still keep your installer/postflight strings in `.sys.ini` — the postflight runs in the installer context, where `.ini` is not loaded. So the `.sys.ini` superset pattern (every user-visible string lives in `.sys.ini`) is still useful for install-card copy, even though `loadLanguage()` covers the form-injection case.

**Confirmed test:** `cs-menu-item-conditions` v0.1.0 first ship was missing the `loadLanguage()` call in `onContentPrepareForm`. Moving every label to `.sys.ini` did NOT fix the menu item edit screen (Joomla didn't load `.sys.ini` in that context either). Adding `$this->loadLanguage()` fixed it (2026-05-06).

---

## 3. INI file encoding: avoid em-dashes; use HTML entities

Symptom: language keys are defined in the file, but Joomla's INI parser stops reading partway through, so every key defined AFTER the break shows as the raw key.

Cause: certain UTF-8 characters get double-encoded when the file passes through some hosts' file managers / cPanel APIs / FTP clients. The em-dash `—` (U+2014, bytes `E2 80 94`) turns into mojibake `â€"` when its three bytes are interpreted as Latin-1 and re-encoded as UTF-8. The parser may then fail on malformed sequences.

**Fix:** never use raw em-dashes (or curly quotes) inside INI values. Use HTML entities, because Joomla renders these values as HTML anyway:

- `—` → `&mdash;`
- `'` → `&rsquo;` or `&#x2019;`
- `"` → `&ldquo;` / `&rdquo;` or `&#x201C;` / `&#x201D;`

The ASCII-safe result parses cleanly on every host.

---

## 4. INI parsing rules you'll trip over

- **Values must be wrapped in plain ASCII double quotes** (`"..."`). Smart/curly quotes (`"..."`) inside the wrapper break parsing.
- **Don't use an internal unescaped double quote** inside a value. If you need one, use `&quot;` or switch the wrapper to single quotes (Joomla's parser supports both).
- **Single quotes (apostrophes) inside double-quoted values are safe.** `"StageIt's folder"` is fine.
- **Leading whitespace before a key is tolerated** but makes grep patterns finicky; keep keys flush-left.

Test before shipping: run `php -l en-GB.com_yourcomponent.ini` won't catch INI issues, but Joomla's `JLanguage::load()` will silently skip keys after a parse error. If a known key shows as raw `COM_XXX_SOMETHING`, check every key DEFINED ABOVE it for malformed characters.

---

## 5. When building a package, include both `.ini` and `.sys.ini` at the package level

For a package extension with `<packagename>xxx</packagename>`, declare the package language strings:

```xml
<languages folder="language">
    <language tag="en-GB">en-GB/en-GB.pkg_xxx.sys.ini</language>
    <language tag="en-GB">en-GB/en-GB.plg_system_xxx.ini</language>
    <language tag="en-GB">en-GB/en-GB.plg_system_xxx.sys.ini</language>
    ...
</languages>
```

…even if the plugin's own XML also declares those same files. Duplicate declarations are harmless; missing declarations silently break translation in the Extensions Manager list and the package info panel.

---

## 6. Shim missing Joomla CORE language keys from your own plugin's `.ini`

Joomla's core language packs occasionally ship missing newer string keys. The screen renders the raw key name instead of the translated value — e.g. `COM_SCHEDULER_PARAMETERS_FIELDSET_LABEL` showing as a literal label on the Scheduled Tasks edit screen on some Joomla 5.x point releases.

**Workaround**: define the missing core key in your *own* plugin/component's `.ini` file. Joomla's translation lookup pulls from a single global string pool, so any loaded `.ini` providing the key will resolve it.

```ini
; In plg_task_yourplugin.ini, shimming a com_scheduler core key
; that was missing on Joomla 5.0–5.1 en-GB packs:
COM_SCHEDULER_PARAMETERS_FIELDSET_LABEL="Parameters"
```

**Why this is safe**:

- If the user's Joomla version DOES ship the key, the core pack's value wins (later-loaded `.ini` files don't override earlier ones unless explicitly merged).
- If the key is missing, your shim resolves it.
- Either way the user sees a translated string instead of a raw key.

**Discovered in `cs-template-integrity` v2.4.0** while building `plg_task_cstemplateintegrity`. The Joomla 5.x en-GB pack on the test site was missing `COM_SCHEDULER_PARAMETERS_FIELDSET_LABEL`. Defining it in the plugin's own `.ini` fixed the display without touching core files or shipping a custom language pack.

**Don't abuse this**: shim only well-known core keys that are *clearly* missing on the user's install. Shimming arbitrary `COM_*` keys to override Joomla's own values is risky (load order can flip between versions, your "override" may break on a different Joomla install). The use case is strictly "Joomla forgot to ship this string in this language for this version."

---

## 7. Component submenu strings MUST be in `.sys.ini`, not just `.ini`

**Symptom**: your component's parent label in the Joomla admin sidebar translates fine ("MCP for Joomla"), but the submenu items underneath show raw constants like `COM_CSMCPFORJ_SUBMENU_DASHBOARD` / `COM_CSMCPFORJ_SUBMENU_CATALOG` — but ONLY when you're viewing OTHER admin pages (Components → Maximenu CK, Extensions → Manage, etc.). When you're inside your own component, the submenu translates correctly. It looks like a phantom bug.

**Why**: Joomla loads `<componentname>.ini` only when the user is currently inside that component. For the admin chrome (sidebar menu, plugin manager, extension manager rows) on every OTHER page, it only loads `<componentname>.sys.ini`. The parent label string (e.g. `COM_CSMCPFORJ`) is conventionally in `.sys.ini` so it always translates. The submenu strings often get put in `.ini` only because that's the "main" language file — and that's the bug.

**Fix**: duplicate every submenu string into `.sys.ini` as well. Joomla loads both when you're inside the component, so the strings are still translated there.

```ini
; In com_yourthing.sys.ini — must be here so the admin sidebar can
; translate the submenu labels when the user is anywhere OTHER than
; inside this component.
COM_YOURTHING="Your Component"
COM_YOURTHING_SUBMENU_DASHBOARD="Dashboard"
COM_YOURTHING_SUBMENU_SETTINGS="Settings"
```

This applies to any component-defined string that appears in Joomla's admin chrome:

- `<submenu>` entries in the component manifest
- ACL action titles in `access.xml` (`COM_YOURTHING_ACTION_*`)
- The component's own display name in Extensions → Manage

**Discovered in `cs-mcp-for-j` v1.10.2** when Tim noticed the catalog/dashboard submenu items rendered as raw constants in the sidebar from the Maximenu CK admin page. The strings were defined in `com_csmcpforj.ini` but not in `com_csmcpforj.sys.ini`. Adding the duplicates to `.sys.ini` fixed it instantly.

**Don't move, duplicate**: don't *move* the strings from `.ini` to `.sys.ini` — the `.ini` is still where component-internal screens read translations from. Duplicate, even though it feels wrong. Joomla's translation lookup deduplicates on lookup, so the duplicate doesn't waste memory or cause conflicts.
