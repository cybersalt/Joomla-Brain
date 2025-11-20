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
- Changelog formats: Maintain both `CHANGELOG.md` and `CHANGELOG.html`
- Versioning: Use semantic versioning (MAJOR.MINOR.PATCH)
- Maintain a development checklist for each Joomla version
- **Language files are MANDATORY**: All extensions MUST use Joomla's core language system for all user-facing text

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
