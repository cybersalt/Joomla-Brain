# Joomla 5 Development Checklist

## Pre-Release Checklist

### Code Quality
- [ ] All code changes committed to git
- [ ] No PHP syntax errors
- [ ] No deprecated Joomla 3/4 APIs used
- [ ] Proper use of Joomla 5 namespaces
- [ ] Language system properly implemented (see Language Requirements below)

### Version & Documentation
- [ ] Version numbers updated in all manifests (pkg_*.xml, plugin XML, component XML)
- [ ] CHANGELOG.md updated with emojis for section headers
- [ ] CHANGELOG.html created/updated with styled presentation
- [ ] All files saved

### Package Building
- [ ] Run build-package.bat (calls PowerShell script for proper structure)
- [ ] Verify validation passes (no XML errors)
- [ ] Check package structure has proper `admin/` folder
- [ ] Verify no intermediate zip files left behind

### Testing
- [ ] Test installation on clean Joomla 5 site
- [ ] Test upgrade from previous version
- [ ] Test all new features
- [ ] Test plugin settings save correctly
- [ ] Verify dark mode compatibility

---

## Common Issues & Solutions

### Component "Class Not Found" Errors

**Problem**: `Class "Joomla\Component\ComponentName\Administrator\Extension\ComponentNameComponent" not found`

**Common Causes & Solutions**:

#### 1. Namespace Duplication Bug
**Symptom**: Autoload cache shows `Joomla\Component\Name\Administrator\Administrator\` (double Administrator)

**Cause**: When namespace is declared inside `<administration>` section, Joomla automatically appends `\Administrator` to it.

**Solution**: Remove `\Administrator` suffix from namespace declaration:
```xml
<!-- WRONG - causes double Administrator -->
<namespace path="src">Joomla\Component\ContentName\Administrator</namespace>

<!-- CORRECT - Joomla adds \Administrator automatically -->
<namespace path="src">Joomla\Component\ContentName</namespace>
```

#### 2. Missing `folder="admin"` Attribute
**Symptom**: Files installed at wrong location, namespace mapping fails

**Cause**: Without `folder="admin"` attribute, Joomla doesn't know where to copy files from in the ZIP.

**Solution**: Add folder attribute to `<files>` tag:
```xml
<administration>
    <files folder="admin">
        <folder>src</folder>
        <folder>services</folder>
    </files>
</administration>
```

**Package Structure**:
```
com_component.zip
├── componentname.xml
├── script.php
└── admin/              ← All admin files here
    ├── src/
    ├── services/
    └── tmpl/
```

#### 3. Stale Autoload Cache
**Symptom**: Component installs but class still not found, even after reinstall

**Cause**: `administrator/cache/autoload_psr4.php` not regenerating with correct mappings

**Solution**: Add installation script to auto-clear cache:
```php
// script.php
protected function clearAutoloadCache()
{
    $cacheFile = JPATH_ADMINISTRATOR . '/cache/autoload_psr4.php';
    if (file_exists($cacheFile)) {
        @unlink($cacheFile);
    }
}

public function postflight($type, $parent)
{
    $this->clearAutoloadCache();
}
```

### Component Service Provider Issues

**Problem**: `Call to undefined method setRegistry()`

**Cause**: `setRegistry()` method was removed from `MVCComponent` in Joomla 5

**Solution**: Remove the call from `services/provider.php`:
```php
// WRONG (J3/J4)
use Joomla\CMS\HTML\Registry;
$component->setRegistry($container->get(Registry::class));

// CORRECT (J5)
// Just remove it - not needed
$component = new ComponentNameComponent(...);
$component->setMVCFactory($container->get(MVCFactoryInterface::class));
return $component;
```

### Template/Layout Not Found Errors

**Problem**: `Layout default not found`

**Cause**: Templates must be in subdirectory matching view name (Joomla 5 MVC convention)

**Solution**: Organize templates by view name:
```
WRONG:
tmpl/default.php

CORRECT:
tmpl/articles/default.php       (for ArticlesView)
tmpl/article/edit.php            (for ArticleView)
```

View-to-template mapping:
- View class: `src/View/Articles/HtmlView.php`
- Template: `tmpl/articles/default.php`

### Pagination API Changes

**Problem**: `Call to undefined method Pagination::getTotal()`

**Cause**: Joomla 5 changed pagination from methods to public properties

**Solution**: Use properties instead of methods:
```php
// WRONG (J3/J4)
$this->pagination->getTotal()
$this->pagination->getLimitStart()

