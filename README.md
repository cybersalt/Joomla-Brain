# Joomla Brain

This repository contains best practices, scripts, and documentation for Joomla component and package development. It is designed to be included as a submodule in other Joomla projects.

## Contents
- `build-package.bat`: Batch script for building Joomla packages
- `PACKAGE-BUILD-NOTES.md`: Notes and troubleshooting for package creation
- `JOOMLA5-CHECKLIST.md`: Checklist for Joomla 5 development
- `JOOMLA6-CHECKLIST.md`: Checklist for Joomla 6 development
- Additional best practices files

## Best Practices Overview

### Joomla 5 & Joomla 6
- Use only Joomla native libraries (no third-party dependencies)
- Minimum PHP version: 8.3.0 for Joomla 6, 8.1.0 for Joomla 5
- Modern namespace usage: `use Joomla\CMS\Factory` instead of `JFactory`
- Modern event system: Use `SubscriberInterface` for plugins
- Asset management: Use Joomla's Web Asset Manager for CSS/JS
- File operations: Use `Joomla\CMS\Filesystem\File` and `Joomla\CMS\Filesystem\Folder`
- Database: Use `Joomla\Database\DatabaseInterface` and `Joomla\CMS\Factory::getDbo()`
- Input handling: Use `Factory::getApplication()->getInput()`
- Manifest version: Use `version="6.0"` for Joomla 6, `version="5.0"` for Joomla 5
- Only the package manifest should declare `<updateservers>`
- Structured exception handling and logging: Use `Joomla\CMS\Log\Log`
- Log path: `administrator/logs/com_stageit.log.php`
- AJAX error display: Show full stack traces in Joomla's message container, formatted in monospace
- No alert() popups: Use Bootstrap alerts in the system message container
- Build scripts: Use PowerShell or batch scripts that preserve file encoding and use forward slashes in ZIPs
- Installation script: Add cleanup code in `postflight()` to remove old/conflicting files and update sites
- Changelog formats: Maintain both `CHANGELOG.md` and `CHANGELOG.html` (HTML must be article-ready without head/body tags)
- Versioning: Use semantic versioning (MAJOR.MINOR.PATCH)
- Maintain a development checklist for each Joomla version
- **Language files are MANDATORY**: All extensions MUST use Joomla's core language system for all user-facing text
- **Custom CSS tab**: All modules MUST include a dedicated tab/fieldset for custom CSS to allow users to add styling without template overrides
- **Enhanced multi-select fields**: Use `layout="joomla.form.field.list-fancy-select"` for tag-style multi-select with removable chips (Joomla 5+)

## Language System Requirements

**CRITICAL**: All Joomla extensions MUST use the core Joomla language system. Never hardcode user-facing text.

### Mandatory Language Implementation

#### 1. XML Manifest Language Keys

**ALWAYS use language constants in XML manifests:**

```xml
<!-- CORRECT: Use language constant -->
<name>MOD_MYMODULE</name>
<description>MOD_MYMODULE_XML_DESCRIPTION</description>

<!-- WRONG: Never hardcode -->
<name>My Module</name>
<description>This is my module</description>
```

#### 2. Language File Structure

**Modules** (site):
```
language/
  en-GB/
    en-GB.mod_modulename.ini
```

**Components**:
```
language/
  en-GB/
    en-GB.com_componentname.ini        # Site language
admin/language/
  en-GB/
    en-GB.com_componentname.ini        # Admin language
    en-GB.com_componentname.sys.ini    # System language (installer, menu)
```

**Plugins**:
```
language/
  en-GB/
    en-GB.plg_plugintype_pluginname.ini
    en-GB.plg_plugintype_pluginname.sys.ini
```

#### 3. Language File Format

**Required format** (UTF-8 without BOM):

```ini
; Joomla! Project
; Copyright (C) 2025 Your Name. All rights reserved.
; License GNU General Public License version 2 or later; see LICENSE.txt
; Note : All ini files need to be saved as UTF-8

MOD_MYMODULE="My Module"
MOD_MYMODULE_XML_DESCRIPTION="Description of what the module does."

MOD_MYMODULE_FIELD_LABEL="Field Label"
MOD_MYMODULE_FIELD_DESC="Field description text."
```

