# Wish Every Joomla Extension Had…

A running list of UX, operational, and transparency patterns that **every** Cybersalt Joomla extension should ship with — not because they're required by Joomla, but because they make the difference between an extension that feels professional and one that feels like a hobby project.

These aren't scaffold patterns (those live in the per-extension-type guides). They're cross-cutting expectations: things that should be true regardless of whether you're building a component, plugin, module, or library.

When you find a new "every extension should do this" pattern, add it here. When you build a new extension, run through this list before shipping.

---

## 🚦 Lock-Out Modal While a Long-Running Operation Is Running

**Source:** Brent Cordis, suggested in chat 2026-04-29.

**Pattern:** Whenever an admin (or site) action takes more than ~1 second to complete — an API call, a bulk import, a cache rebuild, a file upload, a mail-merge run — show a modal that:

1. **Locks the window** (overlay covers the whole viewport, dismissable only when the operation completes or errors).
2. **Names the operation in plain English** ("Fetching 247 results from the Claude API…", not "Processing…").
3. **Shows progress when the work is divisible** — a counter, a bar, or a streaming log of what just finished. If progress is genuinely unknowable, show an indeterminate spinner *with* the operation name.
4. **Cannot be dismissed by clicking the backdrop or pressing Esc** while the operation is in flight. The user should not be able to fire the same destructive action twice by accident.
5. **Closes automatically on success** OR shows the error in the same modal on failure (don't fall back to Joomla's system message bar — the user is already focused here).

**Why it matters:** Joomla's default "submit form, wait for full page reload" pattern leaves the user staring at a frozen-looking screen for anywhere from 2 seconds to 2 minutes. Most users assume something is broken and click again. A lock-out modal converts dead time into communicated time and prevents double-submits.

**Implementation pointer:** Bootstrap 5 modal with `data-bs-backdrop="static" data-bs-keyboard="false"` to disable click-to-dismiss; show via `bootstrap.Modal.getOrCreateInstance(el).show()` before the AJAX call, hide via `.hide()` in the `.then()` handler. See [[JOOMLA5-UI-PATTERNS.md]] for Bootstrap 5 dynamic-modal cleanup gotchas (always `dispose()` after hide so the next invocation gets a fresh instance).

**Examples in the wild:**

- Joomla core's "Site → Maintenance → Clear Cache" — locks the window and shows "Working…" until the operation completes.
- Akeeba Backup's backup-in-progress page — full-screen takeover with progress steps.

---

## 🔌 API-Billing Transparency

**Source:** Brent Cordis, in chat 2026-04-29.

**Pattern:** If your extension calls a paid third-party API on the user's behalf (Claude API, OpenAI, Stripe, SendGrid, Twilio, anything that meters), the install/configuration screen **must** disclose:

1. **Whether the call uses the user's existing subscription or bills separately.** This is the specific point Brent made about Anthropic — `claude.ai` (consumer chat subscription) and `platform.claude.com` (developer API, separately billed) look identical to a non-technical user but are completely different billing systems. Don't assume the user knows.
2. **Roughly what the call costs.** "Each translation uses ~500 input + 200 output tokens; at current Sonnet 4.x pricing that's about $0.003 per article." Even a ballpark number is better than silence.
3. **Whether the user needs to provide their own API key** vs. it routing through a Cybersalt-paid endpoint. If it's their own key, link to the page where they generate it.
4. **Where the data goes.** "Article body is sent to Anthropic's US-region API for translation. Anthropic does not train on API data per their Commercial Terms." Don't make the user dig through privacy policies.

**Why it matters:** Surprise bills are the fastest way to lose a client. A clear "this will charge you $X per Y" disclosure on the config page is the difference between a happy renewal and a chargeback.

**Implementation pointer:** A dedicated `<fieldset name="api">` in `config.xml` with a `type="note"` field at the top containing the cost/billing/data-flow disclosure. Use `<![CDATA[...]]>` for the description so HTML-formatted bullet lists render. Pair with the same disclosure in the post-install dialog (see [[JOOMLA5-COMPONENT-GUIDE.md]] for the post-install card pattern).

---

## 🧪 Automated Lint + Test on Every Push

