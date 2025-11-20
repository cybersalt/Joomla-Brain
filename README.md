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
