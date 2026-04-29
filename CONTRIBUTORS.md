# Contributors

Joomla-Brain is maintained by Cybersalt Consulting Ltd, but several Joomla developers have contributed hard-won knowledge to it. This file gives credit where it's due.

If you've contributed material that ended up in this repo (a guide, a gotcha, a checklist item, a build script improvement, anything), add yourself here in the relevant section. Newest contributions at the top of each section.

---

## Maintainer

- **Tim Davis** — Cybersalt Consulting Ltd. Repo owner, primary editor, and the person who decides what makes it in. Reach via `tim@cybersalt.com` or [github.com/cybersalt](https://github.com/cybersalt).

---

## Contributors

### Brent Cordis

Brent contributed a substantial body of Joomla 5/6 component architecture, testing, web asset management, editor API, and gotcha-catalog material distilled from his own production work. His contribution shaped or wholly originated:

- `JOOMLA-CODING-STANDARDS.md` — PHPDoc/DocBlock alignment rules, ESLint configuration, PHP_CodeSniffer setup, inline comment guidance.
- `JOOMLA5-TESTING-GUIDE.md` — PHPUnit + real Joomla CMS classes pattern (no stubs), `getQueryStub()` helper, model/table/helper test patterns, JavaScript testing with Jest.
- `JOOMLA5-WEB-ASSETS-GUIDE.md` — Web Asset Manager URI auto-resolution, non-standard asset paths, inline asset registration.
- `JOOMLA5-EDITOR-API-GUIDE.md` — `JoomlaEditor` JavaScript API, editor decorators, XTD button plugins, modal-button content-selection pattern, custom editor form fields.
- `JOOMLA5-COMMON-GOTCHAS.md` — `BaseController` vs `FormController`, J5/6 controller API differences, plugin manifest naming, `.sys.ini` requirements, AdminModel + Table CRUD pattern, `Route::_()` task routing, `form.validate` web asset, `HttpFactory` namespace, `Registry::get()` defaults, `Text::script()` registration timing, `Joomla.Text._()` raw-key fallback, Bootstrap 5 modal cleanup, dark-mode CSS pitfalls, `getStoreId()` in ListModel.
- Joomla 6 deprecation matrix additions in `JOOMLA6-CHECKLIST.md` (`createQuery()` introduction, `Joomla\Input\Input` namespace move, `CMSObject` → `stdClass`, `Filesystem\File`/`Folder` deprecations, `Factory::getApplication()` migration of `Factory::getDate()` etc.).
- Toolbar API modern pattern (added to `JOOMLA6-CHECKLIST.md` / `JOOMLA-CODING-STANDARDS.md`).
- SEF router callback naming convention + hidden menu items pattern (added to `JOOMLA5-COMPONENT-ROUTING.md`).

Contribution intake: 2026-04-29. See `CHANGELOG.md` v1.1.0 for the specific commits.

---

## How contributions get attributed

When you send Tim something — a guide, a fix, a new gotcha — and it ends up shipping in the Brain:

1. The commit message names the contributor (e.g. *"Add EDITOR-API-GUIDE.md (contrib: Brent Cordis)"*).
2. The relevant `CHANGELOG.md` entry credits the contributor in the same line.
3. This file gets a section like the one above listing the specific files / sections that originated with that contributor.
4. The guide itself stays in Cybersalt's voice (security-first framing, the same heading conventions, etc.) — the goal is consistency across the Brain, not preserving every contributor's prose verbatim. Credit goes here, in the changelog, and in commit history. Inside the guide, attribution lines like *"Originally contributed by X"* are avoided unless the contributor specifically wants their byline in the file.

If you'd prefer your contribution to *not* be publicly credited, say so when you send it — Cybersalt will note "(anonymous contributor)" in the changelog instead.
