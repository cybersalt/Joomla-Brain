# Joomla 5 Web Services API — Building Extension Endpoints

Reference for shipping a JSON:API-compatible REST endpoint inside a Joomla 5+ component. Most lessons here came out of the cs-template-integrity build (April 2026); they apply to any component that wants its own `/v1/<component>/...` routes.

---

## Authentication: use `X-Joomla-Token`, NOT `Authorization: Bearer`

This is the single most-broken-on-first-try part of Joomla's Web Services API. The token form everyone reaches for first does not work.

```
✅ X-Joomla-Token: <token>
   Accept: application/vnd.api+json

❌ Authorization: Bearer <token>     ← returns 401 Forbidden
```

`Authorization: Bearer …` looks correct, matches every other REST API on the planet, and is wrong. Joomla's API auth plugin only reads `X-Joomla-Token`. If you write any HTTP client (PHP, JS, curl, Postman collection) that calls a Joomla API, hard-code the `X-Joomla-Token` header.

The token comes from **System → Users → My Profile → Joomla API Token** — click the eye icon to reveal it. Generated on first visit; can be regenerated.

---

## Routes don't exist until a `plg_webservices_*` plugin registers them

A component with `api/src/Controller/*Controller.php` + `api/src/View/*/JsonapiView.php` + `api/src/Model/*Model.php` is **not enough**. Hitting `/api/index.php/v1/<component>/<view>` returns `404 Resource not found` — silently. The component is loaded, the controller exists, and Joomla still can't reach it.

**You also need a Web Services plugin** whose only job is to subscribe to `onBeforeApiRoute` and call `$router->createCRUDRoutes()` for every URL the component handles.

```php
// plg_webservices_yourcomponent/src/Extension/Yourcomponent.php
<?php
declare(strict_types=1);

namespace YourVendor\Plugin\WebServices\Yourcomponent\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Event\Application\BeforeApiRouteEvent;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;
use Joomla\Router\Route;

final class Yourcomponent extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return ['onBeforeApiRoute' => 'onBeforeApiRoute'];
    }

    public function onBeforeApiRoute(BeforeApiRouteEvent $event): void
    {
        $router   = $event->getRouter();
        $defaults = ['component' => 'com_yourcomponent'];

        // Standard CRUD routes: GET list, GET item, POST, PATCH, DELETE
        $router->createCRUDRoutes('v1/yourcomponent/things', 'things', $defaults);

        // Custom non-CRUD routes (action methods on the controller)
        $router->addRoutes([
            new Route(
                ['POST'],
                'v1/yourcomponent/things/:id/do-thing',
                'things.doThing',
                ['id' => '(\d+)'],
                $defaults
            ),
        ]);
    }
}
```

Every Joomla core component that has API routes (`com_content`, `com_banners`, `com_templates`, …) ships with a corresponding `plg_webservices_*`. Yours has to ship one too.

### Plugin must be enabled after install

**Joomla installs third-party plugins disabled by default.** Until an admin opens **System → Plugins** and toggles `Web Services - <yourcomponent>` to enabled, the routes 404 silently. The package script can auto-enable it:

```php
// pkg_yourcomponent/script.php
public function postflight(string $type, InstallerAdapter $adapter): bool
{
    if ($type === 'install' || $type === 'update') {
        $db = Factory::getContainer()->get(DatabaseInterface::class);
        $db->setQuery(
            $db->getQuery(true)
                ->update('#__extensions')
                ->set('enabled = 1')
                ->where('type = ' . $db->quote('plugin'))
                ->where('folder = ' . $db->quote('webservices'))
                ->where('element = ' . $db->quote('yourcomponent'))
        )->execute();
    }
    return true;
}
```

---

## POST endpoints don't get `:id` from `$this->input`

