# New Cybersalt Extension Checklist

Follow this checklist in order when creating a new Joomla extension.

## Setup

- [ ] **Create GitHub repo** at `github.com/cybersalt/cs-{name}`
- [ ] **Set GitHub repo description** — one-line summary of what the extension does
- [ ] **Create extension folder** — `plg_{group}_{name}/`, `mod_{name}/`, or `com_{name}/` with proper structure
- [ ] **Add `.gitignore`** — exclude `*.zip` build artifacts
- [ ] **Add Joomla Brain submodule** — `git submodule add https://github.com/cybersalt/Joomla-Brain.git .joomla-brain`

## Extension Code

- [ ] **Company info in manifest** — Cybersalt author, support@cybersalt.com, cybersalt.com (see `company-info.md`)
- [ ] **License** — GNU General Public License version 2 or later (see https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
- [ ] **Namespace** — `Cybersalt\Plugin\{Group}\{Name}`, `Cybersalt\Module\{Name}`, or `Cybersalt\Component\{Name}`
- [ ] **Language system** — all strings translatable, `.ini` and `.sys.ini` files, language constants in XML
- [ ] **Post-install link** — `script.php` with Bootstrap card UI linking to extension settings
- [ ] **Dark mode safe** — Bootstrap classes only, no inline colors

## Documentation

- [ ] **README.md** — description, features, requirements, installation, configuration, build instructions, license, author
- [ ] **CHANGELOG.md** — with emoji section headers (🚀 🔧 📦 🐛 etc.)
- [ ] **CHANGELOG.html** — article-ready HTML (no `<html>`, `<head>`, `<body>`, or `<style>` tags)

## Build & Release

- [ ] **Build with 7-Zip** — never use PowerShell's `Compress-Archive`
- [ ] **Package naming** — `{ext_name}_v{version}_{YYYYMMDD}_{HHMM}.zip`
- [ ] **Test installation** on clean Joomla 5 site
- [ ] **Test plugin settings** save correctly
- [ ] **Verify dark mode** compatibility

## Publish

- [ ] **Initial commit and push** to GitHub
- [ ] **Update REPOS-USING-BRAIN.md** — register the new repo in the Joomla Brain

## Reference

- See `company-info.md` for author/copyright details
- See `JOOMLA5-PLUGIN-GUIDE.md` for plugin structure
- See `JOOMLA5-CHECKLIST.md` for pre-release checklist
- See `PACKAGE-BUILD-NOTES.md` for build troubleshooting
