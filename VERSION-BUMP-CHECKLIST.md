# Version Bump Checklist

Follow this checklist every time you bump the version of a Cybersalt extension.

> [!TIP]
> **For MINOR or MAJOR bumps, also run through `JOOMLA-EXTENSION-WISHLIST.md`** to confirm the cross-cutting expectations (lock-out modals, API-billing transparency, dark-mode testing, CI, etc.) are still in place. PATCH releases can usually skip the wishlist pass unless they touched UI or third-party API integration.

## Steps (in order)

- [ ] **Run a security review of every file changed since the previous tagged version.** Use the `/security-review` workflow against the diff (or against the working tree if changes haven't been committed yet). This is a hard prerequisite — never bump the version on code that hasn't been security-reviewed since the last bump. The review depth scales with bump size — see "Review depth by bump type" below.
- [ ] **Address any HIGH or MEDIUM findings** before proceeding. LOW findings can be deferred to a follow-up release with a tracking issue.
- [ ] **Bump version number** in every manifest XML (component, plugin, module, package — whatever the extension ships)
- [ ] **Update CHANGELOG.md** — add new version section at top with emoji headers (🚀 🔧 📦 🐛 🔒 📝 etc.)
- [ ] **Update CHANGELOG.html** — matching article-ready HTML (no `<html>`, `<head>`, `<body>`, or `<style>` tags)
- [ ] **Refresh README.md.** Don't just ask "did features change" — also look for *drift*. Two specific failure modes that have bitten Cybersalt extensions:
    - **Stale version numbers in section headings.** A heading like `## What ships in v2.0` written when 2.0 was current never auto-updates. Run `grep -nE '\bv?[0-9]+\.[0-9]+(\.[0-9]+)?\b' README.md` to enumerate every version mention; check each line is either still correct or genuinely historical (e.g. *"v0.9.0 closed the live RCE primitive"* is fine forever, but *"What ships in v2.0"* goes stale the moment 2.1 ships). Prefer version-agnostic wording (*"What's in the box"*, *"Components"*) so the doc doesn't decay every release.
    - **Brand names that drifted.** If the user-facing brand changed in any prior release (e.g. `CS Template Integrity` → `Cybersalt Template Integrity` in cs-template-integrity v2.2), install instructions and screenshot captions in the README often still reference the old name. `grep -n '<old-brand>' README.md` to catch them.
    Also: if features changed, refresh the feature list. If install flow changed, refresh the install steps. If a major release reorganized the dashboard, refresh any UI walkthrough.
- [ ] **Rebuild zip** with 7-Zip. The build script produces a timestamped working filename (`{ext_name}_v{version}_{YYYYMMDD}_{HHMM}.zip`) — that's the iteration artifact.
- [ ] **Copy the timestamped zip to a clean version-only name** (`{ext_name}_v{version}.zip`) before uploading. The clean name is what goes on the GitHub release; the timestamped name stays local. Compute the SHA256 of the clean-named copy for `updates.xml`.
- [ ] **Commit and push** to GitHub (manifests + CHANGELOGs + any code changes from the security review)
- [ ] **Create GitHub release** with ONLY the clean-named zip attached (`{ext_name}_v{version}.zip`), tag `v{version}`. Do NOT upload the timestamped working copy — users should see one canonical zip per release, not two near-identical ones.
- [ ] **Update updates.xml** with the new version, the new SHA256 of the released zip, and the GitHub release asset URL — only after the release exists, so the URL resolves
- [ ] **Commit and push updates.xml** as a separate commit
- [ ] **Test install/upgrade** on a live site

## Review depth by bump type

The `/security-review` skill defaults to a 0.7 confidence threshold — actionable findings only. That's the right setting for routine bumps. For major releases the threshold drops because the cost of missing something on a public-facing X.0 release exceeds the cost of looking at theoretical/defense-in-depth findings.

| Bump | Threshold | Static analysis | Scope |
|---|---|---|---|
| **Patch** (X.Y.Z → X.Y.Z+1) | 0.7 (default) | Optional | Files changed since previous tag |
| **Minor** (X.Y → X.Y+1) | 0.7 (default) | Optional | Files changed since previous tag |
| **Major** (X → X+1) | **0.5** | **Required: PHPStan with `phpstan/phpstan-strict-rules` + a security-focused ruleset** | **Whole component** (don't trust prior reviews — codebase has accumulated change since previous major) |

A 0.5 threshold surfaces "could in theory be exploited if A and B and C all line up" findings that the 0.7 threshold filters out. Most will be defense-in-depth recommendations; some will be real attack surfaces you didn't notice. Either way you want to see them at a major release.

PHPStan catches a class of issue the AI review can miss: taint tracking, missing parameter types, incomplete return-type contracts, missed null checks at security-critical boundaries. For Joomla 5/6 components, run with `level: 6` minimum and add `--memory-limit 512M`. Look at *every* error before tagging — many will be benign type hints, but the ones that aren't tend to be the ones a reviewer's eyes glaze past.

## Security review scope

A version-bump security review must cover **every file changed since the previous tagged version** (or, for major bumps, the whole component). Run `git diff v{previous}..HEAD --stat` to enumerate the change set, then audit each file against the standard categories:

- **Input validation** — SQL injection, command injection, path traversal, template injection, XSS in admin views
- **Auth & ACL** — every controller method has a permission check; views call `requireView()` or equivalent at the top of `display()`; CSRF tokens on every state-changing form
- **Crypto & secrets** — no hardcoded keys; key fingerprints don't leak the key; secrets aren't logged
- **Injection & code execution** — no unsanitized eval, no unserialize on untrusted data, no shell exec with user-controllable args
- **Data exposure** — no PII in logs; sensitive admin actions audit-logged; backups don't expose unintended files

If the extension has Web Services API endpoints, also re-walk the API controllers — every route that writes to disk or the DB must check both the Joomla API token AND the component's own granular ACL action (e.g. `cstemplateintegrity.editapply`).

If the extension calls any external HTTP API (Anthropic, OpenAI, etc.), verify timeouts, retry-with-backoff behavior, and that error messages from the upstream don't leak the API key back to the user-facing log.

## Notes

- Always rebuild the zip after ANY code change — the zip IS the deployment mechanism
- Never use PowerShell's `Compress-Archive` — always use 7-Zip
- CHANGELOG.html must contain the COMPLETE changelog, not just the latest version
- Keep both CHANGELOG.md and CHANGELOG.html in sync
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Don't commit the updated `updates.xml` until the GitHub release exists — pointing the update server at a 404 URL will break in-place upgrades for everyone running the previous version.
