# Changelog

All notable changes to Joomla Brain will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-12-18

### 🚀 New Features
- **Module Guide - Subform Fields**: Added comprehensive documentation for repeatable/sortable subform fields
  - `buttons="add,remove,move"` for drag-and-drop reordering
  - Processing subform data in Dispatcher
  - Combining with `showon` for conditional nested fields

- **Module Guide - Grouped List Fields**: Added `groupedlist` field type documentation
  - Renders proper HTML `<optgroup>` elements
  - Warning about `fancy-select` not supporting grouped options properly

- **Module Guide - Conditional Fields (showon)**: Added complete showon attribute documentation
  - Basic value matching
  - Multiple values, negation, AND/OR conditions

- **Module Guide - Live Preview**: Added admin form live preview techniques
  - MutationObserver for DOM changes
  - Click/change/input events for immediate response
  - Polling fallback for color pickers and widgets

### 📝 Documentation
- Updated JOOMLA5-MODULE-GUIDE.md with learnings from cs-world-clocks module development

## [1.1.0] - 2025-11-27

### 🚀 New Features
- **Custom Fields Guide**: Added comprehensive guide for creating custom fields programmatically in Joomla 5
  - MVCFactory and Table class approach (recommended)
  - Complete installation script example
  - Field display params for hiding fields on frontend
  - Common errors and solutions including timestamp field requirements

### 🔧 Improvements
- **Custom Fields Guide**: Updated with required timestamp fields (`created`, `created_by`, `modified`, `modified_by`)
- **Custom Fields Guide**: Added display params section for controlling frontend visibility

### 📝 Documentation
- Added CHANGELOG.md and CHANGELOG.html for version tracking

## [1.0.0] - 2025-11-20

### 🚀 New Features
- **Initial Release**: Joomla Brain repository for best practices and development guides
- **JOOMLA5-CHECKLIST.md**: Comprehensive checklist for Joomla 5 development
- **JOOMLA6-CHECKLIST.md**: Checklist for Joomla 6 development
- **JOOMLA5-PLUGIN-GUIDE.md**: Guide for creating Joomla 5 native plugins
- **JOOMLA3-PLUGIN-GUIDE.md**: Legacy guide for Joomla 3 plugins
- **JOOMLA3-COMPONENT-GUIDE.md**: Legacy guide for Joomla 3 components
- **PACKAGE-BUILD-NOTES.md**: Notes and troubleshooting for package creation
- **FILE-CORRUPTION-FIX.md**: Guide for fixing file encoding issues
- **COMPONENT-TROUBLESHOOTING.md**: Common component issues and solutions
- **Language System Requirements**: Mandatory language file implementation guidelines
- **Custom CSS Tab Requirement**: Guidelines for module custom CSS tabs
- **Enhanced Multi-Select Fields**: Fancy-select layout for modern UX
- **Changelog Format Requirements**: Standards for CHANGELOG.md and CHANGELOG.html
