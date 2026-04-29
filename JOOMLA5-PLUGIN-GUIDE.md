# Joomla 5 Plugin Development Quick Reference

**Source**: [Joomla Manual - Plugin Tutorial](https://manual.joomla.org/docs/5.3/building-extensions/plugins/basic-content-plugin/)

## Joomla 5 Native Plugin Structure

### Required Files
```
plg_content_myplugin/
├── myplugin.xml           ← Manifest (filename MUST match plugin attribute!)
├── services/
│   └── provider.php       ← DIC service provider
├── src/
│   └── Extension/
│       └── MyPlugin.php   ← Main plugin class
└── language/
    └── en-GB/
        ├── plg_content_myplugin.ini
        └── plg_content_myplugin.sys.ini
```

## CRITICAL: Naming Rules

1. **XML filename** must match the `plugin` attribute
   - `plugin="myplugin"` requires `myplugin.xml`
   - Mismatch causes namespace loading failure
2. **Language files** must include plugin type and element
   - Format: `plg_{group}_{element}.ini`
3. **Namespace** must match the `use` statement in provider.php
4. **Check** `administrator/cache/autoload_psr4.php` if namespace issues occur

**NOTE**: The `element` attribute is NOT required on the extension tag for plugins (contrary to some sources).

---

## Manifest XML (Joomla 5)

Based on official documentation:

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension method="upgrade" type="plugin" group="content">
    <name>PLG_CONTENT_MYPLUGIN</name>
    <version>1.0</version>
    <description>PLG_CONTENT_MYPLUGIN_DESCRIPTION</description>
    <author>Your Name</author>
    <creationDate>Today</creationDate>
    <copyright>(C) 2025 Your Company</copyright>
    <license>GNU General Public License version 2 or later</license>
    <namespace path="src">MyCompany\Plugin\Content\MyPlugin</namespace>
    <files>
        <folder plugin="myplugin">services</folder>
        <folder>src</folder>
    </files>
    <languages>
        <language tag="en-GB">language/en-GB/plg_content_myplugin.ini</language>
        <language tag="en-GB">language/en-GB/plg_content_myplugin.sys.ini</language>
    </languages>
</extension>
```

**Key Points:**
- Attribute order: `method`, `type`, `group`
- NO `element` attribute on extension tag
- NO `language` folder in `<files>` section - languages are declared separately
- `plugin` attribute on the services folder identifies the plugin

---

## Service Provider (Joomla 5)

Based on official documentation:

```php
<?php
defined('_JEXEC') or die;

use Joomla\CMS\Extension\PluginInterface;
use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\PluginHelper;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use Joomla\Event\DispatcherInterface;
use MyCompany\Plugin\Content\MyPlugin\Extension\MyPlugin;

return new class implements ServiceProviderInterface {
    public function register(Container $container)
    {
        $container->set(
            PluginInterface::class,
            function (Container $container) {
                $dispatcher = $container->get(DispatcherInterface::class);
                $plugin = new MyPlugin(
                    $dispatcher,
                    (array) PluginHelper::getPlugin('content', 'myplugin')
                );
                $plugin->setApplication(Factory::getApplication());
                return $plugin;
            }
        );
    }
};
```

**Key Points:**
- `new class implements` (no parentheses)
- `public function register(Container $container)` (no return type in official docs)
- Dispatcher is first argument, config array second

---

## Main Plugin Class (Joomla 5 Native)

```php
<?php
namespace MyCompany\Plugin\Content\MyPlugin\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;
use Joomla\CMS\Event\Content\ContentPrepareEvent;

class MyPlugin extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            'onContentPrepare' => 'onContentPrepare',
        ];
    }

    public function onContentPrepare(ContentPrepareEvent $event): void
    {
        // Joomla 5 native: use getter methods
        $context = $event->getContext();
        $article = $event->getItem();
        $params  = $event->getParams();
        $page    = $event->getPage();

        // Modify $article->text as needed
    }
}
```

---

## Joomla 4 Compatibility (if needed)

### Supporting BOTH Joomla 4 and 5:

Use generic `Event` class with `array_values()`:

```php
use Joomla\Event\Event;

public function onContentPrepare(Event $event): void
{
    // Works for both GenericEvent (J4) and concrete Event classes (J5)
    [$context, $article, $params, $page] = array_values($event->getArguments());
}
```

### Returning Values (J4/J5 Compatible)
```php
use Joomla\CMS\Event\Result\ResultAwareInterface;