**Naming conventions:**
- Extension name: `MOD_MODULENAME`, `COM_COMPONENTNAME`, `PLG_TYPE_NAME`
- Description: Add `_XML_DESCRIPTION` suffix
- Field labels: Add `_LABEL` suffix
- Field descriptions: Add `_DESC` suffix
- Use UPPERCASE with underscores

#### 4. XML Manifest Language Declaration

**Always declare language files** in your manifest:

```xml
<languages>
    <language tag="en-GB">language/en-GB/en-GB.mod_modulename.ini</language>
</languages>
```

#### 5. Loading Language in PHP Code

**In modules:**
```php
use Joomla\CMS\Factory;

$app = Factory::getApplication();
$lang = $app->getLanguage();
$lang->load('mod_modulename', dirname(__FILE__));

// Use language strings
echo Text::_('MOD_MODULENAME_SOME_TEXT');
```

**In components and plugins**, language is loaded automatically.

#### 6. Using Language Strings in Templates

```php
use Joomla\CMS\Language\Text;

// Simple translation
echo Text::_('MOD_MYMODULE_TITLE');

// With sprintf formatting
echo Text::sprintf('MOD_MYMODULE_COUNT', $count);

// Plural handling
echo Text::plural('MOD_MYMODULE_N_ITEMS', $count);
```

#### 7. Common Joomla Language Constants

Use existing Joomla constants when appropriate:

```xml
<option value="1">JYES</option>
<option value="0">JNO</option>

<!-- Other common constants -->
JGLOBAL_DESCRIPTION
JFIELD_PUBLISHED_LABEL
JFIELD_PUBLISHED_DESC
JFIELD_ORDERING_LABEL
JFIELD_BASIC_LABEL
JFIELD_CONFIG_ADVANCED_LABEL
JFIELD_ALT_LAYOUT_LABEL
COM_MODULES_FIELD_MODULECLASS_SFX_LABEL
```

### Language File Encoding Rules

**CRITICAL**: All language files MUST be UTF-8 encoded:

1. **Save as UTF-8 without BOM** (Byte Order Mark)
2. **Test before packaging**: Open in a hex editor to verify no BOM (`EF BB BF` at start)
3. **Git configuration**: Ensure `.gitattributes` handles line endings correctly
4. **Special characters**: Use actual UTF-8 characters, not HTML entities

### Validation Checklist

Before releasing any extension, verify:

- [ ] All XML `<name>` tags use language constants (not hardcoded text)
- [ ] All XML `<description>` tags use language constants
- [ ] All field labels and descriptions use language constants
- [ ] Language files are UTF-8 without BOM
- [ ] Language files follow proper naming conventions
- [ ] Language files are declared in the manifest
- [ ] No hardcoded user-facing text in PHP code
- [ ] Test installation shows proper translated text (not language keys)

### Common Mistakes to Avoid

❌ **DON'T:**
```xml
<name>mod_mymodule</name>  <!-- Shows technical name to users -->
<name>My Module</name>      <!-- Not translatable -->
```

✅ **DO:**
```xml
<name>MOD_MYMODULE</name>
```

In language file:
```ini
MOD_MYMODULE="My Module"
```

## Custom CSS Tab Requirement

**MANDATORY**: All Joomla modules MUST include a dedicated Custom CSS tab to allow users to add styling without creating template overrides.

### Why Custom CSS Tabs Are Essential

1. **User Flexibility**: Users can customize styling without modifying template files
2. **Instance-Specific Styling**: Different module instances can have unique styles
3. **Update-Safe**: Custom CSS persists through module updates
4. **No Template Override Required**: Reduces technical barriers for users
5. **Professional Standard**: Expected feature in modern Joomla extensions

### Implementation

#### 1. Add Custom CSS Fieldset to XML Manifest

Add a dedicated fieldset for custom CSS in your module XML:

```xml
<fieldset name="custom_css" label="MOD_MODULENAME_CUSTOM_CSS_LABEL">
    <field
        name="custom_css"
        type="textarea"
        label="MOD_MODULENAME_CUSTOM_CSS_FIELD_LABEL"
        description="MOD_MODULENAME_CUSTOM_CSS_FIELD_DESC"
        rows="10"
        cols="50"
        filter="raw"
    />
</fieldset>
```

