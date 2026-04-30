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
