# Version Bump Checklist

Follow this checklist every time you bump the version of a Cybersalt extension.

## Steps (in order)

- [ ] **Bump version number** in manifest XML (e.g., `stalecachebuster.xml`, `mod_name.xml`)
- [ ] **Update CHANGELOG.md** — add new version section at top with emoji headers (🚀 🔧 📦 🐛 etc.)
- [ ] **Update CHANGELOG.html** — matching article-ready HTML (no `<html>`, `<head>`, `<body>`, or `<style>` tags)
- [ ] **Update README.md** — if features, configuration, or build instructions changed
- [ ] **Rebuild zip** with 7-Zip using timestamped filename: `{ext_name}_v{version}_{YYYYMMDD}_{HHMM}.zip`
- [ ] **Commit and push** to GitHub
- [ ] **Test install/upgrade** on live site

## Notes

- Always rebuild the zip after ANY code change — the zip IS the deployment mechanism
- Never use PowerShell's `Compress-Archive` — always use 7-Zip
- CHANGELOG.html must contain the COMPLETE changelog, not just the latest version
- Keep both CHANGELOG.md and CHANGELOG.html in sync
- Use semantic versioning (MAJOR.MINOR.PATCH)
