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

### Packages
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cs-continuous-learning](https://github.com/cybersalt/cs-continuous-learning) | Package | Continuous learning system — topics, article tagging, custom fields | Joomla 5 native (component + 2 plugins) |
| [StageIt-5](https://github.com/cybersalt/StageIt-5) | Package | Environment banner system | Joomla 5 (legacy plugin format) |
| [StageIt-6](https://github.com/cybersalt/StageIt-6) | Package | Environment banner system | Joomla 6 (legacy plugin format) |

### Components
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cs-filter-by-meta](https://github.com/cybersalt/cs-filter-by-meta) | Component | Content meta audit tool | Joomla 5 |
| [cs-talkback-to-joomla](https://github.com/cybersalt/cs-talkback-to-joomla) | Component | TalkBack to JComments migration tool | Joomla 5 native |
| [CS-Chronoforms-Convert-to-Convert-Forms](https://github.com/cybersalt/CS-Chronoforms-Convert-to-Convert-Forms) | Component | CF6 to Convert Forms migration tool | Joomla 3 (legacy MVC) |

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
