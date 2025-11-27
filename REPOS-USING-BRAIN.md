# Repositories Using Joomla Brain

This file tracks repositories that use the Joomla Brain as a submodule. Use these as references for working implementations.

## Active Repositories

### Plugins
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cs-autogallery](https://github.com/cybersalt/cs-autogallery) | Content Plugin | Bootstrap 5 gallery with GLightbox | Joomla 5 native (services/provider) |

### Packages
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [StageIt-5](https://github.com/cybersalt/StageIt-5) | Package | Environment banner system | Joomla 5 (legacy plugin format) |
| [StageIt-6](https://github.com/cybersalt/StageIt-6) | Package | Environment banner system | Joomla 6 (legacy plugin format) |

### Components
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cs-filter-by-meta](https://github.com/cybersalt/cs-filter-by-meta) | Component | Content meta audit tool | Joomla 5 |
| [CS-Chronoforms-Convert-to-Convert-Forms](https://github.com/cybersalt/CS-Chronoforms-Convert-to-Convert-Forms) | Component | CF6 to Convert Forms migration tool | Joomla 3 (legacy MVC) |

### Modules
| Repo | Type | Description | Status |
|------|------|-------------|--------|
| [cybersalt-related-articles](https://github.com/cybersalt/cybersalt-related-articles) | Module | Related articles display | Joomla 5 |

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