// CORRECT (J5)
$this->pagination->total
$this->pagination->limitstart
```

Available properties:
- `$pagination->total` - Total row count
- `$pagination->limit` - Rows per page
- `$pagination->limitstart` - Starting record
- `$pagination->pagesTotal` - Total pages
- `$pagination->pagesCurrent` - Current page

**Note**: `getListFooter()` still works in J5 but consider using `getPaginationLinks()` for future compatibility.

### Plugin Parameters Not Taking Effect from Component

**Problem**: Plugin settings saved from component don't take effect immediately.

**Solution**: Load fresh params directly from database:
```php
private function loadFreshParams(): void
{
    $db = Factory::getDbo();
    $query = $db->getQuery(true)
        ->select($db->quoteName('params'))
        ->from($db->quoteName('#__extensions'))
        ->where($db->quoteName('element') . ' = ' . $db->quote('pluginname'))
        ->where($db->quoteName('folder') . ' = ' . $db->quote('system'))
        ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'));

    $db->setQuery($query);
    $paramsJson = $db->loadResult();

    if ($paramsJson) {
        // Update existing Registry instead of replacing
        $freshParams = json_decode($paramsJson, true);
        if (is_array($freshParams)) {
            foreach ($freshParams as $key => $value) {
                $this->params->set($key, $value);
            }
        }
    }
}
```

**Important**: Don't replace `$this->params` entirely - update individual values to preserve Joomla's form system compatibility.

### PrepareDataEvent Error When Saving Plugin

**Problem**: `PrepareDataEvent::onSetData(): Argument #1 ($value) must be of type object|array, bool given`

**Causes**:
1. XML encoding issues in plugin manifest (em-dash characters, special characters)
2. Empty string defaults on multi-select fields
3. Corrupted params in database

**Solutions**:
1. Use only ASCII characters in XML (replace `—` with `-`)
2. Remove `default=""` from `usergrouplist` fields with `multiple="true"`
3. Uninstall and reinstall plugin to clear corrupted data

### Package Structure Issues

**Problem**: "Install path does not exist" error during installation.

**Cause**: Component ZIP doesn't have proper `admin/` folder structure.

**Solution**: Use PowerShell build script that creates proper structure:
- Root level: `com_name.xml`, `com_name.php`, `com_name/`, `index.html`
- Admin folder: `admin/` containing all backend files (views, controllers, classes, etc.)

**Bad**: Using simple `Compress-Archive` which flattens folder structure.
**Good**: Using custom zip function that preserves folder hierarchy with forward slashes.

### XML Field Type Issues

**Problem**: Form system returns false instead of data array.

**Solutions for `usergrouplist` fields**:
```xml
<!-- Good - no default attribute for multiple select -->
<field name="backend_usergroups" type="usergrouplist"
       label="Backend Visibility"
       multiple="true" />

<!-- Bad - empty string default causes issues -->
<field name="backend_usergroups" type="usergrouplist"
       default=""
       multiple="true" />
```

---

## Changelog Best Practices

### Markdown Format (CHANGELOG.md)
- Use emojis for section headers: 🚀 🔧 📦 🐛 🔍 📝 🛡️ 🎨
- Bold feature names: `- **Feature Name**: Description`
- Use code formatting for technical terms: \`admin/\`, \`usergrouplist\`

### HTML Format (CHANGELOG.html)
- **CRITICAL**: HTML must be article-ready - NO `<html>`, `<head>`, `<body>`, or `<style>` tags
- HTML version must contain the COMPLETE changelog, not just recent versions
- Do NOT link to CHANGELOG.md as a "see full history" fallback - this creates broken links
- Use semantic HTML only (`<div>`, `<h1>`, `<h2>`, `<ul>`, `<li>`, etc.)
- Use direct emojis (🚀) not HTML entities (`&#128640;`)
- Add class names for optional styling: `.changelog-container`, `.version-badge`, `.date`, `.section-icon`
- Keep both files in sync - when updating CHANGELOG.md, regenerate CHANGELOG.html with full content
- See README.md "Changelog Format Requirements" section for complete documentation

---

## Plugin XML Best Practices

