# Joomla 5 Plugin Package Build Notes

## Package Naming Convention

**ALWAYS include version number AND timestamp in package filenames** for easy sorting and identification of the latest build:

```
{extension_name}_v{version}_{YYYYMMDD}_{HHMM}.zip
```

**Examples:**
- `com_csdiskusage_v1.0.0_20260203_1425.zip`
- `plg_system_routertracer_v1.2.0_20260203_0930.zip`
- `mod_worldclocks_v2.1.0_20260203_1600.zip`

**Why timestamps matter:**
- Sorts chronologically in file explorers
- Instantly identifies the most recent build
- Prevents confusion when testing multiple iterations
- Helps track which build is installed on a site

---

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

## Plugin & Module Structure

For full manifest and file structure details, see:
- **Plugins**: `JOOMLA5-PLUGIN-GUIDE.md`
- **Modules**: `JOOMLA5-MODULE-GUIDE.md`
- **Components**: `COMPONENT-TROUBLESHOOTING.md`

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

## Package Output Location

**Always place built ZIP packages in the project root directory**, not in a `dist/` or `build/` subfolder. This keeps things simple and matches the build script examples below which output to `..` (parent of the build folder, i.e., project root).

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
