# Shipped-File Integrity Check

**Standard for every Cybersalt Joomla extension** (Tim, 2026-10-28). Each extension ships a list of its own files with their sizes and SHA-256 hashes. It checks those files on its dashboard or settings page and shows a red "Installation incomplete" alert when an install or update didn't finish.

The tools live in `tools/integrity/`. You build them once here and copy them into each extension.

## Why

Joomla does not roll back a failed update. Files copied before the failure are the new version. The file that failed can be left at **0 bytes**. Everything after it stays at the old version. The site keeps running in that mixed state, and the only symptom is whatever screen happens to load the broken file.

Things that cause it:
- **Imunify360 Proactive Defense** in Kill mode. Its "ef1" rule hashes the last 12 PHP calls. Joomla's `Folder::copy()` walking a folder can match a malware "dropper" pattern, depending on the order the server's filesystem lists that folder. Seen 2026-10-28 on Bjørn's server: MCP for J 2.9.3 → 2.9.4 left `LogsModel.php` at 0 bytes on every site there. It's not tied to one extension; any folder that lists in the wrong order on that disk can trip it.
- A full disk or quota.
- A timed-out upload.
- Wrong ownership on one folder.

Cybersalt's own servers (s11, green) run the free ImunifyAV tier, which has no Proactive Defense, so we never see the Imunify case ourselves. That's why the extension has to tell the site owner.

## What's in `tools/integrity/`

| File | What it does |
|---|---|
| `New-IntegrityList.ps1` | **Build side.** Reads the extension's XML manifest, works out where Joomla installs every file, and writes `integrity.json` into the source folder before zipping. Supports component (site, admin, api), plugin, module, template, library and `<media>`. Skips `<languages>`. |
| `Install-IntegrityCheck.ps1` | Copies the PHP classes into an extension under **its own namespace** and adds the `CS_INTEGRITY_*` strings to its language file. Re-run it whenever the Brain copy changes. |
| `php/IntegrityCheck.php` | `IntegrityCheck::run(array $lists)` compares one or more installed lists with the disk. `IntegrityCheck::renderAlert($result, $productName, $showOk)` returns a Bootstrap alert (escaped; dark-mode safe) listing missing, empty and changed files. |
| `php/IntegrityField.php` | Form field (`type="Integrity"`) for extensions with no dashboard. Shows the same alert, or a green "All N files match" line. |
| `integrity.en-GB.ini` | The language strings. `renderAlert()` falls back to English when a key is missing. |

Each extension gets its **own copy in its own namespace**, so two Cybersalt extensions on one site never load conflicting versions of one class.

## Results

`run()` returns a `status`:
- `ok`: every listed file matches.
- `problems` (red alert): a file is missing or 0 bytes, or a list file itself is damaged. This is a broken install.
- `changed` (yellow alert): files differ in size or hash but nothing is missing. This is either a failed update where the copy didn't truncate the file, or someone edited the files.
- `nolist`: no list is installed (a dev build, or a version from before the check). Nothing is shown.

## Adding it to an extension

The examples below use a package with a component. For a single plugin, module or template, use the root `<files>` block and the field.

1. **Copy the check in:**
   ```powershell
   & "$brain\tools\integrity\Install-IntegrityCheck.ps1" `
       -Destination packages\com_example\admin\src\Integrity `
       -Namespace 'Cybersalt\Component\Example\Administrator\Integrity' `
       -LanguageIni packages\com_example\admin\language\en-GB\com_example.ini
   ```
   For a plugin, module or template, add `-WithField` and use the namespace your fieldset's `addfieldprefix` points at (e.g. `Cybersalt\Plugin\System\Example\Field`, folder `src/Field`).

2. **List the file in every manifest you build a list for.** Components put it in the admin block; everything else uses the root `<files>`:
   ```xml
   <administration>
       <files folder="admin">
           ...
           <filename>integrity.json</filename>
   ```
   ```xml
   <files>
       <folder plugin="example">services</folder>
       <folder>src</folder>
       <filename>integrity.json</filename>
   </files>
   ```
   `New-IntegrityList.ps1` stops the build with the exact line to add if this is missing.

3. **Generate the list in the build script, right before each extension folder is zipped** (after any step that rewrites shipped files):
   ```powershell
   $integrityTool = @(
       (Join-Path $root '.joomla-brain\tools\integrity\New-IntegrityList.ps1'),
       (Join-Path (Split-Path $root -Parent) 'Joomla-Brain\tools\integrity\New-IntegrityList.ps1')
   ) | Where-Object { Test-Path $_ } | Select-Object -First 1
   if (-not $integrityTool) { throw 'Joomla-Brain tools/integrity not found.' }

   & $integrityTool -ExtensionDir $srcPath
   ```
   Templates leave out `*/user.css`, `*/custom.css`, `*/user.js` and `*/custom.js` automatically. Pass `-Exclude 'path/inside/extension'` for any other file the site owner is meant to edit, or that the extension rewrites itself.

4. **Ignore the generated file in git:** add `integrity.json` to `.gitignore`.

5. **Show it.**
   - *Component dashboard:* check **every** extension in the package, because a broken plugin breaks the product too:
     ```php
     $this->integrityAlert = IntegrityCheck::renderAlert(IntegrityCheck::run([
         'administrator/components/com_example/integrity.json',
         'plugins/system/example/integrity.json',
     ]), Text::_('COM_EXAMPLE'));
     ```
     Wrap it in `try { } catch (\Throwable $e) { }`. If the update broke the check class itself, the dashboard must still load. Echo `$this->integrityAlert` at the top of the dashboard template. It's already escaped.
   - *Plugin, module or template settings page:*
     ```xml
     <fieldset name="basic" addfieldprefix="Cybersalt\Plugin\System\Example\Field">
         <field name="integrity" type="Integrity" label="File check"
                lists="plugins/system/example/integrity.json"
                product="PLG_SYSTEM_EXAMPLE" />
     ```

6. **Test once on a sandbox:** install the build, run the check (it should be `ok`), empty one shipped PHP file and reload (red alert naming that file), restore it, and look at the alert in light and dark mode.

## Limits

- It only protects updates **to** a version that ships it. A failed update to that first version still leaves the old dashboard without the check.
- It checks files, not the database.
- A Proactive Defense block can still happen. This check makes it visible and tells the site owner to reinstall and look at the Imunify incident log. Stopping it is the server owner's job: a per-rule ignore, or a false-positive report to CloudLinux.

## First implementation

**cs-mcp-for-j 2.10.0** (2026-10-28). It checks all four extensions in the package (160 files) from the Dashboard. The J6.1.4 sandbox was updated from 2.9.1 to 2.10.0, and every computed install path matched the installed file. These states were all tested: clean, 0-byte file (Bjørn's case), edited file, deleted file, missing list and damaged list.
