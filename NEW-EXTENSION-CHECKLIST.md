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
- [ ] **`postflight($type)` gates on `$type` before rendering the install card.** Joomla calls `postflight()` on **uninstall** too — without the gate, the user gets an "installed, click here to open the dashboard" card right after they hit Uninstall, often linking to a route that no longer exists. Early-return from `postflight()` when `$type` isn't one of `install`, `update`, `discover_install`. Same gate belongs around any postflight side effect that should only run on install/update (e.g. `enableWebservicesPlugin()` — don't auto-enable a plugin that's about to be removed).
- [ ] **Dark mode safe** — Bootstrap classes only, no inline colors
- [ ] **HTML-escape `Text::_()` in installer output** — `script.php`'s `postflight()` echoes into Joomla's installer frame; wrap every `Text::_()` in `htmlspecialchars(..., ENT_QUOTES \| ENT_SUBSTITUTE, 'UTF-8')` even when the strings are static today (a future translation file could carry markup that breaks the layout, or worse). If your package ships a package-level `script.php` AND a component-level `script.php`, **fix both** — the package one is easy to forget.

## Security Baseline (MANDATORY for components and any extension that writes files)

Mirrors the v0.9.0 security review of cs-template-integrity. **The bar is "passes a security review with zero HIGH or MEDIUM findings."**

- [ ] **`admin/access.xml` declared and listed in the manifest** — every component ships one, with `core.admin`, `core.manage`, `core.options`, plus custom `<name>.view` and `<name>.write` actions. List `<filename>access.xml</filename>` inside `<files folder="admin">` so install copies it.
- [ ] **Permission gate at the top of every controller method** — both admin (BaseController) and API (ApiController). `displayList`, `displayItem`, `add`, `edit`, custom actions: every one of them. A reusable `PermissionHelper::requireView()` / `::requireWrite()` keeps it one line per method. **A valid Joomla API token does NOT authorise any specific component on its own** — without your gate, every staff token on the site can hit your endpoints.
- [ ] **CSRF on every state-changing admin action** — `$this->checkToken()` on POST controllers, `$this->checkToken('get')` on GET-form download/restore links, `Session::getFormToken()` appended to those links so they actually carry the token.
- [ ] **Prepared statements / `quoteName` everywhere** — never concatenate user input into SQL. `bind(':id', $id, ParameterType::INTEGER)` for ints; `bind(':name', $name)` for strings.
- [ ] **Allowlist `ORDER BY` columns** — `filter_fields` in your `ListModel` is the allowlist; never accept arbitrary column names from the request.
- [ ] **Escape every echo** — `htmlspecialchars()` for HTML, `Joomla\CMS\HTML\HTMLHelper::_('escape', ...)` or `$this->escape()` in views.
- [ ] **Path-traversal guard with `str_starts_with` + trailing `DIRECTORY_SEPARATOR`** — never `strpos($parent, $root) !== 0` (bypassable when the site root has a sibling whose name shares the prefix, e.g. `/var/www/joomla` vs `/var/www/joomla-bak`). Resolve `dirname()` through `realpath()` first.
- [ ] **PHP-extension write whitelist** — if your extension writes files under `JPATH_ROOT`, refuse `.php` / `.phtml` / `.phar` / `.pht` writes outside the specific subtree your extension owns (e.g. `templates/<tpl>/html/` for an override-fixer). Defence in depth: even if an authenticated path-resolution bug points your writer at `/components/com_users/foo.php`, the whitelist refuses.
- [ ] **`opcache_invalidate()` after every PHP write** — otherwise the next request runs the old, OPcache-cached bytes and the fix appears not to land.
- [ ] **CRLF / response-splitting on download responses** — sanitize any user-derived value reflected into `Content-Disposition` / `Content-Type` headers via `preg_replace('/[^A-Za-z0-9._-]/', '-', $basename)`. `str_replace('"', '', …)` is not enough.
- [ ] **No free-form file paths from request bodies** — if your API takes an `override_id` / `record_id`, look the path up server-side from the database row; do not accept a `file_path` field from the client. `{file_path, contents}` POST bodies have repeatedly turned into RCE primitives once paired with a write or restore step.
- [ ] **Run the security-review skill before tagging a release** — see `security-review` in `.claude/skills/`.

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