**Important**: Use `filter="raw"` to allow CSS syntax without sanitization.

#### 2. Add Language Strings

Add these to your language file:

```ini
MOD_MODULENAME_CUSTOM_CSS_LABEL="Custom CSS"
MOD_MODULENAME_CUSTOM_CSS_FIELD_LABEL="CSS Code"
MOD_MODULENAME_CUSTOM_CSS_FIELD_DESC="Add custom CSS styles for this module. CSS will be scoped to this module instance."
```

#### 3. Load and Output Custom CSS in Template

In your module template (e.g., `tmpl/default.php`):

```php
// Get custom CSS parameter
$customCss = $params->get('custom_css', '');
$moduleId = (int) $module->id;
$wrapperId = 'mod-modulename-' . $moduleId;
?>

<style>
    /* Your module's default styles */
    #<?php echo $wrapperId; ?> .some-class {
        /* styles */
    }

    <?php if (!empty($customCss)) : ?>
    /* Custom CSS */
    <?php echo $customCss; ?>
    <?php endif; ?>
</style>

<div id="<?php echo $wrapperId; ?>" class="mod-modulename">
    <!-- Module content -->
</div>
```

### Best Practices for Custom CSS Implementation

#### 1. Scope Styles to Module Instance

Always use a unique ID based on the module ID:

```php
$wrapperId = 'mod-modulename-' . (int) $module->id;
```

This allows:
- Multiple instances with different custom CSS
- Specific targeting without affecting other modules
- Clean CSS specificity

#### 2. Position in Style Block

Place custom CSS at the **end** of your style block so it can override default styles:

```php
<style>
    /* Default module styles first */

    <?php if (!empty($customCss)) : ?>
    /* Custom CSS last - highest specificity */
    <?php echo $customCss; ?>
    <?php endif; ?>
</style>
```

#### 3. Provide Usage Instructions

In the field description, help users understand scoping:

```ini
MOD_MODULENAME_CUSTOM_CSS_FIELD_DESC="Add custom CSS styles for this module. Use #mod-modulename-<?php echo $module->id; ?> as the selector prefix to scope styles to this instance."
```

#### 4. Example CSS for Users

Consider adding helpful comments in the placeholder or description:

```xml
<field
    name="custom_css"
    type="textarea"
    label="MOD_MODULENAME_CUSTOM_CSS_FIELD_LABEL"
    description="MOD_MODULENAME_CUSTOM_CSS_FIELD_DESC"
    hint="Example: #mod-modulename-123 .item { color: red; }"
    rows="10"
    cols="50"
    filter="raw"
/>
```

### Security Considerations

#### Safe Usage of filter="raw"

While `filter="raw"` is necessary for CSS, be aware:

1. **Only for CSS**: Never use `filter="raw"` for user-input fields that output HTML
2. **Administrator Access Only**: Module parameters are only editable by administrators
3. **Output in Style Tags**: CSS is output within `<style>` tags, not executable HTML
4. **No JavaScript**: Users should add CSS only, not `<script>` tags

#### Alternative: Sanitize CSS (Advanced)

For extra security, you can sanitize CSS:

```php
// Basic CSS sanitization (strips script tags and dangerous patterns)
$customCss = $params->get('custom_css', '');
$customCss = strip_tags($customCss);
$customCss = preg_replace('/<script\b[^>]*>(.*?)<\/script>/is', '', $customCss);
```

### Complete Example

**XML Manifest (`mod_example.xml`):**
```xml
<config>
    <fields name="params">
        <fieldset name="basic" label="JFIELD_BASIC_LABEL">
            <!-- Your basic fields -->
        </fieldset>

        <fieldset name="custom_css" label="MOD_EXAMPLE_CUSTOM_CSS_LABEL">
            <field
                name="custom_css"
                type="textarea"
                label="MOD_EXAMPLE_CUSTOM_CSS_FIELD_LABEL"
                description="MOD_EXAMPLE_CUSTOM_CSS_FIELD_DESC"
                rows="10"
                cols="50"
                filter="raw"
            />
        </fieldset>

        <fieldset name="advanced" label="JFIELD_CONFIG_ADVANCED_LABEL">
            <!-- Advanced fields -->
        </fieldset>
    </fields>
</config>
```

