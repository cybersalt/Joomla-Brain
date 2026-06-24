# JED Submission Checklist

How to list a Cybersalt extension on the **Joomla Extensions Directory** (extensions.joomla.org) without getting bounced by the reviewer queue.

> [!IMPORTANT]
> Use this checklist **alongside** `NEW-EXTENSION-CHECKLIST.md` and `VERSION-BUMP-CHECKLIST.md` — those cover making the extension; this covers getting it listed. JED submission is a public, slow review queue (1-4 weeks typical), so first-submission rejection costs real calendar time. Run the whole checklist before clicking Submit.

This checklist was distilled from the **live JED submission of cs-template-integrity v2.4.2** on 2026-06-24 ([WMW #343](https://www.youtube.com/@Basicjoomla)) — particularly @Bredc's live catches of the three first-timer gotchas that every developer hits.

---

## Why list on JED at all?

You're already selling / distributing from `cybersalt.com/extensions/{name}` with the cs-release-manager update server, so why JED?

- **Organic discovery.** Every Joomla admin browsing the directory for "override checker" / "backup" / "form builder" / etc. lands in the JED — that traffic doesn't come from cybersalt.com SEO.
- **Trust signal.** A JED listing carries reviewer-vetted credibility many site owners require before installing third-party code.
- **Cross-promotion.** JED listings get featured in Joomla.org communications + reviewer-curated lists.
- **Free.** Listing has no fee; the only cost is the prep work in this checklist.

The cybersalt.com page **stays canonical** — JED links back; the listing isn't a replacement for selling direct.

---

## Pre-flight — before opening the submission form

> *"Always do cleaning before inviting JED on a visit."* — @Bredc, WMW #343

### 1. Extension is at a stable, release-tagged version

- [ ] **Latest GitHub release** tagged + zip attached (e.g. `v2.4.2`)
- [ ] **CHANGELOG.md + CHANGELOG.html** in sync, up to date
- [ ] **No known critical bugs** open in the repo's Issues
- [ ] **README.md refreshed** — no stale version references, no drifted brand names (see `VERSION-BUMP-CHECKLIST.md` → "Refresh README.md")
- [ ] **License file present** (`LICENSE` or `LICENSE.md`) at the repo root, GPL-2.0-or-later text

### 2. Download URL is the FILE URL, not the page URL ⚠️

**The #1 first-timer gotcha. Bjørn caught Tim on this at WMW #343 11:40.**

When JED asks for a "Download URL," they mean the URL that directly serves the `.zip` — not the human-readable landing page that contains a Download button.

- ❌ **Wrong** (this is the landing page):
  `https://www.cybersalt.com/extensions/template-integrity`
- ✅ **Right** (this serves the file directly):
  `https://www.cybersalt.com/index.php?option=com_csreleasemanager&task=api.userdownload&format=raw&element=pkg_cstemplateintegrity&version=2.4.2`

Or, if you're hosting on GitHub Releases:

- ✅ `https://github.com/cybersalt/{repo}/releases/download/v{version}/pkg_{name}-{version}.zip`

**How to verify before submitting:**

```bash
# Should respond with Content-Type: application/zip and the file bytes
curl -sIL "<your-download-url>"
```

If `Content-Type: text/html` comes back, you've handed JED the page URL. Fix and re-verify.

### 3. Logo URL is fully qualified — no `/images/...` shortcuts ⚠️

**Gotcha #2 from WMW #343 at 11:52.**

JED renders your logo on a public catalog page on `extensions.joomla.org`. A relative path like `/images/logo.svg` resolves against `extensions.joomla.org`, not your site — and 404s.

- ❌ `/images/extensions/logos/cs-template-integrity.svg`
- ✅ `https://www.cybersalt.com/images/extensions/logos/cs-template-integrity.svg`

Same rule applies to **screenshots** and any other asset URL JED asks for. Always paste the full `https://...` URL.

### 4. Support link + license page link are required fields ⚠️

**Gotcha #3 from WMW #343 at 12:05-12:06.**

The submission form has dedicated fields for these and JED's review will bounce a submission missing them.

- [ ] **Support link** — where users get help. Options:
  - `https://www.cybersalt.com/support`
  - `https://github.com/cybersalt/{repo}/issues`
  - A dedicated `support@cybersalt.com` mailto: (less preferred — JED wants a page, not just an email)
- [ ] **License page link** — where the license text lives. Standard:
  - `https://www.gnu.org/licenses/old-licenses/gpl-2.0.html` (canonical GPL-2.0 text)
  - Or a local copy: `https://github.com/cybersalt/{repo}/blob/main/LICENSE`

### 5. Screenshots are current

- [ ] **At least 2 screenshots**, 3-5 ideal
- [ ] **800-1280px wide** (JED's thumb generator works best in this range)
- [ ] **PNG or JPG**, no transparent backgrounds (will render on a white page)
- [ ] **Current UI** — not 2019-era screenshots from an earlier version. If the dashboard redesigned in a recent release, retake every screenshot.
- [ ] **Real data**, not Lorem-Ipsum placeholder rows — looks more credible
- [ ] **No client info / credentials / PII** visible in screenshots — black-bar redact if needed
- [ ] **Hosted at a stable URL** — full `https://www.cybersalt.com/...` (same rule as logo)

**Recommended tool:** [ShareX](https://getsharex.com) (free, Windows). Active-window-only captures (`Ctrl+PrintScreen` in ShareX) avoid the desktop background bleed.

### 6. Description copy is in markdown, not HTML

**WMW #343 11:45 + 11:49.**

JED's long-description field accepts markdown. If your extension article on cybersalt.com is in HTML (because Joomla articles are HTML), convert it before pasting:

- Take the HTML source of the article body
- Convert to markdown (any HTML→MD converter, or feed it through Claude with a "convert to markdown, keep structure + emphasis" prompt)
- Paste the markdown into JED's long-description field

**Short description** (~200 chars max) needs to be standalone marketing copy — the elevator-pitch sentence. Borrow from cybersalt.com's `<meta name="description">` if it exists, but write fresh if needed.

### 7. Category + tags decided ahead of time

JED categories are nested. Pick before opening the form so you don't change mid-submission:

- **Site Management → Site Security** — for integrity, malware, override, audit tools
- **Site Management → Site Backup** — backups only
- **Site Management → Site Performance** — caching, optimization
- **Style & Design → Templates** — template frameworks (NOT add-on tools that work on templates)
- **Authoring & Content → Custom Code & Display** — modules that surface content in new ways
- **Tools** — utility / dev-tool extensions
- **Plug-ins → System** — system plugins that don't fit elsewhere

Tags should be specific, comma-separated. Cybersalt-style:

```
joomla 5, joomla 6, security, integrity, overrides, claude ai, mcp, cybersalt
```

### 8. Update server (`updates.xml`) is live + valid

Required so users can in-admin upgrade after they install from JED.

- [ ] Manifest's `<updateservers>` block points at a public, reachable XML URL
- [ ] Curl the URL — get a valid `<updates>` document, not an HTTP error
- [ ] `<sha256>` matches the actual file at the `<downloadurl>` (re-verify after every release)
- [ ] At least one `<update>` entry with `<version>` matching your current release

See `JOOMLA5-UPDATE-SERVER-GUIDE.md` for the full spec.

---

## JED Contributor account setup

(One-time per developer — skip if already done.)

- [ ] **joomla.org account** — sign up at https://id.joomla.org if needed
- [ ] **JED contributor application** — apply at https://extensions.joomla.org via your profile
- [ ] **Verify Cybersalt domain ownership** if asked (typically via DNS TXT or meta tag)

The Cybersalt account is owned by `tim@cybersalt.com`.

---

## The submission form — field-by-field

Walk this in order. Tab between fields; don't lose the form.

| Field | What to enter | Source / gotcha |
|---|---|---|
| Extension name | Match the manifest `<name>` and repo name | Don't rename mid-submission — Bjørn floated alternatives during WMW #343; project doc decision stays. |
| Tagline / short description | ≤200 chars, marketing hook | Lead with the **recognition trigger** (e.g. *"the smarter Joomla override checker"*) not the product name |
| Long description | Markdown, ~500-2000 chars | Converted from the cybersalt.com article HTML |
| Version | Current release version (e.g. `2.4.2`) | Match manifest exactly |
| Category | Pre-decided per step 7 above | Can't easily change after submission — pick carefully |
| Tags | Comma-separated specific terms | Specificity > coverage. Don't keyword-stuff. |
| Compatibility | Joomla 5.x, 6.x | Match what your manifest's `<files>` and `<update>` blocks declare |
| PHP version | Match manifest minimum | J5: 8.1+, J6: 8.3+ |
| Download URL | **File URL, not page URL** (see step 2) | Critical |
| Logo URL | **Full `https://...` URL** (see step 3) | Critical |
| Screenshots | Full URLs, ≥2 images | One per field; full URLs |
| Support link | Public help destination (see step 4) | Required |
| License page link | GPL-2.0 text URL (see step 4) | Required |
| License (dropdown) | GPL v2 or later | Match what you said in the manifest |
| Author / Developer | Cybersalt Consulting Ltd | Match `company-info.md` |
| Author URL | https://www.cybersalt.com | |

---

## After hitting Submit

1. **JED reviewer queue.** Typical wait: 1-4 weeks. Status visible on your contributor dashboard.
2. **Reviewer checks** (publicly documented at https://extensions.joomla.org/support/listing-guidelines/):
   - Manifest validity
   - Clean install on a fresh Joomla site
   - No malware / obvious copyright violations
   - Description copy honest, no false claims
   - Listing assets (logo, screenshots) work
3. **Possible outcomes:**
   - ✅ **Approved** — listing goes live, you get an email with the JED URL
   - 🔄 **Revisions requested** — fix the flagged items, re-submit
   - ❌ **Rejected** — rare for legit extensions; surface the reasons to Tim and remediate
4. **After approval:**
   - [ ] Update the cybersalt.com extension page with the JED listing URL
   - [ ] Update the vault's extension article doc with the JED URL
   - [ ] Update the GitHub repo README with the JED badge
   - [ ] Cross-promote in next Cybersalt News + Net Shaker

---

## Ongoing — keeping the JED listing fresh

JED listings can go stale fast if the extension is moving and the listing isn't.

- **On every release**, update the listing's:
  - Version number
  - Long description (if features changed)
  - Screenshots (if UI changed)
  - Compatibility (if Joomla version range changed)
- **Reviewer can mark a listing "needs updating"** if it goes too long without a refresh. Monthly check is enough.

---

## Reference

- **JED Listing Guidelines:** https://extensions.joomla.org/support/listing-guidelines/
- **JED Submission Page:** https://extensions.joomla.org/submit-extension/
- **GPL-2.0 license text:** https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
- **Cybersalt company info:** `company-info.md`
- **Related Brain docs:**
  - `NEW-EXTENSION-CHECKLIST.md` — extension creation
  - `VERSION-BUMP-CHECKLIST.md` — release ceremony (run BEFORE JED submission)
  - `JOOMLA5-UPDATE-SERVER-GUIDE.md` — required `updates.xml` setup
  - `JOOMLA-EXTENSION-WISHLIST.md` — cross-cutting UX polish

---

## History

- **2026-06-24** — Initial version. Distilled from the live JED submission of cs-template-integrity v2.4.2 on WMW #343 (Watch Me Work episode #343), particularly @Bredc's live catches of the three first-timer gotchas (download URL vs page URL, full-URL logo requirement, support + license link required fields).