**Source:** Brent Cordis, referencing the Joomla Bible Study CI pipeline (https://github.com/Joomla-Bible-Study).

**Pattern:** Every Cybersalt extension repo should have a GitHub Actions workflow that runs on every push and PR:

1. **PHP_CodeSniffer** with the `joomla/coding-standards` ruleset — see [[JOOMLA-CODING-STANDARDS.md]] for setup.
2. **ESLint** with our flat-config (`eslint.config.mjs`) — same guide.
3. **PHPUnit** for any model/table/helper tests — see [[JOOMLA5-TESTING-GUIDE.md]].
4. **Jest** for any front-end JS tests — same guide.
5. **Package validation** via `validate-package.ps1` (or a Linux-equivalent shell script) to catch manifest/structure issues before they hit a release.

**Why it matters:** Pre-flight catches the typos and PSR-4 case-sensitivity mistakes that break extensions on Linux production servers but pass silently on Windows dev machines.

**Implementation pointer:** Adopt Joomla Bible Study's workflow as a starting template. A minimal `.github/workflows/ci.yml` runs on `push` + `pull_request`, sets up PHP 8.3 + Node 20, caches Composer + npm, runs the four checks above as parallel jobs. Future TODO for the Brain: add a `templates/.github/workflows/ci.yml` that new extensions can copy in via `create-template.ps1`.

---

## 📦 Post-Install Card With Next Steps

**Already documented in:** [[JOOMLA5-COMPONENT-GUIDE.md]] (install/update script section).

Listed here for completeness — every extension's `postflight()` should render a Cybersalt-branded card that tells the user where to go next: "Open Configuration", "Install Sample Data", "View Documentation", "Contact Support". Don't leave them on Joomla's generic green "Installation Successful" banner.

### Visual specification (locked-in pattern, 2026-05-06)

The install card has a deliberate, branded look. These rules apply to every Cybersalt extension's postflight card so they're recognisable as a family in both light and dark Atum.

**Critical: the header is its own opinionated surface, but its colour scheme MUST switch with Joomla's mode.** A single fixed background (whether white or slate) breaks in one of the two modes — a white header reads as a glaring island against dark admin chrome, and a slate header looks dirty on a white admin page. The fix is a CSS-variable pattern keyed off Joomla's dark-mode selector:

```css
.cs-install-card {
    --cs-header-bg: #fff;
    --cs-header-title: #0102E1;        /* Cybersalt cobalt — readable on white */
    --cs-header-border: rgba(0, 0, 0, 0.1);
}
html[data-bs-theme="dark"] .cs-install-card,
html[data-color-scheme="dark"] .cs-install-card {
    --cs-header-bg: #1f2937;            /* slate-800 */
    --cs-header-title: #FE9904;        /* brand orange — readable on slate */
    --cs-header-border: rgba(255, 255, 255, 0.1);
}
```

Joomla 5/6 uses BOTH `data-bs-theme="dark"` and `data-color-scheme="dark"` depending on template/version; match both. Light mode = white header + cobalt title (the primary brand colour from LOGO.md). Dark mode = slate header + brand orange title (cobalt would be unreadable on slate). The logo's cobalt + orange echoes both schemes naturally.

Other rules:

1. **Extension logo at 56px**, left of the title, 1rem gap. Logo files install to `media/plg_*_<element>/` via a `<media folder="media" destination="plg_*_<element>">` block in the manifest; the card references them via `Uri::root() . 'media/...'`.
2. **Action buttons in Cybersalt orange `#dc6b1a`** (the action-button orange from §12, NOT the brand orange `#FE9904` which is a logo accent — different role, different colour). All "go do something next" buttons (Open Plugin Settings, Open Menus, etc.) use the same orange so the eye knows where to click. White text on orange; underline tolerated. Specificity-bump the rules with `a.cs-cybersalt-btn` and `!important` on `color` since Joomla's admin link colour will otherwise win.
3. **Footer line** below an `<hr>`: small text with the Plugin Settings button + vendor link + support URL. External links use `target="_blank" rel="noopener noreferrer"`.
4. **Scope all CSS to `.cs-install-card`** — the postflight runs inside Joomla's installer frame; un-scoped styles would leak into the rest of admin.

Reference implementation: cs-menu-item-conditions v1.1.x — see `plg_system_csmenuconditions/script.php`. Confirmed-test failure mode: shipping a fixed-colour header (light or dark) and discovering the other mode looks broken — happened twice on cs-menu-item-conditions before the CSS-variable pattern landed.

---

## 🌐 15-Language Coverage From Day One

**Already documented in:** [[README.md]] → Language System Requirements.

Every Cybersalt extension ships with translations for the **17** core Cybersalt-target languages: en-GB, nl-NL, de-DE, es-ES, fr-FR, it-IT, pt-BR, ru-RU, pl-PL, ja-JP, zh-CN, tr-TR, el-GR, cs-CZ, sv-SE, nb-NO, nn-NO. Don't ship en-GB only and "add translations later" — translations later never happen.

> [!NOTE]
> Norwegian Bokmål (nb-NO) and Nynorsk (nn-NO) were added to the canonical list 2026-05-06 while building cs-articles-module-maxxed v1.1.0 — partly because Norwegian is a Cybersalt-customer language, partly as a small tribute to Bjørn Ove Bremnes whose feature wish became that extension.

> [!IMPORTANT]
> **Timing exception — defer the 14 non-en-GB language files until the first *published* version, not during initial testing.** Reason: Tim test-loops new extensions by reinstalling the zip many times before the first real release; 28 extra files (`.ini` + `.sys.ini` per language × 14 languages) just slow that loop down without adding any value during the "does this even work" phase. Add them as part of the first tagged release, not the first build. Confirmed with Tim while building cs-articles-module-maxxed v1.0.0 (2026-05-06).

---

## 🔐 Security Baseline

**Already documented in:** [[NEW-EXTENSION-CHECKLIST.md]] → Security Baseline + [[README.md]] → SECURITY IS THE #1 PRIORITY.

Every extension passes a `security-review` skill run with **zero HIGH or MEDIUM findings** before tagging a release. Listed here as the most important wishlist item — none of the rest matter if the extension is exploitable.

---

## 🟢 Only Support Actively-Maintained Joomla Versions

**Source:** Tim Davis, established 2026-05-23 while spec'ing cs-cron-master.

**Pattern:** New Cybersalt extensions target **only the Joomla versions that are currently in active support** — at the time of writing that's **Joomla 5.x and Joomla 6.x**. Joomla 4.x dropped to security-only in October 2025 and out of LTS in October 2026; treat it as legacy. Joomla 3 is end-of-life. Existing extensions that already shipped for older Joomla versions don't have to drop support on their next minor release, but **every new extension starts at the current support floor**.

**What this means in practice:**

1. **Manifest `<targetplatform>`:** `<targetplatform name="joomla" version="5\.[0-9]+|6\.[0-9]+" />` — never include `4\.` in a new extension's regex.
2. **Required PHP minimum tracks the lowest currently-supported Joomla.** J5 requires PHP 8.1+, so that's the floor for new extensions.
3. **Use modern patterns unconditionally** — namespaced layout, `services/provider.php`, `BootableExtensionInterface`, `SubscriberInterface`, `AbstractModuleDispatcher`, J5/6 CLI app. No legacy compatibility shims. No "if J4 then …" branches.
4. **README and `.sys.ini` description explicitly state J5/6 only.** Don't leave it ambiguous; J4 users reading the listing will assume "it'll probably work" and file support tickets when it doesn't.
5. **Update-server `<targetplatform>`** in `updates.xml` also matches the same J5/6 regex. Don't let Joomla 4 sites silently auto-update to a release that won't run.

**Why it matters:** Cybersalt manages a fleet of sites. Maintaining a dual-target codebase (J4 + J5/6 in the same extension) doubles the test matrix, doubles the bug surface, and means modern Joomla patterns (DI, named events, `SubscriberInterface`) get watered down to the lowest common denominator. Once Joomla project itself stops actively supporting a version, Cybersalt does too.

**Exceptions:** If a specific paying client needs an extension targeted at the legacy version they're stuck on, that's a one-off contract; build it on a branch, don't pollute the main repo's manifest with it.

**Implementation pointer:** When in doubt, check https://www.joomla.org/announcements/release-news/ and the joomla.org-current-supported-versions page for the active support floor. Don't go from memory — the floor moves.

**Examples in the wild:**

- cs-cron-master v1.0.0 — J5/6 native, manifest regex `5\.[0-9]+|6\.[0-9]+`, no J4 manifest variant. (Established this rule.)
- cs-template-integrity, cs-menu-item-conditions, cs-registration-redirect — all post-2026 J5/6 native.

---

## 📋 Standard Log Viewer (Every Extension With Runtime Logs)

**Source:** Tim Davis, established as an explicit wishlist rule 2026-05-23 while building cs-cron-master's enhanced log view.

**Pattern:** Every Cybersalt extension that records runtime events — cron runs, API calls, file operations, anything that benefits from "what just happened?" diagnostics — ships with a **consistent log viewer** with the following features. This isn't optional; muscle memory across extensions is the goal.

### Required features

1. **Top button bar** in this order:
   - **Refresh** — round-trip back to the logs view, preserves active filters
   - **Dump** (plain text) — opens the current filtered set as text in a new tab so the user can copy/paste into a support ticket or Slack
   - **Download CSV** — exports the current filtered set as a CSV file (`<extname>-log-YYYYMMDD-HHMMSS.csv`)
   - **Delete** (selected rows, standard Joomla confirm)
   - **Clear All** — opens a **Bootstrap modal confirm** before wiping the table (not just a JS alert; not a direct link)

2. **Stats bar** at the top, with one card per metric:
   - Total entries
   - Last 24 hours
   - Success count (green)
   - Warning count (yellow)
   - Error count (red)
   - Any extension-specific counts (e.g. "Skip", "Throttled", "Cached hit")
   - **Each card is a clickable filter link** to the matching filtered view — wishlist rule "📊 Hotlinked dashboard stats" applies here too

3. **Filters** in the searchtools chip row (every visible column has one — wishlist rule "🔍 Filter every column" applies):
   - Free-text search across summary + job-name (or whatever the per-row context is)
   - Status filter (success / warning / error / skip)
   - Trigger / source filter (manual / cron / API / etc.)
   - **Time-range filter**: Last hour / Last 24h / Last 7d / Last 30d / Any time
   - Per-extension grouping (e.g. job-id for cron logs, request-id for HTTP logs)

4. **Per-entry display**:
   - Timestamp (with finished-at tooltip if applicable)
   - Linkified entity reference (job name links to job edit, request-id links to detail, etc.)
   - **Color-coded status badge** (Bootstrap `bg-success` / `bg-warning text-dark` / `bg-danger` / `bg-secondary`)
   - Elapsed time in ms
   - **Expandable verbose details** via HTML `<details>` — keeps the row compact, shows the full stack trace / JSON / verbose output on click
   - Verbose output rendered in a bordered `<pre>` (no `bg-*` background — let Atum handle theme), `max-height: 320px`, `white-space: pre-wrap` so long lines wrap

5. **Empty-state alert** when no rows match the current filters (not a blank table)

6. **Dark-mode safe styling** — Bootstrap utility classes only; no inline `bg-light` / `bg-white` / inline colors; rely on Atum native theme variables; use `border` to delineate `<pre>` blocks instead of background

### Reference implementations

- **DB-backed model** (one row per event in a `#__<ext>_log` table): [cs-cron-master](https://github.com/cybersalt/cs-cron-master) — `admin/tmpl/logs/default.php` + `admin/src/Model/LogsModel.php` (`getStats()`, `getCsv()`, `getTextDump()`)
- **File-backed model** (newline-delimited JSON in `logs/<ext>.log`): [cs-joomla-router-tracer](https://github.com/cybersalt/cs-joomla-router-tracer) — `tmpl/viewer.php`

The DB-backed pattern is preferred for new extensions because it gets the full benefit of Joomla's `ListModel` / `searchtools` / pagination infrastructure for free. Reach for the file-backed pattern only when the extension *already* logs to a file for some other reason (e.g. a system plugin that has to log from contexts where the Joomla DB isn't available).

### What this means for new extensions

When a new extension would benefit from runtime logging, the choice isn't "should we add a log viewer?" — it's "DB-backed or file-backed?" Always one of those two, never "skip it." The user's workflow when something goes wrong should be: open the extension, click Logs, see what happened, dump-to-clipboard for the support ticket. Anything less is a regression.

**Why it matters:** Cybersalt extensions get deployed across a fleet of client sites. When something goes wrong on a site Tim hasn't touched in months, the only thing standing between "I can fix this in 5 minutes" and "I need to SSH in and grep the Apache log" is a thorough in-extension log viewer. The investment in building one pays for itself the first time it saves an emergency support session.

**Implementation pointer:** see `cs-cron-master`'s LogsModel for the canonical `getStats()` / `getCsv()` / `getTextDump()` triad that the toolbar buttons hang off. Roughly 120 lines of model code plus 100 lines of tmpl. Not a lot; just enforce it everywhere.

---

## 📝 Changelog (Markdown + HTML, Kept In Sync)

**Already documented in:** [[README.md]] → Changelog Format + [[VERSION-BUMP-CHECKLIST.md]].

Both `CHANGELOG.md` and `CHANGELOG.html` exist, use the emoji section convention (🚀 New | 🔧 Improvements | 📦 Build | 🐛 Fixes | 🔍 Security | 📝 Docs), and are updated in the same commit as the version bump.

---

## 🧹 Custom CSS Tab on Every Module

**Already documented in:** [[JOOMLA5-MODULE-GUIDE.md]] + [[README.md]] → Best Practices Overview.

Every module ships with a dedicated tab/fieldset for custom CSS so end-users can tweak presentation without forking the module's stylesheet. Cross-references the cache-busting `filemtime()` pattern from [[JOOMLA5-UI-PATTERNS.md]].

---

## 🎨 Dark Mode Tested

**Already documented in:** [[JOOMLA5-COMMON-GOTCHAS.md]] + [[JOOMLA5-WEB-ASSETS-GUIDE.md]].

Every admin UI is tested with Joomla's dark template active before release. No hard-coded `bg-light` or `btn-outline-*` classes that disappear on dark backgrounds. Pair colours come from CSS variables (`--bs-body-bg`, `--bs-body-color`, etc.) rather than fixed hex values.

---

## 📊 Hotlinked Dashboard Stats

**Source:** Tim Davis, suggested while building cs-download-id-manager (May 2026).

**Pattern:** When a component has a Dashboard view with stat cards (active items, today's activity, totals, etc.), every card should be **clickable** and navigate to the relevant filtered list view. Not a static infographic — an entry point.

1. **Each card wraps in an `<a href>`** that builds a URL with the filter pre-applied: `index.php?option=com_yourext&view=items&filter[status]=active`.
2. **Stats grouped into sections** with subheadings (e.g., "Today's Activity", "All-Time Totals", "Catalog & Security") rather than one long row of cards.
3. **Visual feedback on hover** so it's clear they're clickable: subtle lift + shadow via CSS `transform: translateY(-2px)` + `box-shadow`.
4. **Color-coded by meaning** using Bootstrap utility classes (`text-success` for healthy counts, `text-warning` for items needing attention, `text-danger` for failures/reports).

**Why it matters:** Dashboards that don't navigate are read-only walls of numbers. The natural next question after "how many failed checks today?" is "which ones?" — make that one click, not three. Reduces "I have to remember which menu item to click" friction for both new and experienced admins.

**Implementation pointer:** Build URLs with `Route::_()` and Joomla's filter URL convention `filter[fieldname]=value`. Filter values must match what the model's `populateState()` expects. CSS hover effect on a `.dashboard-stat-card` class — see `cs-download-id-manager` for a working example. For filters that combine multiple statuses (e.g., "reported" = suspended + has report_reason), the model needs to translate the filter value into the actual SQL conditions.

---

## 🆘 Built-In Support Area

**Source:** Tim Davis, suggested while building cs-download-id-manager (May 2026).

**Pattern:** Every extension should have a configurable "Support Contact" section in component options (or a parameter group for plugins/modules) that defines:

1. **Support email** — where users can reach help (default: `support@cybersalt.com`)
2. **Support URL** — link to a contact form or knowledge base (default: `https://www.cybersalt.com/services/support-request-form` — this is the canonical Cybersalt support entry point; use it as the default `support_url` across **every** Cybersalt extension so a single page change downstream propagates to every extension's install card. Set on 2026-05-06.)
3. **Support label** — how to refer to support in messages (default: `Cybersalt support`)

Plus a **`SupportHelper` class** (or equivalent) that builds a consistent "please contact …" sentence used everywhere errors surface — API responses, error pages, denial messages, frontend cards. Never hardcode a generic "contact support" string.

The component should also have a **visible Support panel/tab** in the admin UI showing these values plus links to documentation, the changelog, and the GitHub issues page (if open source). New users land here when something breaks.

**Why it matters:** When something goes wrong on a customer site, the message says "Please contact support" — but support contact info isn't in the message. The user has to leave the error, find the extension's website, find the support page, and explain the error from memory. A configurable support helper means every error message can include the right email/URL inline. The visible Support panel reduces "where do I go for help?" friction.

**Implementation pointer:**

```php
// admin/src/Helper/SupportHelper.php
public static function getContactSentence(): string
{
    $params = ComponentHelper::getParams('com_yourext');
    $email = trim($params->get('support_email', ''));
    $url   = trim($params->get('support_url', ''));
    $label = trim($params->get('support_label', 'our support team')) ?: 'our support team';

    $parts = array_filter([$email, $url]);
    return empty($parts)
        ? 'Please contact ' . $label . ' for assistance.'
        : 'Please contact ' . $label . ' (' . implode(' / ', $parts) . ') for assistance.';
}
```

Add a `<fieldset name="support">` to `config.xml` with the three fields. Use `SupportHelper::getContactSentence()` everywhere a "contact support" message is shown. See `cs-download-id-manager` for a working example.

---

## 🔍 Filter Every Column That's Displayed

**Source:** Tim Davis, suggested while building cs-download-id-manager (May 2026); promoted to a hard rule while building cs-image-sentinel (May 2026) after another list view shipped without per-column coverage.

**The rule:** every column shown in an admin list view gets a corresponding filter in the searchtools filter bar. "Search box + status dropdown" is not enough. If the operator can see a column, the operator can slice by it in one click. List views that do not satisfy this are considered incomplete and should not ship.

**By column type:**

1. **Enumerated columns** (status, type, category, result) → dropdown filter populated from the data's actual values (empty options not shown).
2. **Free-text columns** (domain, email, name, path) → text filter on the column. The global search box covers many text columns at once but does NOT count as the per-column filter for this rule.
3. **Date columns** (created, last_check, release_date) → date range with two `calendar` fields (`<col>_from` and `<col>_to`), plus optional preset shortcuts (today, yesterday, last 7/28 days, custom range).
4. **Boolean columns** (is_latest, is_stable, is_published, is_orphan) → Yes/No dropdown.
5. **Foreign key columns** (package, category, author, folder_id) → SQL-backed picker dropdown.
6. **Numeric / id columns** → either an exact-match text input or a min/max pair if range queries are useful.

**Wiring checklist** (skipping any of these breaks the filter silently):

- [ ] `<field>` added to `forms/filter_<view>.xml` under `<fields name="filter">`
- [ ] State key added to `filter_fields` in the `ListModel` constructor
- [ ] Filter applied in `getListQuery()` reading from `$this->getState('filter.<key>')`
- [ ] State key contributes to `getStoreId()` so the cache invalidates when the filter changes (Brain gotcha #17)
- [ ] Language constant added for the field label and any hint
- [ ] If date-range, both ends bound and either-end-empty handled

**Why it matters:** Lists with limited filtering force users to scan visually or learn search syntax. A filter per displayed column means the user's mental model ("I want to see only X") matches the UI directly. Especially important for extensions where buyers/admins are looking at potentially thousands of rows.

**Implementation pointer:** Joomla 5's filter bar pattern (see `JOOMLA5-LIST-FILTERS-GUIDE.md`). For dynamic dropdowns populated from data, use a custom form field type that queries `DISTINCT column FROM table` (see cs-download-id-manager's `EventtypeField` and `ResulttypeField`). For date ranges, a `<select>` with preset ranges (today/yesterday/7days/28days) plus a "Custom…" option that reveals from/to date pickers is the cleanest UX.

---

## 🏷 Admin Page Titles With Vendor + Component + View

**Source:** Tim Davis, suggested while building cs-download-id-manager (May 2026).

**Pattern:** Every admin page's `ToolbarHelper::title()` should follow the format: **`{Vendor} {Component Name} {View Name}`** — for example "Cybersalt Update Access Manager Dashboard", "Cybersalt Update Access Manager Packages", "Cybersalt Update Access Manager Edit Installation".

Don't show just the view name ("Dashboard", "Packages") — that loses context when the admin has multiple Cybersalt extensions installed and is rapidly switching between them. The full title at the top of the page is part of how an admin orients themselves.

**Why it matters:** When you're a site admin with 10 installed extensions, the breadcrumbs and Joomla menu are not always visible. The page title is the most-glanced piece of UI. Repeating the vendor + extension name in every admin title makes "where am I right now?" answerable without looking elsewhere.

**Implementation pointer:** Build a single language constant per view:

```ini
COM_CSUPDATEACCESSMANAGER_TITLE_DASHBOARD="Cybersalt Update Access Manager Dashboard"
COM_CSUPDATEACCESSMANAGER_TITLE_PACKAGES="Cybersalt Update Access Manager Packages"
COM_CSUPDATEACCESSMANAGER_TITLE_PACKAGE_NEW="Cybersalt Update Access Manager — New Package"
COM_CSUPDATEACCESSMANAGER_TITLE_PACKAGE_EDIT="Cybersalt Update Access Manager — Edit Package"
```

Then in each View's `addToolbar()`:

```php
ToolbarHelper::title(Text::_('COM_CSUPDATEACCESSMANAGER_TITLE_DASHBOARD'), 'dashboard');
```

Avoid the temptation to keep one short string ("Dashboard") and concatenate the vendor name in PHP — translators expect the full string per language constant.

---

## 🎯 Pickers, Never IDs Typed by Hand

**Source:** Tim Davis, suggested while building cs-menu-item-conditions (May 2026).

**Pattern:** Whenever a Cybersalt extension's config form needs the user to identify Joomla entities — menu items, components, categories, articles, users, tags, modules, views — render a **picker dropdown**. Never make the user type raw IDs (`123, 456`), `option=...` element names, or `option.view` pairs by hand. The user shouldn't have to leave the form to look anything up.

The same rule applies to URL-pattern fields: prefer an operator selector (Contains / Equals / Begins with / Ends with / Regex) over forcing every user to write PCRE. Most non-technical admins don't know regex; the operator menu lets them describe the match in English.

1. **Single menu item** → `type="menuitem"` (works in plugin settings; do NOT use `modal_menu`, see UI-PATTERNS.md §11).
2. **Multiple menu items** → `type="sql"` with `multiple="true"` + `layout="joomla.form.field.list-fancy-select"`. Query `#__menu` joined to `#__menu_types` so the dropdown groups by menu type.
3. **Multiple components** → `type="sql" multiple="true" layout="joomla.form.field.list-fancy-select"` against `#__extensions WHERE type='component' AND enabled=1`.
4. **Multiple component views** (`option.view` pairs) → custom `ListField` subclass that scans `components/com_*/src/View/*` (J4+ namespaced) and `components/com_*/views/*` (legacy MVC). There is no core field type for this — see `cs-menu-item-conditions/src/Field/ComponentViewsField.php` for a working example.
5. **Categories** → `type="categories"` for multi, `type="category"` for single.
6. **Articles** → `type="sql"` with grouped query (UI-PATTERNS.md §11). `modal_article` silently fails in plugin settings.
7. **Tags** → `type="tag" multiple="true"`.
8. **URL match rules** → `type="subform" multiple="true" layout="joomla.form.field.subform.repeatable"` with two child fields per row: an `operator` list (Contains/Equals/Begins/Ends/Regex) and a `value` text input. Strip protocol+host server-side so the user can paste either a path or a full URL and both work.

**Why it matters:** "Comma-separated list of Itemids" is a UX disaster. Most site admins don't know what an Itemid is, and the ones who do still resent leaving the form to look up the values. Pickers do the lookup, prevent typos that fail silently, and make the form approachable for less-technical users (which is most of them). The operator-builder for URLs prevents the equivalent regex-knowledge tax — a Cybersalt extension shouldn't ship a field that 80% of admins can't fill in correctly.

**Implementation pointer:** See `cs-menu-item-conditions` v0.1.x for a fully-worked example of all four patterns (sql multi-select for menu items + components, custom ListField for views, subform for URL rules with operator selectors). The `addfieldprefix="Cybersalt\Plugin\System\..."` attribute on the `<form>` root is what registers the custom field's namespace so `type="ComponentViews"` resolves.

**Free-text input as a fallback alongside pickers is fine** when the picker can't enumerate every possibility (e.g. a hostname-pattern field that needs wildcards). Don't make it the only option.

---

## 🟢🔴 Yes/No Toggles Should Be Green and Red

**Source:** Tim Davis, suggested while building cs-download-id-manager (May 2026).

**Pattern:** Joomla's default `type="radio"` with `class="btn-group"` (the Yes/No pill toggle pattern) renders as plain blue or grey buttons. Override the styling so:

1. **Selected "Yes"** → solid green button (`bg-success`).
2. **Selected "No"** → solid red button (`bg-danger`).
3. **Unselected** → outline only (`btn-outline-success` / `btn-outline-danger` so the option is still visible at low contrast).

Apply this consistently to **every** Yes/No field across admin and frontend.

**Why it matters:** Toggle states should be readable at a glance. Blue-on-blue or grey-on-grey forces the user to read the labels to know which is selected. Green = "this is on / will happen", red = "this is off / will not happen" matches universal traffic-light intuition.

**Implementation pointer:** In `media/css/admin.css` (or per-extension equivalent):

```css
/* Joomla 5 renders radio btn-groups with .btn-group > input + label */
.btn-group > input[type="radio"]:checked + label.btn-outline-secondary[data-value="1"],
.btn-group > input[type="radio"]:checked + label[for$="0"] {
    /* Yes when selected */
    background-color: var(--bs-success);
    border-color: var(--bs-success);
    color: #fff;
}
.btn-group > input[type="radio"]:checked + label[for$="1"] {
    /* No when selected */
    background-color: var(--bs-danger);
    border-color: var(--bs-danger);
    color: #fff;
}
```

**Caveat:** Joomla's exact rendering differs between J3, J4, and J5. Test in dark mode too. The simplest robust approach is to inspect a rendered Yes/No field on a real install and adjust the selectors accordingly. Document the working CSS in [[JOOMLA5-UI-PATTERNS.md]] once stable.

---

## ❓ Inline-Help Toggle on Every Form

**Source:** Tim Davis, suggested while building cs-image-sentinel (May 2026).

**Pattern:** Every admin **edit form and config dialog** in a Cybersalt extension ships the inline-help toggle button in its toolbar. Operators click it to switch each field's `description` attribute from tooltip rendering to a paragraph rendered directly under the field, and click again to revert.

```php
protected function addToolbar(): void
{
    ToolbarHelper::title(...);
    ToolbarHelper::apply('item.apply');
    ToolbarHelper::save('item.save');
    ToolbarHelper::cancel('item.cancel', 'JTOOLBAR_CLOSE');
    ToolbarHelper::inlinehelp();   // ← this line
}
```

**Why it matters:** Tooltips force the operator to hover-and-wait per field, can't be copy-pasted, are hostile to touch devices, and are easy to dismiss accidentally. Inline help renders the descriptions as part of the form so the operator can read once, plan, and fill the form linearly. The button label is built-in ("Toggle Inline Help") and Joomla's CSS handles the rendering switch — the only failure mode is forgetting to add the button.

**Implementation pointer:** `\Joomla\CMS\Toolbar\ToolbarHelper::inlinehelp()` requires no controller method, no language string, and no view-side rendering changes. The component-options dialog (Component → Options) already includes the toggle automatically — this rule applies to the component's own edit forms, plugin settings (when those are rendered as a form), and any custom config dialogs.

List views generally don't have field descriptions, so the toggle is unnecessary on `View\<Items>\HtmlView.php`. The rule applies to forms, not lists.

---

## ⇧ Shift-Click Range Selection on Bulk-Action Lists

**Source:** Tim Davis, while testing cs-remove-sample-data v1.0.5 (May 2026).

**Pattern:** Any admin list view where each row carries a checkbox for a bulk action (remove, publish, batch, etc.) must support **shift-click range selection**. Click the first checkbox, hold Shift, click a second checkbox further down (or up) the list, and every checkbox between the two snaps to the second click's state — ticked or unticked. The range is scoped per group/table: shift-clicks don't cross into a separate card or table on the same page.

```javascript
// Per-group setup. `boxes` = Array.from(form.querySelectorAll('.row-checkbox[data-group="' + group + '"]'))
const lastClickedByGroup = {};
boxes.forEach(function (b) {
    b.addEventListener('click', function (e) {
        const last = lastClickedByGroup[group];
        if (e.shiftKey && last && last !== b) {
            const i1 = boxes.indexOf(last);
            const i2 = boxes.indexOf(b);
            if (i1 !== -1 && i2 !== -1) {
                const start = Math.min(i1, i2);
                const end   = Math.max(i1, i2);
                const state = b.checked;
                for (let i = start; i <= end; i++) {
                    boxes[i].checked = state;
                }
                window.getSelection && window.getSelection().removeAllRanges();
            }
        }
        lastClickedByGroup[group] = b;
        // refresh master-checkbox state and ticked-count here too
    });
});
```

**Why it matters:** When a list runs to dozens or hundreds of rows, ticking each one individually is tedious and error-prone. Shift-click is the universal table-list muscle memory from desktop file managers, spreadsheets, Gmail, Trello — every Cybersalt list view should honour it instead of forcing the operator to click each row separately. Pair it with a per-group master checkbox and a global "Tick all everywhere" / "Untick all everywhere" pair of buttons so the operator has three speeds: one-at-a-time, range, all.

**Implementation pointer:** Track `lastClickedByGroup` outside the click handler so it persists between events; key by the data-group attribute so each table/card scopes its own range. Read `b.checked` AFTER the click event fires (the browser has already toggled the box by then), and propagate that value to every box in the inclusive range. Always clear `window.getSelection()` afterwards — shift-click on the page also tries to start a text-selection range, which looks broken if you leave it. Reference implementation: `media/js/admin.js` in [cs-remove-sample-data](https://github.com/cybersalt/cs-remove-sample-data).

---

## ⚪ White Disc Behind the Brand Logo on Dark Surfaces

**Source:** Tim Davis, while reviewing cs-articles-module-maxxed v1.3.0 (2026-06-17). Inspired by the cs-siteground-cache header treatment.

**Pattern:** Anywhere a Cybersalt brand logo appears on a dark surface — install-card header in dark Atum, plugin-settings tab brand header, dashboard hero, admin notification panel, frontend module brand element — wrap the SVG in a white circular disc. The cobalt + orange artwork loses contrast against slate-800 backgrounds; a white disc gives it back its readability without changing the artwork itself. **Light mode keeps the logo bare** — the disc only renders in dark mode.

Padding ≈ 10–15% of the logo's intrinsic size gives a visibly larger disc that mirrors the cs-siteground-cache treatment. Anything smaller looks like a clip mask; anything larger looks like a separate UI chip.

**Why it matters:** The brand logo is the "this is a Cybersalt extension" signal. If it disappears against a dark background, brand recognition gets lost in dark mode — and Joomla 5/6 admin runs in dark mode a lot. A consistent white-disc treatment everywhere keeps the brand legible in both light and dark and makes the family of extensions feel intentional rather than "we forgot about dark mode."

**Implementation pointer:** One CSS rule per surface that displays a logo:

```css
html[data-bs-theme="dark"] .your-surface img.brand-logo,
html[data-color-scheme="dark"] .your-surface img.brand-logo {
    background-color: #fff;
    border-radius: 50%;
    padding: 6px;
    box-sizing: content-box;
}
```

Joomla 5/6 uses BOTH `data-bs-theme="dark"` and `data-color-scheme="dark"` depending on template/version — match both. `box-sizing: content-box` keeps the padding *outside* the original image dimensions so the disc visibly extends past the artwork (rather than shrinking the logo to fit inside).

Reference implementation: cs-articles-module-maxxed v1.3.0 — see `src/Field/BrandheaderField.php` (`renderPageInfoLogoInjection()` for the JS-injected variant + `renderFullBrandHeader()` for the card variant) and `script.php` (`renderInstallCard()`) — three branded surfaces, same rule applied to each.

**Companion to:** §"Post-Install Card With Next Steps" and §"Branded Tab Header on Every Settings Fieldset" — both inherit this rule on their dark-mode renderings.

---

## 🖼 Branded Tab Header on Every Settings Fieldset

**Source:** Tim Davis, while reviewing cs-articles-module-maxxed v1.3.0 (2026-06-17).

**Pattern:** Every fieldset in a Cybersalt extension's settings form (plugin params, component options, module params) renders a small branded header card as its first row — extension logo on the left at ~48px, plugin/component name as a coloured `<h4>` heading, a per-fieldset subtitle ("Skip-articles configuration", "Support contact information", "API credentials", etc.) underneath in muted text. Same light/dark CSS-variable theming as the post-install card (white background + cobalt title in light Atum, slate background + brand orange title in dark Atum). All CSS scoped to a `.cs-plugin-tab-header` class so it doesn't leak into the rest of the form.

The pattern uses a tiny **custom form field type** — `BrandheaderField` extending `Joomla\CMS\Form\FormField` — that overrides `renderField()` to emit the header HTML and returns `''` from `getInput()` so no input row renders. The XML attribute `subtitle="LANG_KEY"` lets each fieldset describe itself in one line.

**Why it matters:** Joomla's default tabbed-settings UI gives the operator *no* visual cue about which extension's settings they're currently in — every plugin's tabs look identical. Once a site has a dozen Cybersalt extensions installed, "which one am I in?" becomes a real friction point. A small branded header per tab solves it instantly and reinforces the family look. Also gives every settings tab a one-line statement of purpose, which is half the value of inline help without needing the inline-help toggle to be on.

**Implementation pointer:** Reference implementation in [cs-articles-module-maxxed v1.3.0](https://github.com/cybersalt/cs-articles-module-maxxed) — see `src/Field/BrandheaderField.php` for the custom field class, and `csarticlesmodulemaxxed.xml` for the `<fields name="params" addfieldprefix="Cybersalt\Plugin\System\Csarticlesmodulemaxxed\Field">` wiring + per-fieldset `<field type="brandheader" subtitle="..."/>` placements. The field is ~80 lines including the scoped CSS; copy + adjust the namespace + logo path per extension. Eventually worth extracting to a shared `cs-extension-ui` library if/when more than three extensions adopt it.

**Companion to:** post-install card §"Post-Install Card With Next Steps" — uses the same colour variables and logo so the install card and the settings tabs feel like the same brand.

---

## ➕ Adding to This List

When you encounter something that *should* be in every extension but isn't here yet, add a section using the same template:

```markdown
## [emoji] [Short title]

**Source:** [who suggested it / where it came from] [, date if relevant]

**Pattern:** [one-paragraph description of the pattern]

**Why it matters:** [the user-facing problem it solves]

**Implementation pointer:** [where to look in existing guides, or a sketch if greenfield]
```

Cross-reference the relevant deep-dive guide rather than duplicating implementation detail here. This file is a *checklist*, not a tutorial.