**Language File (`en-GB.mod_example.ini`):**
```ini
MOD_EXAMPLE_CUSTOM_CSS_LABEL="Custom CSS"
MOD_EXAMPLE_CUSTOM_CSS_FIELD_LABEL="CSS Code"
MOD_EXAMPLE_CUSTOM_CSS_FIELD_DESC="Add custom CSS styles for this module. Use the module wrapper ID to scope your styles."
```

**Template File (`tmpl/default.php`):**
```php
<?php
defined('_JEXEC') or die;

$moduleId = (int) $module->id;
$wrapperId = 'mod-example-' . $moduleId;
$customCss = $params->get('custom_css', '');
?>

<style>
    #<?php echo $wrapperId; ?> {
        /* Default module styles */
    }

    <?php if (!empty($customCss)) : ?>
    /* Custom CSS */
    <?php echo $customCss; ?>
    <?php endif; ?>
</style>

<div id="<?php echo $wrapperId; ?>" class="mod-example">
    <!-- Module content -->
</div>
```

### Validation Checklist

Before releasing a module, verify:

- [ ] Custom CSS fieldset added to XML manifest
- [ ] Field uses `filter="raw"` attribute
- [ ] Language strings defined for tab and field
- [ ] Custom CSS loaded in template with `$params->get('custom_css', '')`
- [ ] Custom CSS output at end of style block
- [ ] Module uses unique ID based on `$module->id`
- [ ] Field description explains how to scope styles
- [ ] Tested with actual CSS to verify functionality

## Enhanced Multi-Select Fields (Joomla 5+)

**MANDATORY**: Use Joomla's native fancy-select layout for all multi-select fields to provide modern UX with tag-style interface.

### Why Fancy-Select Is Essential

1. **Better UX**: Tag/chip interface with removable badges instead of scrolling list boxes
2. **Searchable**: Users can type to filter options quickly
3. **Native Joomla**: Uses built-in web components (no custom code needed)
4. **Consistent**: Matches Joomla's admin interface standards
5. **Accessible**: Better keyboard navigation and screen reader support

### Implementation

#### 1. Add Layout Attribute to Multi-Select Fields in XML

For any field with `multiple="true"`, use the fancy-select layout:

```xml
<field
    name="parent_ids"
    type="category"
    extension="com_content"
    label="MOD_MODULENAME_PARENT_IDS_LABEL"
    description="MOD_MODULENAME_PARENT_IDS_DESC"
    multiple="true"
    layout="joomla.form.field.list-fancy-select"
    showon="selection_mode:multiple_parents"
/>
```

**Important attributes:**
- `multiple="true"` - Required for multi-select
- `layout="joomla.form.field.list-fancy-select"` - Enables fancy-select UI
- No `size` or `class` attributes needed

#### 2. Load Web Asset in Module PHP File

In your main module file (e.g., `mod_modulename.php`), load the fancy-select web component:

```php
defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Helper\ModuleHelper;

// Load fancy-select for enhanced multi-select in admin
$app = Factory::getApplication();
if ($app->isClient('administrator')) {
    $wa = $app->getDocument()->getWebAssetManager();
    $wa->useScript('webcomponent.field-fancy-select');
}

// ... rest of module code
```

### Supported Field Types

The fancy-select layout works with:
- `type="category"` - Category selection
- `type="list"` - Custom option lists
- `type="sql"` - Database-driven lists
- Any field type that extends `ListField`

### What Users See

**Without fancy-select** (old way):
```
┌─────────────────────────┐
│ Category 1              │
│ Category 2              │
│ Category 3              │
│ Category 4              │ ← Scroll to see more
│ Category 5              │
└─────────────────────────┘
```

**With fancy-select** (correct way):
```
┌─────────────────────────────────────────────┐
│ [Category 1 ×] [Category 3 ×] [Type to...] │ ← Selected as removable chips
└─────────────────────────────────────────────┘
  ↓ (Click to see dropdown)
┌─────────────────────────────────────────────┐
│ Category 2                                   │
│ Category 4                                   │
│ Category 5                                   │
└─────────────────────────────────────────────┘
```

### Features

- **Select**: Click an item from dropdown or type to search
- **Remove**: Click × on any chip to deselect
- **Search**: Type in box to filter options
- **Keyboard**: Arrow keys, Enter to select, Backspace to remove last item

