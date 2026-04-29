# Joomla-Brain Changelog

A history of meaningful changes to the Joomla-Brain knowledge base — guides added, gotchas catalogued, build scripts updated, deprecations recorded.

This is the changelog for **the Brain itself**, not for any extension that consumes it as a submodule. Extensions maintain their own `CHANGELOG.md` per `VERSION-BUMP-CHECKLIST.md`.

Versioning follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (`1.0.0` → `2.0.0`) — incompatible changes consumers must adapt to. Renaming or removing a guide, restructuring a directory in a way that breaks consumer references, or replacing a recommended pattern with a new one that requires extension code updates.
- **MINOR** (`1.0.0` → `1.1.0`) — new content (new guides, new sections, new checklist items, new gotchas, new build scripts) that's additive. Existing consumers don't have to change anything.
- **PATCH** (`1.1.0` → `1.1.1`) — clarifications, typo fixes, link repairs, formatting cleanups. No new guidance.

Section headers match Cybersalt's extension-changelog convention:

- 🚀 **New** — additions (guides, sections, scripts)
- 🔧 **Improvements** — changes to existing content (rewrites, clarifications, expanded coverage)
- 📦 **Build** — build scripts, packaging, repo tooling
- 🐛 **Fixes** — bugs in scripts, broken links, wrong code samples
- 🔍 **Security** — security-relevant updates to guidance
- 📝 **Docs** — meta-documentation (README, this changelog, CONTRIBUTORS, etc.)

Entries are dated YYYY-MM-DD and listed newest-first within each section.

---

## v1.1.0 — 2026-04-29

Significant expansion of Joomla 5/6 component architecture coverage, testing patterns, web asset management, and editor API. Most of this batch is contributed material from Brent Cordis (see `CONTRIBUTORS.md`), folded into Cybersalt's voice and aligned with the existing security-first framing.

### 🚀 New

- **`CONTRIBUTORS.md`** — credit-and-attribution policy, contributor list. Tim Davis as maintainer, Brent Cordis credited for the v1.1.0 contributed material.
- **`CHANGELOG.md`** — this file. Establishes Brain-level versioning starting at v1.0.0 baseline (current state of the repo prior to this commit) and v1.1.0 for this contribution batch.
- **`JOOMLA-CODING-STANDARDS.md`** — PHPDoc/DocBlock formatting (whitespace alignment, tag ordering, single-line vs multi-line block rules), ESLint configuration for Joomla extension JavaScript, PHP_CodeSniffer setup, inline comment guidance. Contrib: Brent Cordis.
- **`JOOMLA5-TESTING-GUIDE.md`** — PHPUnit + real Joomla CMS classes (no stubs), `getQueryStub()` test helper, model/table/helper test patterns, JavaScript testing with Jest, common testing gotchas (constants in test bootstrap, `setExpectedException` deprecation, `Factory::getApplication()` mocking). Contrib: Brent Cordis.
- **`JOOMLA5-WEB-ASSETS-GUIDE.md`** — `joomla.asset.json` schema, Web Asset Manager URI auto-resolution rules, non-standard asset paths, inline asset registration, dependency declarations, version pinning. Contrib: Brent Cordis.
- **`JOOMLA5-EDITOR-API-GUIDE.md`** — `JoomlaEditor` JavaScript API for getting/setting editor content, editor decorator pattern (implementing a custom editor), XTD button plugins (extension buttons in the editor toolbar), modal-button content-selection pattern, custom editor form fields, editor plugin registration. Contrib: Brent Cordis.
- **`JOOMLA5-COMMON-GOTCHAS.md`** — catalog of Joomla 5/6 gotchas not already covered in `JOOMLA5-EDGE-CASE-SCENARIOS.md` or `JOOMLA5-UI-PATTERNS.md`: BaseController vs FormController, J5/6 controller API differences, plugin manifest `<files>` naming, plugin language `.sys.ini` requirements, AdminModel + Table CRUD pattern, `Route::_()` task= routing for list-to-edit links, `form.validate` web asset for form views, `HttpFactory` namespace, `Registry::get()` defaults, `Text::script()` registration timing, `Joomla.Text._()` returns raw key when unregistered, batch task routing, hidden menu items for SEF routing, Bootstrap 5 dynamic modal cleanup, dark mode (`bg-light` / `btn-outline-*` warnings), `getStoreId()` in `ListModel`. Contrib: Brent Cordis.

