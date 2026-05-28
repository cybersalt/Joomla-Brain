# Repositories Using Joomla Brain

This file tracks repositories that use the Joomla Brain as a submodule. Use these as references for working implementations.

## Active Repositories

### Plugins
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cs-autogallery](https://github.com/cybersalt/cs-autogallery) | Content Plugin | Bootstrap 5 gallery with GLightbox | Joomla 5 native (services/provider) |
| [cs-joomla-router-tracer](https://github.com/cybersalt/cs-joomla-router-tracer) | System Plugin | Router/URL logging for debugging redirect loops | Joomla 5 native (SubscriberInterface, com_ajax) |
| [cs-browser-page-title](https://github.com/cybersalt/cs-browser-page-title) | System Plugin | Sets browser title from custom field | Joomla 5 native (services/provider) |
| [cs-userback-admin](https://github.com/cybersalt/cs-userback-admin) | System Plugin | Userback integration with frontend/backend detection | Joomla 5 native |
| [cs-siteground-cache-for-joomla](https://github.com/cybersalt/cs-siteground-cache-for-joomla) | System Plugin | SiteGround cache integration, auto-purge, admin toolbar button, log viewer | Joomla 5 native (SubscriberInterface, com_ajax, custom fields, header injection) |
| [cs-registration-redirect](https://github.com/cybersalt/cs-registration-redirect) (private) | System Plugin | Redirects users to a configurable URL after com_users registration completes — closes the gap that the per-menu-item-only stock redirect leaves | Joomla 4/5/6 native (SubscriberInterface, onAfterRoute, full update server) |
| [cs-hikashop-login-redirect](https://github.com/cybersalt/cs-hikashop-login-redirect) (private) | System Plugin | Catches HikaShop's "404-instead-of-access-denied" response and redirects Guests to login with a `return=` parameter so they bounce back to the product after authenticating | Joomla 4/5/6 native (SubscriberInterface, **onError** hook, full update server) |
| [cs-menu-item-conditions](https://github.com/cybersalt/cs-menu-item-conditions) (private) | System Plugin | Per-menu-item, per-page visibility — adds a Conditions tab to the menu item edit form with **picker dropdowns** for menu items / components / views (no manual ID entry) and a **URL match builder** with operator selector (Contains/Equals/Begins/Ends/Regex). Strips matching `<li>` blocks in `onAfterRender` so hover handlers and embedded scripts (Turnstile, reCAPTCHA, etc.) never initialize on hidden items. v1.0.0 first stable release 2026-05-06. | Joomla 5/6 native (SubscriberInterface, `onContentPrepareForm` for `com_menus.item`, custom `ListField` for views, subform with operators for URL rules, balanced-tag walker for nested submenus) |

### Packages
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cs-continuous-learning](https://github.com/cybersalt/cs-continuous-learning) | Package | Continuous learning system — topics, article tagging, custom fields | Joomla 5 native (component + 2 plugins) |
| [cs-cron-master](https://github.com/cybersalt/cs-cron-master) (private) | Package (com + plg_system) | Generic cron-job manager with pluggable handlers. Drop a `HandlerInterface` class in `admin/src/Handler/` and the registry auto-discovers it. Three trigger modes per job (manual / front-dispatch / system-cron). First handler bundled: RSTickets! Pro IMAP/POP3 polling — clean-room replacement for RSJoomla's `plg_system_rsticketsprocron`. v1.0.0 released 2026-05-23. | Joomla 5/6 native (admin component, system plugin, J5/6 CLI app, BootableExtensionInterface, SubscriberInterface, custom HandlerListField + JobListField pickers, Diagnostics view for handler deps, every-column filter coverage, dark-mode safe) |
| [StageIt-5](https://github.com/cybersalt/StageIt-5) | Package | Environment banner system | Joomla 5 (legacy plugin format) |
| [StageIt-6](https://github.com/cybersalt/StageIt-6) | Package | Environment banner system | Joomla 6 (legacy plugin format) |

### Components
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cs-download-id-manager](https://github.com/cybersalt/cs-download-id-manager) | Package (com + plg_content) | Cybersalt Release Manager — membership-gated update access + authenticated downloads for pro extensions. Replaces traditional download IDs with installation-id + email-hash two-factor auth; ships as bundled package (component + content plugin); content plugin renders `{cs-download element="..."}` shortcodes as authenticated download buttons. Rebranded from "CS Update Access Manager" 2026-05-04. | Joomla 5/6 native (admin+site+API, custom fields, update server, content plugin, email notifications, domain blocking, end-to-end update flow proven in production) |
| [cs-filter-by-meta](https://github.com/cybersalt/cs-filter-by-meta) | Component | Content meta audit tool | Joomla 5 |
| [cs-talkback-to-joomla](https://github.com/cybersalt/cs-talkback-to-joomla) | Component | TalkBack to JComments migration tool | Joomla 5 native |
| [cs-template-integrity](https://github.com/cybersalt/cs-template-integrity) | Package (com + plg_webservices) | Template-override integrity monitor — pairs your site with Claude to review every flagged override and apply patches you confirm. **v2.0 (2026-04-29)** added server-side scan automation (extension calls Anthropic directly with a saved API key) and chat-with-Claude on the session detail view (tool-use loop runs apply_fix / dismiss_override / dismiss_all server-side). Both manual (paste-prompt) and automated workflows ship together. | Joomla 5/6 native (Web Services API, ApiController, JsonapiView, access.xml + ACL gate, Anthropic Messages API + tool use, GPL-2 — public, update server live) |
| [CS-Chronoforms-Convert-to-Convert-Forms](https://github.com/cybersalt/CS-Chronoforms-Convert-to-Convert-Forms) | Component | CF6 to Convert Forms migration tool | Joomla 3 (legacy MVC) |
| [cs-remove-sample-data](https://github.com/cybersalt/cs-remove-sample-data) | Component | Detects and removes items installed by Joomla's Blog and Multilingual sample-data plugins, including the `-{lang}`-suffixed variants the blog plugin creates on multilingual sites. Preview + per-item opt-out + per-column filters + activity log. **v1.0.0 (2026-05-28)** public release. Locale-aware alias reconstruction via `ApplicationHelper::stringURLSafe()` + same `.ini` file as the sample-data plugin; two-tier CSRF check (Joomla token + same-origin Referer/Origin fallback) for session-rotation resilience; inline JS/CSS in scan view to sidestep CDN caching of `/media/` assets. Passes security review with zero HIGH / zero MEDIUM. | Joomla 5/6 native (component, custom token endpoint, update server live) |

### Modules
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cybersalt-related-articles](https://github.com/cybersalt/cybersalt-related-articles) | Module | Related articles display | Joomla 5 |
| [cs-world-clocks](https://github.com/cybersalt/cs-world-clocks) | Module | World clocks display | Joomla 5 native (Dispatcher pattern) |
| [cs-image-map-hotlinking](https://github.com/cybersalt/cs-image-map-hotlinking) | Module | Interactive image maps with visual hotspot editor | Joomla 5/6 native (Dispatcher, custom fields, inline data) |

## Update Server Compliance

When next working on any of these extensions, add full Joomla update server support (see `PACKAGE-BUILD-NOTES.md` and `JOOMLA5-CHECKLIST.md`):

| Repo | updates.xml | sha256 | updateservers | changelogurl | CHANGELOG.html |
|------|-------------|--------|---------------|--------------|----------------|
| cs-userback-admin | ✅ | ✅ | ✅ | ✅ | ✅ |
| cs-autogallery | ❌ | ❌ | ❌ | ❌ | ✅ |
| cs-joomla-router-tracer | ❌ | ❌ | ❌ | ✅ | ✅ |
| cs-browser-page-title | ❌ | ❌ | ❌ | ❌ | ✅ |
| StageIt-5 | ❌ | ❌ | ✅ | ❌ | ✅ |
| StageIt-6 | ❌ | ❌ | ✅ | ❌ | ✅ |
| cs-filter-by-meta | ❌ | ❌ | ❌ | ❌ | ✅ |
| cs-talkback-to-joomla | ❌ | ❌ | ❌ | ✅ | ✅ |
| cybersalt-related-articles | ❌ | ❌ | ❌ | ❌ | ❌ |
| cs-world-clocks | ❌ | ❌ | ❌ | ❌ | ✅ |
| cs-image-map-hotlinking | ❌ | ❌ | ❌ | ❌ | ✅ |
| cs-siteground-cache-for-joomla | ✅ | ✅ | ✅ | ✅ | ✅ |
| cs-registration-redirect | ✅ | ✅ | ✅ | ✅ | ✅ |
| cs-hikashop-login-redirect | ✅ | ✅ | ✅ | ✅ | ✅ |
| cs-menu-item-conditions | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## Adding This Submodule

```bash
git submodule add https://github.com/cybersalt/Joomla-Brain.git .joomla-brain
```

## Updating the Submodule

```bash
cd .joomla-brain
git pull origin main
cd ..
git add .joomla-brain
git commit -m "Update Joomla Brain submodule"
```

## Notes

- **Legacy plugin format** = single PHP file with `<filename plugin="name">name.php</filename>`
- **Joomla 5 native** = services/provider.php with DI container and SubscriberInterface
- Both formats work in Joomla 5 due to backward compatibility
- Joomla 6 will require the native format (legacy deprecated)

## External Resources

### MCP4Joomla
[nikosdion/joomla-mcp-php](https://github.com/nikosdion/joomla-mcp-php/) — MCP server (PHP) that lets AI tools manage Joomla sites via the Web Services API. 212 tools covering content, users, menus, extensions, custom fields, config, and more. Useful for AI-assisted site management, content creation, and testing. Requires Joomla 5.2+ with Web Services API enabled + Super User API token.

## Standards

### Log Viewer UI
All CyberSalt extensions with logging MUST use the standard log viewer implementation for consistent user experience. Reference implementation: [cs-joomla-router-tracer](https://github.com/cybersalt/cs-joomla-router-tracer)

Required features:
- Dark theme with CSS variables
- Button bar: Refresh, Dump Log (clipboard), Download, Clear
- Stats bar with entry counts, file size, warnings/errors
- Filterable log entries with expandable details
- JSON syntax highlighting
- Stack trace display