public function onContentAfterTitle(Event $event)
{
    $value = 'My return value';

    if ($event instanceof ResultAwareInterface) {
        // Joomla 5 concrete event
        $event->addResult($value);
    } else {
        // Joomla 4 GenericEvent
        $result = $event->getArgument('result') ?? [];
        $result[] = $value;
        $event->setArgument('result', $result);
    }
}
```

---

## Key Differences Summary

| Aspect | Joomla 4 | Joomla 5 Native |
|--------|----------|-----------------|
| Event Class | `Joomla\Event\Event` (Generic) | Concrete class e.g., `ContentPrepareEvent` |
| Get Parameters | `array_values($event->getArguments())` | `$event->getContext()`, `$event->getItem()`, etc. |
| Return Values | `$event->setArgument('result', ...)` | `$event->addResult(...)` |

---

## Available Concrete Event Classes (Joomla 5)

Located in `libraries/src/Event/`:
- `Joomla\CMS\Event\Content\ContentPrepareEvent`
- `Joomla\CMS\Event\Content\AfterTitleEvent`
- `Joomla\CMS\Event\Content\AfterDisplayEvent`
- `Joomla\CMS\Event\Content\BeforeDisplayEvent`
- `Joomla\CMS\Event\Content\BeforeSaveEvent`
- `Joomla\CMS\Event\Content\AfterSaveEvent`
- And more...

---

## System Plugins

System plugins use the `system` group and have access to application-level events that fire at different points in the request lifecycle. This makes them ideal for tasks that need to modify the final output or access request data.

### System Plugin Structure

```
plg_system_myplugin/
├── myplugin.xml           ← Manifest (group="system")
├── services/
│   └── provider.php       ← DIC service provider
├── src/
│   └── Extension/
│       └── MyPlugin.php   ← Main plugin class
└── language/
    └── en-GB/
        ├── plg_system_myplugin.ini
        └── plg_system_myplugin.sys.ini
```

### System Plugin Manifest

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="plugin" group="system" method="upgrade">
    <name>plg_system_myplugin</name>
    <namespace path="src">MyCompany\Plugin\System\MyPlugin</namespace>
    <!-- ... rest of manifest ... -->
</extension>
```

### System Plugin Service Provider

```php
<?php
\defined('_JEXEC') or die;

use Joomla\CMS\Extension\PluginInterface;
use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\PluginHelper;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use Joomla\Event\DispatcherInterface;
use Joomla\Database\DatabaseInterface;
use MyCompany\Plugin\System\MyPlugin\Extension\MyPlugin;

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->set(
            PluginInterface::class,
            function (Container $container) {
                $plugin = new MyPlugin(
                    $container->get(DispatcherInterface::class),
                    (array) PluginHelper::getPlugin('system', 'myplugin')
                );
                $plugin->setApplication(Factory::getApplication());
                $plugin->setDatabase($container->get(DatabaseInterface::class));

                return $plugin;
            }
        );
    }
};
```

### Using DatabaseAwareTrait

System plugins often need database access. Use `DatabaseAwareTrait`:

```php
<?php
namespace MyCompany\Plugin\System\MyPlugin\Extension;

\defined('_JEXEC') or die;

use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;
use Joomla\Database\DatabaseAwareTrait;

class MyPlugin extends CMSPlugin implements SubscriberInterface
{
    use DatabaseAwareTrait;

    public static function getSubscribedEvents(): array
    {
        return [
            'onAfterRender' => 'onAfterRender',
        ];
    }

    public function onAfterRender(): void
    {
        $db = $this->getDatabase();
        // Use $db for queries
    }
}
```

### Key System Events

| Event | When it Fires | Use Case |
|-------|---------------|----------|
| `onAfterInitialise` | After Joomla initializes | Early setup, before routing |
| `onAfterRoute` | After routing determined | Modify routing, check permissions |
| `onBeforeRender` | Before page renders | Modify document, add scripts |
| `onAfterRender` | After all rendering complete | Modify final HTML output |
| `onBeforeCompileHead` | Before head section compiled | Add meta tags, scripts |

### CRITICAL: Content vs System Plugins for Page Modifications

**Problem**: Content plugin events like `onContentPrepare` and `onContentAfterDisplay` fire BEFORE Joomla's article view sets the page title. Any title changes get overwritten.

**Solution**: Use a **system plugin** with `onAfterRender` to modify the final HTML output:

```php
public function onAfterRender(): void
{
    $app = $this->getApplication();

    // Only run on frontend
    if (!$app->isClient('site')) {
        return;
    }

    // Get the rendered body
    $body = $app->getBody();

    // Modify the <title> tag using regex
    $pattern = '/<title>.*?<\/title>/is';
    $replacement = '<title>New Title</title>';
    $newBody = preg_replace($pattern, $replacement, $body, 1);

    if ($newBody !== null) {
        $app->setBody($newBody);
    }
}
```