### 🔧 Improvements

- **`JOOMLA6-CHECKLIST.md`** — added Joomla 6 deprecation matrix: `$db->getQuery(true)` → `$db->createQuery()`; `Joomla\CMS\Input\Input` → `Joomla\Input\Input` (namespace move); `CMSObject` deprecated → use `stdClass` for plain data carriers; `Joomla\CMS\Filesystem\File`/`Folder` deprecated; `Factory::getDate()` and similar wrappers moved under `Factory::getApplication()->...`. Also added the modern Toolbar API pattern (using `Toolbar::getInstance()` with method-chained button factories instead of `ToolbarHelper::*` static calls). Contrib: Brent Cordis.
- **`JOOMLA5-COMPONENT-ROUTING.md`** — added the SEF router callback naming convention (`getCategoryRoute`, `getYourViewRoute` lookups in helper classes) and the hidden menu items pattern for SEF routing of views that don't have a user-visible menu item. Contrib: Brent Cordis.
- **`README.md`** — added new guides to the Contents section, added a Versioning + Changelog section pointing to this file.

### 📝 Docs

- The Joomla-Brain itself now has versioning and a changelog. Previously there was none — every contribution was just another commit on `main` with no semantic boundary.

---

## v1.0.0 — 2026-04-29 (baseline)

Pre-existing state of the repo prior to introducing Brain-level versioning. Cataloged here so v1.1.0 has a meaningful predecessor to compare against. No content changes were made for v1.0.0 itself — it represents the repo as of commit `23c8dd4` ("REPOS-USING-BRAIN: cs-template-integrity v2.0.0 status update").

Existing content at v1.0.0:

- `README.md`, `JOOMLA5-CHECKLIST.md`, `JOOMLA6-CHECKLIST.md`, `NEW-EXTENSION-CHECKLIST.md`, `VERSION-BUMP-CHECKLIST.md`
- `JOOMLA5-MODULE-GUIDE.md`, `JOOMLA5-PLUGIN-GUIDE.md`, `JOOMLA5-COMPONENT-ROUTING.md`, `JOOMLA5-CUSTOM-FIELDS-GUIDE.md`, `JOOMLA5-UPDATE-SERVER-GUIDE.md`, `JOOMLA5-LIST-FILTERS-GUIDE.md`, `JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`, `JOOMLA5-UI-PATTERNS.md`, `JOOMLA5-WEB-SERVICES-API-GUIDE.md`, `JOOMLA5-TEMPLATE-OVERRIDES.md`, `JOOMLA5-EDGE-CASE-SCENARIOS.md`
- `COMPONENT-TROUBLESHOOTING.md`, `JOOMLA3-COMPONENT-GUIDE.md`, `JOOMLA3-PLUGIN-GUIDE.md`
- `PACKAGE-BUILD-NOTES.md`, build scripts (`build-package.bat`, `build-package.ps1`, `build-simple.ps1`, `build-and-validate.ps1`), encoding utilities (`check-encoding.ps1`, `convert-utf8.ps1`), `validate-package.ps1`, `create-template.ps1`
- `company-info.md`, `REPOS-USING-BRAIN.md`, `.claude/skills/joomla-development.md`

---

## Maintenance notes

- **When to bump**: Decide based on the consumer impact. New guide = MINOR. Renaming or removing a guide = MAJOR. Typo fix = PATCH.
- **Tag the release**: After bumping, `git tag v1.1.0 && git push --tags`. Submodule consumers can then pin to a specific tag instead of always tracking `main` if they want stability.
- **Keep entries terse but specific**: each bullet should name the file affected, what changed, and (for contributed material) who contributed.