### Complete Example

**XML Manifest (`mod_example.xml`):**
```xml
<config>
    <fields name="params">
        <fieldset name="basic" label="JFIELD_BASIC_LABEL">
            <field
                name="categories"
                type="category"
                extension="com_content"
                label="MOD_EXAMPLE_CATEGORIES_LABEL"
                description="MOD_EXAMPLE_CATEGORIES_DESC"
                multiple="true"
                layout="joomla.form.field.list-fancy-select"
            />
        </fieldset>
    </fields>
</config>
```

**Module File (`mod_example.php`):**
```php
<?php
defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Helper\ModuleHelper;

// Load fancy-select for enhanced multi-select in admin
$app = Factory::getApplication();
if ($app->isClient('administrator')) {
    $wa = $app->getDocument()->getWebAssetManager();
    $wa->useScript('webcomponent.field-fancy-select');
}

// Module logic here
require ModuleHelper::getLayoutPath('mod_example', $params->get('layout', 'default'));
```

### Validation Checklist

Before releasing an extension with multi-select fields, verify:

- [ ] All multi-select fields use `layout="joomla.form.field.list-fancy-select"`
- [ ] Web asset loaded in module PHP file with admin client check
- [ ] No `class="advancedSelect"` or custom CSS classes (not needed)
- [ ] No custom JavaScript for select enhancement (Joomla handles it)
- [ ] Tested in administrator: chips appear with × buttons
- [ ] Search/filter works when typing in field
- [ ] Selected items can be removed by clicking ×

### Common Mistakes to Avoid

❌ **DON'T:**
```xml
<!-- Old/wrong approaches -->
<field multiple="true" class="advancedSelect" />
<field multiple="true" size="10" class="chosen" />
<field multiple="true" type="list" /> <!-- Missing layout -->
```

✅ **DO:**
```xml
<field
    multiple="true"
    layout="joomla.form.field.list-fancy-select"
/>
```

## Changelog Format Requirements

**MANDATORY**: All extensions MUST maintain both `CHANGELOG.md` and `CHANGELOG.html` files.

### Why Both Formats Are Required

1. **CHANGELOG.md**: For developers, version control, and GitHub display
2. **CHANGELOG.html**: For end-users and Joomla article integration
3. **Consistency**: Same content in both formats ensures documentation accuracy
4. **Accessibility**: Different audiences prefer different formats

### CHANGELOG.md Format

**Format**: Markdown with emoji section headers

#### Structure:
```markdown
# Changelog

All notable changes to [Extension Name] will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-11-20

### 🚀 New Features
- **Feature Name**: Description of the feature
  - Sub-feature detail
  - Another detail

### 🔧 Improvements
- **Improvement**: Description

### 📦 Build & Infrastructure
- **Build change**: Description

### 🐛 Bug Fixes
- **Fixed issue**: Description

### 📝 Documentation
- Documentation updates

## [1.1.0] - 2025-11-17
...
```

#### Emoji Section Headers:
- 🚀 New Features
- 🔧 Improvements
- 📦 Build & Infrastructure
- 🐛 Bug Fixes
- 🔍 Security
- 📝 Documentation
- 🎨 UI/UX
- 🛡️ Breaking Changes

### CHANGELOG.html Format

**CRITICAL**: HTML changelog MUST be article-ready (no `<html>`, `<head>`, or `<body>` tags, and no `<style>` tags)

#### Purpose:
The HTML changelog is designed to be **copy-pasted directly into Joomla articles** for release announcements and documentation pages. It uses semantic HTML that inherits styling from the Joomla template.

#### Structure:
```html
<div class="changelog-container">
    <h1>📋 Extension Name - Changelog</h1>

    <div class="intro">
        <p><strong>All notable changes...</strong></p>
    </div>

    <h2>
        <span class="version-badge">v1.2.0</span>
        <span class="date">2025-11-20</span>
    </h2>

    <h3><span class="section-icon">🚀</span>New Features</h3>
    <ul>
        <li><strong>Feature</strong>: Description</li>
    </ul>

    <!-- More versions... -->

    <div class="footer">
        <p>&copy; 2025 Your Name</p>
    </div>
</div>
```

