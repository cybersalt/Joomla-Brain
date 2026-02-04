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

### Package Naming Convention (MANDATORY)
**ALWAYS include version AND timestamp** in package filenames for sorting:

```
{extension_name}_v{version}_{YYYYMMDD}_{HHMM}.zip
```

**Examples:**
- `com_csdiskusage_v1.0.0_20260203_1425.zip`
- `plg_system_routertracer_v1.2.0_20260203_0930.zip`
- `mod_worldclocks_v2.1.0_20260203_1600.zip`
- `pkg_stageit_v6.0.0_20260203_1045.zip`

This ensures files sort chronologically and you can instantly identify the latest build.

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

## Multi-Lingual Ready Extensions (MANDATORY)

All new Joomla extensions MUST be built with multi-lingual support from the start. Never hardcode text strings.

### Language File Structure

Every extension needs language files for all user-facing text:

```
extension/
├── language/
│   └── en-GB/
│       ├── mod_example.ini           # Frontend strings (modules)
│       └── mod_example.sys.ini       # System strings (install, menu)
```

For components with admin interface:
```
com_example/
├── admin/
│   └── language/
│       └── en-GB/
│           ├── com_example.ini       # Admin interface strings
│           └── com_example.sys.ini   # System strings
├── site/
│   └── language/
│       └── en-GB/
│           └── com_example.ini       # Frontend strings
```

### Language Key Naming Convention

Use the extension prefix followed by descriptive keys:

```ini
; Good - Clear, prefixed keys
MOD_WORLDCLOCKS_FIELD_TIMEZONE_LABEL="Timezone"
MOD_WORLDCLOCKS_FIELD_TIMEZONE_DESC="Select the timezone to display."
COM_MYCOMPONENT_ERROR_NOT_FOUND="The requested item was not found."
PLG_SYSTEM_MYPLUGIN_SETTING_ENABLED="Enable Feature"

; Bad - Ambiguous, generic keys
TIMEZONE="Timezone"
ERROR="Error"
```

### PHP Usage

```php
use Joomla\CMS\Language\Text;

// Simple string
echo Text::_('MOD_EXAMPLE_TITLE');

// String with placeholder (%s, %d)
echo Text::sprintf('MOD_EXAMPLE_ITEMS_FOUND', $count);

// Plural forms
echo Text::plural('MOD_EXAMPLE_N_ITEMS', $count);
```

### JavaScript Usage

```javascript
// In Joomla 5, use Joomla.Text
const message = Joomla.Text._('MOD_EXAMPLE_CONFIRM_DELETE');

// Pass strings from PHP to JS
$wa = $this->getDocument()->getWebAssetManager();
$wa->addInlineScript('
    Joomla.Text.load(' . json_encode([
        'MOD_EXAMPLE_CONFIRM' => Text::_('MOD_EXAMPLE_CONFIRM'),
        'MOD_EXAMPLE_CANCEL'  => Text::_('MOD_EXAMPLE_CANCEL'),
    ]) . ');
');
```

### Language File Format (.ini)

```ini
; Extension Name - Language File
; Copyright notice
; License

; Section comment
KEY_NAME="Value with proper escaping"
KEY_WITH_QUOTES="Use \"escaped quotes\" inside"
KEY_WITH_PLACEHOLDER="Found %d items in %s"

; HTML is allowed but use sparingly
KEY_WITH_HTML="Click <strong>here</strong> to continue"
```

**CRITICAL Requirements:**
- Files MUST be UTF-8 WITHOUT BOM
- Keys MUST be UPPERCASE with underscores
- Values MUST be in double quotes
- No trailing spaces after values
- Semicolons start comments

### Manifest Language Declaration

```xml
<languages folder="language">
    <language tag="en-GB">en-GB/mod_example.ini</language>
    <language tag="en-GB">en-GB/mod_example.sys.ini</language>
</languages>
```

### Multi-Lingual Checklist

- [ ] All user-facing text uses `Text::_()` or `Text::sprintf()`
- [ ] Language keys use extension prefix (MOD_, COM_, PLG_)
- [ ] Both `.ini` and `.sys.ini` files exist
- [ ] Files are UTF-8 without BOM
- [ ] No hardcoded text in PHP, JS, or template files
- [ ] Form field labels/descriptions use language keys
- [ ] Error messages use language keys
- [ ] Success messages use language keys

---

## Joomla 5 Core Database Tables

When building extensions that work with database tables (backup, staging, migration tools), use this reference.

### Table Naming Convention
- Joomla tables: `{prefix}_{extension}_{tablename}` (e.g., `jos_content`, `jos_users`)
- Third-party: `{prefix}_{extensionname}_{tablename}` (e.g., `jos_virtuemart_products`)

### Core Table Groups (75 tables in Joomla 5.2+)