### Field Definitions
```xml
<!-- Radio buttons with Yes/No -->
<field name="show_banner" type="radio" default="1"
       label="Show Banner"
       description="Description here"
       class="btn-group btn-group-yesno">
    <option value="1">Yes</option>
    <option value="0">No</option>
</field>

<!-- Multi-select user groups (no default attribute!) -->
<field name="backend_usergroups" type="usergrouplist"
       label="Backend Visibility"
       description="Select user groups. Leave empty for all."
       multiple="true" />

<!-- Color picker -->
<field name="live_color" type="color" default="#59a645"
       label="Live Background Color" />

<!-- Number with range -->
<field name="gradient_duration" type="number" default="5"
       label="Duration (seconds)"
       min="5" max="120" step="1" />
```

### Character Encoding
- Use UTF-8 encoding declaration: `<?xml version="1.0" encoding="utf-8"?>`
- Avoid special characters like em-dashes (—), use regular dashes (-)
- Test XML validation before packaging

---

## Dark Mode Compatibility

### CRITICAL: Use Atum Native Styling

**DO NOT** try to control colors in your extension CSS. Let Atum handle dark/light mode automatically.

**Wrong approach:**
```css
/* DON'T DO THIS - causes white boxes and color conflicts */
background: var(--atum-bg-dark, var(--template-bg-dark-3, #e9ecef));
color: #495057;
```

**Correct approach:**
```css
/* Let colors inherit from Atum - don't set them at all */
/* Only set structural properties like padding, margin, display */
padding: 0.75rem;
margin-bottom: 1rem;
```

### What You CAN Style
- Padding, margins, spacing
- Display properties (flex, grid, etc.)
- Font sizes
- Borders (use `currentColor` or inherit)
- Native form elements with `accent-color`

### What You Should NOT Style
- Background colors
- Text colors
- Alert/warning colors (use Bootstrap classes: `alert alert-warning`)
- Table row backgrounds (use Bootstrap `table` class)

### Native Checkbox Styling
```css
/* Use accent-color for native checkboxes */
input[type="checkbox"] {
    width: 18px;
    height: 18px;
    accent-color: var(--link-color, #0d6efd);
}
```

### Testing
- Toggle dark mode in Joomla admin (user menu > template style)
- Check all form elements, backgrounds, and text colors
- Ensure checkboxes and inputs are visible in both modes
- Verify no "white boxes" appear in dark mode

---

## Component Saving Plugin Parameters

When saving plugin params from a component:

```php
private function savePluginParams($input) {
    $db = Factory::getDbo();

    // Get current params
    $query = $db->getQuery(true)
        ->select($db->quoteName('params'))
        ->from($db->quoteName('#__extensions'))
        ->where($db->quoteName('element') . ' = ' . $db->quote('pluginname'))
        ->where($db->quoteName('folder') . ' = ' . $db->quote('system'))
        ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'));

    $db->setQuery($query);
    $paramsJson = $db->loadResult();
    $params = $paramsJson ? json_decode($paramsJson, true) : [];

    // Update from POST data
    $pluginFields = ['show_banner', 'style_mode', ...];
    foreach ($pluginFields as $field) {
        $value = $input->post->get('plugin_' . $field, null, 'raw');
        if ($value !== null) {
            $params[$field] = $value;
        }
    }

    // Handle arrays separately (usergroups)
    $usergroups = $input->post->get('plugin_backend_usergroups', [], 'array');
    $params['backend_usergroups'] = array_map('intval', $usergroups);

    // Save back
    $query = $db->getQuery(true)
        ->update($db->quoteName('#__extensions'))
        ->set($db->quoteName('params') . ' = ' . $db->quote(json_encode($params)))
        ->where(...);

    $db->setQuery($query);
    $db->execute();
}
```

---

## Language Requirements

**MANDATORY**: All Joomla extensions must use the core language system.

### Language Checklist

- [ ] XML manifest uses language constants for `<name>` tag (e.g., `MOD_MODULENAME` not `mod_modulename`)
- [ ] XML manifest uses language constants for `<description>` tag
- [ ] All form field labels use language constants
- [ ] All form field descriptions use language constants
- [ ] Language files are UTF-8 without BOM
- [ ] Language files follow proper naming convention (e.g., `en-GB.mod_modulename.ini`)
- [ ] Language files are declared in manifest `<languages>` section
- [ ] No hardcoded user-facing text in PHP code
- [ ] Language strings use proper naming convention (UPPERCASE_WITH_UNDERSCORES)
- [ ] Existing Joomla constants used where appropriate (JYES, JNO, etc.)

### Language File Structure

