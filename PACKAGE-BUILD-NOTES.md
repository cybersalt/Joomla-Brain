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

---

## Joomla Update Server (GitHub-hosted)

To allow Joomla's built-in updater to detect and install new versions, you need three things:

### 1. Manifest XML — add update server and changelog URLs

```xml
<changelogurl>https://raw.githubusercontent.com/OWNER/REPO/main/CHANGELOG.html</changelogurl>
<updateservers>
    <server type="extension" name="Extension Name Updates">https://raw.githubusercontent.com/OWNER/REPO/main/updates.xml</server>
</updateservers>
```

### 2. `updates.xml` — in project root, committed to main branch

```xml
<?xml version="1.0" encoding="utf-8"?>
<updates>
    <update>
        <name>Extension Name</name>
        <description>Short description</description>
        <element>extensionname</element>
        <type>plugin</type>
        <folder>system</folder>
        <client>0</client>
        <version>1.2.2</version>
        <infourl title="Extension Name">https://github.com/OWNER/REPO</infourl>
        <downloads>
            <downloadurl type="full" format="zip">https://github.com/OWNER/REPO/releases/download/v1.2.2/extension_v1.2.2.zip</downloadurl>
        </downloads>
        <sha256>CHECKSUM_HERE</sha256>
        <tags>
            <tag>stable</tag>
        </tags>
        <targetplatform name="joomla" version="5\.[0-9]+" />
        <php_minimum>8.1</php_minimum>
    </update>
</updates>
```

### 3. SHA256 Checksum — REQUIRED to avoid Joomla warning

Without a `<sha256>` element, Joomla shows: *"This extension does not provide a checksum for validation"*

Generate with:
```bash
sha256sum your_extension.zip
```

Then add the hash to `updates.xml` inside the `<update>` block.

### 4. GitHub Release — upload both filenames

The `<downloadurl>` uses a **non-timestamped** filename (e.g., `ext_v1.2.2.zip`), but your build produces a timestamped file. Upload both:

```bash
# Upload timestamped (primary asset)
gh release create v1.2.2 ext_v1.2.2_20260319_1658.zip

# Upload non-timestamped copy (for Joomla updater)
cp ext_v1.2.2_20260319_1658.zip ext_v1.2.2.zip
gh release upload v1.2.2 ext_v1.2.2.zip --clobber
```

### Release workflow summary

1. Bump version in manifest XML
2. Update `CHANGELOG.md`, `CHANGELOG.html`, `README.md` changelog section
3. Build zip with 7-Zip (timestamped name)
4. Generate SHA256 checksum and update `updates.xml`
5. Commit and push all changes
6. Create GitHub Release with both zip filenames attached

---

## Claude Code: Allow Bash Without Prompting

The build process uses chained bash commands (rm, mkdir, cp, 7z.exe, git, gh) that each trigger separate permission prompts. There are two ways to fix this:

### Option 1: Global (Recommended) — All Projects

Add `"Bash"` to the allow array in your **user-level** settings file:

**File:** `C:\Users\Tim\.claude\settings.json`

```json
{
  "permissions": {
    "allow": [
      "Bash"
    ]
  }
}
```

This allows all Bash commands in every project without prompting.

### Option 2: Per-Project

Add a `.claude/settings.local.json` file in the repo root:

```json
{
  "permissions": {
    "allow": [
      "Bash"
    ]
  }
}
```

Add `.claude/settings.local.json` to `.gitignore` since it's a local dev preference. This only applies to the repo it's in.