| Group | Tables |
|-------|--------|
| **Core** (21) | assets, associations, banners, banner_clients, banner_tracks, extensions, languages, mail_templates, messages, messages_cfg, newsfeeds, overrider, postinstall_messages, schemas, session, tuf_metadata, ucm_base, ucm_content, updates, update_sites, update_sites_extensions |
| **Content** (12) | categories, content, contentitem_tag_map, content_frontpage, content_rating, content_types, history, tags, redirect_links, menu, menu_types, schemaorg |
| **Users** (10) | contact_details, usergroups, users, user_keys, user_mfa, user_notes, user_profiles, user_usergroup_map, viewlevels, webauthn_credentials |
| **Templates** (4) | template_overrides, template_styles, modules, modules_menu |
| **Smart Search** (11) | finder_filters, finder_links, finder_links_terms, finder_logging, finder_taxonomy, finder_taxonomy_map, finder_terms, finder_terms_common, finder_tokens, finder_tokens_aggregate, finder_types |
| **Workflows** (4) | workflows, workflow_associations, workflow_stages, workflow_transitions |
| **Custom Fields** (4) | fields, fields_categories, fields_groups, fields_values |
| **Privacy/Logging** (6) | action_logs, action_log_config, action_logs_extensions, action_logs_users, privacy_consents, privacy_requests |
| **Scheduler** (1) | scheduler_tasks |
| **Guided Tours** (2) | guidedtours, guidedtour_steps |

### Tables Removed in J4/J5
- `core_log_searches`, `sections`, `weblinks` - Removed
- `ucm_history` → `history` - Renamed
- `banner/bannertrack/bannerclient` → `banners/banner_tracks/banner_clients` - Renamed
- `finder_links_terms0-f` → `finder_links_terms` - Consolidated

### Programmatic Table Detection
```php
$db = Factory::getDbo();
$tables = array_filter($db->getTableList(), fn($t) => str_starts_with($t, $db->getPrefix()));
```

---

## Dark Mode / Atum Template Styling

**CRITICAL:** Use CSS variables for colors - hardcoded colors break dark mode.

### CSS Variables Reference
```css
/* Text and backgrounds */
color: var(--bs-body-color, #212529);
background: var(--bs-body-bg, #fff);
border-color: var(--bs-border-color, #dee2e6);

/* Table styling */
background: var(--bs-tertiary-bg, #f8f9fa);  /* Alternating rows */
background: var(--bs-secondary-bg, #e9ecef); /* Hover state */

/* Links */
color: var(--link-color, #0d6efd);
```

### Typography - Use rem and inherit
```css
/* GOOD - inherits from Atum */
font-size: 0.875rem;
font-family: inherit;
line-height: 1.5;
color: var(--bs-body-color);

/* BAD - hardcoded values */
font: 11px Arial, sans-serif;
color: #333;
```

### Dark/Light Mode Selectors
```css
/* Must support BOTH selectors - Joomla uses both */
html[data-bs-theme="dark"] body.admin.com_yourext { ... }
html[data-color-scheme="dark"] body.admin.com_yourext { ... }

html[data-bs-theme="light"] body.admin.com_yourext { ... }
html[data-color-scheme="light"] body.admin.com_yourext { ... }
```

### Icons - Use Joomla Icon Fonts
**DON'T use image files** - they don't adapt to dark mode and may be missing.
```html
<!-- Joomla's icon classes (Font Awesome subset) -->
<span class="icon-trash" aria-hidden="true"></span>     <!-- Delete -->
<span class="icon-refresh" aria-hidden="true"></span>   <!-- Restore -->
<span class="icon-save" aria-hidden="true"></span>      <!-- Save -->
<span class="icon-edit" aria-hidden="true"></span>      <!-- Edit -->
<span class="icon-plus" aria-hidden="true"></span>      <!-- Add -->
<span class="icon-minus" aria-hidden="true"></span>     <!-- Remove -->
<span class="icon-eye" aria-hidden="true"></span>       <!-- View -->
<span class="icon-download" aria-hidden="true"></span>  <!-- Download -->
```

Style icons with CSS:
```css
.my-delete-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    color: #dc3545;  /* Bootstrap danger red */
    font-size: 16px;
}
.my-delete-icon:hover { color: #a71d2a; }
```

### Cache Busting
Add version parameter to prevent stale CSS/JS:
```php
// DEVELOPMENT: Use timestamp for auto-refresh on every request
$assetVersion = date('YmdHis');

// PRODUCTION: Use static version number for releases
$assetVersion = '1.0.0';

$document->addStyleSheet('components/com_example/css/style.css?v=' . $assetVersion);
$document->addScript('components/com_example/js/script.js?v=' . $assetVersion);
```
**Tip:** During development, use `date('YmdHis')` to automatically bust the cache on each page load. Switch to a static version number before building the release package.

### Table Styling Pattern
```css
table.my-table {
    width: 100%;
    border-collapse: collapse;
    background: var(--bs-body-bg, #fff);
    color: var(--bs-body-color, #212529);
}
table.my-table tr:nth-child(2n+1) {
    background: var(--bs-tertiary-bg, #f8f9fa);
}
table.my-table tr:hover {
    background: var(--bs-secondary-bg, #e9ecef);
}
table.my-table td, table.my-table th {
    padding: 0.75rem;
    border-bottom: 1px solid var(--bs-border-color, #dee2e6);
}
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
- **Database schema identical to Joomla 5** (76 tables, same structure)
- Only schema change: `#__history` table added `is_current` and `is_legacy` columns
- Dark/light mode uses same CSS variables as Joomla 5 Atum template
