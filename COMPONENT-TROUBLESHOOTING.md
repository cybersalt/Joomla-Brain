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

## Resources

- [Joomla 5.3 Pagination API](https://api.joomla.org/cms-5/classes/Joomla-CMS-Pagination-Pagination.html)
- [Joomla Manifest Documentation](https://manual.joomla.org/docs/5.4/building-extensions/install-update/installation/manifest/)
- [PSR-4 Autoloading](https://manual.joomla.org/docs/5.3/general-concepts/namespaces/autoloading/)
