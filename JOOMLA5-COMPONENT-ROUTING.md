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

## SEF Router Callback Naming (RouterView)

When using `RouterView` with view-based callbacks, the method names follow a **strict** convention derived from the view name. Get it wrong and Joomla silently skips your callback — producing broken URLs that fall back to numeric IDs or `/component/com_yourext/...`.

### The naming rule

```
get + ucfirst(viewName) + 'Segment'   → build (ID → alias)
get + ucfirst(viewName) + 'Id'        → parse (alias → ID)
```

Case must match **exactly**. Joomla looks up the method by literal string match.

```php
// View 'item' → these exact method names:
public function getItemSegment($id, $query): array        // Build: ID → alias
public function getItemId($segment, $query): int|false    // Parse: alias → ID

// View 'category' → these exact method names:
public function getCategorySegment($id, $query): array
public function getCategoryId($segment, $query): int|false
```

### What `getXxxSegment()` must return

An **associative array** mapping ID → alias:

```php
public function getItemSegment($id, $query): array
{
    $alias = $this->lookupAlias((int) $id);
    return [(int) $id => $alias ?: (string) $id];
}
```

Returning a flat array (`return [$alias];`) produces the wrong slug — Joomla expects the keyed form so it can round-trip the ID.

### What `getXxxId()` must return

An integer ID, or `false` when the alias can't be resolved:

```php
public function getItemId($segment, $query): int|false
{
    $id = $this->lookupId($segment);
    return $id ?: false;
}
```

If your aliases can collide across categories (two items both aliased `intro` under different parents), `getXxxId()` **must** scope the lookup using `$query` — typically by `category_id` or `parent_id` already in the query — or you'll resolve to the wrong record.

### Rule order matters

`RouterView` runs three rule classes in sequence. Register them in this order:

```php
$this->attachRule(new MenuRules($this));      // 1. Match against menu items first
$this->attachRule(new StandardRules($this));  // 2. Then per-view callbacks
$this->attachRule(new NomenuRules($this));    // 3. Fall back to ?option=… form
```

Wrong order = unexpected slugs or unresolved URLs.

### Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Method name case wrong (`getitemSegment`) | Callback silently skipped, URLs use numeric IDs | Match `get` + `ucfirst(view)` + `Segment`/`Id` exactly |
| `getXxxSegment()` returns flat array | Slug is wrong or duplicated | Return `[id => alias]` associative form |
| `getXxxId()` doesn't scope by parent | Ambiguous aliases resolve to wrong record | Filter the lookup query by `$query['category_id']` etc. |
| Rule order: `Standard` before `Menu` | Menu-item URLs don't match their menu paths | Order as `MenuRules` → `StandardRules` → `NomenuRules` |

---

## Hidden Menu Items for SEF Routing

`Route::_()` resolves URLs by walking the site menu via `SiteMenu::getItems()` — and **that method filters by the current user's access levels**. For components that gate views behind login, this creates a non-obvious trap:

> **If your routing menu items are `access=2` (Registered), guests can't resolve SEF URLs**, so `Route::_()` falls through to the non-SEF `?option=…&view=…` form on the wrong base path. The component's controller still enforces login — Public access on the *menu item* only affects URL resolution, not page access.

### The pattern

Create a **hidden menu type** during component install. The menu type isn't assigned to any module (so visitors never see it), but it gives `Route::_()` a published menu item per view to anchor against.

For each site view your component exposes:

- Menu item published (`published=1`)
- Access level `1` (Public) — even if the view itself requires login
- Linked to `index.php?option=com_yourext&view=<viewname>`
- Assigned to the hidden menu type (so it doesn't appear in any visible menu module)

### Why access=1 even for login-only views

Access on a menu item is checked **only when generating the URL** — not when serving the page. The component's controller is what enforces auth:

```php
public function execute($task)
{
    if (Factory::getApplication()->getIdentity()->guest) {
        Factory::getApplication()->enqueueMessage(Text::_('JLIB_RULES_NOT_ALLOWED'), 'error');
        $this->setRedirect(Route::_('index.php?option=com_users&view=login', false));
        return;
    }
    // ...
}
```

So: menu item is `access=1` (URL resolution works for everyone), controller redirects guests at request time (page is still gated). Both layers do their own job.

### Install-time creation

Create the hidden menu type and items via the `script.php` install postflight, or via a fresh-install SQL file (`admin/sql/install.mysql.utf8.sql`):

```sql
INSERT INTO `#__menu_types` (`menutype`, `title`, `description`)
VALUES ('com_yourext_hidden', 'YourExt Hidden Routing', 'Hidden — provides SEF URL anchors only');

INSERT INTO `#__menu` (`menutype`, `title`, `alias`, `path`, `link`, `type`, `published`, `parent_id`, `level`, `component_id`, `access`, `params`, `lft`, `rgt`, `language`, `client_id`)
VALUES
('com_yourext_hidden', 'Items', 'items', 'items', 'index.php?option=com_yourext&view=items', 'component', 1, 1, 1, (SELECT extension_id FROM #__extensions WHERE element='com_yourext'), 1, '{}', 0, 0, '*', 0),
('com_yourext_hidden', 'Item', 'item', 'item', 'index.php?option=com_yourext&view=item', 'component', 1, 1, 1, (SELECT extension_id FROM #__extensions WHERE element='com_yourext'), 1, '{}', 0, 0, '*', 0);
```

Then rebuild nested-set values via `Table\Menu::rebuild()` in postflight, or accept that admin → Menus → Rebuild does the same job on first admin visit.

### Symptom of getting this wrong

URLs like `/component/com_yourext/items` instead of `/items`, **specifically for not-logged-in users** while logged-in admins see the clean `/items` URL. Classic "works on my machine" — the developer is logged in as Super User (access to everything), the visitor is a guest (no access to the access=2 menu item).

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
- [ ] If using `RouterView`: callback method names match `getXxxSegment` / `getXxxId` exactly
- [ ] If using `RouterView`: rules attached in order `MenuRules` → `StandardRules` → `NomenuRules`
- [ ] Hidden menu type + per-view menu items created at install with `access=1`
- [ ] Login-gated views enforce auth in the controller, NOT via menu access level
- [ ] Autoload cache cleared after install (`administrator/cache/autoload_psr4.php`)
