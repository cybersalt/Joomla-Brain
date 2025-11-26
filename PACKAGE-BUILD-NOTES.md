# Joomla 5 Plugin Package Build Notes

## CRITICAL: Use 7-Zip for Creating ZIP Packages

**Windows PowerShell's `Compress-Archive` and .NET's `ZipFile.CreateFromDirectory` do NOT create proper directory entries in ZIP files.** This causes Joomla installer to fail with:

```
Warning: file_put_contents(.../language/index.html): Failed to open stream: No such file or directory
```

### The Fix: Always Use 7-Zip

```powershell
# From the build folder
Set-Location 'path\to\build'
& 'C:\Program Files\7-Zip\7z.exe' a -tzip '..\plugin_name.zip' *
```

7-Zip properly creates directory entries (shown as `D....` in listing), which Joomla needs to create folders before extracting files into them.

---

## Plugin Manifest Structure (Joomla 5)

### Minimal Working Manifest

```xml
<?xml version="1.0" encoding="UTF-8"?>
<extension type="plugin" group="content" method="upgrade" version="5.0">
  <name>plg_content_myplugin</name>
  <author>Your Name</author>
  <version>1.0.0</version>
  <description>Plugin description</description>
  <files>
    <filename plugin="myplugin">myplugin.php</filename>
    <filename>index.html</filename>
    <folder>language</folder>
  </files>
  <config>
    <fields name="params">
      <fieldset name="basic" label="Settings">
        <!-- fields here -->
      </fieldset>
    </fields>
  </config>
</extension>
```

### Key Points

1. **Extension tag attributes**: `type="plugin" group="content" method="upgrade" version="5.0"`
   - NO `element` attribute needed
   - `version="5.0"` is the manifest version, not Joomla version

2. **Manifest filename**: Can be `myplugin.xml` or `plg_content_myplugin.xml` - both work

3. **Plugin attribute**: `<filename plugin="myplugin">` - the `plugin` attribute value becomes the plugin's element name

4. **DO NOT use `<languages>` section** for plugins that keep language files within the plugin folder. Just use:
   ```xml
   <folder>language</folder>
   ```
   Combined with `protected $autoloadLanguage = true;` in PHP class.

5. **Language file naming**: Use `plg_content_myplugin.ini` (no `en-GB.` prefix when inside plugin folder)

---

## Directory Structure

```
plugin_folder/
├── myplugin.xml              # Manifest
├── myplugin.php              # Main plugin class
├── index.html                # Security blank file
└── language/
    ├── index.html
    └── en-GB/
        ├── index.html
        └── plg_content_myplugin.ini
```

---

## Common Installation Errors

### "Unexpected token '<'... is not valid JSON"

**Cause**: PHP is outputting HTML warnings/errors before the JSON response.

**Debug**: Check browser dev tools Network tab → look at actual response body.

**Common causes**:
- Missing directory in ZIP (use 7-Zip!)
- Language file path mismatch between manifest and actual file
- PHP syntax error in plugin file
- BOM characters in files

### "Unable to detect manifest file"

**Causes**:
- Manifest XML has syntax error
- Files referenced in manifest don't exist in ZIP
- ZIP doesn't have proper directory entries

### "Failed to open stream: No such file or directory"

**Cause**: ZIP was created without directory entries. Joomla tries to write a file before the parent directory exists.

**Fix**: Use 7-Zip to create the ZIP.

---

## File Encoding

- All files must be UTF-8 **without BOM**
- Check first bytes: should NOT start with `239,187,191` (BOM)
- PHP files should start with `60,63,112,104,112` (`<?php`)
- XML files should start with `60,63,120,109,108` (`<?xml`)

---

## Radio/Toggle Fields

Use `class="btn-group btn-group-yesno"` for Yes/No toggles:

```xml
<field name="enable_feature" type="radio" label="Enable Feature"
       class="btn-group btn-group-yesno" default="1">
  <option value="1">JYES</option>
  <option value="0">JNO</option>
</field>
```

The `layout="joomla.form.field.radio.switcher"` also works but the class method is more compatible.

---

## Build Script Example

```powershell
# build-plugin.ps1
$pluginName = "csautogallery"
$buildDir = "build"
$zipName = "plg_content_$pluginName.zip"

# Clean
Remove-Item $zipName -Force -ErrorAction SilentlyContinue

# Create ZIP with 7-Zip (REQUIRED for proper directory entries)
Set-Location $buildDir
& 'C:\Program Files\7-Zip\7z.exe' a -tzip "..\$zipName" *
Set-Location ..

Write-Host "Created $zipName"
```
