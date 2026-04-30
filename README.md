# Joomla Brain

This repository contains best practices, scripts, and documentation for Joomla component and package development. It is designed to be included as a submodule in other Joomla projects.

> **Disclaimer**: This is a living document that evolves as we learn, build, and correct mistakes. Content may change at any time — patterns may be revised, guidance may be updated, and errors may be fixed as our understanding of Joomla development deepens. Always check for updates.

## ⚠️ SECURITY IS THE #1 PRIORITY

**Every piece of code we write must be developed with security as the primary focus.** This is non-negotiable for all Cybersalt extensions, whether internal or public. **The bar is "passes a security review with zero HIGH or MEDIUM findings"** — run the `security-review` skill before tagging any release.

Before writing any code, consider:
- **SQL Injection**: Always use `$db->quote()`, `$db->quoteName()`, prepared statements. Never concatenate user input into queries.
- **XSS**: Always escape output — `htmlspecialchars()` for HTML, `esc()` helper for JavaScript `innerHTML`, DOM APIs over string concatenation. Includes `Text::_()` output in installer scripts (`script.php`'s `postflight()` echoes into Joomla's installer frame).
- **CSRF**: Always check `Session::checkToken()` on form submissions and AJAX handlers — including GET-form download/restore links via `$this->checkToken('get')` plus `Session::getFormToken()` appended to the URL.
- **Access Control**: Always verify user permissions (`$user->authorise()`) before data modifications. Components MUST ship `admin/access.xml` with custom `<name>.view` and `<name>.write` actions, and gate **every** controller method (admin AND API) with the matching check. **A valid Joomla API token does NOT authorise any specific component on its own.**
- **Information Disclosure**: Never expose raw exception messages, SQL errors, or file paths to users. Log them and show generic messages.
- **Input Validation**: Always validate ORDER BY columns against an explicit allowlist. Always validate and sanitize user input.
- **File-write safety** (only relevant if your extension writes files under `JPATH_ROOT`): separator-anchored `str_starts_with` for containment (NOT `strpos`), PHP-extension whitelist for the specific subtree your extension owns, `opcache_invalidate()` after every write, never accept free-form `file_path` from request bodies — look the path up server-side from a database row instead.
- **Response headers**: sanitize any user-derived value reflected into `Content-Disposition`/`Content-Type` via `preg_replace('/[^A-Za-z0-9._-]/', '-', …)`. `str_replace('"', '', …)` is not enough.

See `NEW-EXTENSION-CHECKLIST.md` → "Security Baseline" for the full checklist, and `COMPONENT-TROUBLESHOOTING.md` → "Security Checklist for Public Extensions".

## Contents

