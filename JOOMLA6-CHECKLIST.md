# Joomla 6 Development Checklist

## Joomla 6.1 Release (2026-04-14)

### Technical Requirements

| Requirement | Recommended | Minimum |
|-------------|-------------|---------|
| PHP | 8.4 | 8.3.0 |
| MySQL | 8.4 | 8.0.13 |
| MariaDB | 12.0 | 10.4 |
| PostgreSQL | 17.6 | 12.0 |
| Apache | 2.4 | 2.4 |
| Nginx | 1.29 | 1.26 |

Required PHP modules: json, simplexml, dom, zlib, gd, mysqlnd/pdo_mysql/pdo_pgsql
Recommended: mbstring

### New Features in Joomla 6.1

#### Proof-of-Work CAPTCHA (#46514)
New core captcha — no external API, no account needed, privacy-friendly. Silently solves math puzzles in background. Excellent for spam protection without third-party dependencies.

#### Visual Workflow Editor (#46021)
Interactive Vue.js-based workflow diagram. See entire publication process visually, manage transitions graphically.

#### Media Custom Fields — Audio, Video, Documents (#45013)
Three new file types for media custom fields beyond images. When creating a custom field, you can specify `file_types` parameter: `images`, `audios`, `videos`, `documents`. This determines which allowed file extensions from Media Manager config are used.

**Impact on extensions:** If your extension uses media custom fields, you can now offer audio/video/document selection fields natively.

#### Module Versioning (#46772)
Version history now extended to modules (was previously only for articles and categories). Modules get the same "Versions" button in the toolbar.

#### Module Multilingual Associations (#46671)
Modules can now be associated across languages, like articles and categories. Multilingual sites can maintain parallel module instances.

#### Subform Grid Layout (#42347)
**New alternative to the table layout for subforms.** Instead of the unresponsive table layout, a CSS Grid layout is now available that partially mimics the table look but is responsive.

**Impact on extensions:** If you use subform fields, consider testing with the new grid layout option.

#### Subform Order-Changed Event (#46093)
New `subform-order-changed` JavaScript event fires when subform row order changes. Listen for this if you need to react to reordering in subform fields.

#### Lazy-Loaded Plugins (#46862, #45062)
All plugins (except compat plugin) are now lazy-loaded using PHP's Lazy Object feature. Plugins are only instantiated when actually needed, not on every request.

**Impact on extensions:** No action needed — this is transparent. But if your plugin constructor does heavy work, it will now only run when the plugin is actually triggered.

#### `#__extensions.custom_data` Now Accessible (#46622)
The `custom_data` MEDIUMTEXT column on `#__extensions` is now available via Joomla's extension getter methods for components, menus, modules, and template styles. Previously required a separate SQL query.

**Impact on extensions:** You can now store and retrieve custom extension data without extra queries.

#### `onAfterDisplay` Event Result Now Echoed (#46771)
The result of `onAfterDisplay` events in `HtmlView` is now properly output. Previously the event fired but its return value was ignored.

**Impact on extensions:** If you use `onAfterDisplay` to inject content after a view renders, it will now work correctly.

#### CLI Enable/Disable Extension Command (#43977)
New CLI command to enable or disable extensions from the command line. Useful for deployment scripts and automation.

#### Copy Child Templates (#46278)
Child templates can now be copied, making it easier to create variations.

#### Child Templates: Language Extend vs Override (#46353)
Child templates now **extend** parent language instead of overriding. Allows child templates to add translations without losing parent strings.

#### Email Template Tags Case-Insensitive (#46787)
Tags in email templates are now case-insensitive. `{USERNAME}`, `{username}`, and `{UserName}` all work.

#### Force/Never Force MFA for Superusers (#46248)
New option to force or exempt superusers from MFA requirements.

#### Batch Copy & Move Tags (#41927)
Tags can now be copied and moved via batch operations.

#### Filter Featured Articles in Menu Item (#46252)
Article menu items can now filter by featured status.

#### Action Log Accessibility (#46884, #46883)
Title attributes added to links in action log messages for screen readers.

#### Deprecation: `Factory::getSession()` (#45869)
`Factory::getSession()` usage replaced. **Breaking change** — if your extension uses this, update to `Factory::getApplication()->getSession()`.

