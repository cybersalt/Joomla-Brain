# Joomla 5 Component Troubleshooting Guide

## Diagnostic Script

When experiencing component installation/loading issues, use this diagnostic script to identify the problem:

```php
<?php
/**
 * Component Diagnostic Tool
 * Upload to Joomla root and access via browser
 */
define('_JEXEC', 1);
define('JPATH_BASE', __DIR__);

require_once JPATH_BASE . '/includes/defines.php';
require_once JPATH_BASE . '/includes/framework.php';

$componentName = 'com_yourcomponent'; // Change this
$componentPath = JPATH_ADMINISTRATOR . '/components/' . $componentName;

echo "<h1>Component Diagnostic: $componentName</h1><pre>";

// 1. Check files exist
echo "=== File Structure ===\n";
$requiredPaths = [
    'src/Extension',
    'services',
    'tmpl'
];

foreach ($requiredPaths as $path) {
    $fullPath = $componentPath . '/' . $path;
    echo is_dir($fullPath) ? "✓ " : "✗ ";
    echo "$path\n";
}

// 2. Check namespace registration
echo "\n=== Database Registration ===\n";
$db = \Joomla\CMS\Factory::getDbo();
$query = $db->getQuery(true)
    ->select('manifest_cache')
    ->from('#__extensions')
    ->where($db->quoteName('element') . ' = ' . $db->quote($componentName));
$db->setQuery($query);
$manifestCache = $db->loadResult();

if ($manifestCache) {
    $manifest = json_decode($manifestCache, true);
    echo "Namespace: " . ($manifest['namespace'] ?? 'NOT SET') . "\n";
    print_r($manifest['namespace']);
} else {
    echo "✗ Component not found in database\n";
}

// 3. Check autoload cache
echo "\n=== Autoload Cache ===\n";
$autoloadFile = JPATH_ADMINISTRATOR . '/cache/autoload_psr4.php';
if (file_exists($autoloadFile)) {
    $autoload = require $autoloadFile;
    foreach ($autoload as $namespace => $path) {
        if (strpos($namespace, str_replace('com_', '', $componentName)) !== false) {
            $pathStr = is_array($path) ? json_encode($path) : $path;
            echo "Found: $namespace => $pathStr\n";
        }
    }
} else {
    echo "✗ Autoload cache missing (will regenerate on next load)\n";
}

echo "</pre>";
```

## Step-by-Step Troubleshooting

### Step 1: Identify the Error Type

