# Joomla Development Skill

You are assisting with Joomla extension development. Apply these patterns, conventions, and best practices from the Joomla-Brain knowledge base.

## Core Requirements (MANDATORY)

### 1. Language System
- ALL user-facing text MUST use Joomla's language system - NEVER hardcode text
- Language file naming:
  - Modules: `language/en-GB/mod_modulename.ini`
  - Plugins: `language/en-GB/plg_type_element.ini` + `.sys.ini`
  - Components: `admin/language/en-GB/com_componentname.ini` + `.sys.ini`
- Files MUST be UTF-8 WITHOUT BOM

### 2. Custom CSS Tab (All Modules)
- Every module MUST include a Custom CSS fieldset/tab
- Use `filter="raw"` in XML field definition
- Scope CSS using unique ID: `mod-modulename-{$module->id}`

### 3. Changelogs
- Maintain BOTH `CHANGELOG.md` and `CHANGELOG.html`
- Markdown uses emoji headers: 🚀 New | 🔧 Improvements | 📦 Build | 🐛 Fixes | 🔍 Security | 📝 Docs
- HTML version is article-ready (NO `<html>`, `<body>`, `<style>` tags)
- Use semantic versioning: MAJOR.MINOR.PATCH

### 4. Enhanced Multi-Select (Joomla 5+)
- Use `layout="joomla.form.field.list-fancy-select"` for multi-select fields
- Load asset: `$wa->useScript('webcomponent.field-fancy-select')`

---

## Joomla 5 Plugin Pattern

### File Structure
```
plg_group_element/
├── element.xml           # Filename MUST match plugin attribute
├── services/provider.php # DI service provider
├── src/Extension/Element.php
└── language/en-GB/plg_group_element.ini
```

### Service Provider (services/provider.php)
```php
<?php
defined('_JEXEC') or die;
use Joomla\CMS\Extension\PluginInterface;
use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\PluginHelper;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use Joomla\Event\DispatcherInterface;
use YourNamespace\Plugin\Group\Element\Extension\Element;

return new class implements ServiceProviderInterface {
    public function register(Container $container): void {
        $container->set(PluginInterface::class, function (Container $container) {
            $plugin = new Element(
                $container->get(DispatcherInterface::class),
                (array) PluginHelper::getPlugin('group', 'element')
            );
            $plugin->setApplication(Factory::getApplication());
            return $plugin;
        });
    }
};
```

### Plugin Class
```php
<?php
namespace YourNamespace\Plugin\Group\Element\Extension;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;

class Element extends CMSPlugin implements SubscriberInterface {
    public static function getSubscribedEvents(): array {
        return ['onContentPrepare' => 'onContentPrepare'];
    }
    public function onContentPrepare($event): void {
        // Event-based handler
    }
}
```

---

## Joomla 5 Module Pattern

**RECOMMENDED: Dispatcher Pattern** (no entry point file needed)

### File Structure (Dispatcher Pattern)
```
mod_modulename/
├── mod_modulename.xml
├── services/provider.php           # DI service provider
├── src/Dispatcher/Dispatcher.php   # NOT src/Site/Dispatcher!
├── tmpl/default.php
└── language/en-GB/mod_modulename.ini
```

### Service Provider (services/provider.php)
```php
<?php
\defined('_JEXEC') or die;
use Joomla\CMS\Extension\Service\Provider\Module;
use Joomla\CMS\Extension\Service\Provider\ModuleDispatcherFactory;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;

return new class implements ServiceProviderInterface {
    public function register(Container $container): void {
        $container->registerServiceProvider(new ModuleDispatcherFactory('\\YourNamespace\\Module\\ModuleName'));
        $container->registerServiceProvider(new Module());
    }
};
```

### Dispatcher Class (src/Dispatcher/Dispatcher.php)
```php
<?php
namespace YourNamespace\Module\ModuleName\Site\Dispatcher;  // Site auto-added!
\defined('_JEXEC') or die;
use Joomla\CMS\Dispatcher\AbstractModuleDispatcher;

class Dispatcher extends AbstractModuleDispatcher {
    protected function getLayoutData(): array {
        $data = parent::getLayoutData();
        $params = $data['params'];
        $data['items'] = $this->buildItems($params);
        return $data;
    }
}
```

**CRITICAL**: Namespace includes `\Site\Dispatcher` but file is at `src/Dispatcher/` - Joomla auto-adds `Site`.

### Manifest (files section)
```xml
<files>
    <folder module="mod_modulename">services</folder>
    <folder>src</folder>
    <folder>tmpl</folder>
</files>
```

### Legacy Helper Pattern (for existing modules)
```
mod_modulename/
├── mod_modulename.php      # Entry point with explicit require_once
├── src/Site/Helper/ModulenameHelper.php  # MUST be in Site subfolder!
```

---

## Packaging (CRITICAL)

### Use 7-Zip Only
Windows PowerShell `Compress-Archive` and .NET `ZipFile` do NOT create proper directory entries. This causes Joomla installer failures.