Joomla's API dispatcher populates `$this->input` from URL captures **for GET routes**. For POST/PATCH/DELETE, the `:id` capture is passed as a method argument instead — and even that doesn't always work. In practice, accept `:id` from three sources and pick the first that's non-zero:

```php
public function doThing($id = null): void
{
    $id = $this->resolveIdFromRequest($id, '#/things/(\d+)/#');
    if ($id <= 0) {
        $this->sendJsonApiError(400, 'INVALID_ID', 'Numeric id required.');
        return;
    }
    // ...
}

private function resolveIdFromRequest($argId, string $regex): int
{
    if ($argId !== null && (int) $argId > 0) {
        return (int) $argId;
    }
    if (($fromInput = $this->input->getInt('id', 0)) > 0) {
        return $fromInput;
    }
    $path = (string) $this->input->server->get('REQUEST_URI', '', 'string');
    if ($path !== '' && preg_match($regex, $path, $m)) {
        return (int) $m[1];
    }
    return 0;
}
```

If you don't include the regex fallback, your POST endpoints will reject every request with a `:id` URL capture even when the id is clearly in the URL. Forget this and lose an afternoon.

---

## Permission gate: check at the top of every controller method

A valid Joomla API token authenticates the *user*; it does not authorise them for any specific component. Without an explicit ACL check, **any token that can hit Joomla's API can read/write your endpoints** — production sites typically have multiple staff API tokens floating around, plus any extension that ever asked the user to generate one. v0.8 of cs-template-integrity shipped with no permission gate; the v0.9 security review classified that as an authenticated arbitrary-write-under-webroot primitive.

**Ship `admin/access.xml` with your component**, declare two custom actions, and gate every endpoint:

```xml
<!-- admin/access.xml -->
<?xml version="1.0" encoding="utf-8"?>
<access component="com_yourcomponent">
    <section name="component">
        <action name="core.admin"   title="JACTION_ADMIN"   description="JACTION_ADMIN_COMPONENT_DESC" />
        <action name="core.manage"  title="JACTION_MANAGE"  description="JACTION_MANAGE_COMPONENT_DESC" />
        <action name="core.options" title="JACTION_OPTIONS" description="JACTION_OPTIONS_COMPONENT_DESC" />

        <action name="yourcomponent.view"
                title="COM_YOURCOMPONENT_ACTION_VIEW_TITLE"
                description="COM_YOURCOMPONENT_ACTION_VIEW_DESC" />
        <action name="yourcomponent.write"
                title="COM_YOURCOMPONENT_ACTION_WRITE_TITLE"
                description="COM_YOURCOMPONENT_ACTION_WRITE_DESC" />
    </section>
</access>
```

Reference it in the manifest:

```xml
<files folder="admin">
    <filename>access.xml</filename>   <!-- THIS LINE -->
    <folder>language</folder>
    <folder>services</folder>
    <folder>sql</folder>
    <folder>src</folder>
    <folder>tmpl</folder>
</files>
```

A reusable `PermissionHelper` keeps the check at one line per method:

```php
final class PermissionHelper
{
    public const COMPONENT    = 'com_yourcomponent';
    public const ACTION_VIEW  = 'yourcomponent.view';
    public const ACTION_WRITE = 'yourcomponent.write';

    public static function requireView(): User
    {
        return self::requireAny([self::ACTION_VIEW, 'core.manage', 'core.admin']);
    }

    public static function requireWrite(): User
    {
        return self::requireAny([self::ACTION_WRITE, 'core.manage', 'core.admin']);
    }

    private static function requireAny(array $actions): User
    {
        $user = Factory::getApplication()->getIdentity();
        if ($user === null || $user->guest) {
            throw new \RuntimeException('AUTH_REQUIRED', 401);
        }
        foreach ($actions as $action) {
            if ($user->authorise($action, self::COMPONENT)) {
                return $user;
            }
        }
        throw new \RuntimeException('FORBIDDEN', 403);
    }
}
```

Then in every API controller method:

