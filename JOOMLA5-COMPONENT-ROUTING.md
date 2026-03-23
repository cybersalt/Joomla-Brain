# Joomla 5 Component SEF Routing Guide

## Overview

Components need a router to generate clean SEF URLs. Without a router, Joomla produces ugly URLs like `?option=com_example&view=articles&topic_id=5` or, with SEF enabled, falls back to `/component/com_example/articles?topic_id=5`.

**IMPORTANT**: Joomla 5/6 provides two router base classes. Use `RouterBase` for components with simple view structures. Avoid `RouterView` unless your views map exactly to Joomla's parent-child item pattern (like com_content's category → article).

---

## Quick Start: RouterBase Implementation

### 1. Create the Router Class

**File**: `site/src/Service/Router.php`

```php
<?php
namespace YourVendor\Component\YourComponent\Site\Service;

defined('_JEXEC') or die;

use Joomla\CMS\Application\SiteApplication;
use Joomla\CMS\Component\Router\RouterBase;
use Joomla\CMS\Factory;
use Joomla\CMS\Menu\AbstractMenu;

class Router extends RouterBase
{
    public function build(&$query)
    {
        $segments = [];
        $menuView = '';

        if (!empty($query['Itemid'])) {
            $menuItem = $this->menu->getItem($query['Itemid']);
            $menuView = $menuItem->query['view'] ?? '';
        }

        $view = $query['view'] ?? '';

        // If the view matches the menu item, no segment needed
        if ($view === $menuView) {
            unset($query['view']);
        }

        // Convert IDs to alias segments
        // Example: topic_id → topic alias
        if (isset($query['topic_id'])) {
            $alias = $this->lookupAlias((int) $query['topic_id']);
            $segments[] = $alias ?: (string) $query['topic_id'];
            unset($query['topic_id']);
            unset($query['view']); // view is implied by the segment
        }

        return $segments;
    }

    public function parse(&$segments)
    {
        $vars = [];

        if (empty($segments)) {
            return $vars;
        }

        $menuItem = $this->menu->getActive();
        $menuView = $menuItem->query['view'] ?? '';

        // Example: topics menu + one segment = item alias
        if ($menuView === 'topics' && count($segments) === 1) {
            $id = $this->lookupId($segments[0]);
            if ($id) {
                $vars['view'] = 'articles';
                $vars['topic_id'] = $id;
                $segments = [];
                return $vars;
            }
        }

        // Fallback
        $vars['view'] = array_shift($segments);
        return $vars;
    }

    private function lookupAlias(int $id): ?string
    {
        $db = Factory::getContainer()->get('DatabaseDriver');
        $query = $db->getQuery(true)
            ->select($db->quoteName('alias'))
            ->from($db->quoteName('#__yourext_items'))
            ->where($db->quoteName('id') . ' = ' . $id);
        $db->setQuery($query);
        return $db->loadResult() ?: null;
    }

    private function lookupId(string $alias): int
    {
        $db = Factory::getContainer()->get('DatabaseDriver');
        $query = $db->getQuery(true)
            ->select($db->quoteName('id'))
            ->from($db->quoteName('#__yourext_items'))
            ->where($db->quoteName('alias') . ' = ' . $db->quote($alias));
        $db->setQuery($query);
        return (int) $db->loadResult();
    }
}
```

### 2. Register the Router in the Service Provider

**File**: `admin/services/provider.php`

```php
use Joomla\CMS\Component\Router\RouterFactoryInterface;
use Joomla\CMS\Extension\Service\Provider\RouterFactory;

// In register() method:
$container->registerServiceProvider(new RouterFactory('\\YourVendor\\Component\\YourComponent'));

// In the ComponentInterface factory:
$component->setRouterFactory($container->get(RouterFactoryInterface::class));
```

### 3. Update the Component Class

**File**: `admin/src/Extension/YourComponent.php`

```php
use Joomla\CMS\Component\Router\RouterServiceInterface;
use Joomla\CMS\Component\Router\RouterServiceTrait;

class YourComponentComponent extends MVCComponent implements BootableExtensionInterface, RouterServiceInterface
{
    use HTMLRegistryAwareTrait;
    use RouterServiceTrait;
    // ...
}
```