#### Deprecation: OPTGROUP Handling (#46737)
`HTMLHelper::select.options` OPTGROUP handling deprecated. Use the new class/attribute support for optgroups (#46739).

#### Deprecation: Language Strings (#47356)
Some language strings deprecated in 6.1.

---

## Before Starting Development
- [ ] Use `version="6.0"` in all manifests (works for 6.0+)
- [ ] Include `<element>com_yourname</element>` in component manifests
- [ ] Plan your folder structure early
- [ ] Ensure PHP 8.3+ compatibility (OFFICIAL Joomla 6 requirement)
- [ ] **USE JOOMLA NATIVE LIBRARIES ONLY** - Essential for true J6 native status

## Joomla 6 Native Principles
- [ ] Archive Handling: Use `Joomla\Archive\Archive` instead of PCLZip/ZipArchive
- [ ] File Operations: Use `Joomla\CMS\Filesystem\File` and `Joomla\CMS\Filesystem\Folder`
- [ ] Database: Use `Joomla\Database\DatabaseInterface` and `Joomla\CMS\Factory::getDbo()`
- [ ] HTTP Requests: Use `Joomla\CMS\Http\HttpFactory` instead of cURL/file_get_contents
- [ ] Caching: Use `Joomla\CMS\Cache\CacheControllerFactory`
- [ ] Configuration: Use `Joomla\CMS\Component\ComponentHelper::getParams()`
- [ ] Events: Use `Joomla\CMS\Plugin\CMSPlugin` and `SubscriberInterface`
- [ ] Language: Use `Joomla\CMS\Language\Text` instead of custom solutions
- [ ] Session: Use `Joomla\CMS\Factory::getApplication()->getSession()` (NOT `Factory::getSession()` — deprecated!)
- [ ] Input: Use `Joomla\CMS\Factory::getApplication()->getInput()`

## Manifest & Packaging
- [ ] Only the package manifest should declare `<updateservers>`
- [ ] Component manifest must include `<element>` and proper `<files>` sections
- [ ] File naming: `{ext_name}_v{version}_{YYYYMMDD}_{HHMM}.zip` — see `PACKAGE-BUILD-NOTES.md`
- [ ] Build with 7-Zip only

## Error Handling & Logging
- [ ] Wrap all database and AJAX operations in try-catch
- [ ] Use `Joomla\CMS\Log\Log` for error logging
- [ ] Log full stack traces and timestamps for errors
- [ ] Show generic error messages to users, log details internally
- [ ] Use Bootstrap alerts in the system message container (no alert() popups)

## Security (MANDATORY — see README.md)
- [ ] SQL Injection: Always use `$db->quote()`, prepared statements
- [ ] XSS: Always escape output — `htmlspecialchars()`, `esc()` in JS
- [ ] CSRF: Always check `Session::checkToken()`
- [ ] Access Control: Always verify `$user->authorise()`
- [ ] Information Disclosure: Never expose raw exceptions to users

## Update Server Best Practices
- [ ] Only the package manifest should declare the update server
- [ ] Installer script should remove legacy and duplicate update sites
- [ ] Ensure update mechanism works for future updates

## Build & Installation
- [ ] Use 7-Zip for all packages — see `PACKAGE-BUILD-NOTES.md`
- [ ] Installation script should clean up old/conflicting files and update sites
- [ ] Always test installation over existing versions

## Documentation & Changelog
- [ ] Maintain both `CHANGELOG.md` and `CHANGELOG.html` — see `README.md` Changelog Format
- [ ] Use semantic versioning (MAJOR.MINOR.PATCH)
- [ ] Use exact dates (YYYY-MM-DD) in changelogs

## Dark Mode / Light Mode Compatibility
Same Atum template CSS variables as Joomla 5. See `.claude/skills/joomla-development.md` Dark Mode section for the full CSS variable reference, icon classes, and dark/light mode selectors.

## Joomla 6 Database Schema
**Joomla 6.1 has the same core tables as Joomla 5** with these additions:
- `#__history` table: Added `is_current` and `is_legacy` columns (TINYINT)
- `#__extensions`: `custom_data` column now accessible via Joomla getter methods

## Compatibility Notes
- These best practices are for Joomla 5 and Joomla 6. Older versions (Joomla 3/4) require different patterns.
- `Factory::getSession()` is deprecated in 6.1 — use `Factory::getApplication()->getSession()`
- All plugins are lazy-loaded in 6.1 — heavy constructor work only runs when plugin is triggered
- Subform fields have a new grid layout option alongside the existing table layout

---

## Joomla 5 → 6 Deprecation Matrix

The full set of API moves and removals between Joomla 5 and Joomla 6. Code that works against this matrix will run on Joomla 6 **without** the "Behaviour - Backward Compatibility 6" plugin, which is the bar for "true J6 native" status.

### Use these (Joomla 6 native, also works on J5)

| Task | Modern API |
|---|---|
| Database access | `$this->getDatabase()` or inject `DatabaseInterface` |
| Build queries | `$db->createQuery()` (preferred over `$db->getQuery(true)`) |
| Current user | `$this->getCurrentUser()` in models, `$this->getIdentity()` in views/controllers |
| Input handling | `\Joomla\Input\Input` — **NOT** `\Joomla\CMS\Input\Input` (CMS wrapper removed in J6) |
| Create model/table | `$this->getMVCFactory()->createModel('Name')` (MVCFactory) |
| Input in controllers | `$this->input` (already uses `\Joomla\Input\Input` under the hood) |
| Error handling | Throw exceptions (`\RuntimeException`, `\InvalidArgumentException`, `\UnexpectedValueException`) |
| Web assets | `WebAssetManager` via `$wa = $this->getDocument()->getWebAssetManager()` |
| File operations | PHP native (`file_put_contents`, `mkdir`, `is_dir`) or Symfony Filesystem — **NOT** `Joomla\CMS\Filesystem\*` |
| `getItem()` return value | Treat as `stdClass` — direct property access only. **NOT** `CMSObject` — no `->get('x')` / `->set('x', $v)` magic |
| Toolbar | `$this->getDocument()->getToolbar()` (see Toolbar API section below) — **NOT** `Toolbar::getInstance()` |
| Session | `Factory::getApplication()->getSession()` — **NOT** `Factory::getSession()` |

### Never use these (removed in J6 or only behind compat plugin)

| Deprecated | Why | Replacement |
|---|---|---|
| `Factory::getDbo()` / `$this->_db` | Removed in J5 | `$this->getDatabase()` |
| `$db->getQuery(true)` | Still works in J5/J6, deprecated pattern | `$db->createQuery()` |
| `\Joomla\CMS\Input\Input` | Namespace moved in J6 | `\Joomla\Input\Input` |
| `\Joomla\CMS\Filesystem\File` / `Folder` / `Path` | Moved behind compat plugin in J6, removed in J7 | PHP native or Symfony Filesystem |
| `CMSObject` and its `->get()` / `->set()` magic | `getItem()` returns `stdClass` in J6 | Direct property access: `$item->title` |
| `Factory::getUser()` | Deprecated | `$this->getCurrentUser()` (models) or `$this->getIdentity()` (controllers/views) |
| `getSession()->get('user')` | Pattern superseded | `$this->getIdentity()` |
| `$model->getError()` / `$model->setError()` | Old error pattern | Throw exceptions |
| `new ItemModel()` (direct instantiation) | Hard-coded dependencies | `$this->getMVCFactory()->createModel('Item')` |
| `jimport(...)` | Removed | PSR-4 autoloading |
| `CMSObject` (the class itself) | Deprecated; removed in J7 | `stdClass` or a custom DTO class |
| `Factory::getDate()` (legacy) | Wrapped under app | `Factory::getApplication()->getDate()` (or just `Factory::getDate()` still works in J5/6 — but the application accessor is the modern shape) |

### Migration steps (mechanical pass on existing code)

1. **Query builder**: search-replace `$db->getQuery(true)` → `$db->createQuery()`. Both work on J5; only `createQuery()` is guaranteed forward.
2. **Input classes**: search-replace `use Joomla\CMS\Input\Input` → `use Joomla\Input\Input`. `$this->input` in controllers already works on both.
3. **`CMSObject` → `stdClass`**: any code using `$item->get('property')` or `$item->set('property', $value)` on objects from `getItem()` — replace with `$item->property` and `$item->property = $value`.
4. **Filesystem**: replace `Joomla\CMS\Filesystem\File::write($path, $content)` → `file_put_contents($path, $content)`, `Folder::create($dir)` → `mkdir($dir, 0755, true)`, etc. PHP natives are direct equivalents for most operations. For more complex needs (recursive copy, atomic writes), pull in `symfony/filesystem`.
5. **Factory methods**:
   - `Factory::getUser()` → `$this->getCurrentUser()` (models) / `$this->getIdentity()` (controllers/views).
   - `Factory::getApplication()` → inject via constructor or use `$this->getApplication()`.
   - `Factory::getDbo()` → `$this->getDatabase()` or inject `DatabaseInterface`.
6. **Error handling**: `$model->getError()` / `$model->setError()` → try/catch with thrown exceptions (`\RuntimeException`, `\InvalidArgumentException`).
7. **Test with the compat plugin DISABLED**: install the "Behaviour - Backward Compatibility 6" plugin then disable it. If your extension still works, it's J6-native. If it breaks, the failure points to remaining deprecation calls.

---

## Toolbar API (modern pattern)

The modern toolbar API uses `$this->getDocument()->getToolbar()` (NOT the deprecated `Toolbar::getInstance()`) plus method-chained button factories. Use this in `View::addToolbar()`:

### List view toolbar

```php
use Joomla\CMS\Helper\ContentHelper;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Toolbar\ToolbarHelper;

protected function addToolbar(): void
{
    $toolbar = $this->getDocument()->getToolbar();
    $canDo   = ContentHelper::getActions('com_example');

    ToolbarHelper::title(Text::_('COM_EXAMPLE_ITEMS'), 'list');

    if ($canDo->get('core.create')) {
        $toolbar->addNew('item.add');
    }

    if ($canDo->get('core.edit.state') || $canDo->get('core.delete')) {
        // Dropdown groups related actions under one button
        $dropdown = $toolbar->dropdownButton('status-group')
            ->text('JTOOLBAR_CHANGE_STATUS')
            ->toggleSplit(false)
            ->icon('icon-ellipsis-h')
            ->buttonClass('btn btn-action')
            ->listCheck(true);

        $childBar = $dropdown->getChildToolbar();

        if ($canDo->get('core.edit.state')) {
            $childBar->publish('items.publish')->listCheck(true);
            $childBar->unpublish('items.unpublish')->listCheck(true);
            $childBar->archive('items.archive')->listCheck(true);
            $childBar->checkin('items.checkin');
        }

        if ($canDo->get('core.create') && $canDo->get('core.edit')) {
            $childBar->popupButton('batch', 'JTOOLBAR_BATCH')
                ->popupType('inline')
                ->textHeader(Text::_('COM_EXAMPLE_BATCH_OPTIONS'))
                ->url('#joomla-dialog-batch')
                ->modalWidth('800px')
                ->modalHeight('fit-content')
                ->listCheck(true);
        }

        if ($canDo->get('core.delete')) {
            $childBar->trash('items.trash')->listCheck(true);
        }
    }

    if ($canDo->get('core.admin')) {
        $toolbar->preferences('com_example');
    }
}
```

### Edit view toolbar

Use a save dropdown for save variants:

```php
use Joomla\CMS\Toolbar\Toolbar;

$toolbar->apply('item.apply');

$saveGroup = $toolbar->dropdownButton('save-group');
$saveGroup->configure(function (Toolbar $childBar) use ($viewName) {
    $childBar->save($viewName . '.save');
    $childBar->save2new($viewName . '.save2new');
    $childBar->save2copy($viewName . '.save2copy');
});

$toolbar->cancel('item.cancel', $isNew ? 'JTOOLBAR_CANCEL' : 'JTOOLBAR_CLOSE');
```

### Available toolbar button methods (from `CoreButtonsTrait`)

`addNew`, `apply`, `save`, `save2new`, `save2copy`, `cancel`, `publish`, `unpublish`, `archive`, `unarchive`, `trash`, `delete`, `checkin`, `preferences`, `help`, `back`, `link`, `versions`, `divider`

For custom buttons, use `customButton()` or `popupButton()`.

---

## Related

- [`JOOMLA-CODING-STANDARDS.md`](JOOMLA-CODING-STANDARDS.md) — PHPDoc standards your J6 migration must keep passing
- [`JOOMLA5-TESTING-GUIDE.md`](JOOMLA5-TESTING-GUIDE.md) — real-CMS test pattern; tests against real Joomla 6 catch deprecation issues automatically
- [`JOOMLA5-COMMON-GOTCHAS.md`](JOOMLA5-COMMON-GOTCHAS.md) — the J5/J6 controller API differences and event-dispatching compat patterns
- [`JOOMLA5-WEB-ASSETS-GUIDE.md`](JOOMLA5-WEB-ASSETS-GUIDE.md) — WebAssetManager replaces the deprecated `JHtml::_('script', ...)` pattern