```powershell
Set-Location 'build_folder'
& 'C:\Program Files\7-Zip\7z.exe' a -tzip '..\package.zip' *
```

### Package Manifest (pkg_*.xml)
```xml
<extension type="package" method="upgrade">
    <files>
        <file type="module" client="site" id="mod_mymodule">mod_mymodule.zip</file>
        <file type="plugin" group="system" id="myplugin">plg_system_myplugin.zip</file>
    </files>
</extension>
```

### Build Workflow
- Create packages in repository ROOT, not `dist/` or `build/`
- Delete previous versions before building
- Include timestamp: `pkg_name_v1.0.0_2025-01-15_1430.zip`
- **CRITICAL:** Rebuild package after EVERY code change before testing

---

## Custom Fields Programmatically

```php
use Joomla\CMS\Factory;

$app = Factory::getApplication();
$mvcFactory = $app->bootComponent('com_fields')->getMVCFactory();
$fieldTable = $mvcFactory->createTable('Field', 'Administrator');

// REQUIRED: These fields have no defaults - will cause installation failure if missing
$fieldData = [
    'title' => 'My Field',
    'context' => 'com_content.article',
    'type' => 'text',
    'state' => 1,
    'language' => '*',
    'access' => 1,
    'created' => Factory::getDate()->toSql(),
    'created_by' => $app->getIdentity()->id ?? 0,
    'modified' => Factory::getDate()->toSql(),
    'modified_by' => $app->getIdentity()->id ?? 0,
];
```

---

## Component Namespace Pattern

When namespace is declared inside `<administration>`, Joomla automatically appends `\Administrator`:
```xml
<!-- This becomes YourNamespace\Component\Name\Administrator -->
<namespace path="src">YourNamespace\Component\Name</namespace>
```
Do NOT add `\Administrator` yourself - causes duplication bug.

---

## Common Patterns

### Output Nothing When Empty
```php
// Check BEFORE opening wrapper div
if (empty($items)) {
    return;
}
```

### Image Extraction
```php
if (preg_match('/<img[^>]+src=["\']([^"\']+)["\'][^>]*>/i', $content, $matches)) {
    $image = $matches[1];
}
```

### Radio/Toggle Fields
```xml
<field name="feature" type="radio" class="btn-group btn-group-yesno" default="1">
    <option value="1">JYES</option>
    <option value="0">JNO</option>
</field>
```

### Subform Fields (Repeatable/Sortable)
```xml
<field name="items" type="subform" multiple="true"
    layout="joomla.form.field.subform.repeatable"
    buttons="add,remove,move" max="50">
    <form>
        <field name="type" type="list" default="preset">
            <option value="preset">Preset</option>
            <option value="custom">Custom</option>
        </field>
        <field name="preset_value" type="list" showon="type:preset">...</field>
        <field name="custom_value" type="text" showon="type:custom"/>
    </form>
</field>
```
- `buttons="add,remove,move"` enables drag-and-drop reordering
- Process in Dispatcher: `$params->get('items', [])` returns array of objects

### Grouped List Fields (Optgroups)
```xml
<field name="location" type="groupedlist" label="Location">
    <group label="North America">
        <option value="us">United States</option>
        <option value="ca">Canada</option>
    </group>
    <group label="Europe">
        <option value="uk">United Kingdom</option>
    </group>
</field>
```
**IMPORTANT**: Do NOT use `list` with `fancy-select` for grouped options - Choices.js doesn't handle disabled separators. Use `groupedlist` for proper `<optgroup>` rendering.

### Conditional Field Display (showon)
```xml
<field name="details" showon="show_details:1" ... />
<field name="options" showon="type:a,b" ... />           <!-- OR values -->
<field name="other" showon="type!:disabled" ... />       <!-- NOT equal -->
<field name="adv" showon="show:1[AND]level:expert" ... /><!-- AND -->
<field name="either" showon="type:a[OR]type:b" ... />    <!-- OR conditions -->
```

---

## Common Errors & Fixes

| Error | Cause | Solution |
|-------|-------|----------|
| "Unexpected token '<'" | HTML error before JSON | Use 7-Zip, check XML syntax |
| "Class not found" | Namespace mismatch | Verify manifest, provider.php, class match |
| "Field 'created' doesn't have default" | Missing timestamps | Add created/modified fields |
| Plugin not working | Not enabled | Plugins require manual enabling after install |

---

## Reference Implementations

Check these repos for working examples:
- **cs-autogallery** - Joomla 5 native plugin pattern
- **StageIt-5/6** - Module + Plugin packages
- **cybersalt-related-articles** - Joomla 5 module

---

## File Encoding

- All files: UTF-8 WITHOUT BOM
- Verify with `check-encoding.ps1` from Joomla-Brain
- Convert with `convert-utf8.ps1` if needed

---

## Joomla 6 Notes

- Minimum PHP 8.3.0
- Use `version="6.0"` in manifests
- Native Joomla libraries only (no third-party)
- No `setRegistry()` in service providers