This approach guarantees your changes won't be overwritten because `onAfterRender` fires after ALL processing is complete.

### Accessing Request Data in System Plugins

```php
public function onAfterRender(): void
{
    $app = $this->getApplication();

    // Get request parameters
    $option = $app->input->get('option');  // e.g., 'com_content'
    $view = $app->input->get('view');      // e.g., 'article'
    $id = $app->input->getInt('id');       // e.g., 123

    // Check if viewing a single article
    if ($option === 'com_content' && $view === 'article' && $id) {
        // Process article-specific logic
    }
}
```

### Querying Custom Field Values Directly

When `jcfields` isn't available (common in system plugins), query the database directly:

```php
private function getFieldValue(int $itemId, int $fieldId): ?string
{
    $db = $this->getDatabase();

    $query = $db->getQuery(true)
        ->select($db->quoteName('value'))
        ->from($db->quoteName('#__fields_values'))
        ->where($db->quoteName('field_id') . ' = :fieldId')
        ->where($db->quoteName('item_id') . ' = :itemId')
        ->bind(':fieldId', $fieldId)
        ->bind(':itemId', $itemId);

    $db->setQuery($query);

    return $db->loadResult() ?: null;
}
```

### SQL Field Type for Custom Field Selection

Allow users to select a custom field from a dropdown in plugin settings:

```xml
<field
    name="custom_field_id"
    type="sql"
    default=""
    label="PLG_SYSTEM_MYPLUGIN_FIELD_LABEL"
    description="PLG_SYSTEM_MYPLUGIN_FIELD_DESC"
    query="SELECT id, title FROM #__fields WHERE context = 'com_content.article' AND state = 1 ORDER BY title"
    key_field="id"
    value_field="title"
>
    <option value="">- Select a Custom Field -</option>
</field>
```

---

## Common Errors

### "Unexpected token '<'... is not valid JSON"
**Cause**: Joomla installer returning HTML error page instead of JSON
**Possible Fixes**:
1. Ensure XML filename matches `plugin` attribute exactly
2. Check PHP syntax errors in provider.php or Extension class
3. Verify namespace declarations match across all files
4. Delete `administrator/cache/autoload_psr4.php` and reinstall

### "Class not found"
**Cause**: Namespace mismatch between manifest, provider.php, and class file
**Fix**:
1. Check `administrator/cache/autoload_psr4.php`
2. Delete cache file and reinstall
3. Verify all three locations use identical namespace

### AJAX Handler Returns Blank Page
**Cause**: Using `SubscriberInterface` but returning string instead of setting result on Event
**Fix**:
1. Add `use Joomla\Event\Event;`
2. Change method signature to accept `Event $event` parameter
3. Use `$event->addResult($result)` instead of `return $result`
4. Ensure event is listed in `getSubscribedEvents()` array

### AJAX Handler Not Being Called
**Cause**: Event not subscribed when using `SubscriberInterface`
**Fix**: Add the AJAX event to `getSubscribedEvents()`:
```php
'onAjaxMyplugin' => 'onAjaxMyplugin',
```

### "Call to undefined method getMode()"
**Cause**: `AdministratorRouter` doesn't have `getMode()` method (only `SiteRouter` does)
**Fix**: Use `method_exists()` check before calling router-specific methods:
```php
if (method_exists($router, 'getMode')) {
    $mode = $router->getMode();
}
```

### `modal_article` (and friends) renders with no Select button in plugin settings
**Symptom**: A `<field type="modal_article" select="true" clear="true" />` placed in a plugin manifest's `<config><fields name="params">…</fields></config>` block renders just the input — no Select button, no Clear button, no way to actually pick anything. The user sees a label, a description, and a useless empty input.

**Cause**: The `modal_article` field family relies on a layout + JS bundle that Joomla loads in module/component admin contexts (e.g., `com_modules` for module params, the article edit form for related-article picking) but **does not load in the plugin manager (`com_plugins`)** on Joomla 5/6. The field class still emits the `<input>` because that's done in PHP, but the modal trigger button + browse modal never wire up.

This was confirmed on Joomla 6.1 with cs-registration-redirect v1.1.2 — even after dropping `showon` (which is its own separate gotcha — see below), the picker still rendered empty.

**Fix**: Use `type="sql"` instead. The `sql` field works in any context and renders a dropdown bound to a database query:

```xml
<field
    name="redirect_article"
    type="sql"
    label="PLG_..._ARTICLE_LABEL"
    description="PLG_..._ARTICLE_DESC"
    default="0"
    query="SELECT a.id, CONCAT(IFNULL(c.title, '–'), ' / ', a.title) AS title
           FROM #__content AS a
           LEFT JOIN #__categories AS c ON c.id = a.catid
           WHERE a.state = 1
           ORDER BY c.title, a.title"
    key_field="id"
    value_field="title"
>
    <option value="0">- Select an article -</option>
</field>
```

For sites with thousands of articles this gives a long dropdown but it works reliably. If volume is a concern, scope with `LIMIT 500` plus an order on `created DESC` or filter by `featured = 1`.

The same workaround applies to `modal_contact`, `modal_menu`, `modal_user`, etc. when used in plugin settings — replace with a `sql` query against the corresponding core table.

### Modal-trigger field hidden by `showon` — Select button never wires up
**Cause**: Even in contexts where `modal_*` fields *do* work (modules, articles), wrapping one in `showon` hides it at page load with `display:none`. The trigger JS runs once at page load against the visible DOM and never re-binds when the field is revealed. The field becomes visible but the Select button does nothing.

**Fix**: Drop `showon` from modal-trigger fields. Render them always; prefix each conditional field's description with *"Used when destination type is X"* so the user knows which one applies.

See `JOOMLA5-UI-PATTERNS.md` § "Modal-trigger fields and `showon` don't mix" for the fuller writeup, and § "Article picker via `sql` field" for the plugin-settings workaround.

---

## AJAX Handlers with com_ajax (CRITICAL for SubscriberInterface)

When using plugins with `SubscriberInterface` that need AJAX endpoints via `com_ajax`, you **cannot** simply return a string. The result must be set on the Event object.

### The Problem

```php
// THIS DOES NOT WORK - returns blank page!
public function onAjaxMyplugin(): string
{
    return json_encode(['success' => true]);
}
```

### The Solution

1. **Import the Event class**
2. **List the event in `getSubscribedEvents()`**
3. **Accept Event parameter and set result on it**

```php
use Joomla\Event\Event;

public static function getSubscribedEvents(): array
{
    return [
        'onContentPrepare' => 'onContentPrepare',
        'onAjaxMyplugin'   => 'onAjaxMyplugin',  // MUST be listed!
    ];
}

public function onAjaxMyplugin(Event $event): void
{
    $app = Factory::getApplication();

    // Security checks
    if (!$app->isClient('administrator')) {
        $this->setAjaxResult($event, json_encode(['error' => 'Access denied']));
        return;
    }

    if (!Session::checkToken('get') && !Session::checkToken('post')) {
        $this->setAjaxResult($event, json_encode(['error' => 'Invalid token']));
        return;
    }

    $result = json_encode(['success' => true, 'data' => 'Hello World']);
    $this->setAjaxResult($event, $result);
}

/**
 * Helper method to set AJAX result on event (J4/J5 compatible)
 */
private function setAjaxResult(Event $event, string $result): void
{
    if (method_exists($event, 'addResult')) {
        $event->addResult($result);
    } else {
        $results = $event->getArgument('result', []);
        $results[] = $result;
        $event->setArgument('result', $results);
    }
}
```

### URL Format for com_ajax Plugin Calls

```
index.php?option=com_ajax&plugin=myplugin&group=system&format=raw&{token}=1
```

- `plugin` = plugin element name (lowercase)
- `group` = plugin group (system, content, etc.)
- `format=raw` for unformatted output
- Include CSRF token for security

---

## Standard Log Viewer Implementation

**For CyberSalt Extensions**: All extensions with logging MUST use a consistent log viewer UI for user familiarity.

### Required Components

1. **Custom Form Field** for admin settings buttons:
   - `src/Field/ViewerbuttonField.php` (note: lowercase 'b' for Joomla field loading)
   - Displays: View Log, Download Log, Test Logging buttons

2. **AJAX Actions**:
   - `view` - Return log entries as JSON with pagination
   - `stats` - Return log statistics
   - `clear` - Archive and clear log file
   - `download` - Download raw log file
   - `viewer` - Return full HTML viewer
   - `test` - Diagnostic test of logging functionality

3. **Viewer Template** (`tmpl/viewer.php`):
   - Dark theme with CSS variables
   - Stats bar (entries, requests, size, warnings, errors)
   - Filters (request ID, event type, entry limit)
   - Button bar: Refresh, Dump Log, Download, Clear
   - Expandable log entries with JSON syntax highlighting
   - Stack trace display

### Reference Implementation

