# Joomla Brain

This repository contains best practices, scripts, and documentation for Joomla component and package development. It is designed to be included as a submodule in other Joomla projects.

> **Disclaimer**: This is a living document that evolves as we learn, build, and correct mistakes. Content may change at any time — patterns may be revised, guidance may be updated, and errors may be fixed as our understanding of Joomla development deepens. Always check for updates.

## ⚠️ SECURITY IS THE #1 PRIORITY

**Every piece of code we write must be developed with security as the primary focus.** This is non-negotiable for all Cybersalt extensions, whether internal or public.

Before writing any code, consider:
- **SQL Injection**: Always use `$db->quote()`, `$db->quoteName()`, prepared statements. Never concatenate user input into queries.
- **XSS**: Always escape output — `htmlspecialchars()` for HTML, `esc()` helper for JavaScript `innerHTML`, DOM APIs over string concatenation.
- **CSRF**: Always check `Session::checkToken()` on form submissions and AJAX handlers.
- **Access Control**: Always verify user permissions (`$user->authorise()`) before data modifications.
- **Information Disclosure**: Never expose raw exception messages, SQL errors, or file paths to users. Log them and show generic messages.
- **Input Validation**: Always validate ORDER BY columns against an explicit allowlist. Always validate and sanitize user input.

See `COMPONENT-TROUBLESHOOTING.md` → "Security Checklist for Public Extensions" for the full checklist.

## Contents

### Guides (Detailed References)
- `JOOMLA5-MODULE-GUIDE.md`: Full module development guide (Dispatcher + Legacy patterns)
- `JOOMLA5-PLUGIN-GUIDE.md`: Full plugin development guide (Content + System plugins)
- `JOOMLA5-COMPONENT-ROUTING.md`: Component SEF routing with RouterBase
- `JOOMLA5-CUSTOM-FIELDS-GUIDE.md`: Creating custom fields programmatically
- `JOOMLA5-UPDATE-SERVER-GUIDE.md`: Update server setup, authenticated downloads, `/extension.xml` behavior
- `COMPONENT-TROUBLESHOOTING.md`: Component installation/loading diagnostics
- `JOOMLA3-COMPONENT-GUIDE.md`: Legacy Joomla 3 component reference
- `JOOMLA3-PLUGIN-GUIDE.md`: Legacy Joomla 3 plugin reference

### Checklists
- `JOOMLA5-CHECKLIST.md`: Pre-release checklist for Joomla 5
- `JOOMLA6-CHECKLIST.md`: Pre-release checklist for Joomla 6
- `NEW-EXTENSION-CHECKLIST.md`: Creating a new Cybersalt extension
- `VERSION-BUMP-CHECKLIST.md`: Version bump steps

### Build & Packaging
- `PACKAGE-BUILD-NOTES.md`: Package naming, 7-Zip requirement, common errors
- `build-package.bat` / `build-package.ps1` / `build-simple.ps1`: Build scripts
- `check-encoding.ps1` / `convert-utf8.ps1`: File encoding utilities
- `validate-package.ps1`: Package validation
- `create-template.ps1`: Extension template generator

### Other
- `company-info.md`: Cybersalt author/copyright details
- `REPOS-USING-BRAIN.md`: Repositories using this submodule
- `.claude/skills/joomla-development.md`: Claude Code quick-reference skill

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
- AJAX error display: Show full stack traces in Joomla's message container, formatted in monospace
- No alert() popups: Use Bootstrap alerts in the system message container
- Build scripts: Use 7-Zip only (see `PACKAGE-BUILD-NOTES.md`)
- Versioning: Use semantic versioning (MAJOR.MINOR.PATCH)
- **Language files are MANDATORY**: All extensions MUST use Joomla's core language system — see Language System below
- **Custom CSS tab**: All modules MUST include a dedicated tab/fieldset for custom CSS — see `JOOMLA5-MODULE-GUIDE.md`
- **Enhanced multi-select fields**: Use `layout="joomla.form.field.list-fancy-select"` — see `JOOMLA5-MODULE-GUIDE.md`

## Language System Requirements

**CRITICAL**: All Joomla extensions MUST use the core Joomla language system. Never hardcode user-facing text.

### Key Rules

1. **XML manifests** must use language constants: `<name>MOD_MYMODULE</name>` (not `<name>My Module</name>`)
2. **All field labels and descriptions** must use language constants
3. **Language files** must be UTF-8 without BOM
4. **Language file naming**: `mod_modulename.ini`, `plg_type_element.ini` + `.sys.ini`, `com_componentname.ini` + `.sys.ini`
5. **Use existing Joomla constants** where appropriate: `JYES`, `JNO`, `JFIELD_BASIC_LABEL`, etc.

### Language File Format

```ini
; Extension Name - Language File
; Copyright (C) 2025 Your Name. All rights reserved.
; License GNU General Public License version 2 or later

MOD_MYMODULE="My Module"
MOD_MYMODULE_XML_DESCRIPTION="Description of the module."
MOD_MYMODULE_FIELD_SETTING_LABEL="Setting"
MOD_MYMODULE_FIELD_SETTING_DESC="Description of the setting."
```

### PHP Usage

```php
use Joomla\CMS\Language\Text;

echo Text::_('MOD_EXAMPLE_TITLE');           // Simple string
echo Text::sprintf('MOD_EXAMPLE_COUNT', $n); // With placeholder
echo Text::plural('MOD_EXAMPLE_N_ITEMS', $n); // Plural forms
```

### Core Languages (MANDATORY for all PHP Web Design extensions)

All extensions MUST include translations for these 15 core languages:
en-GB, nl-NL, de-DE, es-ES, fr-FR, it-IT, pt-BR, ru-RU, pl-PL, ja-JP, zh-CN, tr-TR, el-GR, cs-CZ, sv-SE

## Changelog Format

**MANDATORY**: All extensions MUST maintain both `CHANGELOG.md` and `CHANGELOG.html` files, kept in sync.

- **CHANGELOG.md**: Markdown with emoji section headers (🚀 New | 🔧 Improvements | 📦 Build | 🐛 Fixes | 🔍 Security | 📝 Docs)
- **CHANGELOG.html**: Article-ready HTML — NO `<html>`, `<head>`, `<body>`, or `<style>` tags. Use semantic HTML with class names (`changelog-container`, `version-badge`, `date`, `section-icon`). Use direct emojis (🚀), not HTML entities.

### CHANGELOG.html Structure

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

## Usage Guide

### Adding Joomla-Brain to Your Project

```bash
git submodule add https://github.com/cybersalt/Joomla-Brain.git .joomla-brain
git commit -m "Add Joomla-Brain submodule"
```

### Updating Joomla-Brain

```bash
git submodule update --remote .joomla-brain
git add .joomla-brain
git commit -m "Update Joomla Brain submodule"
```

### Cloning a Project with Joomla-Brain

```bash
git clone --recurse-submodules <your-repo-url>
```

Or after cloning:

```bash
git submodule init && git submodule update
```

### Example Integration

See [cs-category-grid-display](https://github.com/cybersalt/cs-category-grid-display) for a complete example.

## Contributing
Feel free to add more best practices and scripts to help Joomla developers!