### Key Requirements for CHANGELOG.html

#### 1. No Document Structure or Style Tags
❌ **NEVER include:**
```html
<!DOCTYPE html>
<html>
<head>
<style>
<body>
</body>
</html>
```

✅ **ONLY include:**
- Semantic HTML content only
- `<div>` container with content
- Standard HTML tags (h1, h2, h3, ul, li, p, strong, code, etc.)

#### 2. Use Semantic HTML
Use proper semantic HTML that will inherit styling from the Joomla template:

```html
<div class="changelog-container">
    <h1>📋 Title</h1>
    <h2>Version</h2>
    <h3>Section</h3>
    <ul>
        <li><strong>Item</strong>: Description</li>
    </ul>
</div>
```

The Joomla template CSS will style these elements appropriately.

#### 3. Use Class Names for Identification
Add class names to elements that might need custom styling:

```html
<div class="changelog-container">  <!-- Container class -->
<span class="version-badge">       <!-- Version badge -->
<span class="date">                <!-- Date -->
<span class="section-icon">        <!-- Emoji icon -->
<div class="intro">                <!-- Intro box -->
<div class="version-summary">      <!-- Summary box -->
<div class="footer">               <!-- Footer -->
```

Users can add custom CSS to their Joomla template if they want to style these classes.

#### 4. Use Direct Emojis
Use Unicode emojis directly (not HTML entities) for better display:
- ✅ Use: `🚀` (direct emoji)
- ❌ Don't use: `&#128640;` (HTML entity)

Modern Joomla supports UTF-8 emojis without issues.

### Usage Workflow

#### Creating Changelogs

1. **Write CHANGELOG.md first** (easier to edit in markdown)
2. **Convert to CHANGELOG.html** with proper styling
3. **Ensure content matches** between both files
4. **Test HTML** by pasting into a Joomla article

#### Updating for New Releases

1. Update version number in both files
2. Add new version section at the top
3. Categorize changes with emoji headers
4. Keep formatting consistent
5. Commit both files together

#### Pasting into Joomla Articles

1. Open CHANGELOG.html in text editor
2. Copy **entire contents** (including `<style>` tag)
3. In Joomla article editor, switch to **Code view**
4. Paste the HTML
5. Save article
6. Preview to verify styling

### Complete Example Structure

**CHANGELOG.md:**
```markdown
# Changelog

## [1.2.0] - 2025-11-20

### 🚀 New Features
- **Feature**: Description

### 🔧 Improvements
- **Improvement**: Description
```

**CHANGELOG.html:**
```html
<div class="changelog-container">
    <h1>📋 Extension - Changelog</h1>
    <h2>
        <span class="version-badge">v1.2.0</span>
        <span class="date">2025-11-20</span>
    </h2>
    <h3><span class="section-icon">🚀</span>New Features</h3>
    <ul>
        <li><strong>Feature</strong>: Description</li>
    </ul>
</div>
```

### Validation Checklist

Before committing changelogs, verify:

- [ ] Both CHANGELOG.md and CHANGELOG.html exist
- [ ] Content matches between both files
- [ ] CHANGELOG.md uses emoji section headers
- [ ] CHANGELOG.html has NO `<html>`, `<head>`, `<body>`, or `<style>` tags
- [ ] CHANGELOG.html uses only semantic HTML
- [ ] CHANGELOG.html has class names for optional styling
- [ ] Version numbers follow semantic versioning
- [ ] Dates are in YYYY-MM-DD format
- [ ] New version added at top of file
- [ ] Tested HTML by pasting into Joomla article
- [ ] Both files committed together

### Common Mistakes to Avoid

❌ **DON'T:**
```html
<!DOCTYPE html>
<html>
<head>
    <style>
        .changelog { color: blue; }
    </style>
</head>
<body>
    <div class="changelog">...</div>
</body>
</html>
```

✅ **DO:**
```html
<div class="changelog-container">
    <h1>📋 Extension - Changelog</h1>
    <h2><span class="version-badge">v1.0.0</span></h2>
    <h3><span class="section-icon">🚀</span>New Features</h3>
    <ul>
        <li><strong>Feature</strong>: Description</li>
    </ul>
</div>
```

