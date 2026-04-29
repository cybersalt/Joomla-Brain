# Contributors

Joomla-Brain is maintained by Cybersalt Consulting Ltd, but several Joomla developers have contributed hard-won knowledge to it. This file gives credit where it's due.

If you've contributed material that ended up in this repo (a guide, a gotcha, a checklist item, a build script improvement, anything), add yourself here in the relevant section. Newest contributions at the top of each section.

---

## Maintainer

- **Tim Davis** — Cybersalt Consulting Ltd. Repo owner, primary editor, and the person who decides what makes it in. Reach via `tim@cybersalt.com` or [github.com/cybersalt](https://github.com/cybersalt).

---

## Contributors

### Brent Cordis ([@bcordis](https://github.com/bcordis))

**Source:** [Joomla-Bible-Study/claude-skill-joomla](https://github.com/Joomla-Bible-Study/claude-skill-joomla) — published as a Claude Code skill / Claude.ai skill by [Christian Web Ministries](https://christianwebministries.org). Licensed under [GPL-2.0-or-later](https://github.com/Joomla-Bible-Study/claude-skill-joomla/blob/main/LICENSE), compatible with the Joomla ecosystem and our existing Cybersalt extensions.

Brent contributed a substantial body of Joomla 5/6 component architecture, testing, web asset management, editor API, and gotcha-catalog material distilled from his own production work on [Proclaim](https://github.com/Joomla-Bible-Study/Proclaim), [CWMScriptureLinks](https://github.com/bcordis/CWMScriptureLinks), and other CWM extensions. His contribution shaped or wholly originated:

- `JOOMLA-CODING-STANDARDS.md` — PHPDoc/DocBlock alignment rules, ESLint configuration, PHP_CodeSniffer setup, inline comment guidance.
- `JOOMLA5-TESTING-GUIDE.md` — PHPUnit + real Joomla CMS classes pattern (no stubs), `getQueryStub()` helper, model/table/helper test patterns, JavaScript testing with Jest.
- `JOOMLA5-WEB-ASSETS-GUIDE.md` — Web Asset Manager URI auto-resolution, non-standard asset paths, inline asset registration.
- `JOOMLA5-EDITOR-API-GUIDE.md` — `JoomlaEditor` JavaScript API, editor decorators, XTD button plugins, modal-button content-selection pattern, custom editor form fields.
- `JOOMLA5-COMMON-GOTCHAS.md` — `BaseController` vs `FormController`, J5/6 controller API differences, plugin manifest naming, `.sys.ini` requirements, AdminModel + Table CRUD pattern, `Route::_()` task routing, `form.validate` web asset, `HttpFactory` namespace, `Registry::get()` defaults, `Text::script()` registration timing, `Joomla.Text._()` raw-key fallback, Bootstrap 5 modal cleanup, dark-mode CSS pitfalls, `getStoreId()` in ListModel.
- Joomla 6 deprecation matrix additions in `JOOMLA6-CHECKLIST.md` (`createQuery()` introduction, `Joomla\Input\Input` namespace move, `CMSObject` → `stdClass`, `Filesystem\File`/`Folder` deprecations, `Factory::getApplication()` migration of `Factory::getDate()` etc.).
- Toolbar API modern pattern (added to `JOOMLA6-CHECKLIST.md` / `JOOMLA-CODING-STANDARDS.md`).
- SEF router callback naming convention + hidden menu items pattern (added to `JOOMLA5-COMPONENT-ROUTING.md`).
- `JOOMLA5-COMPONENT-GUIDE.md` (v1.2.0) — comprehensive component scaffold reference covering admin/site/api split, MVC factories, controller hierarchy with security framing, AdminModel + ListModel patterns, Table::check() exceptions, modern Toolbar API, form XML security, dispatcher, install/update script, access.xml, 13-step new-entity workflow, 20-item pre-release checklist.
- `JOOMLA5-LIBRARY-GUIDE.md` (v1.2.0) — installable Joomla library extensions, manifest XML with `<libraryname>` + `<namespace>`, PSR-4 mapping rules, library PHP class style, DatabaseInterface DI, custom form fields via `addfieldprefix`, packaging, package-extension ordering.
- Plugin guide additions (v1.2.0): Common Plugin Groups reference table (14 groups), Task Plugin pattern with `TASKS_MAP` + `TaskPluginTrait` + `ExecuteTaskEvent`, Webservices Plugin with `onBeforeApiRoute` + `createCRUDRoutes`, Finder Plugin with `Adapter` base class.

Contribution intake:

- **2026-04-29** — first batch (v1.1.0) against [Joomla-Bible-Study/claude-skill-joomla v0.1.0](https://github.com/Joomla-Bible-Study/claude-skill-joomla/releases/tag/v0.1.0). See `CHANGELOG.md` v1.1.0 for the specific commits.
- **2026-04-29** — second batch (v1.2.0) against the same upstream pin (`v0.1.0`). Pulled in remaining reference material the first batch didn't cover (component scaffold, library extensions, additional plugin patterns). See `CHANGELOG.md` v1.2.0.

When pulling future updates from Brent's repo, the expected pattern is:

1. Diff the upstream `skills/joomla/SKILL.md` and `skills/joomla/references/*.md` against the last-imported revision.
2. Cherry-pick new or substantially changed material into the matching Brain guide (or a new one), keeping Cybersalt's voice.
3. Cite the upstream commit / tag in the import commit message: `(source: Joomla-Bible-Study/claude-skill-joomla@<sha>)`.
4. Bump `CHANGELOG.md` and add a one-liner here noting the new intake date and upstream revision.

---

## How contributions get attributed

When you send Tim something — a guide, a fix, a new gotcha — and it ends up shipping in the Brain:

1. The commit message names the contributor and links any source repo (e.g. *"Add EDITOR-API-GUIDE.md (source: Joomla-Bible-Study/claude-skill-joomla, contrib: Brent Cordis)"*).
2. The relevant `CHANGELOG.md` entry credits the contributor in the same line, with a clickable link to the source repo when there is one.
3. This file gets a section like the one above with:
   - A `[Display Name](github-profile-url)` link as the section heading.
   - A **Source** line citing the upstream repo with a clickable link, plus the upstream license (so future maintainers can verify license compatibility before pulling further updates).
   - A list of which Brain files / sections originated with that contributor.
4. The guide itself stays in Cybersalt's voice (security-first framing, the same heading conventions, etc.) — the goal is consistency across the Brain, not preserving every contributor's prose verbatim. Credit goes here, in the changelog, and in commit history. Inside the guide, attribution lines like *"Originally contributed by X"* are avoided unless the contributor specifically wants their byline in the file.

**License compatibility check before importing:** Joomla-Brain is GPL-compatible. Material from GPL-2.0, GPL-2.0-or-later, or LGPL repos can be folded in. Material under MIT, BSD, or Apache-2.0 can also be re-licensed forward into GPL. **Do not pull from CC-BY-NC, proprietary, or "all rights reserved" sources** without an explicit written grant from the author.

If you'd prefer your contribution to *not* be publicly credited, say so when you send it — Cybersalt will note "(anonymous contributor)" in the changelog instead.