#### "Class not found"
- **Namespace issue** → See [Namespace Troubleshooting](#namespace-troubleshooting)
- **Autoload cache** → See [Cache Issues](#cache-issues)

#### "Call to undefined method"
- **API compatibility** → See [API Changes](#api-compatibility-issues)

#### "Layout not found"
- **Template structure** → See [Template Issues](#template-structure-issues)

### Step 2: Check Manifest Configuration

**Correct component manifest structure:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="component" version="5.0" method="upgrade">
    <name>COM_COMPONENTNAME</name>
    <version>1.0.0</version>
    <description>COM_COMPONENTNAME_XML_DESCRIPTION</description>

    <!-- CRITICAL: No \Administrator suffix here -->
    <namespace path="src">Joomla\Component\ComponentName</namespace>

    <!-- Installation script for cache clearing -->
    <scriptfile>script.php</scriptfile>

    <administration>
        <menu>COM_COMPONENTNAME</menu>

        <!-- CRITICAL: folder="admin" attribute -->
        <files folder="admin">
            <folder>services</folder>
            <folder>src</folder>
            <folder>tmpl</folder>
        </files>

        <!-- CRITICAL: folder path includes "admin/" -->
        <languages folder="admin/language">
            <language tag="en-GB">en-GB/com_componentname.ini</language>
            <language tag="en-GB">en-GB/com_componentname.sys.ini</language>
        </languages>
    </administration>
</extension>
```

### Step 3: Verify Package Structure

Extract your component ZIP and verify structure:

```
com_componentname.zip
├── componentname.xml          ← Manifest at root
├── script.php                 ← Installation script at root
└── admin/                     ← All files in admin folder
    ├── services/
    │   └── provider.php
    ├── src/
    │   ├── Extension/
    │   │   └── ComponentNameComponent.php
    │   ├── Controller/
    │   ├── Model/
    │   └── View/
    │       └── Items/
    │           └── HtmlView.php
    └── tmpl/
        └── items/             ← Subdirectory matches view name!
            └── default.php
```

**Common mistakes:**
- ❌ Files at root level instead of in `admin/`
- ❌ Templates at `tmpl/default.php` instead of `tmpl/viewname/default.php`
- ❌ Missing `script.php` at root level

---

## Namespace Troubleshooting

### Problem: Double "Administrator" in Namespace

**Symptoms:**
```
Joomla\Component\Name\Administrator\Administrator\Extension\...
```

**Diagnosis:**
Run diagnostic script and check autoload cache output.

**Fix:**
```xml
<!-- BEFORE (Wrong) -->
<namespace path="src">Joomla\Component\Name\Administrator</namespace>

<!-- AFTER (Correct) -->
<namespace path="src">Joomla\Component\Name</namespace>
```

**Why:** Joomla automatically appends `\Administrator` when the namespace is inside `<administration>` section.

### Problem: Namespace Not Registered

**Symptoms:**
- Diagnostic shows "Namespace: NOT SET"
- Class not found even with correct file structure

**Diagnosis:**
```sql
SELECT manifest_cache FROM `#__extensions`
WHERE element = 'com_yourcomponent';
```

**Fix:**
1. Uninstall component completely
2. Fix manifest XML
3. Rebuild package
4. Reinstall

**Prevention:** Add to `script.php`:
```php
public function postflight($type, $parent) {
    // Force cache regeneration
    $cacheFile = JPATH_ADMINISTRATOR . '/cache/autoload_psr4.php';
    if (file_exists($cacheFile)) {
        @unlink($cacheFile);
    }
}
```

---

## Cache Issues

### Stale Autoload Cache

**Symptoms:**
- Component installs successfully
- Files are in correct locations
- Still get "Class not found"
- Manual deletion of cache fixes it temporarily

**Permanent Solution:**

Create `script.php` in component root:

```php
<?php
defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Installer\InstallerAdapter;

class Com_ComponentnameInstallerScript
{
    protected function clearAutoloadCache()
    {
        $cacheFile = JPATH_ADMINISTRATOR . '/cache/autoload_psr4.php';

        if (file_exists($cacheFile)) {
            try {
                @unlink($cacheFile);
            } catch (\Exception $e) {
                Factory::getApplication()->enqueueMessage(
                    'Please manually delete administrator/cache/autoload_psr4.php',
                    'warning'
                );
            }
        }
    }

    public function postflight($type, $parent)
    {
        $this->clearAutoloadCache();
        return true;
    }

    public function uninstall($parent)
    {
        $this->clearAutoloadCache();
        return true;
    }
}
```

**Add to manifest:**
```xml
<scriptfile>script.php</scriptfile>
```

---

## API Compatibility Issues

### Pagination API Changes

| Joomla 3/4 (Method) | Joomla 5 (Property) |
|---------------------|---------------------|
| `$pagination->getTotal()` | `$pagination->total` |
| `$pagination->getLimitStart()` | `$pagination->limitstart` |
| `$pagination->getLimit()` | `$pagination->limit` |
| `$pagination->getPagesTotal()` | `$pagination->pagesTotal` |

**Still works in J5:**
- `$pagination->getListFooter()` (but consider `getPaginationLinks()`)

### Service Provider Changes

**Removed in J5:**
```php
// Don't use these anymore
$component->setRegistry($container->get(Registry::class));
```

**Current J5 pattern:**
```php
use Joomla\CMS\Dispatcher\ComponentDispatcherFactoryInterface;
use Joomla\CMS\Extension\ComponentInterface;
use Joomla\CMS\MVC\Factory\MVCFactoryInterface;

$container->set(
    ComponentInterface::class,
    function (Container $container) {
        $component = new ComponentNameComponent(
            $container->get(ComponentDispatcherFactoryInterface::class)
        );
        $component->setMVCFactory($container->get(MVCFactoryInterface::class));
        return $component;
    }
);
```

---

## Template Structure Issues

### View-to-Template Mapping

**The Rule:** Template path must match view namespace

```php
// View class:
namespace Joomla\Component\Name\Administrator\View\Articles;
class HtmlView extends BaseHtmlView { }

// Template location:
tmpl/articles/default.php  ✓ CORRECT

// Common mistakes:
tmpl/default.php          ✗ WRONG - no view subdirectory
tmpl/Article/default.php  ✗ WRONG - wrong case (Articles vs Article)
```

**Multiple layouts:**
```
tmpl/
├── articles/
│   ├── default.php      → Main list view
│   └── modal.php        → Modal layout
└── article/
    └── edit.php         → Edit form
```

### Layout Override Path

For template overrides:
```
templates/yourtemplate/html/com_componentname/articles/default.php
                            └─────┬─────┘ └───┬──┘
                             component    view name
```

---

## Build Script Best Practices

**PowerShell build script template:**

```powershell
# Create admin folder in component package
New-Item -ItemType Directory -Path "temp_component\admin" -Force

# Copy manifest to root
Copy-Item "componentname.xml" -Destination "temp_component\componentname.xml"

# Copy script.php to root
Copy-Item "administrator\components\com_name\script.php" -Destination "temp_component\script.php"

# Copy all admin files to admin folder
Copy-Item "administrator\components\com_name\*" -Destination "temp_component\admin\" -Recurse

# Create ZIP with forward slashes (required for Joomla)
# Use custom ZIP function, not Compress-Archive
```

**Critical:** Use forward slashes in ZIP paths, not backslashes.

---

## Workflow System Issues After J3→J4/J5 Migration

### Problem: Articles Not Showing in Article Manager

After migrating from Joomla 3 to Joomla 4/5, articles may not appear in the Article Manager. This is caused by a missing or incomplete workflow system.

**Root Cause:** The Joomla 3→4 migration may fail to create some or all of the 4 workflow tables, or fail to populate them with default records. Without these, Joomla cannot process article workflows and articles become invisible in the Article Manager.

### The 4 Workflow Tables

Joomla 5 uses exactly 4 workflow tables:

| Table | Purpose | Default Records |
|-------|---------|-----------------|
| `#__workflows` | Workflow definitions | 1 record: "COM_WORKFLOW_BASIC_WORKFLOW" for `com_content.article` |
| `#__workflow_stages` | Workflow stages | 1 record: "COM_WORKFLOW_BASIC_STAGE" (id=1, workflow_id=1) |
| `#__workflow_transitions` | Stage transitions | 7 records: Unpublish, Publish, Trash, Archive, Feature, Unfeature, Publish & Feature |
| `#__workflow_associations` | Per-article stage assignments | 1 record per article (item_id, stage_id=1, extension='com_content.article') |

### Diagnosis

Check via phpMyAdmin or database manager:

```sql
-- Check if tables exist
SHOW TABLES LIKE '%workflow%';

-- Check for default workflow record
SELECT * FROM #__workflows WHERE extension = 'com_content.article';

-- Check for default stage
SELECT * FROM #__workflow_stages WHERE workflow_id = 1;

-- Check for transitions (should be 7)
SELECT COUNT(*) FROM #__workflow_transitions WHERE workflow_id = 1;

-- Check for articles missing associations
SELECT COUNT(*) FROM #__content c
WHERE NOT EXISTS (
    SELECT 1 FROM #__workflow_associations wa WHERE wa.item_id = c.id
);
```

### Fix: Restore Missing Tables

```sql
-- Create workflow_stages if missing
CREATE TABLE IF NOT EXISTS `#__workflow_stages` (
    `id` int NOT NULL AUTO_INCREMENT,
    `asset_id` int DEFAULT 0,
    `ordering` int NOT NULL DEFAULT 0,
    `workflow_id` int NOT NULL,
    `published` tinyint NOT NULL DEFAULT 0,
    `title` varchar(255) NOT NULL,
    `description` text NOT NULL,
    `default` tinyint NOT NULL DEFAULT 0,
    `checked_out_time` datetime DEFAULT NULL,
    `checked_out` int unsigned DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_workflow_id` (`workflow_id`),
    KEY `idx_checked_out` (`checked_out`),
    KEY `idx_title` (`title`(191)),
    KEY `idx_asset_id` (`asset_id`),
    KEY `idx_default` (`default`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

-- Create workflow_transitions if missing
CREATE TABLE IF NOT EXISTS `#__workflow_transitions` (
    `id` int NOT NULL AUTO_INCREMENT,
    `asset_id` int DEFAULT 0,
    `ordering` int NOT NULL DEFAULT 0,
    `workflow_id` int NOT NULL,
    `published` tinyint NOT NULL DEFAULT 0,
    `title` varchar(255) NOT NULL,
    `description` text NOT NULL,
    `from_stage_id` int NOT NULL,
    `to_stage_id` int NOT NULL,
    `options` text NOT NULL,
    `checked_out_time` datetime DEFAULT NULL,
    `checked_out` int unsigned DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_title` (`title`(191)),
    KEY `idx_asset_id` (`asset_id`),
    KEY `idx_checked_out` (`checked_out`),
    KEY `idx_from_stage_id` (`from_stage_id`),
    KEY `idx_to_stage_id` (`to_stage_id`),
    KEY `idx_workflow_id` (`workflow_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;

-- Create workflow_associations if missing
CREATE TABLE IF NOT EXISTS `#__workflow_associations` (
    `item_id` int NOT NULL DEFAULT 0,
    `stage_id` int NOT NULL,
    `extension` varchar(50) NOT NULL,
    PRIMARY KEY (`item_id`, `extension`),
    KEY `idx_item_id` (`item_id`),
    KEY `idx_stage_id` (`stage_id`),
    KEY `idx_extension` (`extension`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;
```

### Fix: Insert Default Records

```sql
-- Default workflow
INSERT IGNORE INTO #__workflows
    (id, asset_id, published, title, description, extension, `default`, ordering, created, created_by, modified, modified_by)
VALUES
    (1, 0, 1, 'COM_WORKFLOW_BASIC_WORKFLOW', '', 'com_content.article', 1, 1, NOW(), 0, NOW(), 0);

-- Default stage
INSERT IGNORE INTO #__workflow_stages
    (id, asset_id, ordering, workflow_id, published, title, description, `default`)
VALUES
    (1, 0, 1, 1, 1, 'COM_WORKFLOW_BASIC_STAGE', '', 1);

-- Default transitions (all use from_stage_id=-1 meaning "any stage", to_stage_id=1)
INSERT IGNORE INTO #__workflow_transitions (id, asset_id, published, ordering, workflow_id, title, description, from_stage_id, to_stage_id, options) VALUES
    (1, 0, 1, 1, 1, 'UNPUBLISH', '', -1, 1, '{"publishing":"0"}'),
    (2, 0, 1, 2, 1, 'PUBLISH', '', -1, 1, '{"publishing":"1"}'),
    (3, 0, 1, 3, 1, 'TRASH', '', -1, 1, '{"publishing":"-2"}'),
    (4, 0, 1, 4, 1, 'ARCHIVE', '', -1, 1, '{"publishing":"2"}'),
    (5, 0, 1, 5, 1, 'FEATURE', '', -1, 1, '{"featuring":"1"}'),
    (6, 0, 1, 6, 1, 'UNFEATURE', '', -1, 1, '{"featuring":"0"}'),
    (7, 0, 1, 7, 1, 'PUBLISH_AND_FEATURE', '', -1, 1, '{"publishing":"1","featuring":"1"}');

-- Create associations for articles that don't have them
INSERT INTO #__workflow_associations (item_id, stage_id, extension)
SELECT c.id, 1, 'com_content.article'
FROM #__content c
WHERE NOT EXISTS (
    SELECT 1 FROM #__workflow_associations wa WHERE wa.item_id = c.id
);
```

### Important Notes

- **Workflows do NOT need to be enabled** in `com_content` configuration for articles to save/display properly. The `workflow_enabled` setting is irrelevant to this problem.
- The problem **recurs for new articles** if `#__workflow_stages` or `#__workflow_transitions` tables are missing - even if the `#__workflows` record exists and `#__workflow_associations` are populated for existing articles.
- Always fix the infrastructure (tables + default records) FIRST, then populate article associations.
- Use `INSERT IGNORE` for safe re-runnable inserts of default records.
- Use `SHOW TABLES LIKE` for checking table existence programmatically.

### Programmatic Table Existence Check

```php
protected function isTableMissing(string $tableName): bool
{
    $db = $this->getDatabase();
    $fullName = $db->getPrefix() . $tableName;
    $db->setQuery("SHOW TABLES LIKE " . $db->quote($fullName));
    return empty($db->loadResult());
}
```

---

## Quick Reference Checklist

When component won't load, check in order:

1. ✓ Namespace in manifest has NO `\Administrator` suffix
2. ✓ `<files folder="admin">` attribute present
3. ✓ Package has `admin/` folder structure
4. ✓ Template files in `tmpl/viewname/` subdirectories
5. ✓ `script.php` present and clears autoload cache
6. ✓ Service provider doesn't call `setRegistry()`
7. ✓ Pagination uses properties, not methods
8. ✓ Autoload cache deleted after installation

---

## Module-Specific Errors

These apply to modules using the Dispatcher pattern:

| Error | Cause | Solution |
|-------|-------|----------|
| `Undefined variable $displayData` in template | Dispatcher pattern extracts variables directly, not into `$displayData` | Use `$myVar ?? default` instead of `$displayData['myVar']` |
| `Call to undefined method escape()` in template | `$this->escape()` not available in module templates | Use `htmlspecialchars($text, ENT_QUOTES, 'UTF-8')` |
| com_ajax returns `[]` for module helper | Module not published on site side | com_ajax requires module to be published. Use inline data-attributes instead |
| com_ajax `DatabaseAwareTrait` queries fail silently | Helper class missing `DatabaseAwareInterface` | Must `implements DatabaseAwareInterface` not just `use DatabaseAwareTrait` |
| Uninstall shows "successfully installed" message | `postflight()` runs on all types including uninstall | Check `if ($type === 'uninstall') return;` at start |
| Image not showing in admin/frontend | Double-prepending `images/` to path | Joomla media field may store `images/foo.jpg` (already prefixed) — check before adding |
| Admin form fields invisible in dark mode | Hardcoded background/text colors | Use `color: inherit`, `var(--body-bg)`, `var(--body-color)` — never set explicit bg/text colors |
| Invalid CSS selector in querySelector | Using `!=` in attribute selectors | CSS doesn't support `!=`. Use `:not([name="x"])` or filter in JS |

---

## Admin Sidebar Menu Icons (Atum Template)

**Problem:** Setting `img="class:book"` or other class-based icons in the component manifest `<menu>` tag does NOT render icons in Joomla 5's Atum admin sidebar.

**Why:** Atum's sidebar renderer only outputs the `title` column content. The `img` column with `class:` prefix is ignored for third-party components.

**Solution:** Embed the `<img>` tag directly in the menu item's title via the install script:

```php
// In your package install script (postflight)
$icon  = "<img src='components/com_mycomp/assets/images/icon-16.svg' width='16' height='16'> ";
$title = $icon . 'My Component';

$query = $db->getQuery(true)
    ->update($db->quoteName('#__menu'))
    ->set($db->quoteName('title') . ' = ' . $db->quote($title))
    ->where($db->quoteName('client_id') . ' = 1')
    ->where($db->quoteName('link') . ' = ' . $db->quote('index.php?option=com_mycomp'))
    ->where($db->quoteName('level') . ' = 1');
$db->setQuery($query);
$db->execute();
```

**Important:** Use single quotes in the `<img>` tag (not double quotes) to avoid breaking the `aria-label` attribute that Joomla wraps around the title.

Include the icon file in `admin/assets/images/` and add `<folder>assets</folder>` to the manifest's `<files>` section.

---

## Security Checklist for Public Extensions

Before releasing any extension publicly, audit for these vulnerabilities (advice from Yannick Gaultier, Weeblr llc):

- [ ] **SQL Injection** — always use `$db->quote()`, `$db->quoteName()`, prepared statements, or query builder. Never concatenate user input into queries.
- [ ] **XSS** — always escape output with `htmlspecialchars()` or `$this->escape()`. Never echo raw user input.
- [ ] **CSRF** — always check tokens with `Session::checkToken()` on form submissions and AJAX calls.
- [ ] **Access Control** — verify user permissions before any data modification.
- [ ] **File Uploads** — validate file types, sizes, and paths. Never trust user-provided filenames.
- [ ] **Path Traversal** — sanitize any user-provided file paths. Use `basename()` and validate against allowed directories.
- [ ] **Information Disclosure** — don't expose database errors, file paths, or configuration details to frontend users.

> "The biggest risk in building and releasing an extension to the public is having vulnerabilities and having your clients' sites hacked." — Yannick Gaultier

---

## ComponentHelper::getParams() Cache Issues

**CRITICAL**: `ComponentHelper::getParams()` caches params at the start of the request. If you write params to `#__extensions` and then read them back via `ComponentHelper::getParams()` in the same request (or in a redirect that Joomla processes quickly), you get stale data.

### When This Bites You

- **Install scripts**: `postflight()` writes params via direct DB query, then another method reads them via `ComponentHelper::getParams()` — gets empty/old values
- **Controller actions**: `saveParam()` writes to DB, redirects to a view that reads via `ComponentHelper::getParams()` — may get stale cache
- **Wizard flows**: Write email/config in one action, redirect to dashboard that checks if email is linked — dashboard sees old cached value

### The Fix: Read Directly from DB

```php
// DON'T do this after writing params in the same request:
$params = ComponentHelper::getParams('com_yourext');
$value = $params->get('my_key'); // May be stale!

// DO this instead:
$db = Factory::getContainer()->get(DatabaseInterface::class);
$query = $db->getQuery(true)
    ->select($db->quoteName('params'))
    ->from($db->quoteName('#__extensions'))
    ->where($db->quoteName('element') . ' = ' . $db->quote('com_yourext'))
    ->where($db->quoteName('type') . ' = ' . $db->quote('component'));
$paramsJson = $db->setQuery($query)->loadResult() ?: '{}';
$params = new \Joomla\Registry\Registry($paramsJson);
$value = $params->get('my_key'); // Always fresh
```

### Where to Use Direct DB Read

- Install/update script `postflight()` methods
- Controller actions that save params and then redirect to a view
- Any View class that needs params written during the current session
- The safe rule: if you call `saveParam()` anywhere in the request chain, read from DB

---

## Form Validation — `Joomla.submitbutton` isValid Error

**Error**: `Uncaught TypeError: Cannot read properties of undefined (reading 'isValid')` when clicking Save/Apply on admin edit forms.

**Cause**: The form has `class="form-validate"` but Joomla's form validator script isn't loaded.

**Fix**: Load it via WebAssetManager at the top of every edit template:

```php
<?php
$wa = Factory::getApplication()->getDocument()->getWebAssetManager();
$wa->useScript('form.validate');
?>

<form ... class="form-validate">
```

**Every admin edit template** (`edit.php`) that uses `class="form-validate"` MUST include this. List templates (`default.php`) don't need it.

---

## Bootstrap JS on Frontend (Site Side)

Joomla's admin backend (Atum template) loads Bootstrap JS automatically. **The frontend does NOT.** If your site-side template uses Bootstrap modals, collapse, tooltips, or other JS-dependent features, you must explicitly load them.

```php
<?php
$wa = Factory::getApplication()->getDocument()->getWebAssetManager();
$wa->useScript('bootstrap.modal');     // For modals
$wa->useScript('bootstrap.collapse');  // For collapse/accordion
$wa->useScript('bootstrap.tooltip');   // For tooltips
$wa->useScript('bootstrap.dropdown');  // For dropdowns
?>
```

**Common symptom**: Clicking a button with `data-bs-toggle="modal"` does nothing — the button gets a red outline (CSS is loaded) but the modal doesn't open (JS is missing).

---

## Custom Form Field Types — addfieldprefix

When using custom form field types (classes in your component's `src/Field/` directory), Joomla needs to know where to find them. Without `addfieldprefix`, the field renders as an empty dropdown.

**Fix**: Add `addfieldprefix` to the `<fields>` or `<fieldset>` element in your form XML:

```xml
<!-- Filter forms -->
<fields name="filter" addfieldprefix="Cybersalt\Component\YourExt\Administrator\Field">
    <field name="my_field" type="mycustomtype" ... />
</fields>

<!-- Edit forms -->
<fieldset name="details" addfieldprefix="Cybersalt\Component\YourExt\Administrator\Field">
    <field name="my_field" type="mycustomtype" ... />
</fieldset>
```

The field class must follow Joomla's naming convention:
- Type `mycustomtype` → Class `MycustomtypeField` in file `src/Field/MycustomtypeField.php`
- Type `packageselect` → Class `PackageselectField` in file `src/Field/PackageselectField.php`

**Common symptom**: Dropdown is completely empty (no options), or field doesn't render at all.

---

## Frontend Controller Actions — Use POST Forms, Not GET Links

For actions on the frontend (deactivate, delete, report, etc.), **always use POST forms** instead of GET anchor links.

**Why**:
1. GET links put `task=controller.action` in the URL, which SEF routers mangle (e.g., turning dots into path separators)
2. Destructive actions should use POST per HTTP semantics
3. CSRF tokens are safer in POST body than URL parameters

**Pattern**:

```php
<form action="<?php echo $actionUrl; ?>" method="post" class="d-inline">
    <input type="hidden" name="task" value="installations.deactivate">
    <input type="hidden" name="id" value="<?php echo (int) $item->id; ?>">
    <?php echo HTMLHelper::_('form.token'); ?>
    <button type="submit" class="btn btn-outline-warning btn-sm"
        onclick="return confirm('Are you sure?');">
        Deactivate
    </button>
</form>
```

**And always include Itemid** in the action URL for correct template assignment:
```php
$activeItemId = Factory::getApplication()->getInput()->getInt('Itemid', 0);
$actionUrl = Route::_('index.php?option=com_yourext&Itemid=' . $activeItemId);
```

**Also in controller redirects** — look up the menu item and include Itemid:
```php
private function getReturnUrl(): string
{
    $app = Factory::getApplication();
    $itemId = $app->getInput()->getInt('Itemid', 0);

    if (!$itemId) {
        $menuItems = $app->getMenu()->getItems('component', 'com_yourext');
        foreach ($menuItems as $mi) {
            if (($mi->query['view'] ?? '') === 'yourview') {
                $itemId = $mi->id;
                break;
            }
        }
    }

    $url = 'index.php?option=com_yourext&view=yourview';
    if ($itemId) {
        $url .= '&Itemid=' . $itemId;
    }

    return Route::_($url, false);
}
```

---

## File Uploads in Admin Forms — Don't Use `type="file"` Form Field

**Symptom**: User selects a file in your admin edit form, clicks Save, the record saves successfully but the file never gets uploaded. No error, just silently doesn't work.

**Cause**: Joomla's `type="file"` form field gets filtered/stripped during `Form::filter()` in `AdminModel::save()`. The file upload data never reaches your save logic.

**Fix**: Don't render the file input through Joomla's Form layer. Add it as plain HTML in the template, outside the `jform[]` namespace:

```php
<!-- In the template, NOT in form XML -->
<div class="control-group mb-3">
    <div class="control-label">
        <label for="package_file"><?php echo Text::_('UPLOAD_FILE'); ?></label>
    </div>
    <div class="controls">
        <input type="file" name="package_file" id="package_file" accept=".zip" class="form-control">
    </div>
</div>
```

Then in your model's `save()` method, read the file directly from `$_FILES` (top-level, not from `jform`):

```php
public function save($data): bool
{
    $app = Factory::getApplication();

    // File input is at top level, not inside jform
    $upload = $app->getInput()->files->get('package_file', null, 'raw');

    if (!empty($upload) && is_array($upload) && empty($upload['error']) && !empty($upload['tmp_name'])) {
        // ... process the upload, copy to target dir, etc.
        // Set the resulting filename on $data so it gets saved with the record
        $data['filename'] = $sanitizedFilename;
    }

    return parent::save($data);
}
```

**Don't forget**:
- The `<form>` element needs `enctype="multipart/form-data"`
- Validate the file extension before saving (`pathinfo($upload['name'], PATHINFO_EXTENSION)`)
- Use `\Joomla\Filesystem\File::makeSafe()` on the filename to prevent path traversal
- Use `\Joomla\Filesystem\File::upload()` to move the file (handles `move_uploaded_file` plus permissions)

---

## Resources

- [Joomla 5.3 Pagination API](https://api.joomla.org/cms-5/classes/Joomla-CMS-Pagination-Pagination.html)
- [Joomla Manifest Documentation](https://manual.joomla.org/docs/5.4/building-extensions/install-update/installation/manifest/)
- [PSR-4 Autoloading](https://manual.joomla.org/docs/5.3/general-concepts/namespaces/autoloading/)
