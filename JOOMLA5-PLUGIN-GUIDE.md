# Joomla 5 Plugin Development Quick Reference

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

1. **Extension tag MUST have `element` attribute**
   - `<extension type="plugin" group="content" element="myplugin" method="upgrade">`
   - Missing `element` causes JSON parse error on install (Joomla returns HTML error)
2. **XML filename** must match the `plugin` attribute AND `element` attribute
   - `element="myplugin"` + `plugin="myplugin"` requires `myplugin.xml`
   - Mismatch causes namespace loading failure
3. **Language files** must include plugin type and element
   - Format: `plg_{group}_{element}.ini`
4. **Namespace** must match the `use` statement in provider.php
5. **Check** `administrator/cache/autoload_psr4.php` if namespace issues occur

---

## Manifest XML (Joomla 5)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<extension type="plugin" group="content" element="myplugin" method="upgrade">
    <name>plg_content_myplugin</name>
    <namespace path="src">MyCompany\Plugin\Content\MyPlugin</namespace>
    <files>
        <folder plugin="myplugin">services</folder>  <!-- CRITICAL: filename.xml must match this -->
        <folder>src</folder>
    </files>
    <languages>
        <language tag="en-GB">language/en-GB/plg_content_myplugin.ini</language>
        <language tag="en-GB">language/en-GB/plg_content_myplugin.sys.ini</language>
    </languages>
</extension>
```

---

## Service Provider (Joomla 5)
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

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->set(
            PluginInterface::class,
            function (Container $container) {
                $config = (array) PluginHelper::getPlugin('content', 'myplugin');
                $subject = $container->get(DispatcherInterface::class);
                $plugin = new MyPlugin($subject, $config);
                $plugin->setApplication(Factory::getApplication());
                return $plugin;
            }
        );
    }
};
```

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
**Cause**: Namespace not loading properly
**Fix**: Ensure XML filename matches `plugin` attribute exactly

### "Class not found"
**Cause**: Namespace mismatch between manifest, provider.php, and class file
**Fix**:
1. Check `administrator/cache/autoload_psr4.php`
2. Delete cache file and reinstall
3. Verify all three locations use identical namespace