### Guides (Detailed References)
- `JOOMLA5-COMPONENT-GUIDE.md`: Comprehensive component scaffold reference — admin/site/api split, MVC factories, controller hierarchy with security framing (BaseController vs FormController vs AdminController), AdminModel + ListModel patterns with `getStoreId()` cache key, Table::check() exception pattern, modern Toolbar API, form XML with `addfieldprefix`/`showon`/subform/`filterText` security, dispatcher, install/update script, access.xml, 13-step new-entity workflow, 20-item pre-release checklist
- `JOOMLA5-MODULE-GUIDE.md`: Full module development guide (Dispatcher + Legacy patterns)
- `JOOMLA5-PLUGIN-GUIDE.md`: Full plugin development guide — Content/System plugins, 14-group reference table, Task plugin pattern (TASKS_MAP + TaskPluginTrait + ExecuteTaskEvent), Webservices plugin (`onBeforeApiRoute` + `createCRUDRoutes`), Finder plugin (Adapter base class for Smart Search)
- `JOOMLA5-LIBRARY-GUIDE.md`: Installable Joomla library extensions — when to use, manifest XML with `<libraryname>` + `<namespace>`, PSR-4 mapping rules, library class style, DatabaseInterface DI, custom form fields via `addfieldprefix`, packaging, package-extension ordering, multiple-libraries vs. one-with-sub-namespaces
- `JOOMLA5-COMPONENT-ROUTING.md`: Component SEF routing with RouterBase
- `JOOMLA5-CUSTOM-FIELDS-GUIDE.md`: Creating custom fields programmatically
- `JOOMLA5-UPDATE-SERVER-GUIDE.md`: Update server setup, authenticated downloads, `/extension.xml` behavior
- `JOOMLA5-LIST-FILTERS-GUIDE.md`: Admin list views — js-stools filter bar, Choices.js on every select, sortable column headers, pagination, clickable count cards (match native Article Manager / User Manager)
- `JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`: Where Joomla actually loads language files from, INI encoding traps (em-dashes, smart quotes), plugin `.sys.ini` requirements, and why translations silently break
- `JOOMLA5-UI-PATTERNS.md`: Cache-busting with filemtime, self-contained modal dialogs, dark mode CSS overrides, config page fieldset layouts, pre-flight dialog pattern for destructive operations, Joomlatools Files gotchas, Joomla API PATCH quirks, `HTMLHelper::script` silently dropping `defer` from `$options`
- `JOOMLA5-WEB-SERVICES-API-GUIDE.md`: Building component endpoints — `X-Joomla-Token` (NOT `Authorization: Bearer`), the mandatory `plg_webservices_*` route registration, `:id` capture quirks on POST routes, ACL gate at every controller method, JsonapiView/ApiController wiring
- `JOOMLA5-TEMPLATE-OVERRIDES.md`: `#__template_overrides` schema (`hash_id` is base64 of the relative path, NOT a hash), path resolution from `hash_id` first segment, write-side safety guards (separator-anchored containment check, PHP-extension whitelist, `opcache_invalidate`)
- `JOOMLA5-EDGE-CASE-SCENARIOS.md`: Catalog of environmental / third-party conditions that break extensions and the patterns for detecting and handling them. Covers Akeeba Admin Tools `.htaccess` blocks, RewriteBase in subdirectory staging, Joomlatools Fileman container paths, Composer autoloader hash mismatches, non-standard log directories, CDN caching. Living reference — add new scenarios here as they're encountered.
- `JOOMLA5-WEB-ASSETS-GUIDE.md`: Web Asset Manager (`joomla.asset.json`) — URI auto-resolution rules (never include `css/` or `js/` in `uri`), vendor-asset paths via `registerAndUseScript`, inline asset XSS-safe interpolation (`json_encode` for strings), dependency declarations including `core` and the jQuery-not-in-core gotcha for J5/6, Bootstrap 5.3 dark-mode class warnings
- `JOOMLA5-EDITOR-API-GUIDE.md`: Modern `JoomlaEditor` JavaScript API vs deprecated `Joomla.editors.instances`, XTD button plugin pattern (`SubscriberInterface` + `onEditorButtonsSetup` + `JoomlaEditorButton.registerAction`), three button action types (insert / modal / custom), modal-iframe `postMessage` content selection, editor form-field XML `filter="JComponentHelper::filterText"` as the #1 XSS preventer
- `JOOMLA5-TESTING-GUIDE.md`: PHPUnit + Jest patterns. Real-CMS bootstrap loading both `libraries/loader.php` and `libraries/vendor/autoload.php`, `getQueryStub()` helper anonymous-class pattern for `DatabaseQuery`, five testing gotchas (DatabaseInterface vs DatabaseDriver for `createQuery()`, CMSApplicationInterface vs CMSApplication for `getSession()`, vendor-autoloader requirement, `createStub()` vs `createMock()`, `Factory::getApplication()` setup/teardown)
- `JOOMLA5-COMMON-GOTCHAS.md`: 17 traps from real builds — BaseController vs FormController vs AdminController security implications, J5 controller API differences (no `getInput()`/`getApplication()`), J5/J6 typed-event compatibility, plugin manifest naming (`{element}.xml` only), `$autoloadLanguage = true` and locale prefix for plugin language files, `HttpFactory` namespace (`Joomla\CMS\Http`, not `Joomla\Http`), `Text::script()` registration timing, BS5 dynamic-modal cleanup, `getStoreId()` cache invalidation in ListModel, more
- `JOOMLA-CODING-STANDARDS.md`: PHPDoc/DocBlock conventions (alignment with two+ spaces, `@since` required, no `@author`), JavaScript ESLint flat-config (`eslint.config.mjs`), PHP_CodeSniffer setup with `joomla/coding-standards`, inline comment rules (`//` only, never `#`)
- `COMPONENT-TROUBLESHOOTING.md`: Component installation/loading diagnostics
- `JOOMLA3-COMPONENT-GUIDE.md`: Legacy Joomla 3 component reference
- `JOOMLA3-PLUGIN-GUIDE.md`: Legacy Joomla 3 plugin reference

### Checklists
- `JOOMLA5-CHECKLIST.md`: Pre-release checklist for Joomla 5
- `JOOMLA6-CHECKLIST.md`: Pre-release checklist for Joomla 6
- `NEW-EXTENSION-CHECKLIST.md`: Creating a new Cybersalt extension
- `VERSION-BUMP-CHECKLIST.md`: Version bump steps
- `JOOMLA-EXTENSION-WISHLIST.md`: Cross-cutting UX/operational expectations every Cybersalt extension should ship with — lock-out modals during long-running operations, API-billing transparency, automated lint+test on every push, plus consolidated reminders for post-install card, 15-language coverage, security baseline, dark-mode testing

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

## Versioning & Changelog

Joomla Brain uses semantic versioning at the repository level so consumers (the projects that include this as a submodule) can pin to a known-good revision and audit what changed when they bump.

- **`CHANGELOG.md`** — section-by-section record of what landed in each Brain release. Same emoji conventions as our extension changelogs (🚀 New | 🔧 Improvements | 📦 Build | 🐛 Fixes | 🔍 Security | 📝 Docs).
- **`CONTRIBUTORS.md`** — credit and attribution policy. Guides stay in Cybersalt's voice; named contributions are acknowledged here and in the matching `CHANGELOG.md` entry + commit message.
- **Tags** — releases are tagged `v1.0.0`, `v1.1.0`, etc. on `main`. Bump `MINOR` when a guide is added or substantially expanded; bump `PATCH` for fixes and small clarifications.

When contributing, update `CHANGELOG.md` in the same commit (or PR) as the change, and reference any external contributors in `CONTRIBUTORS.md`.

## Contributing
Feel free to add more best practices and scripts to help Joomla developers!
