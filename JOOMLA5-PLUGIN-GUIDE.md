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

## Example Repositories

- [cs-browser-page-title](https://github.com/cybersalt/cs-browser-page-title) - System plugin that sets browser page title from custom field value

---

## Official Documentation Links

- [Plugin Tutorial](https://manual.joomla.org/docs/5.3/building-extensions/plugins/basic-content-plugin/)
- [Modules and Plugins DI](https://manual.joomla.org/docs/general-concepts/dependency-injection/modules-and-plugins/)
- [Manifest Files](https://manual.joomla.org/docs/5.4/building-extensions/install-update/installation/manifest/)
