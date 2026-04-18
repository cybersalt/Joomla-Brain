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
