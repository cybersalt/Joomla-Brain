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

## Compatibility Notes
- These best practices are for Joomla 5 and Joomla 6. Older versions (Joomla 3/4) require different patterns and libraries.