**Note**: The Joomla template will provide all styling. If custom styling is needed, users can add CSS to their template that targets the class names provided.

## Usage Guide

### Adding Joomla-Brain to Your Project

#### Step 1: Add as a Submodule

From your Joomla project root directory, run:

```bash
git submodule add https://github.com/cybersalt/Joomla-Brain.git joomla-brain
git commit -m "Add Joomla-Brain submodule for development best practices"
```

This creates a `joomla-brain/` directory in your project with all the resources.

#### Step 2: Update Your Build Scripts

Reference Joomla-Brain in your build scripts. Example for batch scripts:

```batch
@echo off
REM Best Practices Reference: See joomla-brain/PACKAGE-BUILD-NOTES.md
REM Joomla 5 Checklist: See joomla-brain/JOOMLA5-CHECKLIST.md

REM ... your build commands here ...
```

#### Step 3: Create a Configuration File (Optional)

Create a `.joomla-brain-config` file in your project root to document your setup:

```bash
# Joomla-Brain Configuration
PROJECT_TYPE=module  # or component, plugin, package
PROJECT_NAME=mod_yourmodule
JOOMLA_VERSION=5.0
MIN_PHP_VERSION=8.1.0

# Build Configuration
BUILD_SCRIPT=package-j5.bat
PACKAGE_NAME=mod_yourmodule_j5.zip

# Checklist References
CHECKLIST=joomla-brain/JOOMLA5-CHECKLIST.md
BUILD_NOTES=joomla-brain/PACKAGE-BUILD-NOTES.md
```

#### Step 4: Create Project Documentation

Add a `README.md` to your project that references Joomla-Brain:

```markdown
# Your Joomla Extension

## Development

This project follows best practices defined in the [Joomla-Brain](joomla-brain/) submodule.

### Key References
- **Joomla 5 Checklist**: [joomla-brain/JOOMLA5-CHECKLIST.md](joomla-brain/JOOMLA5-CHECKLIST.md)
- **Package Build Notes**: [joomla-brain/PACKAGE-BUILD-NOTES.md](joomla-brain/PACKAGE-BUILD-NOTES.md)
- **Best Practices**: [joomla-brain/README.md](joomla-brain/README.md)

### Building
See [joomla-brain/JOOMLA5-CHECKLIST.md](joomla-brain/JOOMLA5-CHECKLIST.md) before building releases.
```

### Using Joomla-Brain Resources

#### Before Each Release

1. **Review the Checklist**: Open `joomla-brain/JOOMLA5-CHECKLIST.md` (or `JOOMLA6-CHECKLIST.md`)
2. **Update Version Numbers**: In all XML manifests
3. **Update Changelogs**: Both `CHANGELOG.md` and `CHANGELOG.html` with emoji headers
4. **Build Package**: Using your build script that follows Joomla-Brain standards
5. **Test Installation**: On a clean Joomla site

#### During Development

- **Reference Best Practices**: Check `joomla-brain/README.md` for coding standards
- **Troubleshooting Builds**: See `joomla-brain/PACKAGE-BUILD-NOTES.md` for common issues
- **File Encoding Issues**: See `joomla-brain/FILE-CORRUPTION-FIX.md`

#### Build Scripts

You can either:
1. **Use the provided script**: Copy `joomla-brain/build-package.bat` to your project root and customize
2. **Reference in your script**: Add comments pointing to Joomla-Brain documentation

### Updating Joomla-Brain

To get the latest best practices and scripts:

```bash
git submodule update --remote joomla-brain
git add joomla-brain
git commit -m "Update Joomla-Brain to latest version"
```

### Working with Submodules in Your Team

#### Cloning a Project with Joomla-Brain

When team members clone your project:

```bash
git clone <your-repo-url>
cd <your-repo>
git submodule init
git submodule update
```

Or clone with submodules in one step:

```bash
git clone --recurse-submodules <your-repo-url>
```

#### Keeping Joomla-Brain Updated

Team members can update to the latest Joomla-Brain:

```bash
git submodule update --remote joomla-brain
```

### Example Integration

See the [cs-category-grid-display](https://github.com/cybersalt/cs-category-grid-display) repository for a complete example of Joomla-Brain integration.

## Contributing
Feel free to add more best practices and scripts to help Joomla developers!