**Module example:**
```
language/en-GB/en-GB.mod_modulename.ini
```

**Component example:**
```
language/en-GB/en-GB.com_componentname.ini
admin/language/en-GB/en-GB.com_componentname.ini
admin/language/en-GB/en-GB.com_componentname.sys.ini
```

### XML Manifest Language Usage

```xml
<!-- CORRECT -->
<name>MOD_CATEGORYGRID</name>
<description>MOD_CATEGORYGRID_XML_DESCRIPTION</description>

<!-- WRONG - Never do this -->
<name>mod_categorygrid</name>
<name>Category Grid</name>
```

### Common Language Constants

Use existing Joomla constants:
- `JYES` / `JNO` for yes/no options
- `JFIELD_PUBLISHED_LABEL` / `JFIELD_PUBLISHED_DESC` for published field
- `JFIELD_BASIC_LABEL` for basic fieldset
- `JFIELD_CONFIG_ADVANCED_LABEL` for advanced fieldset
- `JFIELD_ALT_LAYOUT_LABEL` for layout field
- `COM_MODULES_FIELD_MODULECLASS_SFX_LABEL` for module class suffix

See the [Language System Requirements](README.md#language-system-requirements) section in README.md for complete documentation.

---

## Multi-Lingual Ready Extensions

**MANDATORY**: All new extensions MUST be set up for multi-lingual support from the start, even if initially only English is provided.

### Why Multi-Lingual Ready?

- Joomla has a worldwide community with translations in 70+ languages
- Adding translation support later requires refactoring all hardcoded strings
- Professional extensions always support multiple languages
- It's a Joomla best practice and expected by the community

### Multi-Lingual Checklist

- [ ] **No hardcoded strings**: Every user-facing string uses `Text::_()` or `Text::sprintf()`
- [ ] **Language file structure**: Create proper `language/en-GB/` folder structure
- [ ] **Consistent key naming**: Use `EXTENSION_PREFIX_DESCRIPTIVE_NAME` pattern
- [ ] **Translatable XML**: All manifest labels/descriptions use language constants
- [ ] **Form fields**: Every field label and description is translatable
- [ ] **JavaScript strings**: Use `Joomla.Text._()` for JS translations
- [ ] **Error messages**: All error/success messages use language constants
- [ ] **Email templates**: Any email content uses translatable strings

### Language Key Naming Convention

```
COM_COMPONENTNAME_VIEW_TITLE
COM_COMPONENTNAME_FIELD_FIELDNAME_LABEL
COM_COMPONENTNAME_FIELD_FIELDNAME_DESC
COM_COMPONENTNAME_ERROR_SOMETHING_FAILED
COM_COMPONENTNAME_SUCCESS_ITEM_SAVED

MOD_MODULENAME_FIELD_SETTING_LABEL
MOD_MODULENAME_NO_ITEMS_FOUND

PLG_SYSTEM_PLUGINNAME_SETTING_LABEL
PLG_CONTENT_PLUGINNAME_ERROR_MESSAGE
```

### PHP Usage

```php
// Simple string
echo Text::_('COM_MYEXT_WELCOME_MESSAGE');

// String with variables
echo Text::sprintf('COM_MYEXT_ITEMS_FOUND', $count);

// Plural forms
echo Text::plural('COM_MYEXT_N_ITEMS_DELETED', $count);
```

### JavaScript Usage

Add strings to script options in your view:
```php
$document = Factory::getApplication()->getDocument();
$document->addScriptOptions('com_myext', [
    'text' => [
        'confirm' => Text::_('COM_MYEXT_CONFIRM_DELETE'),
        'success' => Text::_('COM_MYEXT_SUCCESS'),
    ]
]);
```

Access in JavaScript:
```javascript
const text = Joomla.getOptions('com_myext').text;
alert(text.confirm);
```

### Language File Template

```ini
; Language file for My Extension
; Copyright (C) [YEAR] [COMPANY]. All rights reserved.
; License GNU General Public License version 2 or later

; Extension name and description (shown in installer)
COM_MYEXTENSION="My Extension"
COM_MYEXTENSION_XML_DESCRIPTION="Description of the extension for the installer."

; Common
COM_MYEXTENSION_SAVE="Save"
COM_MYEXTENSION_CANCEL="Cancel"
COM_MYEXTENSION_ERROR_GENERIC="An error occurred. Please try again."

; Field labels and descriptions
COM_MYEXTENSION_FIELD_TITLE_LABEL="Title"
COM_MYEXTENSION_FIELD_TITLE_DESC="Enter the title for this item."

; Messages
COM_MYEXTENSION_SUCCESS_SAVED="Item saved successfully."
COM_MYEXTENSION_ERROR_NOT_FOUND="The requested item was not found."
```

---

## Joomla 5 Core Database Tables

Joomla 5 installs 75 core tables. When building extensions that work with database tables (backup tools, staging tools, migration), use this reference to identify core vs third-party tables.

### Table Naming Convention

Joomla tables follow the pattern: `{prefix}_{extension}_{tablename}`
- `{prefix}` = Site-specific prefix (e.g., `jos_`, `j5_`)
- `{extension}` = Extension identifier (e.g., `content`, `users`, `finder`)
- `{tablename}` = Specific table name

Third-party extensions typically follow: `{prefix}_{extensionname}_{tablename}` (e.g., `jos_virtuemart_products`)

### Core Table Groups (Joomla 5.2+)

**Joomla Core** (21 tables):
`assets`, `associations`, `banners`, `banner_clients`, `banner_tracks`, `extensions`, `languages`, `mail_templates`, `messages`, `messages_cfg`, `newsfeeds`, `overrider`, `postinstall_messages`, `schemas`, `session`, `tuf_metadata`, `ucm_base`, `ucm_content`, `updates`, `update_sites`, `update_sites_extensions`

**Joomla Content** (12 tables):
`categories`, `content`, `contentitem_tag_map`, `content_frontpage`, `content_rating`, `content_types`, `history`, `tags`, `redirect_links`, `menu`, `menu_types`, `schemaorg`

**Joomla Users** (10 tables):
`contact_details`, `usergroups`, `users`, `user_keys`, `user_mfa`, `user_notes`, `user_profiles`, `user_usergroup_map`, `viewlevels`, `webauthn_credentials`

**Joomla Templates and Layout** (4 tables):
`template_overrides`, `template_styles`, `modules`, `modules_menu`

**Joomla Smart Search / Finder** (11 tables):
`finder_filters`, `finder_links`, `finder_links_terms`, `finder_logging`, `finder_taxonomy`, `finder_taxonomy_map`, `finder_terms`, `finder_terms_common`, `finder_tokens`, `finder_tokens_aggregate`, `finder_types`

**Joomla Workflows** (4 tables) - *New in J4*:
`workflows`, `workflow_associations`, `workflow_stages`, `workflow_transitions`

**Joomla Custom Fields** (4 tables) - *New in J3.7+*:
`fields`, `fields_categories`, `fields_groups`, `fields_values`

**Joomla Privacy and Logging** (6 tables) - *New in J3.9+/J4*:
`action_logs`, `action_log_config`, `action_logs_extensions`, `action_logs_users`, `privacy_consents`, `privacy_requests`

**Joomla Scheduler** (1 table) - *New in J4*:
`scheduler_tasks`

**Joomla Guided Tours** (2 tables) - *New in J4*:
`guidedtours`, `guidedtour_steps`

### Tables Removed in Joomla 4/5

These tables existed in Joomla 3.x but were removed or renamed:
- `core_log_searches` - Removed
- `sections` - Removed (legacy from J1.5)
- `weblinks` - Moved to separate extension
- `ucm_history` - Renamed to `history`
- `banner`, `bannertrack`, `bannerclient` - Renamed to `banners`, `banner_tracks`, `banner_clients`
- `finder_links_terms0` through `finder_links_termsf` - Consolidated to single `finder_links_terms`

### Programmatic Table Detection

To get all tables for a database prefix:
```php
use Joomla\CMS\Factory;

$db = Factory::getDbo();
$prefix = $db->getPrefix();
$tables = $db->getTableList();

// Filter to only this site's tables
$siteTables = array_filter($tables, fn($t) => str_starts_with($t, $prefix));
```

---

## Git Workflow

### Feature Branch Workflow
1. Create feature branch: `git checkout -b feature/feature-name`
2. Make changes and commit frequently
3. Test thoroughly
4. Update version numbers and changelog
5. Commit final changes
6. Merge to main: `git checkout main && git merge feature/feature-name --no-ff`
7. Build release package

### Submodule Handling
If using shared submodule (Joomla Brain):
1. Commit submodule changes first: `git -C shared add -A && git -C shared commit -m "message"`
2. Then commit main repo changes
3. Push both repos
