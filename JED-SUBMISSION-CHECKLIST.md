# JED Submission Checklist

How to list a Cybersalt extension on the **Joomla Extensions Directory** (extensions.joomla.org) without getting bounced by the reviewer queue.

> [!IMPORTANT]
> Use this checklist **alongside** `NEW-EXTENSION-CHECKLIST.md` and `VERSION-BUMP-CHECKLIST.md` — those cover making the extension; this covers getting it listed. JED submission is a public, slow review queue (1-4 weeks typical), so first-submission rejection costs real calendar time. Run the whole checklist before clicking Submit.

This checklist was distilled from the **live JED submission of cs-template-integrity v2.4.3** on 2026-06-24 ([WMW #343](https://www.youtube.com/@Basicjoomla)) — particularly @Bredc's live catches of the three first-timer gotchas that every developer hits.

> [!NOTE]
> **Correction 2026-09-06.** Earlier revisions of this checklist recorded the WMW #343 submission as **v2.4.2**. The listing actually held **v2.4.3**. Corrected throughout; the same correction was made in the vault's JED account note.

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
  `https://www.cybersalt.com/index.php?option=com_csreleasemanager&task=api.userdownload&format=raw&element=pkg_cstemplateintegrity&version=2.4.3`

Or, if you're hosting on GitHub Releases:

- ✅ `https://github.com/cybersalt/{repo}/releases/download/v{version}/pkg_{name}-{version}.zip`

**How to verify before submitting:**

```bash
# Should respond with Content-Type: application/zip and the file bytes
curl -sIL "<your-download-url>"
```

If `Content-Type: text/html` comes back, you've handed JED the page URL. Fix and re-verify.

#### The Download URL is pinned to the extension ELEMENT name ⚠️

**Learned the hard way 2026-09-06.**

That URL hard-codes `element=pkg_{something}`. JED stores it as a literal string and never derives it from anything else about the listing. Two consequences:

- **Renaming a listing does not update the Download URL.** Only a JED team member can rename a listing, and when they do they change the *name* — nothing else. If the extension's element was renamed in the same breath (e.g. `pkg_cstemplateintegrity` → `pkg_csoverridechecker`), the listing keeps serving the old element and **silently 404s**.
- **Tidying up the release server breaks it too.** Unpublishing or deleting the old element's package in Cybersalt Release Manager kills a Download URL that still points at it. The listing page looks completely healthy; only the download is dead.

Note that JED listings can hold **more than one** element-bearing URL — on the Override Checker listing both `download_link` and `download_integration_url` carried the stale element. Fix every one of them.

- [ ] **Re-test the listing's Download URL after any rename, element change, or Release Manager tidy-up** — not just after a version bump. `curl -sIL` and confirm `HTTP 200` + `Content-Type: application/zip`, and sanity-check the byte count against the built zip.

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

**A required field can still be saved empty — and nothing tells you** *(learned 2026-09-06)*. "License page on your site" sat **blank** on the Override Checker listing from the original submission right through to 2026-09-06, plausibly a contributor to that listing still being pending months later. The form accepted the submission, and no reviewer message named it.

- [ ] **Walk every required field on the listing and confirm it's populated** — don't rely on the form to enforce it, and don't limit remediation to the items a reviewer happened to mention. A reviewer's message is a sample of what's wrong, not the complete list.

### 4b. The listing "logo" is a logo + screenshot banner (Tim's standard, 2026-10-19)

The JED form's **Logo** field is not a small icon: it becomes the big image across the top of the
listing page (1200×525, aspect 16:7). A bare logo on white looks empty. **Every Cybersalt listing uses
a banner: the extension logo on the left, a screenshot of the extension working on the right.**

```bash
python -I tools/jed-banner.py <logo.svg|png> <screenshot.png> <ext>-jed-banner-1200x525.png
```

- Use an **anonymized** screenshot that shows the product doing its job (status panel, report, dashboard),
  not an empty settings form.
- Upload the banner in the **Logo** field (it's a file upload, not a URL). The **Images** are feature
  slides (step 4c), not plain screenshots.
- Changing it on an existing listing: Edit → Logo → **Delete** the old file → Add file → Save. The
  zip and images stay as they are. Scripted: `python -I tools/jed-swap-logo.py <state.json> <edit_url> <banner.png> <tag> dry|save`.

### 4c. The listing "Images" are feature slides, all 8 if there's enough to show (Tim's standard, 2026-10-28)

The Images play in the same 1200×525 slideshow as the Logo banner. Plain full-page screenshots get
scaled down into a sea of white space and nobody can read them. **Every image is a slide: a feature
headline and 2–3 plain sentences on the left, a cropped, readable screenshot of that feature on the
right** (the banner's 700×455 frame). JED allows **8 images; use all 8** when the extension has that
many real features. Don't pad with filler.

```bash
python -I tools/jed-slides.py slides.json          # build (config format in the script's docstring)
python -I tools/jed-login.py <user> <pass> state.json
python -I tools/jed-swap-images.py state.json <edit_url> <tag> dry  s1.png ... s8.png   # read <tag>-edit.png
python -I tools/jed-swap-images.py state.json <edit_url> <tag> save s1.png ... s8.png
python -I tools/jed-listing-order.py https://extensions.joomla.org/extension/<alias>/
```

- **Crop to one feature** at a 0.7–1.2 scale (the script prints it). Keep the crop aspect near 700:455.
- **Copy:** a 2–7 word headline and 2–3 sentences. Use plain words and no em dashes, and only make claims you checked in the code.
- ⛔ **JED slider quirk:** the public slideshow shows the **first stored image last** (Logo, images
  2…8, then image 1). `jed-swap-images.py` handles it: pass the slides in viewing order and it uploads
  the last one first. Check the result with `jed-listing-order.py`.
- Two sessions logged in to the **same JED account** log each other out. Work one listing per account
  at a time, or log in again right before each save.
- The edit form's file inputs are, in order, zip, Logo, Images (the Images input takes several files).
  The swap script deletes the old image rows and refuses to save if the Logo, zip or version changed.
- Keep the config, source screenshots and built slides with the extension's notes so the slides can be
  rebuilt when the UI changes.
- **If the extension has a video, put it in the Video field** (Tim, 2026-10-28: "I'd like to have the
  videos as the first slides"). There is one Video field. It takes AllVideos syntax,
  `{youtube}VIDEO_ID{/youtube}` or `{vimeo}ID{/vimeo}`, and JED always plays it as the slide right after
  the Logo, before the images. ⛔ A bare YouTube URL saves fine but never renders. The video is the
  first thing a visitor plays, so Tim wants it **crisp and clean** and showing the current UI. If there
  isn't one, or it's old, note "needs a new video" in the extension's open items. Don't use an
  outdated one just to fill the slot. Set it with:

  ```
  python -I tools/jed-set-video.py <state.json> <edit_url> <youtube_id> <tag> dry|save
  ```

### 5. Screenshots are current

- [ ] **Enough features for 8 slides** (step 4c); at least 2
- [ ] **800-1280px wide** captures (crop from them, don't upscale tiny ones)
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

### 9. JED rules learned in the 2026-10-20 overnight pass ⚠️

From preparing six extensions plus ~30 MCP for J add-ons. The sources are cited in the vault note
`04.knowledge/jed-addon-and-paid-listing-rules.md`.

**Pacing and add-ons**
- **At most 3 submissions can be pending at once.** Bulk submission needs JED approval (support ticket after the first 3).
- **An "Ext. Specific Addon" can't be listed until its parent extension is approved.** On the form, tick
  Plugin + "E Ext. Specific Addon". Category: the parent's *Extension Specific* subcategory if one exists, otherwise
  *Extensions Specific Non-sorted*. One listing per add-on is accepted; JED doesn't want packs.

**Names** (the manifest `<name>` must match the listing)
- Banned: the reserved words **module / plugin / template / component / extension**, **"Free"**, version
  numbers, company names. JED Checker flags all of them.
- **"Joomla" in a name needs an OSM trademark licence.** Use "for J" or similar.
- Add-on names end with **"for <parent>"**.
- JED Checker's 40-character "too long" warning counts the whole translated name, including `System - `.
- The part before the first ` - ` must be the plugin group.
- A **package** `<name>` should be a language key (`PKG_X`). JED Checker derives the sys.ini filename
  from `<name>` and ignores `<packagename>`.
- Language keys must be **UPPERCASE**, or the name doesn't resolve and the naming rule fails.

**Manifest and files**
- Remove `<targetplatform>` and `<php_minimum>` from **install** manifests; JED Checker flags both.
  They belong in the update XML.
- Every PHP file needs a GPL `@license` docblock.
- Add `*.ini text eol=lf` to `.gitattributes`, because `core.autocrlf=true` ships CRLF language files.
- JED Checker skips language INIs whose filename contains a hyphen (`rules/language.php` regex), so it reports
  false "unknown key" warnings. Explain this to the reviewer.
- JAMSS false positives: #21 = hex escapes in a regex (`[[:cntrl:]]` avoids it); #17 = `base64_decode(` nested in
  parentheses; #23 = superglobal access near exec-like names. Justify each one to the reviewer.
- JED Checker breaks on Joomla 6 ("Error: 0"), so run it on a Joomla 5 site and give the results 40 s or more to render.

**Paid listings**
- Type **"Paid download"**, integration **"Paid purchase required at link:"** pointing at the extension's
  **own** product page.
- A **licence link on your own site is required**; gnu.org (or a private repo's GitHub) is rejected.
- The extension must **work without a licence key**: a Download ID may only gate downloads and updates.
- Reviewers work from the uploaded zip.

**Renaming a listing**
- The title is **read-only** on the edit form; only the JED team can rename.
- The web ticket (*Listing* department, subject "- RENAME LISTING - …") is hCaptcha-gated.
- **Emailing `jed-support@community.joomla.org` works** (the Reply-To address on JED reviewer mail).

**Before any release that goes public**
- **Scan the full git history for secrets.** A live client cPanel token sat in a public extension repo's
  first commit for 3½ months: `git log --all -p | grep -E '[A-Z0-9]{32}'`. Never commit deploy scripts with
  tokens; read them from the environment.
- After an element rename, re-test the **versionless download URL**, not just the feed. Release Manager kept the
  zip in the old element's folder, so the download 404'd while the feed looked fine.

---

## JED Contributor account setup

(One-time per developer — skip if already done.)

- [ ] **joomla.org account** — sign up at https://id.joomla.org if needed
- [ ] **JED contributor application** — apply at https://extensions.joomla.org via your profile
- [ ] **Verify Cybersalt domain ownership** if asked (typically via DNS TXT or meta tag)

The Cybersalt account is owned by `tim@cybersalt.com`.

---

## Naming: JED vs everywhere else

**Decided 2026-09-06 (Tim).** Cybersalt extensions carry two names on purpose. This is a
convention, not drift — do not "fix" one to match the other.

| Surface | Form | Example |
|---|---|---|
| **JED listing** | `CS ` abbreviated prefix | **CS Override Checker** |
| Extension display name, manifest `<name>`, package title | Full company name | **Cybersalt Override Checker** |
| Documentation, cybersalt.com storefront, README | Full company name | **Cybersalt Override Checker** |

**Why.** JED is a dense directory sitting next to hundreds of other extensions, where a long vendor
prefix costs scan-ability and eats the character budget in listing titles and search results. The
abbreviation keeps the Cybersalt association without the length. Everywhere the reader has already
arrived at something of ours — the admin UI, the docs, the storefront — the full company name does
useful branding work.

**Practical consequences:**

- The JED listing name will NOT match the manifest `<name>`. That is expected.
- **Only a JED team member can rename a listing** — the owner cannot do it from the contributor
  dashboard. If a listing goes up under the wrong form, open a support ticket. This is what happened
  with `LISTING-9G6LE3B554`, renamed from *CS Template Integrity* to *CS Override Checker* on
  2026-09-02.
- **A rename does not touch the version or download URL.** After any rename, re-check that the
  listing still advertises the current release and that the download URL resolves.

## The submission form — field-by-field

Walk this in order. Tab between fields; don't lose the form.

| Field | What to enter | Source / gotcha |
|---|---|---|
| Extension name | **Use the `CS ` short form** — see "Naming: JED vs everywhere else" below | Deliberately NOT the manifest `<name>`. JED gets `CS Override Checker`; the extension, docs and storefront keep `Cybersalt Override Checker`. |
| Tagline / short description | ≤200 chars, marketing hook | Lead with the **recognition trigger** (e.g. *"the smarter Joomla override checker"*) not the product name |
| Long description | Markdown, ~500-2000 chars | Converted from the cybersalt.com article HTML |
| Version | Current release version (e.g. `2.4.2`) | Match manifest exactly |
| Category | Pre-decided per step 7 above | Can't easily change after submission — pick carefully |
| Tags | Comma-separated specific terms | Specificity > coverage. Don't keyword-stuff. |
| Compatibility | Joomla 5.x, 6.x | Match what your manifest's `<files>` and `<update>` blocks declare |
| PHP version | Match manifest minimum | J5: 8.1+, J6: 8.3+ |
| Download URL | **File URL, not page URL** (see step 2) | Critical |
| Logo | **Upload** the 1200×525 logo + screenshot banner (see step 4b) | Required. The current form takes a file, not a URL |
| Images | **Upload** up to 8 feature slides (see step 4c) | Files, not URLs. The slider shows the first upload last, so use `tools/jed-swap-images.py` |
| Video | `{youtube}VIDEO_ID{/youtube}` (see step 4c) | One video. It plays right after the Logo. A bare URL doesn't render |
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
  - **Download URL(s)** — and actually re-test them (see step 2). There may be more than one field carrying the element name.
  - Long description (if features changed)
  - Screenshots (if UI changed)
  - Compatibility (if Joomla version range changed)
- **After any listing rename, element rename, or Release Manager tidy-up**, re-test the Download URL specifically. None of those events update it, and a stale element 404s with no visible symptom on the listing. See step 2.
- **Periodically re-walk the required fields** (support link, license page link, etc.). One of them being quietly empty is a plausible reason for a listing to sit in the queue with nobody explaining why. See step 4.
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

- **2026-10-28** — Added step 4c: listing **Images are feature slides** (headline + text left, readable
  cropped screenshot right), all 8 when the features are there. New tools: `jed-slides.py`,
  `jed-swap-images.py`, `jed-login.py`, `jed-listing-order.py`. Found the JED slider quirk: the
  first stored image is shown last. First applied to CS MCP for J (17890). Later the same day: the
  Video field (one video, AllVideos syntax, shown right after the Logo; a bare URL doesn't render)
  and `tools/jed-set-video.py`.
- **2026-10-20** — Added step 9: the JED rules learned while preparing six extensions plus the MCP for J add-ons
  in one overnight pass. Covers the pending limit, add-on and paid-listing rules, the naming rules (including
  "Joomla" and the OSM licence), manifest/JED Checker gotchas, how a listing gets renamed, and a pre-release
  secret scan.

- **2026-06-24** — Initial version. Distilled from the live JED submission of cs-template-integrity v2.4.3 on WMW #343 (Watch Me Work episode #343), particularly @Bredc's live catches of the three first-timer gotchas (download URL vs page URL, full-URL logo requirement, support + license link required fields).
- **2026-10-19** — Added step 4b: the listing logo is a **logo + screenshot banner** (Tim's standard), built with `tools/jed-banner.py`. The current JED form uploads the extension zip, the logo and the images as files (field table updated). Also learned: run **JED Checker** before submitting (the form makes you confirm it); its 2.4.4 release has no zip, so zip the repo root, and run it on a **Joomla 5** site (it errors on Joomla 6).
- **2026-09-06** — Corrected the WMW #343 submission version from 2.4.2 to **2.4.3** (the figure was wrong here and in the vault's JED account note). Added two gotchas from bringing the Override Checker listing current: **the Download URL is pinned to the extension element name** and survives a listing rename (step 2), and **a required field can be saved empty** — the License page link had been blank since submission (step 4). Both echoed in "Ongoing — keeping the JED listing fresh".