```php
public function displayList()
{
    if (!$this->authoriseOrFail([PermissionHelper::class, 'requireView'])) {
        return null;
    }
    return parent::displayList();
}

public function add(): void
{
    if (!$this->authoriseOrFail([PermissionHelper::class, 'requireWrite'])) {
        return;
    }
    // ...
}
```

Override `displayList()`, `displayItem()`, `add()`, `edit()`, **and any custom action methods** — `parent::displayList()` from `ApiController` does NOT itself check anything beyond the user being authenticated.

Super Users always pass. Regular admins must have the action explicitly granted in **System → Permissions → <YourComponent>**.

---

## Filenames that match Joomla's expectations

| Thing | Where | Filename pattern |
|---|---|---|
| Component manifest | `packages/com_X/` | `X.xml` (component element) |
| Plugin manifest | `packages/plg_group_X/` | `X.xml` (plugin element, NOT `plg_group_X.xml`) |
| Plugin extension class | `packages/plg_group_X/src/Extension/` | `X.php` (Pascal-case-ish, e.g. `Yourcomponent.php`) |
| Component extension class | `packages/com_X/admin/src/Extension/` | `XComponent.php` |
| Web Services routes plugin | `plg_webservices_X` | name in `<folder plugin="X">services</folder>` matches plugin element |
| Service providers | `services/provider.php` | always `provider.php` |

The `<folder plugin="X">` attribute in a plugin manifest sets the plugin element used by Joomla to find the manifest, the language file, and the extension class. If it doesn't match the actual filenames you'll get `Class not found` errors at install or first request.

---

## JsonapiView + ApiController + Model wiring

The minimum viable component-side files for a single `things` resource:

```
api/
├── src/
│   ├── Controller/ThingsController.php   # extends ApiController
│   ├── Model/ThingsModel.php             # extends ListModel for list, ItemModel for item
│   └── View/Things/JsonapiView.php       # extends BaseApiView
└── language/en-GB/com_yourcomponent.ini
```

```php
// api/src/Controller/ThingsController.php
final class ThingsController extends ApiController
{
    protected $contentType  = 'things';     // used by JsonapiView for "type"
    protected $default_view = 'things';
}

// api/src/View/Things/JsonapiView.php
final class JsonapiView extends BaseApiView
{
    protected $fieldsToRenderList = ['id', 'name', /* ... */];
    protected $fieldsToRenderItem = ['id', 'name', /* ... */];
}

// api/src/Model/ThingsModel.php  (list)
final class ThingsModel extends ListModel
{
    public function __construct($config = [])
    {
        $config['filter_fields'] ??= ['id', 'name'];
        parent::__construct($config);
    }
    protected function getListQuery() { /* ... */ }
}
```

For custom non-CRUD action methods on the controller (e.g. `applyFix($id)`), you don't need a corresponding view — just send your own JSON:API response from the controller:

```php
private function sendJsonApi(array $payload, int $status = 200): void
{
    $app = Factory::getApplication();
    $app->setHeader('status', (string) $status, true);
    $app->setHeader('Content-Type', 'application/vnd.api+json; charset=utf-8', true);
    $app->sendHeaders();
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $app->close();
}
```

---

## Reference: cs-template-integrity

Working implementation of all the patterns above:
- Component: [cs-template-integrity/packages/com_cstemplateintegrity/api/](https://github.com/cybersalt/cs-template-integrity)
- Web Services plugin: [cs-template-integrity/packages/plg_webservices_cstemplateintegrity/](https://github.com/cybersalt/cs-template-integrity)
- access.xml + PermissionHelper: same repo's `admin/access.xml` and `admin/src/Helper/PermissionHelper.php`

Akeeba's [joomla-mcp-php](https://github.com/nikosdion/joomla-mcp-php) ships HTTP-client collections (`http/*.http` files) for every core API route — the cleanest route-listing reference outside the Joomla source tree.
