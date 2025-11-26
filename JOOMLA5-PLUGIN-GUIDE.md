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

---

## Official Documentation Links

- [Plugin Tutorial](https://manual.joomla.org/docs/5.3/building-extensions/plugins/basic-content-plugin/)
- [Modules and Plugins DI](https://manual.joomla.org/docs/general-concepts/dependency-injection/modules-and-plugins/)
- [Manifest Files](https://manual.joomla.org/docs/5.4/building-extensions/install-update/installation/manifest/)
