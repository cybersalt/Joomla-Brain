# Joomla 5 Development Checklist

## Pre-Release Checklist

### Code Quality
- [ ] All code changes committed to git
- [ ] No PHP syntax errors
- [ ] No deprecated Joomla 3/4 APIs used
- [ ] Proper use of Joomla 5 namespaces

### Version & Documentation
- [ ] Version numbers updated in all manifests (pkg_*.xml, plugin XML, component XML)
- [ ] CHANGELOG.md updated with emojis for section headers
- [ ] CHANGELOG.html created/updated with styled presentation
- [ ] All files saved

### Package Building
- [ ] Run build-package.bat (calls PowerShell script for proper structure)
- [ ] Verify validation passes (no XML errors)
- [ ] Check package structure has proper `admin/` folder
- [ ] Verify no intermediate zip files left behind

### Testing
- [ ] Test installation on clean Joomla 5 site
- [ ] Test upgrade from previous version
- [ ] Test all new features
- [ ] Test plugin settings save correctly
- [ ] Verify dark mode compatibility

---

## Common Issues & Solutions

### Plugin Parameters Not Taking Effect from Component

**Problem**: Plugin settings saved from component don't take effect immediately.

**Solution**: Load fresh params directly from database:
```php
private function loadFreshParams(): void
{
    $db = Factory::getDbo();
    $query = $db->getQuery(true)
        ->select($db->quoteName('params'))
        ->from($db->quoteName('#__extensions'))
        ->where($db->quoteName('element') . ' = ' . $db->quote('pluginname'))
        ->where($db->quoteName('folder') . ' = ' . $db->quote('system'))
        ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'));

    $db->setQuery($query);
    $paramsJson = $db->loadResult();

    if ($paramsJson) {
        // Update existing Registry instead of replacing
        $freshParams = json_decode($paramsJson, true);
        if (is_array($freshParams)) {
            foreach ($freshParams as $key => $value) {
                $this->params->set($key, $value);
            }
        }
    }
}
```

**Important**: Don't replace `$this->params` entirely - update individual values to preserve Joomla's form system compatibility.

### PrepareDataEvent Error When Saving Plugin

**Problem**: `PrepareDataEvent::onSetData(): Argument #1 ($value) must be of type object|array, bool given`

**Causes**:
1. XML encoding issues in plugin manifest (em-dash characters, special characters)
2. Empty string defaults on multi-select fields
3. Corrupted params in database

**Solutions**:
1. Use only ASCII characters in XML (replace `—` with `-`)
2. Remove `default=""` from `usergrouplist` fields with `multiple="true"`
3. Uninstall and reinstall plugin to clear corrupted data

### Package Structure Issues

**Problem**: "Install path does not exist" error during installation.

**Cause**: Component ZIP doesn't have proper `admin/` folder structure.

**Solution**: Use PowerShell build script that creates proper structure:
- Root level: `com_name.xml`, `com_name.php`, `com_name/`, `index.html`
- Admin folder: `admin/` containing all backend files (views, controllers, classes, etc.)

**Bad**: Using simple `Compress-Archive` which flattens folder structure.
**Good**: Using custom zip function that preserves folder hierarchy with forward slashes.

### XML Field Type Issues

**Problem**: Form system returns false instead of data array.

**Solutions for `usergrouplist` fields**:
```xml
<!-- Good - no default attribute for multiple select -->
<field name="backend_usergroups" type="usergrouplist"
       label="Backend Visibility"
       multiple="true" />

<!-- Bad - empty string default causes issues -->
<field name="backend_usergroups" type="usergrouplist"
       default=""
       multiple="true" />
```

---

## Changelog Best Practices

### Markdown Format (CHANGELOG.md)
- Use emojis for section headers: 🚀 🔧 📦 🐛 🔍 📝 🛡️ 🎨
- Bold feature names: `- **Feature Name**: Description`
- Use code formatting for technical terms: \`admin/\`, \`usergrouplist\`

### HTML Format (CHANGELOG.html)
- Create styled HTML version for better presentation
- Use HTML entities for emojis: `&#128640;` for 🚀
- Include CSS styling for consistent look
- Only include recent versions (last 3-4)
- Link to full CHANGELOG.md for complete history

---

## Plugin XML Best Practices

### Field Definitions
```xml
<!-- Radio buttons with Yes/No -->
<field name="show_banner" type="radio" default="1"
       label="Show Banner"
       description="Description here"
       class="btn-group btn-group-yesno">
    <option value="1">Yes</option>
    <option value="0">No</option>
</field>

<!-- Multi-select user groups (no default attribute!) -->
<field name="backend_usergroups" type="usergrouplist"
       label="Backend Visibility"
       description="Select user groups. Leave empty for all."
       multiple="true" />

<!-- Color picker -->
<field name="live_color" type="color" default="#59a645"
       label="Live Background Color" />

<!-- Number with range -->
<field name="gradient_duration" type="number" default="5"
       label="Duration (seconds)"
       min="5" max="120" step="1" />
```

### Character Encoding
- Use UTF-8 encoding declaration: `<?xml version="1.0" encoding="utf-8"?>`
- Avoid special characters like em-dashes (—), use regular dashes (-)
- Test XML validation before packaging

---

## Dark Mode Compatibility

### CSS Variables for Atum Template
```css
/* Background that works in both modes */
background: var(--atum-bg-dark, var(--body-bg, #fafafa));

/* Border colors */
border: 1px solid var(--template-bg-dark-7, #ddd);
```

### Testing
- Toggle dark mode in Joomla admin (user menu > template style)
- Check all form elements, backgrounds, and text colors
- Ensure checkboxes and inputs are visible in both modes

---

## Component Saving Plugin Parameters

When saving plugin params from a component:

```php
private function savePluginParams($input) {
    $db = Factory::getDbo();

    // Get current params
    $query = $db->getQuery(true)
        ->select($db->quoteName('params'))
        ->from($db->quoteName('#__extensions'))
        ->where($db->quoteName('element') . ' = ' . $db->quote('pluginname'))
        ->where($db->quoteName('folder') . ' = ' . $db->quote('system'))
        ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'));

    $db->setQuery($query);
    $paramsJson = $db->loadResult();
    $params = $paramsJson ? json_decode($paramsJson, true) : [];

    // Update from POST data
    $pluginFields = ['show_banner', 'style_mode', ...];
    foreach ($pluginFields as $field) {
        $value = $input->post->get('plugin_' . $field, null, 'raw');
        if ($value !== null) {
            $params[$field] = $value;
        }
    }

    // Handle arrays separately (usergroups)
    $usergroups = $input->post->get('plugin_backend_usergroups', [], 'array');
    $params['backend_usergroups'] = array_map('intval', $usergroups);

    // Save back
    $query = $db->getQuery(true)
        ->update($db->quoteName('#__extensions'))
        ->set($db->quoteName('params') . ' = ' . $db->quote(json_encode($params)))
        ->where(...);

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
