# Joomla 5 Development Checklist

## Pre-Release Checklist

### Code Quality
- [ ] All code changes committed to git
- [ ] No PHP syntax errors
- [ ] No deprecated Joomla 3/4 APIs used
- [ ] Proper use of Joomla 5 namespaces
- [ ] Language system properly implemented (see `README.md` Language System section)

### Version & Documentation
- [ ] Version numbers updated in all manifests (pkg_*.xml, plugin XML, component XML)
- [ ] CHANGELOG.md updated with emojis for section headers
- [ ] CHANGELOG.html created/updated (article-ready, see `README.md` Changelog Format)
- [ ] All files saved

### Package Building
- [ ] Built with 7-Zip (never PowerShell `Compress-Archive`) — see `PACKAGE-BUILD-NOTES.md`
- [ ] Package naming: `{ext_name}_v{version}_{YYYYMMDD}_{HHMM}.zip`
- [ ] Verify validation passes (no XML errors)
- [ ] Check package structure has proper `admin/` folder (components)
- [ ] Verify no intermediate zip files left behind

### Post-Install Link
- [ ] `script.php` `postflight()` displays a clickable link/button to open the extension after install/update
- [ ] Uses Bootstrap classes (`card`, `btn btn-primary`) — NOT inline background/text colors (dark mode compatibility)
- [ ] Message distinguishes between "installed" and "updated"
- [ ] All text uses language constants from `.sys.ini`
- [ ] For plugins: link to filtered plugin list (direct edit fails due to CSRF)

### Component Routing (site-facing components only)
- [ ] Router class at `site/src/Service/Router.php` using `RouterBase`
- [ ] `RouterServiceInterface` + `RouterServiceTrait` on component class
- [ ] `RouterFactory` registered in `admin/services/provider.php`
- [ ] All `Route::_()` calls include `&Itemid=` (see `JOOMLA5-COMPONENT-ROUTING.md`)
- [ ] Autoload cache cleared after install

### Dark Mode / Atum Compatibility
- [ ] No hardcoded colors — use CSS variables or let Atum inherit
- [ ] Use Bootstrap classes for alerts, buttons, cards
- [ ] Use Joomla icon font classes (not image files)
- [ ] Test in both light and dark mode
- [ ] See `.claude/skills/joomla-development.md` Dark Mode section for CSS variable reference

### Update Server (for GitHub-hosted extensions)
- [ ] `<updateservers>` in manifest XML points to raw `updates.xml` on GitHub
- [ ] `<changelogurl>` in manifest XML points to a `changelog.xml` on GitHub raw — **NOT `CHANGELOG.html`**. Joomla's extension manager and update flow expect Joomla-format changelog XML at this URL (`<changelogs>` root with one `<changelog>` per version, containing `<addition>`/`<fix>`/`<security>`/`<language>`/`<change>`/`<remove>`/`<maintenance>`/`<note>` items). HTML at this URL produces an empty modal when the user clicks the version badge in Extension Manager. CHANGELOG.html / CHANGELOG.md remain useful as the human-readable pair (linked from README) but they are not what `<changelogurl>` should reference. cs-template-integrity shipped this wrong from v2.0 through v2.3.1 — modal was empty for ~6 releases. Fixed in v2.3.2 by adding `changelog.xml` and switching both the package manifest and `updates.xml` to point at it.
- [ ] **Same `<changelogurl>` value in both `pkg_*.xml` AND `updates.xml`.** They are two independent fields read at different times: the package manifest URL is baked into `manifest_cache` at install time and used by Extension Manager → version badge; the updates.xml URL is read fresh on every update poll. Both should point at `changelog.xml`.
- [ ] `updates.xml` has correct `<version>`, `<element>`, `<type>`, `<folder>`
- [ ] `<downloadurl>` points to the GitHub release asset (non-timestamped filename)
- [ ] `<sha256>` checksum included (generate with `sha256sum` on the zip)
- [ ] `<targetplatform>` set (e.g., `version="5\.[0-9]+"`)
- [ ] `<php_minimum>` set (e.g., `8.1`)
- [ ] GitHub Release created with **only the non-timestamped zip filename** (`{ext_name}_v{version}.zip`). The timestamped zip is the local iteration artifact — keep it on disk, do NOT upload it to the release.

### GitHub Release
- [ ] GitHub Release created via `gh release create vX.Y.Z`
- [ ] Install zip attached to the release
- [ ] Non-timestamped zip uploaded (for `updates.xml` download URL)
- [ ] Release notes match changelog entry
- [ ] README.md changelog section updated

### Testing
- [ ] Test installation on clean Joomla 5 site
- [ ] Test upgrade from previous version
- [ ] Test all new features
- [ ] Test plugin settings save correctly
- [ ] Verify dark mode compatibility

