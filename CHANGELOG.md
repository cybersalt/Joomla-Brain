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

## v1.3.0 — 2026-04-29

Adds a new cross-cutting "wishlist" guide for UX/operational expectations that apply to every Cybersalt Joomla extension regardless of type.

### 🚀 New

- **`JOOMLA-EXTENSION-WISHLIST.md`** — running list of "wish every extension had" patterns that aren't required by Joomla but make the difference between professional and hobby-grade. New entries from [Brent Cordis](https://github.com/bcordis)'s 2026-04-29 chat suggestions: (1) lock-out modal during long-running operations (Bootstrap 5 modal with `static` backdrop, names the operation, shows progress when divisible, prevents double-submits); (2) API-billing transparency (disclose subscription-vs-API billing, ballpark per-call cost, own-key vs. routed, where data goes); (3) automated lint+test on every push (PHP_CodeSniffer + ESLint + PHPUnit + Jest + package validation in GitHub Actions, modeled on Joomla Bible Study's CI). Plus consolidated cross-references to existing Brain guidance already covering: post-install card, 15-language coverage, security baseline, changelog format, custom CSS tab on modules, dark-mode testing.
- **`README.md`** — added wishlist guide to Contents.

### 📝 Docs

- The wishlist is intentionally a *checklist*, not a tutorial — implementation detail stays in the per-type guides; the wishlist just tells you what to verify before shipping.

---

## v1.2.1 — 2026-04-29

Small clarifying addition to `JOOMLA5-MODULE-GUIDE.md` after a second-pass diff against [Brent Cordis](https://github.com/bcordis)'s reference material. No new file, no breaking change.

### 🔧 Improvements

- **`JOOMLA5-MODULE-GUIDE.md`** — added a "Dispatcher-side Helper Injection (HelperFactoryAware)" subsection showing the `HelperFactoryAwareInterface` + `HelperFactoryAwareTrait` pattern on the Dispatcher class, with `$this->getHelperFactory()->getHelper(...)` from inside `getLayoutData()`. Existing guide already registered `HelperFactory` in `services/provider.php` and showed a standalone helper, but never explicitly wired the two together on the dispatcher side. Includes the same `DatabaseAwareInterface` (not just trait) gotcha the com_ajax section flags later. Contrib: Brent Cordis (source: Joomla-Bible-Study/claude-skill-joomla v0.1.0 references/module.md).

---

## v1.2.0 — 2026-04-29

Second contribution batch from [Brent Cordis](https://github.com/bcordis), again sourced from [Joomla-Bible-Study/claude-skill-joomla v0.1.0](https://github.com/Joomla-Bible-Study/claude-skill-joomla/releases/tag/v0.1.0). This pass folds in the remaining reference material (component scaffold, library extensions, additional plugin patterns) that the v1.1.0 batch didn't cover. License-compatible (GPL-2.0-or-later); folded into Cybersalt's voice and security-first framing.

### 🚀 New

- **`JOOMLA5-COMPONENT-GUIDE.md`** — comprehensive component scaffold reference (~1,450 lines). Covers admin/site/api split, manifest XML, service provider with MVCFactory/ComponentDispatcherFactory/RouterFactory/CategoryFactory wiring, Extension class trait/interface pairs, controller hierarchy (BaseController vs FormController vs AdminController with security framing), AdminModel + ListModel patterns with `getStoreId()` cache-key warning, Table::check() exception pattern, modern Toolbar API via `getDocument()->getToolbar()`, form XML with `addfieldprefix`/`showon`/subform/`JComponentHelper::filterText` security, dispatcher, install/update script with Cybersalt post-install card pattern, config.xml with rules fieldset, site views with `whereIn(getAuthorisedViewLevels())`, access.xml, 13-step "adding a new entity" workflow, 20-item pre-release checklist. Cross-references existing deep-dive guides (routing, custom fields, list filters, web services, web assets, editor API, testing, gotchas, coding standards, J6 checklist) instead of duplicating. Contrib: Brent Cordis.
- **`JOOMLA5-LIBRARY-GUIDE.md`** — installable Joomla library extensions. When to use vs. component helpers or component-bundled Composer packages, directory structure, manifest XML with `<libraryname>` + `<namespace path="src">`, PSR-4 mapping rules, library PHP class style (strict_types, _JEXEC guard, final), DatabaseInterface DI for DB access, consuming libraries from components/plugins/modules, custom form fields via `addfieldprefix` (no system plugin needed), language files (.sys.ini), packaging, package-extension ordering rule (library MUST be listed before its consumers), multiple-libraries vs. one-library-with-sub-namespaces decision, pre-release checklist. Includes the warning never to use `libraries/vendor/` as `<libraryname>` (collides with Joomla core's Composer autoloader). Contrib: Brent Cordis.

### 🔧 Improvements

- **`JOOMLA5-PLUGIN-GUIDE.md`** — added four sections before Example Repositories: (1) Common Plugin Groups reference table covering 14 groups (content, system, finder, task, webservices, schemaorg, user, authentication, installer, editors, editors-xtd, quickicon, fields, privacy) with the events that matter in each; (2) Task Plugin pattern with `TASKS_MAP`, `TaskPluginTrait`, `ExecuteTaskEvent`, `TaskStatus` return values, langConstPrefix-derived TITLE/DESC keys; (3) Webservices Plugin with `onBeforeApiRoute` + `ApiRouter::createCRUDRoutes`, cross-ref to web services guide; (4) Finder Plugin with `Adapter` base class for hooking custom component content into Smart Search. Contrib: Brent Cordis.
- **`README.md`** — added the two new guides to the Contents section.

### 📝 Docs

- **`CONTRIBUTORS.md`** — recorded the v1.2.0 intake date and confirmed the same upstream pin (`v0.1.0` of `Joomla-Bible-Study/claude-skill-joomla`).

---

## v1.1.0 — 2026-04-29

Significant expansion of Joomla 5/6 component architecture coverage, testing patterns, web asset management, and editor API. Most of this batch is contributed material from [Brent Cordis](https://github.com/bcordis), sourced from [Joomla-Bible-Study/claude-skill-joomla v0.1.0](https://github.com/Joomla-Bible-Study/claude-skill-joomla/releases/tag/v0.1.0) (GPL-2.0-or-later, license-compatible with the Brain). See `CONTRIBUTORS.md` for the full attribution. Folded into Cybersalt's voice and aligned with the existing security-first framing.

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
