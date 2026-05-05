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

---

## 🌐 15-Language Coverage From Day One

**Already documented in:** [[README.md]] → Language System Requirements.

Every Cybersalt extension ships with translations for the 15 core PHP Web Design languages: en-GB, nl-NL, de-DE, es-ES, fr-FR, it-IT, pt-BR, ru-RU, pl-PL, ja-JP, zh-CN, tr-TR, el-GR, cs-CZ, sv-SE. Don't ship en-GB only and "add translations later" — translations later never happen.

---

## 🔐 Security Baseline

**Already documented in:** [[NEW-EXTENSION-CHECKLIST.md]] → Security Baseline + [[README.md]] → SECURITY IS THE #1 PRIORITY.

Every extension passes a `security-review` skill run with **zero HIGH or MEDIUM findings** before tagging a release. Listed here as the most important wishlist item — none of the rest matter if the extension is exploitable.

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

1. **Support email** — where users can reach help
2. **Support URL** — link to a contact form or knowledge base
3. **Support label** — how to refer to support in messages (e.g., "Cybersalt support", "the development team")

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

## 🔍 Filter Every Column That's Worth Filtering

**Source:** Tim Davis, suggested while building cs-download-id-manager (May 2026).

**Pattern:** When a list view has columns like Status, Package, Type, Result, etc., every one of those enumerated columns should have a corresponding filter in the filter bar (or filter row above the table). If a user can see a column and it has a finite set of values, they should be able to filter to just that value.

1. **Enumerated columns** (status, type, category, result) → dropdown filter populated from existing values in the data (so empty options aren't shown).
2. **Free-text columns** (domain, email, name) → covered by the global search box, but optionally given a dedicated text filter when the list is large.
3. **Date columns** (created, last_check, release_date) → date range filter (today, yesterday, last 7 days, last 28 days, custom range).
4. **Boolean columns** (is_latest, is_stable, is_published) → simple Yes/No filter.
5. **Foreign key columns** (package, category, author) → dropdown of available parent items.

The goal: if a user looks at the list and asks "show me only the X ones" the answer is always one click away.

**Why it matters:** Lists with limited filtering force users to scan visually or learn unintuitive search syntax. A filter per filterable column means the user's mental model ("I want to see only X") matches the UI directly. Especially important for extensions where buyers/admins are looking at potentially hundreds of rows.

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