---

## Post-Install Link Implementation

**MANDATORY**: Every Cybersalt extension MUST include a post-install link.

```php
public function postflight($type, $parent): bool
{
    $this->clearAutoloadCache();
    $this->showPostInstallMessage($type);
    return true;
}

protected function showPostInstallMessage(string $type): void
{
    $messageKey = $type === 'update'
        ? 'COM_YOUREXT_POSTINSTALL_UPDATED'
        : 'COM_YOUREXT_POSTINSTALL_INSTALLED';

    // For components:
    $url = 'index.php?option=com_yourcomponent';
    // For plugins (filtered list - direct edit links fail due to CSRF token):
    // $url = 'index.php?option=com_plugins&view=plugins&filter[search]=Your Plugin Name';

    echo '<div class="card mb-3" style="margin: 20px 0;">'
        . '<div class="card-body">'
        . '<h3 class="card-title">' . Text::_('COM_YOUREXT') . '</h3>'
        . '<p class="card-text">' . Text::_($messageKey) . '</p>'
        . '<a href="' . $url . '" class="btn btn-primary text-white">'
        . '<span class="icon-wrench" aria-hidden="true"></span> '
        . Text::_('COM_YOUREXT_POSTINSTALL_OPEN')
        . '</a>'
        . '</div></div>';
}
```

**Required `.sys.ini` strings:**
```ini
COM_YOUREXT_POSTINSTALL_INSTALLED="The extension has been successfully installed."
COM_YOUREXT_POSTINSTALL_UPDATED="The extension has been successfully updated."
COM_YOUREXT_POSTINSTALL_OPEN="Open Extension Name"
```

---

## Common Issues Quick Reference

For detailed troubleshooting with code examples, see:
- **Component issues**: `COMPONENT-TROUBLESHOOTING.md`
- **Plugin issues**: `JOOMLA5-PLUGIN-GUIDE.md` (Common Errors section)
- **Module issues**: `JOOMLA5-MODULE-GUIDE.md` (Common Installation Errors section)
- **Build/packaging issues**: `PACKAGE-BUILD-NOTES.md`

| Issue | Quick Fix |
|-------|-----------|
| "Class not found" | Check namespace, clear autoload cache, verify manifest |
| Double `\Administrator\Administrator` | Remove `\Administrator` suffix from namespace in manifest |
| "Unexpected token '<'" | Use 7-Zip, check XML syntax |
| `setRegistry()` undefined | Remove the call — not needed in J5 |
| Layout not found | Templates go in `tmpl/viewname/default.php` |
| Pagination `getTotal()` undefined | Use properties: `$pagination->total`, `$pagination->limitstart` |
| Plugin params not taking effect | Load fresh from `#__extensions` table |
| PrepareDataEvent error | Check XML encoding, remove empty defaults on multi-select |

---

## Plugin Parameters from Component

When saving plugin params from a component, load and merge with existing params:

```php
private function savePluginParams($input) {
    $db = Factory::getDbo();
    $query = $db->getQuery(true)
        ->select($db->quoteName('params'))
        ->from($db->quoteName('#__extensions'))
        ->where($db->quoteName('element') . ' = ' . $db->quote('pluginname'))
        ->where($db->quoteName('folder') . ' = ' . $db->quote('system'))
        ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'));

    $db->setQuery($query);
    $params = json_decode($db->loadResult(), true) ?: [];

    // Update from POST data
    $pluginFields = ['show_banner', 'style_mode'];
    foreach ($pluginFields as $field) {
        $value = $input->post->get('plugin_' . $field, null, 'raw');
        if ($value !== null) {
            $params[$field] = $value;
        }
    }

    // Save back
    $query = $db->getQuery(true)
        ->update($db->quoteName('#__extensions'))
        ->set($db->quoteName('params') . ' = ' . $db->quote(json_encode($params)))
        ->where($db->quoteName('element') . ' = ' . $db->quote('pluginname'))
        ->where($db->quoteName('folder') . ' = ' . $db->quote('system'))
        ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'));

    $db->setQuery($query);
    $db->execute();
}
```

---

## Git Workflow

### Feature Branch Workflow
1. Create feature branch: `git checkout -b feature/feature-name`
2. Make changes and commit frequently
3. Test thoroughly
4. Update version numbers and changelog
5. Commit final changes
6. Merge to main: `git checkout main && git merge feature/feature-name --no-ff`
7. Build release package

### Submodule Handling
If using shared submodule (Joomla Brain):
1. Commit submodule changes first: `git -C shared add -A && git -C shared commit -m "message"`
2. Then commit main repo changes
3. Push both repos
