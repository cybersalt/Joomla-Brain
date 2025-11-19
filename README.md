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
- Asset management: Use Joomla’s Web Asset Manager for CSS/JS
- File operations: Use `Joomla\CMS\Filesystem\File` and `Joomla\CMS\Filesystem\Folder`
- Database: Use `Joomla\Database\DatabaseInterface` and `Joomla\CMS\Factory::getDbo()`
- Input handling: Use `Factory::getApplication()->getInput()`
- Manifest version: Use `version="6.0"` for Joomla 6, `version="5.0"` for Joomla 5
- Only the package manifest should declare `<updateservers>`
- Structured exception handling and logging: Use `Joomla\CMS\Log\Log`
- Log path: `administrator/logs/com_stageit.log.php`
- AJAX error display: Show full stack traces in Joomla’s message container, formatted in monospace
- No alert() popups: Use Bootstrap alerts in the system message container
- Build scripts: Use PowerShell or batch scripts that preserve file encoding and use forward slashes in ZIPs
- Installation script: Add cleanup code in `postflight()` to remove old/conflicting files and update sites
- Changelog formats: Maintain both `CHANGELOG.md` and `CHANGELOG.html`
- Versioning: Use semantic versioning (MAJOR.MINOR.PATCH)
- Maintain a development checklist for each Joomla version

## Usage
Add this repository as a submodule in your Joomla project:

```
git submodule add <shared-repo-url> shared
```

Update the submodule as needed:
```
git submodule update --remote
```

## Contributing
Feel free to add more best practices and scripts to help Joomla developers!