---

## Critical: Itemid Must Be Passed in Templates

**Setting `$query['Itemid']` inside your router's `build()` method is TOO LATE.** Joomla's `SiteRouter` resolves the menu item path *before* calling the component router. If no `Itemid` is in the query, Joomla falls back to `/component/com_yourext/...`.

### Always pass Itemid in Route::_() calls

**From a view that IS the menu item** (e.g., topics list template):
```php
// Get the current menu item ID
$activeItemId = Factory::getApplication()->input->getInt('Itemid', 0);

// Build URL with the Itemid
$url = Route::_('index.php?option=com_example&view=articles&topic_id=' . $topic->id . '&Itemid=' . $activeItemId);
// Result: /parent/topics-list/topic-alias
```

**From a view that is NOT the menu item** (e.g., articles template linking back to topics):
```php
// Look up the topics menu item
$topicsItemId = 0;
$menuItems = Factory::getApplication()->getMenu()->getItems('component', 'com_example');
foreach ($menuItems as $mi) {
    if (($mi->query['view'] ?? '') === 'topics') {
        $topicsItemId = $mi->id;
        break;
    }
}

$url = Route::_('index.php?option=com_example&view=articles&topic_id=' . $id . '&Itemid=' . $topicsItemId);
```

### What happens without Itemid

| With Itemid | Without Itemid |
|---|---|
| `/stageit/topics-list/topic-alias` | `/component/cslearning/articles/topic-alias` |
| Correct template applied | Default template applied |
| Menu item highlighted | No menu highlighting |

---

## RouterBase vs RouterView

### Use RouterBase when:
- Your views are simple lists (topics, articles, dashboard)
- Child views are filtered lists, not individual items (articles filtered by topic)
- You want full control over URL segments

### Avoid RouterView when:
- Your views don't have database-backed parent-child item relationships
- `setKey()` / `setParent()` would reference IDs that aren't in the URL
- **RouterView with incorrect key configuration causes fatal errors (HTTP 500/520)**

### RouterView pitfalls
- `setKey('id')` on a list view causes crashes — RouterView tries to look up items by ID during route building
- `setParent($topics, 'topic_id')` requires the parent view to have an item with that key — list views don't have individual items
- `StandardRules` with `RouterView` can produce unexpected slugs when it can't resolve the view hierarchy

---

## Common Routing Errors

### "Unable to detect manifest file" after adding router
**Cause**: Fatal PHP error in the router class crashes the entire component.
**Debug**: Check PHP error logs. Common causes:
- Wrong namespace in Router.php
- Missing `use` statements
- Constructor signature mismatch

### URLs show `/component/com_yourext/...`
**Cause**: No `Itemid` in the `Route::_()` call, so Joomla can't find a menu item.
**Fix**: Pass `Itemid` explicitly in templates (see above).

### All links resolve to the same slug
**Cause**: Router `build()` isn't consuming query vars with `unset()`.
**Fix**: Always `unset($query['view'])` and `unset($query['your_id'])` after converting them to segments.

### Wrong template/theme applied to component pages
**Cause**: Without a router, Joomla can't associate the URL with the menu item's template assignment.
**Fix**: Register a proper router AND pass Itemid in Route::_() calls.

### HTTP 520 / blank page after installing router
**Cause**: RouterView with `setKey()` on list views causes fatal errors.
**Fix**: Use `RouterBase` instead of `RouterView` for list-based views.

---

## Checklist for Component Routing

- [ ] Router class exists at `site/src/Service/Router.php`
- [ ] Router extends `RouterBase` (not `RouterView` unless you have item-level views)
- [ ] `RouterFactory` registered in `admin/services/provider.php`
- [ ] `RouterServiceInterface` + `RouterServiceTrait` on component class
- [ ] `setRouterFactory()` called in provider's component factory
- [ ] All `Route::_()` calls in templates include `&Itemid=`
- [ ] `build()` method `unset()`s all query vars it converts to segments
- [ ] `parse()` method sets `$segments = []` after consuming all segments
- [ ] Autoload cache cleared after install (`administrator/cache/autoload_psr4.php`)
