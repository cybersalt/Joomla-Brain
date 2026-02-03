# Joomla 6 Development Checklist

## Before Starting Development
- [ ] Use `version="6.0"` in all manifests
- [ ] Include `<element>com_yourname</element>` in component manifests
- [ ] Plan your folder structure early
- [ ] Ensure PHP 8.3+ compatibility (OFFICIAL Joomla 6 requirement)
- [ ] **USE JOOMLA NATIVE LIBRARIES ONLY** - Essential for true J6 native status

## Joomla 6 Native Principles
- [ ] Archive Handling: Use `Joomla\Archive\Archive` instead of PCLZip/ZipArchive
- [ ] File Operations: Use `Joomla\CMS\Filesystem\File` and `Joomla\CMS\Filesystem\Folder`
- [ ] Database: Use `Joomla\Database\DatabaseInterface` and `Joomla\CMS\Factory::getDbo()`
- [ ] HTTP Requests: Use `Joomla\CMS\Http\HttpFactory` instead of cURL/file_get_contents
- [ ] Caching: Use `Joomla\CMS\Cache\CacheControllerFactory`
- [ ] Configuration: Use `Joomla\CMS\Component\ComponentHelper::getParams()`
- [ ] Events: Use `Joomla\CMS\Plugin\CMSPlugin` and `SubscriberInterface`
- [ ] Language: Use `Joomla\CMS\Language\Text` instead of custom solutions
- [ ] Session: Use `Joomla\CMS\Session\Session` instead of PHP sessions
- [ ] Input: Use `Joomla\CMS\Factory::getApplication()->getInput()`

## Manifest & Packaging
- [ ] Only the package manifest should declare `<updateservers>`
- [ ] Component manifest must include `<element>` and proper `<files>` sections
- [ ] File naming conventions: `com_name.zip`, `plg_group_name.zip`, `pkg_name_Joomla_6_vX.X.X_timestamp.zip`
- [ ] Directory structure: `/component/`, `/plugins/system/pluginname/`, `language/en-GB/`, `resources/`

## Error Handling & Logging
- [ ] Wrap all database and AJAX operations in try-catch
- [ ] Use `Joomla\CMS\Log\Log` for error logging
- [ ] Log path: `administrator/logs/com_stageit.log.php`
- [ ] Log full stack traces and timestamps for errors
- [ ] Show full stack traces in Joomla’s message container, formatted in monospace
- [ ] Use Bootstrap alerts in the system message container (no alert() popups)

## Update Server Best Practices
- [ ] Only the package manifest should declare the update server
- [ ] Installer script should remove legacy and duplicate update sites
- [ ] Ensure update mechanism works for future updates

## Build & Installation
- [ ] Use build scripts that preserve file encoding and use forward slashes in ZIPs
- [ ] Installation script should clean up old/conflicting files and update sites
- [ ] Always test installation over existing versions

## Documentation & Changelog
- [ ] Maintain both `CHANGELOG.md` and `CHANGELOG.html`
- [ ] Use semantic versioning (MAJOR.MINOR.PATCH)
- [ ] Maintain a development checklist for each Joomla version

## Dark Mode / Light Mode Compatibility (Atum Template)

Joomla 6 uses the Atum admin template with Bootstrap 5 CSS variables for dark/light mode. Follow these patterns:

### CSS Variables to Use
```css
/* Colors - use CSS variables, NOT hardcoded values */
color: var(--bs-body-color, #212529);
background: var(--bs-body-bg, #fff);
border-color: var(--bs-border-color, #dee2e6);

/* Table alternating rows */
background: var(--bs-tertiary-bg, #f8f9fa);

/* Table hover */
background: var(--bs-secondary-bg, #e9ecef);
```

### Typography - Inherit from Atum
```css
/* DO use rem units and inherit fonts */
font-size: 0.875rem;
font-family: inherit;
line-height: 1.5;

/* DON'T hardcode fonts */
font: 11px Arial, sans-serif; /* BAD */
```

### Dark Mode Detection
```css
/* Joomla uses both data attributes */
html[data-bs-theme="dark"] body.admin.com_yourext { ... }
html[data-color-scheme="dark"] body.admin.com_yourext { ... }
```

### Icons - Use Joomla Icon Fonts (NOT image files)
```php
// Use Joomla's icon classes (Font Awesome subset)
<span class="icon-trash" aria-hidden="true"></span>    // Delete
<span class="icon-refresh" aria-hidden="true"></span>  // Restore/Refresh
<span class="icon-save" aria-hidden="true"></span>     // Save
<span class="icon-edit" aria-hidden="true"></span>     // Edit
<span class="icon-plus" aria-hidden="true"></span>     // Add
<span class="icon-minus" aria-hidden="true"></span>    // Remove
```

### Cache Busting for CSS/JS
```php
$assetVersion = '1.0.0';
$document->addStyleSheet('components/com_example/css/style.css?v=' . $assetVersion);
$document->addScript('components/com_example/js/script.js?v=' . $assetVersion);
```

## Joomla 6 Database Schema

**Joomla 6 has the same 76 tables as Joomla 5** - no tables added or removed.

Only schema change in Joomla 6:
- `#__history` table: Added `is_current` and `is_legacy` columns (TINYINT)

## Compatibility Notes
- These best practices are for Joomla 5 and Joomla 6. Older versions (Joomla 3/4) require different patterns and libraries.