See [cs-joomla-router-tracer](https://github.com/cybersalt/cs-joomla-router-tracer) for the canonical implementation.

---

## Lessons Learned from cs-siteground-cache-for-joomla

### Language Files: .ini vs .sys.ini

**Problem**: System plugin strings (toolbar buttons, admin notices) showed as raw keys (`PLG_SYSTEM_MYPLUGIN_SOMETHING`) on most admin pages, but worked on the plugin settings page.

**Cause**: Joomla only auto-loads `.sys.ini` globally. The `.ini` file is only loaded when viewing the plugin's own settings. If your plugin injects UI (toolbar buttons, notices) on every admin page, those strings must be in `.sys.ini`.

**Solution**: Either:
1. Put all globally-needed strings in both `.ini` AND `.sys.ini`
2. Call `$this->loadLanguage()` in `onAfterInitialise` (CMSPlugin built-in method — knows all install paths)

Do NOT use manual `$app->getLanguage()->load()` with hardcoded paths — it's fragile. Use `$this->loadLanguage()`.

### Custom Field Types: addfieldprefix Required

**Problem**: Custom field types (e.g., `type="purgebutton"`) render as plain text inputs instead of the custom UI.

**Cause**: Missing `addfieldprefix` attribute. Joomla doesn't know to look in your plugin's namespace for field classes.

**Fix**: Add to the `<fields>` tag in the manifest:
```xml
<fields name="params" addfieldprefix="Cybersalt\Plugin\System\MyPlugin\Field">
```

### Injecting into Atum Admin Header Bar

To add a button to the top header bar that matches native styling (Clean Cache, site link, etc.), inject into the `.header-items` container using the exact Atum HTML pattern:

```php
// In onAfterRender for admin:
$body = $app->getBody();
$buttonHtml = '<div class="header-item"><a href="javascript:" class="header-item-content" onclick="myAction()" title="My Button"><div class="header-item-icon"><span class="icon-trash" aria-hidden="true"></span></div><div class="header-item-text">My Button</div></a></div>';

$body = preg_replace('/(<div[^>]*class="[^"]*header-items[^"]*"[^>]*>)/i', '$1' . $buttonHtml, $body, 1);
$app->setBody($body);
```

Key: use `header-item` > `header-item-content` > `header-item-icon` + `header-item-text` structure. Do NOT use Bootstrap `btn` classes — they override Atum's native styling.

### onAfterRespond May Not Fire on Admin Save+Redirect

**Problem**: When saving content in admin, Joomla does a POST then 302 redirect. `onAfterRespond` may not fire reliably, so deferred operations (like cache purge queues) are lost.

**Solution**: Register a PHP shutdown function as fallback:
```php
register_shutdown_function([$this, 'processQueue']);
```
Use a static guard to prevent double execution if `onAfterRespond` also fires.

### Custom Multi-Select Field for Installed Components

To let users select from installed Joomla components, create a custom field extending `ListField`:

```php
class ComponentselectField extends ListField
{
    protected function getOptions(): array
    {
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $query = $db->getQuery(true)
            ->select(['element', 'name'])
            ->from('#__extensions')
            ->where('type = ' . $db->quote('component'))
            ->where('enabled = 1')
            ->order('name ASC');
        // ... build options from results
    }
}
```

In manifest use `layout="joomla.form.field.list-fancy-select"` with `multiple="true"` for the searchable tag-style selector.

---

## Catching component-thrown 404s — use `onError`, not `onAfterDispatch`/`onAfterRender`

**Symptom:** A system plugin needs to detect when a third-party component (HikaShop, VirtueMart, etc.) responds with a 404 because of access denial / missing record / etc., and react to it (redirect, log, enqueue notice). The natural reach is `onAfterDispatch` or `onAfterRender` — but neither fires.

**Cause:** When a component raises an exception mid-dispatch (which is how HikaShop signals access denial — see `components/com_hikashop/controllers/product.php` and friends), Joomla's dispatch loop never completes. The lifecycle on this path is:

```
onAfterRoute  →  onError  →  (error renderer takes over)  →  onAfterRespond
```

- `onAfterDispatch` does NOT fire — dispatch threw before completing.
- `onAfterRender` does NOT fire — the regular renderer never runs; the *error* renderer is a separate code path that doesn't fire `onAfterRender`.
- `onAfterRespond` fires too late — the response has already been committed; you cannot redirect from there.

The only event that fires *after* the 404 has been raised *and before* the response is committed is **`onError`**.

**Verified empirically** on Joomla 6.1 + HikaShop 6.4 with an instrumented plugin that logged every event firing on the 404 path. Log excerpt (Guest hits a restricted product):

```
[18:35:55] onAfterRoute    uri=/en/store/product/foo opt=com_hikashop view=category guest=1 docType=NO-DOC isErr=0 hdrStatus=
[18:35:55] onError         uri=/en/store/product/foo opt=com_hikashop view=product  guest=1 docType=html  isErr=0 hdrStatus=
[18:35:55] onAfterRespond  uri=/en/store/product/foo opt=com_hikashop view=product  guest=1 docType=error isErr=1 hdrStatus=404
```

**How to handle it:** Subscribe to `onError` and read the throwable from the event:

```php
use Joomla\CMS\Event\ErrorEvent;
use Joomla\Event\SubscriberInterface;

public static function getSubscribedEvents(): array
{
    return ['onError' => 'onError'];
}

public function onError(ErrorEvent $event): void
{
    $error = $event->getError();
    if ((int) $error->getCode() !== 404) {
        return;
    }

    $app = $this->getApplication();
    $input = $app->getInput();

    // At this point $input still reflects the original request — check the
    // option/view to decide whether this is "your" 404.
    if ($input->get('option') !== 'com_hikashop') {
        return;
    }

    // ... build redirect, etc.
    $app->redirect($yourUrl);
}
```

The event's input still reflects the original route (`option=com_hikashop`, `view=product`, etc.), and the response has not been committed yet — `$app->redirect(...)` works.

**Don't bother detecting the 404 by header/document inspection.** A spec earlier suggested checking `$app->getDocument() instanceof ErrorDocument` or sniffing the `Status: 404` header from `onAfterDispatch` / `onAfterRender`. That approach is dead — the detection is fine but neither hook fires on the path you care about. Use `onError` and read `$event->getError()->getCode()` directly.

**Reference:** cs-hikashop-login-redirect v1.0.0 — the original spec called for `onAfterDispatch` + `onAfterRender`; field testing on Philippe's site (dominicanamberfossils.com, J6.1.0 + HikaShop 6.4.0) proved this didn't work and the plugin was rewritten around `onError`.

---

## `return=` URLs must be absolute for `Uri::isInternal()` to accept them

**Symptom:** Plugin builds a base64-encoded `return=` query parameter for a redirect to Joomla's login form (the standard pattern for "log in then come back here"). The user logs in successfully but lands on the wrong page — a menu-defined default, the homepage, or the user's last-state — instead of the URL the plugin encoded.

**Cause:** `Joomla\Component\Users\Site\Model\LoginModel::loadFormData()` decodes the URL `return=` parameter (base64), then validates it via:

```php
if (!Uri::isInternal($return)) {
    $return = '';
}
```

`Uri::isInternal()` performs `stripos($url, Uri::base())` against the full site URL (`https://example.com/`). A path-only URL like `/en/store/product/foo` doesn't match at position 0 (the host is missing), so `isInternal` returns `FALSE` — and `$return` gets silently reset to empty. The form then falls back to user-state defaults.

**`Uri::isInternal('/en/store/product/foo')`** → `FALSE`
**`Uri::isInternal('https://example.com/en/store/product/foo')`** → `TRUE`

**Fix:** Encode the full URL, not just `path+query`:

```php
// ❌ Wrong — stripped by Uri::isInternal
$return = base64_encode(Uri::getInstance()->toString(['path', 'query']));

// ✅ Right — full URL passes Uri::isInternal
$return = base64_encode(Uri::getInstance()->toString(['scheme', 'host', 'port', 'path', 'query']));

$loginUrl = $loginBase . (str_contains($loginBase, '?') ? '&' : '?') . 'return=' . $return;
```

**Bonus gotcha — site-config can still override `return=`:** Even with the absolute URL fix in place, post-login the user can still bounce somewhere unexpected if the **login menu item's "Login Redirect Page"** parameter is set. Joomla menu items have `loginredirectchoice` + `login_redirect_menuitem` params; when `loginredirectchoice = 1`, the menu item's value overrides the form's `return` field entirely. This is a site-config issue, not a plugin bug — point users at: Menus → edit the login menu item → "Login Redirect Page" → "Use Returned URL" / "No".

**Reference:** cs-hikashop-login-redirect v1.0.0 — encoded `path+query` originally, redirect worked but post-login bounced to a menu default; switched to full URL and the form's hidden `return` rendered correctly.

---

## Common Plugin Groups

Joomla ships dozens of plugin groups; these are the ones you'll actually build against. Knowing which group fires which events is the difference between five minutes of work and an afternoon spelunking through `libraries/src/`.

| Group | Purpose | Common events |
|-------|---------|--------------|
| **content** | Modify/process article and content rendering | `onContentPrepare`, `onContentAfterTitle`, `onContentBeforeDisplay`, `onContentAfterDisplay`, `onContentAfterSave`, `onContentBeforeDelete` |
| **system** | Site-wide hooks across the request lifecycle | `onAfterInitialise`, `onAfterRoute`, `onAfterDispatch`, `onBeforeRender`, `onAfterRender`, `onBeforeCompileHead`, `onError` |
| **finder** | Smart Search indexing | `onFinderAfterSave`, `onFinderAfterDelete`, `onFinderChangeState`, `onFinderCategoryChangeState` |
| **task** | Scheduled tasks (Joomla's cron-like Scheduler) | `onTaskOptionsList`, `onExecuteTask` |
| **webservices** | Register API routes for the JSON:API web services | `onBeforeApiRoute` |
| **schemaorg** | Structured data injection | `onSchemaPrepare`, `onSchemaBeforeCompileHead` |
| **user** | User lifecycle hooks | `onUserAfterSave`, `onUserAfterDelete`, `onUserLogin`, `onUserLogout`, `onUserAuthenticate` |
| **authentication** | Auth providers (LDAP, GitHub, etc.) | `onUserAuthenticate` |
| **installer** | Extension install/update events | `onInstallerBeforeInstallation`, `onInstallerAfterInstaller` |
| **editors** | WYSIWYG editor implementations | `onInit`, `onSave`, `onGetContent`, `onSetContent` |
| **editors-xtd** | Editor toolbar buttons | `onDisplay` |
| **quickicon** | Admin control-panel quick icons | `onGetIcons` |
| **fields** | Custom field types | `onCustomFieldsGetTypes`, `onCustomFieldsPrepareDom` |
| **privacy** | GDPR export/anonymise hooks | `onPrivacyExportRequest`, `onPrivacyRemoveData` |

**Picking a group:** the group determines *when* and *where* the plugin fires. A "modify article HTML before render" plugin is **content**, not system. A "log every page load" plugin is **system**, not content. Don't fight the group — if you find yourself reaching for events from a different group, it usually means you picked wrong.

---

## Task Plugin (Joomla Scheduler)

Task plugins register routines that the Joomla Scheduler can run on a schedule (or on-demand). The pattern uses `TaskPluginTrait` for boilerplate and a `TASKS_MAP` constant to declare what routines this plugin advertises.

```php
<?php

namespace Cybersalt\Plugin\Task\MyTask\Extension;

\defined('_JEXEC') or die;

use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Component\Scheduler\Administrator\Event\ExecuteTaskEvent;
use Joomla\Component\Scheduler\Administrator\Task\Status as TaskStatus;
use Joomla\Component\Scheduler\Administrator\Traits\TaskPluginTrait;
use Joomla\Event\SubscriberInterface;

final class MyTask extends CMSPlugin implements SubscriberInterface
{
    use TaskPluginTrait;

    /**
     * Task routines this plugin advertises.
     *
     * The key is the routine ID (used internally by the Scheduler);
     * the array describes what the user sees in the admin and which
     * method runs.
     */
    protected const TASKS_MAP = [
        'mytask.cleanup' => [
            'langConstPrefix' => 'PLG_TASK_MYTASK_CLEANUP',
            'method'          => 'doCleanup',
            'form'            => 'cleanup_params', // optional: form XML for per-task params
        ],
        'mytask.report' => [
            'langConstPrefix' => 'PLG_TASK_MYTASK_REPORT',
            'method'          => 'doReport',
        ],
    ];

    public static function getSubscribedEvents(): array
    {
        return [
            'onTaskOptionsList' => 'advertiseRoutines',     // from TaskPluginTrait
            'onExecuteTask'     => 'standardRoutineHandler', // from TaskPluginTrait
        ];
    }

    private function doCleanup(ExecuteTaskEvent $event): int
    {
        // Your cleanup work here. Throw on hard failure, return a status otherwise.
        // Use $this->logTask('Removed N expired records') from TaskPluginTrait
        // to write to the task's log channel.

        return TaskStatus::OK;
    }

    private function doReport(ExecuteTaskEvent $event): int
    {
        // ...
        return TaskStatus::OK;
    }
}
```

**Language keys:** `TaskPluginTrait` builds two keys per routine from `langConstPrefix`:

- `{langConstPrefix}_TITLE` — shown as the task type in the admin dropdown.
- `{langConstPrefix}_DESC` — shown as the description below the dropdown.

So your `.ini` must include:

```ini
PLG_TASK_MYTASK_CLEANUP_TITLE="Database cleanup"
PLG_TASK_MYTASK_CLEANUP_DESC="Removes expired records from the database."
PLG_TASK_MYTASK_REPORT_TITLE="Generate weekly report"
PLG_TASK_MYTASK_REPORT_DESC="Compiles a CSV report of the past week's activity."
```

**Status values** (from `Joomla\Component\Scheduler\Administrator\Task\Status`):

| Constant | When to return |
|---|---|
| `TaskStatus::OK` | Task succeeded. |
| `TaskStatus::KNOCKOUT` | Task should be removed/disabled (rare). |
| `TaskStatus::TIMEOUT` | Soft timeout — task ran too long; let the Scheduler retry. |
| `TaskStatus::WILL_RESUME` | Task is paused mid-work and will continue on next run. |
| Throw an exception | Hard failure — Scheduler logs it as failed. |

> [!TIP]
> The Scheduler runs tasks via Joomla's Web Cron, a CLI runner, or the admin "Run on demand" button. Test your task with the on-demand button first — it gives you immediate feedback without waiting for the next cron tick.

---

## Webservices Plugin (JSON:API routes)

Webservices plugins extend Joomla's web services API by registering CRUD routes for a component. They're the cleanest way to expose a custom component over the JSON:API.

```php
<?php

namespace Cybersalt\Plugin\Webservices\MyApi\Extension;

\defined('_JEXEC') or die;

use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\CMS\Router\ApiRouter;
use Joomla\Event\SubscriberInterface;

final class MyApi extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return [
            'onBeforeApiRoute' => 'onBeforeApiRoute',
        ];
    }

    public function onBeforeApiRoute(&$router): void
    {
        /** @var ApiRouter $router */
        $router->createCRUDRoutes(
            'v1/example/items',          // URL prefix under /api/index.php/
            'items',                      // controller name in com_example
            ['component' => 'com_example']
        );

        // Custom non-CRUD endpoints:
        $router->createCRUDRoutes(
            'v1/example/items/:id/publish',
            'items',
            ['component' => 'com_example', 'task' => 'publish']
        );
    }
}
```

The matching API controller lives in your component:

```
components/com_example/src/Controller/ItemsController.php
```

Both **must exist** for the route to do anything — the plugin only registers the URL pattern; the component's `Api/Controller/` and `Api/View/` classes do the actual work.

See [[JOOMLA5-WEB-SERVICES-API-GUIDE.md]] for the full pipeline (manifest, controller, model, view, JSON:API document).

---

## Finder Plugin (Smart Search indexing)

If your component stores searchable content, a Finder plugin teaches Joomla's Smart Search how to index it. Finder plugins extend `Joomla\Component\Finder\Administrator\Indexer\Adapter` (not `CMSPlugin` directly).

```php
<?php

namespace Cybersalt\Plugin\Finder\MyContent\Extension;

\defined('_JEXEC') or die;

use Joomla\Component\Finder\Administrator\Indexer\Adapter;
use Joomla\Event\SubscriberInterface;

final class MyContent extends Adapter implements SubscriberInterface
{
    protected $context   = 'MyContent';
    protected $extension = 'com_mycomponent';
    protected $layout    = 'item';
    protected $type_title = 'My Content Item';
    protected $table     = '#__mycomponent_items';

    public static function getSubscribedEvents(): array
    {
        return [
            'onFinderAfterSave'           => 'onFinderAfterSave',
            'onFinderAfterDelete'         => 'onFinderAfterDelete',
            'onFinderChangeState'         => 'onFinderChangeState',
            'onFinderCategoryChangeState' => 'onFinderCategoryChangeState',
        ];
    }

    // Implement index($item, $format) and other Adapter abstract methods...
}
```

**When to bother:** if Smart Search is enabled on the site and clients expect "search the whole site" to find content from your component. If they just use the component's own list filter, skip the Finder plugin.

---

## Example Repositories

- [cs-browser-page-title](https://github.com/cybersalt/cs-browser-page-title) - System plugin that sets browser page title from custom field value
- [cs-siteground-cache-for-joomla](https://github.com/cybersalt/cs-siteground-cache-for-joomla) - System plugin with admin header button injection, inline log viewer, custom field types, UNIX socket IPC, shutdown function fallback
- [cs-hikashop-login-redirect](https://github.com/cybersalt/cs-hikashop-login-redirect) - System plugin (private repo) hooking `onError` to redirect Guests on HikaShop access-denied 404s; canonical example of catching a component-thrown 404 from a system plugin

---

## Official Documentation Links

- [Plugin Tutorial](https://manual.joomla.org/docs/5.3/building-extensions/plugins/basic-content-plugin/)
- [Modules and Plugins DI](https://manual.joomla.org/docs/general-concepts/dependency-injection/modules-and-plugins/)
- [Manifest Files](https://manual.joomla.org/docs/5.4/building-extensions/install-update/installation/manifest/)
