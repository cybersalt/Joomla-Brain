# Joomla 5+ Component Development Guide

A soup-to-nuts scaffold reference for building modern Joomla 5/6 components. This is the file to consult when starting a new component or adding a new view to an existing one. It covers manifest, service provider, extension class, MVC layers (controller / model / view / table), template files, form XML, dispatcher, install script, ACL, config.xml, filter forms, site views, and webservices wiring.

> **Scope:** Big-picture scaffolding. Several subsystems have deep-dive guides — this file points at them rather than re-deriving them:
> - **SEF routing** → [`JOOMLA5-COMPONENT-ROUTING.md`](JOOMLA5-COMPONENT-ROUTING.md)
> - **Webservices API endpoints** → [`JOOMLA5-WEB-SERVICES-API-GUIDE.md`](JOOMLA5-WEB-SERVICES-API-GUIDE.md)
> - **Custom form fields** → [`JOOMLA5-CUSTOM-FIELDS-GUIDE.md`](JOOMLA5-CUSTOM-FIELDS-GUIDE.md)
> - **Filter / list views** → [`JOOMLA5-LIST-FILTERS-GUIDE.md`](JOOMLA5-LIST-FILTERS-GUIDE.md)
> - **Toolbar API (modern pattern)** → [`JOOMLA6-CHECKLIST.md` § Toolbar API](JOOMLA6-CHECKLIST.md)
> - **Web Asset Manager** → [`JOOMLA5-WEB-ASSETS-GUIDE.md`](JOOMLA5-WEB-ASSETS-GUIDE.md)
> - **PHPDoc / coding standards** → [`JOOMLA-CODING-STANDARDS.md`](JOOMLA-CODING-STANDARDS.md)

> **Security framing throughout this guide:** every code sample has an ACL gate, every output gets escaped, every editor field carries `filter="JComponentHelper::filterText"`. If you copy a snippet and find a "missing" check, that's a bug — file an issue. The goal is "security review, zero HIGH/MEDIUM findings."

---

## 1. Component anatomy

```
com_example/
├── com_example.xml                     # Manifest (root)
├── example.script.php                  # Install/update script (referenced by <scriptfile>)
├── admin/
│   ├── access.xml                      # ACL action definitions
│   ├── config.xml                      # Component options (Options button)
│   ├── forms/
│   │   ├── item.xml                    # Form for the edit view
│   │   └── filter_items.xml            # Filter form for the list view (auto-discovered)
│   ├── language/en-GB/
│   │   ├── en-GB.com_example.ini       # Admin UI strings
│   │   └── en-GB.com_example.sys.ini   # Strings shown during install + in extensions list
│   ├── services/
│   │   └── provider.php                # DI registration
│   ├── sql/
│   │   ├── install.mysql.utf8.sql
│   │   ├── uninstall.mysql.utf8.sql
│   │   └── updates/mysql/              # Versioned update SQL
│   ├── src/
│   │   ├── Controller/                 # AdminController, FormController, BaseController subclasses
│   │   ├── Dispatcher/Dispatcher.php
│   │   ├── Extension/ExampleComponent.php
│   │   ├── Field/                      # Custom form fields
│   │   ├── Helper/                     # Helper classes
│   │   ├── Model/                      # AdminModel, ListModel subclasses
│   │   ├── Service/                    # HTML helpers, etc.
│   │   ├── Table/                      # Table subclasses
│   │   └── View/<View>/HtmlView.php
│   └── tmpl/<view>/                    # Admin templates (default.php, edit.php)
├── site/
│   ├── forms/                          # Frontend forms if needed
│   ├── language/en-GB/en-GB.com_example.ini
│   ├── layouts/                        # Reusable layouts (LayoutHelper)
│   ├── src/
│   │   ├── Controller/DisplayController.php
│   │   ├── Dispatcher/Dispatcher.php   # Optional — only if you need custom site dispatch
│   │   ├── Helper/
│   │   ├── Model/
│   │   ├── Service/Router.php          # SEF router
│   │   └── View/<View>/HtmlView.php
│   └── tmpl/<view>/                    # Site templates
├── api/
│   └── src/
│       ├── Controller/                 # ApiController subclasses
│       └── View/<View>/JsonapiView.php
├── media/
│   ├── joomla.asset.json
│   ├── css/
│   ├── js/
│   └── images/
└── LICENSE
```

The classic `admin/` ↔ `site/` ↔ `api/` split aligns with the three Joomla applications (Administrator, Site, API). The manifest's `<files folder="…">`, `<administration><files folder="admin">`, and `<api><files folder="api">` blocks tell the installer which sub-tree maps to which application.

---

## 2. Manifest XML (`com_example.xml`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="component" method="upgrade">
    <name>com_example</name>
    <author>Cybersalt</author>
    <authorEmail>support@cybersalt.com</authorEmail>
    <authorUrl>https://cybersalt.com</authorUrl>
    <copyright>(C) 2026 Cybersalt. All rights reserved.</copyright>
    <license>GNU General Public License version 2 or later; see LICENSE.txt</license>
    <version>1.0.0</version>
    <creationDate>2026-01-15</creationDate>
    <description>COM_EXAMPLE_XML_DESCRIPTION</description>
    <namespace path="src">Cybersalt\Component\Example</namespace>

    <scriptfile>example.script.php</scriptfile>

    <install>
        <sql>
            <file driver="mysql" charset="utf8">sql/install.mysql.utf8.sql</file>
        </sql>
    </install>

    <uninstall>
        <sql>
            <file driver="mysql" charset="utf8">sql/uninstall.mysql.utf8.sql</file>
        </sql>
    </uninstall>

    <update>
        <schemas>
            <schemapath type="mysql">sql/updates/mysql</schemapath>
        </schemas>
    </update>

    <files folder="site">
        <folder>forms</folder>
        <folder>language</folder>
        <folder>layouts</folder>
        <folder>src</folder>
        <folder>tmpl</folder>
    </files>

    <media destination="com_example" folder="media">
        <filename>joomla.asset.json</filename>
        <folder>css</folder>
        <folder>js</folder>
        <folder>images</folder>
    </media>

    <administration>
        <menu img="class:generic">COM_EXAMPLE</menu>
        <submenu>
            <menu link="option=com_example&amp;view=items"
                  view="items"
                  alt="Example/Items">
                COM_EXAMPLE_MENU_ITEMS
            </menu>
        </submenu>

        <files folder="admin">
            <filename>access.xml</filename>
            <filename>config.xml</filename>
            <folder>forms</folder>
            <folder>language</folder>
            <folder>services</folder>
            <folder>sql</folder>
            <folder>src</folder>
            <folder>tmpl</folder>
        </files>
    </administration>

    <api>
        <files folder="api">
            <folder>src</folder>
        </files>
    </api>

    <changelogurl>https://raw.githubusercontent.com/cybersalt/com_example/main/CHANGELOG.html</changelogurl>
    <updateservers>
        <server type="extension" priority="1" name="Example Updates">
            https://cybersalt.com/updates/com_example.xml
        </server>
    </updateservers>
</extension>
```

**Key rules:**

- **`<namespace path="src">`** — PSR-4 root. `path="src"` maps to *each* of the `admin/src/`, `site/src/`, `api/src/` directories; Joomla picks the right one based on the application that's running (`Administrator\…` namespace for admin, `Site\…` for site, `Api\…` for API).
- **`<scriptfile>`** — installer script lives at the package root, NOT under `admin/`.
- **`<administration>`** — every admin file/folder must be listed here, NOT in the top-level `<files>`.
- **`<api>`** — only needed if you ship REST endpoints. See [`JOOMLA5-WEB-SERVICES-API-GUIDE.md`](JOOMLA5-WEB-SERVICES-API-GUIDE.md).
- **Only the package manifest declares `<updateservers>`.** Component / module / plugin manifests inside a package extension MUST omit it — the package-level `<server>` is the single source of truth.

---

## 3. Service provider (`admin/services/provider.php`)

```php
<?php

\defined('_JEXEC') or die;

use Cybersalt\Component\Example\Administrator\Extension\ExampleComponent;
use Joomla\CMS\Component\Router\RouterFactoryInterface;
use Joomla\CMS\Dispatcher\ComponentDispatcherFactoryInterface;
use Joomla\CMS\Extension\ComponentInterface;
use Joomla\CMS\Extension\Service\Provider\CategoryFactory;
use Joomla\CMS\Extension\Service\Provider\ComponentDispatcherFactory;
use Joomla\CMS\Extension\Service\Provider\MVCFactory;
use Joomla\CMS\Extension\Service\Provider\RouterFactory;
use Joomla\CMS\HTML\Registry;
use Joomla\CMS\MVC\Factory\MVCFactoryInterface;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->registerServiceProvider(new CategoryFactory('\\Cybersalt\\Component\\Example'));
        $container->registerServiceProvider(new MVCFactory('\\Cybersalt\\Component\\Example'));
        $container->registerServiceProvider(new ComponentDispatcherFactory('\\Cybersalt\\Component\\Example'));
        $container->registerServiceProvider(new RouterFactory('\\Cybersalt\\Component\\Example'));

        $container->set(
            ComponentInterface::class,
            function (Container $container) {
                $component = new ExampleComponent(
                    $container->get(ComponentDispatcherFactoryInterface::class)
                );
                $component->setRegistry($container->get(Registry::class));
                $component->setMVCFactory($container->get(MVCFactoryInterface::class));
                $component->setRouterFactory($container->get(RouterFactoryInterface::class));

                return $component;
            }
        );
    }
};
```

**What each factory does:**

| Factory | Purpose | Skip if… |
|---|---|---|
| `CategoryFactory` | Registers the component with Joomla's category system | Component doesn't use `#__categories` |
| `MVCFactory` | Resolves controller/model/view/table classes from namespaces | Never skip |
| `ComponentDispatcherFactory` | Wires the dispatcher | Never skip |
| `RouterFactory` | Wires the SEF router | Component has no site frontend |

**Setter chain on the component object:** every `set*()` call corresponds to an `*AwareInterface` the component class implements. Don't add `setRegistry()` if you don't `use HTMLRegistryAwareTrait` on the extension class — calling a setter for a trait that isn't used is a no-op at best and a hard error at worst.

---

## 4. Extension class (`admin/src/Extension/ExampleComponent.php`)

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Extension;

\defined('_JEXEC') or die;

use Joomla\CMS\Categories\CategoryServiceInterface;
use Joomla\CMS\Categories\CategoryServiceTrait;
use Joomla\CMS\Component\Router\RouterServiceInterface;
use Joomla\CMS\Component\Router\RouterServiceTrait;
use Joomla\CMS\Extension\BootableExtensionInterface;
use Joomla\CMS\Extension\MVCComponent;
use Joomla\CMS\HTML\HTMLRegistryAwareTrait;
use Psr\Container\ContainerInterface;

class ExampleComponent extends MVCComponent implements
    BootableExtensionInterface,
    CategoryServiceInterface,
    RouterServiceInterface
{
    use HTMLRegistryAwareTrait;
    use CategoryServiceTrait;
    use RouterServiceTrait;

    public function boot(ContainerInterface $container): void
    {
        // Register HTMLHelper services, event listeners, etc.
        // Runs once, on first access to the component.
    }
}
```

**Trait/interface pairs you'll commonly see:**

- `RouterServiceInterface` + `RouterServiceTrait` → component publishes a SEF router
- `CategoryServiceInterface` + `CategoryServiceTrait` → component uses `#__categories`
- `AssociationServiceInterface` + `AssociationServiceTrait` → component supports multilingual associations
- `WorkflowServiceInterface` + `WorkflowServiceTrait` → component participates in publishing workflows
- `TagServiceInterface` + `TagServiceTrait` → items can be tagged
- `HTMLRegistryAwareTrait` (no interface required) → component registers HTMLHelper services

Every interface you implement must have its setter wired in the service provider's component factory.

---

## 5. Controllers — pick the right base class

This is one of the most common security mistakes in Joomla components. The choice between `BaseController`, `FormController`, and `AdminController` determines which built-in security checks run on every request.

| Base class | Use for | Built-in security |
|---|---|---|
| `BaseController` | Display only (no state changes) | None — you supply checks |
| `FormController` | Edit a single record (CRUD) | Token check, ACL check on `add`/`edit`, dirty-data preserve on cancel |
| `AdminController` | Bulk operations on a list | Token check, ACL check, batch routing, ordering tasks |

**Rule:** if your controller modifies data, it should NOT extend `BaseController` directly. Either inherit from `FormController` (single item) or `AdminController` (list operations). A `BaseController` subclass that handles `task=save` will silently skip Joomla's built-in token check — that is a CSRF bug.

This is also covered with extra context in [`JOOMLA5-COMMON-GOTCHAS.md` § BaseController vs FormController](JOOMLA5-COMMON-GOTCHAS.md).

### 5.1 Display controller (default — read-only)

**File:** `admin/src/Controller/DisplayController.php`

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Controller;

\defined('_JEXEC') or die;

use Joomla\CMS\MVC\Controller\BaseController;

class DisplayController extends BaseController
{
    /**
     * @var  string
     * @since  1.0.0
     */
    protected $default_view = 'items';

    public function display($cachable = false, $urlparams = []): static
    {
        return parent::display($cachable, $urlparams);
    }
}
```

### 5.2 Form controller (single-item CRUD)

**File:** `admin/src/Controller/ItemController.php`

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Controller;

\defined('_JEXEC') or die;

use Joomla\CMS\MVC\Controller\FormController;

class ItemController extends FormController
{
    // FormController already implements: edit, save, apply, cancel.
    // Override only when you need different ACL behavior:

    protected function allowAdd($data = []): bool
    {
        return $this->app->getIdentity()
            ->authorise('core.create', 'com_example');
    }

    protected function allowEdit($data = [], $key = 'id'): bool
    {
        $id = (int) ($data[$key] ?? 0);

        return $this->app->getIdentity()
            ->authorise('core.edit', 'com_example.item.' . $id);
    }
}
```

### 5.3 Admin controller (list/bulk operations)

**File:** `admin/src/Controller/ItemsController.php`

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Controller;

\defined('_JEXEC') or die;

use Joomla\CMS\MVC\Controller\AdminController;

class ItemsController extends AdminController
{
    public function getModel(
        $name = 'Item',
        $prefix = 'Administrator',
        $config = ['ignore_request' => true]
    ) {
        return parent::getModel($name, $prefix, $config);
    }
}
```

`AdminController` provides `publish`, `unpublish`, `archive`, `trash`, `delete`, `checkin`, `saveorder`, `reorder`, and the `batch` task automatically. You almost never need to override them — just provide the matching methods on the model.

---

## 6. Models — `AdminModel` for items, `ListModel` for lists

### 6.1 Form model (`admin/src/Model/ItemModel.php`)

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Model;

\defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Form\Form;
use Joomla\CMS\MVC\Model\AdminModel;
use Joomla\CMS\Table\Table;

class ItemModel extends AdminModel
{
    /**
     * @var  string
     * @since  1.0.0
     */
    public $typeAlias = 'com_example.item';

    public function getTable($name = 'Item', $prefix = 'Administrator', $options = []): Table
    {
        return parent::getTable($name, $prefix, $options);
    }

    public function getForm($data = [], $loadData = true): Form|false
    {
        $form = $this->loadForm(
            'com_example.item',
            'item',
            ['control' => 'jform', 'load_data' => $loadData]
        );

        return empty($form) ? false : $form;
    }

    protected function loadFormData(): mixed
    {
        $data = Factory::getApplication()
            ->getUserState('com_example.edit.item.data', []);

        if (empty($data)) {
            $data = $this->getItem();
        }

        return $data;
    }
}
```

The `$typeAlias` enables tags, history, and content type associations. Use `com_<component>.<itemtype>` form.

### 6.2 List model (`admin/src/Model/ItemsModel.php`)

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Model;

\defined('_JEXEC') or die;

use Joomla\CMS\MVC\Model\ListModel;
use Joomla\Database\ParameterType;
use Joomla\Database\QueryInterface;

class ItemsModel extends ListModel
{
    public function __construct($config = [])
    {
        if (empty($config['filter_fields'])) {
            $config['filter_fields'] = [
                'id',        'a.id',
                'title',     'a.title',
                'published', 'a.published',
                'ordering',  'a.ordering',
                'created',   'a.created',
            ];
        }

        parent::__construct($config);
    }

    protected function getListQuery(): QueryInterface
    {
        $db    = $this->getDatabase();
        $query = $db->createQuery();

        $query->select($db->quoteName([
            'a.id', 'a.title', 'a.alias', 'a.published',
            'a.ordering', 'a.created',
            'a.checked_out', 'a.checked_out_time',
        ]))
            ->from($db->quoteName('#__example_items', 'a'));

        // Filter: published state
        $published = $this->getState('filter.published');

        if (is_numeric($published)) {
            $query->where($db->quoteName('a.published') . ' = :published')
                ->bind(':published', $published, ParameterType::INTEGER);
        }

        // Filter: search (always parameterized — never concatenate)
        $search = $this->getState('filter.search');

        if (!empty($search)) {
            $search = '%' . trim($search) . '%';
            $query->where($db->quoteName('a.title') . ' LIKE :search')
                ->bind(':search', $search);
        }

        // Ordering — escape, but ALSO validate against filter_fields allowlist
        $orderCol  = $this->getState('list.ordering', 'a.id');
        $orderDirn = $this->getState('list.direction', 'DESC');
        $query->order($db->escape($orderCol) . ' ' . $db->escape($orderDirn));

        return $query;
    }

    protected function populateState($ordering = 'a.id', $direction = 'DESC'): void
    {
        parent::populateState($ordering, $direction);
    }

    /**
     * Cache key — INCLUDE every state value that affects the query.
     */
    protected function getStoreId($id = ''): string
    {
        $id .= ':' . $this->getState('filter.search');
        $id .= ':' . $this->getState('filter.published');

        return parent::getStoreId($id);
    }
}
```

> **`getStoreId()` cache trap:** `ListModel` caches results keyed by `getStoreId()`. If you add filters and forget to extend `getStoreId()`, the second filter request returns the first filter's cached result. See [`JOOMLA5-COMMON-GOTCHAS.md` § getStoreId in ListModel](JOOMLA5-COMMON-GOTCHAS.md).

> **ORDER BY allowlist:** the `filter_fields` array IS your ORDER BY allowlist. Joomla validates `list.ordering` against it before the query runs. If you skip declaring `filter_fields`, sorting works in dev but the column never matches in prod (silent failure).

---

## 7. Table class (`admin/src/Table/ItemTable.php`)

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Table;

\defined('_JEXEC') or die;

use Joomla\CMS\Table\Table;
use Joomla\Database\DatabaseDriver;

class ItemTable extends Table
{
    public function __construct(DatabaseDriver $db)
    {
        parent::__construct('#__example_items', 'id', $db);

        $this->setColumnAlias('published', 'published');
    }

    public function check(): bool
    {
        try {
            parent::check();
        } catch (\Exception $e) {
            $this->setError($e->getMessage());
            return false;
        }

        // Auto-generate alias from title
        if (empty($this->alias)) {
            $this->alias = $this->title;
        }

        $this->alias = $this->stringURLSafe($this->alias);

        return true;
    }
}
```

> **The `check()` exception pattern:** `parent::check()` may throw. Wrap it, store the error via `setError()`, and return `false` so `AdminModel::save()` can surface the error to the user. Letting the exception propagate produces a generic 500 page. See [`JOOMLA5-COMMON-GOTCHAS.md` § Table::check()](JOOMLA5-COMMON-GOTCHAS.md).

---

## 8. Views

### 8.1 Admin list view (`admin/src/View/Items/HtmlView.php`)

```php
<?php

namespace Cybersalt\Component\Example\Administrator\View\Items;

\defined('_JEXEC') or die;

use Joomla\CMS\Form\Form;
use Joomla\CMS\Helper\ContentHelper;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;
use Joomla\CMS\Pagination\Pagination;
use Joomla\CMS\Toolbar\Button\DropdownButton;

class HtmlView extends BaseHtmlView
{
    protected array $items            = [];
    protected ?Pagination $pagination = null;
    public ?Form $filterForm          = null;
    public array $activeFilters       = [];

    public function display($tpl = null): void
    {
        // Joomla 5+: call model methods directly. The deprecated $this->get('Items')
        // proxy still works but adds a deprecation notice.
        /** @var \Cybersalt\Component\Example\Administrator\Model\ItemsModel $model */
        $model = $this->getModel();

        $this->items         = $model->getItems();
        $this->pagination    = $model->getPagination();
        $this->filterForm    = $model->getFilterForm();
        $this->activeFilters = $model->getActiveFilters();

        $this->addToolbar();

        parent::display($tpl);
    }

    /**
     * Modern toolbar — see JOOMLA6-CHECKLIST.md § Toolbar API for the full pattern.
     * NOTE: `ToolbarHelper::*` static calls still work but are deprecated direction.
     */
    protected function addToolbar(): void
    {
        $canDo   = ContentHelper::getActions('com_example');
        $toolbar = $this->getDocument()->getToolbar('toolbar');

        $toolbar->title(Text::_('COM_EXAMPLE_ITEMS'), 'list');

        if ($canDo->get('core.create')) {
            $toolbar->addNew('item.add');
        }

        if ($canDo->get('core.edit.state')) {
            /** @var DropdownButton $dropdown */
            $dropdown = $toolbar->dropdownButton('status-group', 'JTOOLBAR_CHANGE_STATUS')
                ->toggleSplit(false)
                ->icon('icon-ellipsis-h')
                ->buttonClass('btn btn-action')
                ->listCheck(true);

            $childBar = $dropdown->getChildToolbar();
            $childBar->publish('items.publish')->listCheck(true);
            $childBar->unpublish('items.unpublish')->listCheck(true);
            $childBar->archive('items.archive')->listCheck(true);
            $childBar->trash('items.trash')->listCheck(true);
        }

        if ($canDo->get('core.delete')) {
            $toolbar->delete('items.delete', 'JTOOLBAR_EMPTY_TRASH')
                ->message('JGLOBAL_CONFIRM_DELETE')
                ->listCheck(true);
        }

        if ($canDo->get('core.admin')) {
            $toolbar->preferences('com_example');
        }
    }
}
```

### 8.2 Admin edit view (`admin/src/View/Item/HtmlView.php`)

```php
<?php

namespace Cybersalt\Component\Example\Administrator\View\Item;

\defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Form\Form;
use Joomla\CMS\Language\Text;
use Joomla\CMS\MVC\View\HtmlView as BaseHtmlView;

class HtmlView extends BaseHtmlView
{
    protected ?Form $form    = null;
    protected ?object $item  = null;

    public function display($tpl = null): void
    {
        /** @var \Cybersalt\Component\Example\Administrator\Model\ItemModel $model */
        $model      = $this->getModel();
        $this->form = $model->getForm();
        $this->item = $model->getItem();

        $this->addToolbar();

        parent::display($tpl);
    }

    protected function addToolbar(): void
    {
        Factory::getApplication()->getInput()->set('hidemainmenu', true);

        $isNew   = ($this->item->id == 0);
        $toolbar = $this->getDocument()->getToolbar('toolbar');

        $toolbar->title(
            Text::_($isNew ? 'COM_EXAMPLE_ITEM_NEW' : 'COM_EXAMPLE_ITEM_EDIT'),
            'pencil-alt'
        );

        $toolbar->apply('item.apply');

        $saveGroup = $toolbar->dropdownButton('save-group');
        $childBar  = $saveGroup->getChildToolbar();
        $childBar->save('item.save');
        $childBar->save2new('item.save2new');
        $childBar->save2copy('item.save2copy');

        $toolbar->cancel('item.cancel', $isNew ? 'JTOOLBAR_CANCEL' : 'JTOOLBAR_CLOSE');
    }
}
```

---

## 9. Templates

### 9.1 Admin list template (`admin/tmpl/items/default.php`)

```php
<?php

\defined('_JEXEC') or die;

use Joomla\CMS\HTML\HTMLHelper;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Layout\LayoutHelper;
use Joomla\CMS\Router\Route;

/** @var \Cybersalt\Component\Example\Administrator\View\Items\HtmlView $this */

// Joomla 5+: get state from the model. The deprecated $this->state property is
// still populated by BaseHtmlView::display() but raises a deprecation in J6.
$model     = $this->getModel();
$state     = $model->getState();
$listOrder = $this->escape($state->get('list.ordering'));
$listDirn  = $this->escape($state->get('list.direction'));
$user      = $this->getCurrentUser();
?>

<form action="<?php echo Route::_('index.php?option=com_example&view=items'); ?>"
      method="post" name="adminForm" id="adminForm">

    <?php echo LayoutHelper::render('joomla.searchtools.default', ['view' => $this]); ?>

    <?php if (empty($this->items)) : ?>
        <div class="alert alert-info">
            <span class="icon-info-circle" aria-hidden="true"></span>
            <?php echo Text::_('JGLOBAL_NO_MATCHING_RESULTS'); ?>
        </div>
    <?php else : ?>
        <table class="table" id="itemList">
            <caption class="visually-hidden">
                <?php echo Text::_('COM_EXAMPLE_ITEMS_TABLE_CAPTION'); ?>
            </caption>
            <thead>
                <tr>
                    <td class="w-1 text-center">
                        <?php echo HTMLHelper::_('grid.checkall'); ?>
                    </td>
                    <th scope="col" class="w-1 text-center">
                        <?php echo HTMLHelper::_('searchtools.sort', 'JSTATUS', 'a.published', $listDirn, $listOrder); ?>
                    </th>
                    <th scope="col">
                        <?php echo HTMLHelper::_('searchtools.sort', 'JGLOBAL_TITLE', 'a.title', $listDirn, $listOrder); ?>
                    </th>
                    <th scope="col" class="w-5 text-center">
                        <?php echo HTMLHelper::_('searchtools.sort', 'JGRID_HEADING_ID', 'a.id', $listDirn, $listOrder); ?>
                    </th>
                </tr>
            </thead>
            <tbody>
            <?php foreach ($this->items as $i => $item) :
                $canEdit      = $user->authorise('core.edit', 'com_example.item.' . $item->id);
                $canCheckin   = $user->authorise('core.manage', 'com_checkin')
                    || $item->checked_out == $user->id || empty($item->checked_out);
                $isCheckedOut = !empty($item->checked_out) && $item->checked_out != $user->id;
            ?>
                <tr class="row<?php echo $i % 2; ?>">
                    <td class="text-center">
                        <?php echo HTMLHelper::_('grid.id', $i, $item->id, false, 'cid', 'cb', $item->title); ?>
                    </td>
                    <td class="text-center">
                        <?php echo HTMLHelper::_('jgrid.published', $item->published, $i, 'items.', true); ?>
                    </td>
                    <td>
                        <?php if ($isCheckedOut) : ?>
                            <?php echo HTMLHelper::_('jgrid.checkedout', $i, $item->editor ?? '', $item->checked_out_time, 'items.', $canCheckin); ?>
                            <?php echo $this->escape($item->title); ?>
                        <?php elseif ($canEdit) : ?>
                            <a href="<?php echo Route::_('index.php?option=com_example&task=item.edit&id=' . (int) $item->id); ?>">
                                <?php echo $this->escape($item->title); ?>
                            </a>
                        <?php else : ?>
                            <?php echo $this->escape($item->title); ?>
                        <?php endif; ?>
                        <?php if (!empty($item->alias)) : ?>
                            <div class="small text-body-secondary"><?php echo $this->escape($item->alias); ?></div>
                        <?php endif; ?>
                    </td>
                    <td class="text-center">
                        <?php echo (int) $item->id; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>

        <?php echo $this->pagination->getListFooter(); ?>
    <?php endif; ?>

    <input type="hidden" name="task" value="">
    <input type="hidden" name="boxchecked" value="0">
    <?php echo HTMLHelper::_('form.token'); ?>
</form>
```

> **`task=` routing for edit links:** `task=item.edit&id=N` (NOT `view=item&layout=edit&id=N`). Routing through `task=` triggers `FormController::edit()`, which checks ACL, locks the row via `checkout()`, and redirects to the edit view. Linking directly to `view=item` skips all that. See [`JOOMLA5-COMMON-GOTCHAS.md` § List-to-edit routing](JOOMLA5-COMMON-GOTCHAS.md).

### 9.2 Admin edit template (`admin/tmpl/item/edit.php`)

```php
<?php

\defined('_JEXEC') or die;

use Joomla\CMS\HTML\HTMLHelper;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Layout\LayoutHelper;
use Joomla\CMS\Router\Route;

/** @var \Cybersalt\Component\Example\Administrator\View\Item\HtmlView $this */

// form.validate is REQUIRED for client-side form validation to fire on submit.
$wa = $this->getDocument()->getWebAssetManager();
$wa->useScript('keepalive')
   ->useScript('form.validate');
?>

<form action="<?php echo Route::_('index.php?option=com_example&layout=edit&id=' . (int) $this->item->id); ?>"
      method="post" name="adminForm" id="item-form" class="form-validate" enctype="multipart/form-data">

    <?php echo LayoutHelper::render('joomla.edit.title_alias', $this); ?>

    <div class="main-card">
        <?php echo HTMLHelper::_('uitab.startTabSet', 'myTab', ['active' => 'details', 'recall' => true]); ?>

        <?php echo HTMLHelper::_('uitab.addTab', 'myTab', 'details', Text::_('JDETAILS')); ?>
            <div class="row">
                <div class="col-lg-9">
                    <?php echo $this->form->renderField('description'); ?>
                </div>
                <div class="col-lg-3">
                    <?php echo LayoutHelper::render('joomla.edit.global', $this); ?>
                </div>
            </div>
        <?php echo HTMLHelper::_('uitab.endTab'); ?>

        <?php echo HTMLHelper::_('uitab.endTabSet'); ?>
    </div>

    <input type="hidden" name="task" value="">
    <?php echo HTMLHelper::_('form.token'); ?>
</form>
```

> **Don't forget `form.validate`:** without `$wa->useScript('form.validate')`, the `class="form-validate"` on the form is decorative — submission ignores client-side `required` / `type="email"` / pattern attributes. See [`JOOMLA5-COMMON-GOTCHAS.md` § form.validate](JOOMLA5-COMMON-GOTCHAS.md).

---

## 10. Form XML (`admin/forms/item.xml`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<form>
    <fieldset addfieldprefix="Cybersalt\Component\Example\Administrator\Field">
        <field
            name="id"
            type="hidden"
            default="0"
        />

        <field
            name="title"
            type="text"
            label="JGLOBAL_TITLE"
            required="true"
            maxlength="255"
            class="w-100"
        />

        <field
            name="alias"
            type="text"
            label="JFIELD_ALIAS_LABEL"
            description="JFIELD_ALIAS_DESC"
            maxlength="400"
            class="w-100"
        />

        <field
            name="description"
            type="editor"
            label="JGLOBAL_DESCRIPTION"
            filter="JComponentHelper::filterText"
            buttons="true"
        />

        <field
            name="published"
            type="list"
            label="JSTATUS"
            default="1"
        >
            <option value="1">JPUBLISHED</option>
            <option value="0">JUNPUBLISHED</option>
            <option value="2">JARCHIVED</option>
            <option value="-2">JTRASHED</option>
        </field>

        <field
            name="access"
            type="accesslevel"
            label="JFIELD_ACCESS_LABEL"
            default="1"
        />

        <field
            name="ordering"
            type="ordering"
            label="JFIELD_ORDERING_LABEL"
        />
    </fieldset>
</form>
```

> **`filter="JComponentHelper::filterText"` is the #1 XSS preventer for editor fields.** It runs the input through Joomla's configurable text filter (admin-configurable per-group), stripping `<script>`, dangerous attributes, etc. Without it, the editor accepts arbitrary HTML — including JS payloads from any user with access to the form.
>
> Numeric IDs use `filter="int"`. Text fields without HTML use `filter="cmd"` (alphanumerics + `_`/`.`). See [`JOOMLA5-EDITOR-API-GUIDE.md` § Editor form fields](JOOMLA5-EDITOR-API-GUIDE.md) for the full filter list.

`addfieldprefix` on the `<fieldset>` tells Joomla where to find custom field classes (so `type="customlist"` resolves to `Cybersalt\Component\Example\Administrator\Field\CustomlistField`). See [`JOOMLA5-CUSTOM-FIELDS-GUIDE.md`](JOOMLA5-CUSTOM-FIELDS-GUIDE.md).

### Conditional fields (`showon`)

```xml
<field
    name="enable_email"
    type="radio"
    class="btn-group"
    default="0"
>
    <option value="0">JNO</option>
    <option value="1">JYES</option>
</field>

<field
    name="email_address"
    type="email"
    label="COM_EXAMPLE_EMAIL"
    showon="enable_email:1"
/>
```

Multiple values: `showon="published:1,2"`. Multiple fields: `showon="published:1[AND]featured:1"`. Negation: `showon="published!:0"`.

### Subform fields (repeatable groups)

```xml
<field
    name="contacts"
    type="subform"
    layout="joomla.form.field.subform.repeatable-table"
    multiple="true"
    label="COM_EXAMPLE_CONTACTS"
>
    <form>
        <field name="name" type="text" label="JGLOBAL_TITLE" />
        <field name="email" type="email" label="COM_EXAMPLE_EMAIL" />
    </form>
</field>
```

---

## 11. SEF Router (`site/src/Service/Router.php`)

The SEF router is its own deep topic — see **[`JOOMLA5-COMPONENT-ROUTING.md`](JOOMLA5-COMPONENT-ROUTING.md)**, which covers:

- `RouterBase` vs `RouterView` choice (and when each crashes)
- 3-part registration (Router class + RouterFactory + setRouterFactory)
- The `Itemid` pass-through requirement in templates
- `RouterView` callback naming (`getXxxSegment` / `getXxxId`)
- Hidden menu items for SEF routing of login-gated views
- `MenuRules` → `StandardRules` → `NomenuRules` order

For the simple component scaffold case, the routing guide's "Quick Start: RouterBase Implementation" section is the place to go.

---

## 12. Dispatcher (`admin/src/Dispatcher/Dispatcher.php`)

Most components don't need a custom dispatcher — Joomla's `ComponentDispatcher` does the right thing. Define your own only when you need:

- A component-wide ACL gate (every request must be authorised before any controller fires)
- Custom request preprocessing
- Header injection or response transformation

```php
<?php

namespace Cybersalt\Component\Example\Administrator\Dispatcher;

\defined('_JEXEC') or die;

use Joomla\CMS\Dispatcher\ComponentDispatcher;
use Joomla\CMS\Language\Text;

class Dispatcher extends ComponentDispatcher
{
    /**
     * @var  string
     * @since  1.0.0
     */
    protected $defaultController = 'display';

    protected function checkAccess(): void
    {
        $user = $this->app->getIdentity();

        if (!$user->authorise('core.manage', 'com_example')) {
            throw new \RuntimeException(Text::_('JERROR_ALERTNOAUTHOR'), 403);
        }
    }
}
```

`checkAccess()` runs before any controller. Throwing here gives a single chokepoint instead of having to repeat the check in every controller method.

---

## 13. Install/update script (`example.script.php`)

```php
<?php

\defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Installer\InstallerAdapter;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Log\Log;

class Com_ExampleInstallerScript
{
    protected string $minimumPhp    = '8.2.0';
    protected string $minimumJoomla = '5.0.0';

    /**
     * Runs BEFORE install/update. Return false to abort.
     */
    public function preflight(string $type, InstallerAdapter $adapter): bool
    {
        if (version_compare(PHP_VERSION, $this->minimumPhp, '<')) {
            Log::add(
                Text::sprintf('COM_EXAMPLE_ERROR_PHP_VERSION', $this->minimumPhp, PHP_VERSION),
                Log::ERROR,
                'jerror'
            );
            return false;
        }

        return true;
    }

    public function install(InstallerAdapter $adapter): bool { return true; }

    public function update(InstallerAdapter $adapter): bool { return true; }

    /**
     * Runs AFTER install/update. $type is 'install', 'update', or 'discover_install'.
     */
    public function postflight(string $type, InstallerAdapter $adapter): void
    {
        $this->showPostInstallMessage($type);

        if ($type === 'update') {
            $this->migrateData();
        }
    }

    public function uninstall(InstallerAdapter $adapter): bool { return true; }

    private function migrateData(): void
    {
        // DML migrations that don't fit the SQL update files (e.g., conditional logic
        // that depends on existing data).
    }

    /**
     * Show a clickable link to the component on the install success page.
     * REQUIRED for all Cybersalt extensions — see joomla-development skill.
     */
    private function showPostInstallMessage(string $type): void
    {
        $messageKey = $type === 'update'
            ? 'COM_EXAMPLE_POSTINSTALL_UPDATED'
            : 'COM_EXAMPLE_POSTINSTALL_INSTALLED';

        echo '<div class="card mb-3" style="margin: 20px 0;">'
            . '<div class="card-body">'
            . '<h3 class="card-title">' . Text::_('COM_EXAMPLE') . '</h3>'
            . '<p class="card-text">' . Text::_($messageKey) . '</p>'
            . '<a href="index.php?option=com_example" class="btn btn-primary text-white">'
            . Text::_('COM_EXAMPLE_POSTINSTALL_OPEN')
            . '</a></div></div>';
    }
}
```

The post-install link is a Cybersalt house standard. Strings must live in `.sys.ini` (loaded during install, before regular `.ini` files are available).

---

## 14. Component options (`admin/config.xml`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<config>
    <fieldset name="component"
              label="COM_EXAMPLE_CONFIG_GENERAL"
              description="COM_EXAMPLE_CONFIG_GENERAL_DESC">

        <field
            name="items_per_page"
            type="number"
            label="COM_EXAMPLE_CONFIG_ITEMS_PER_PAGE"
            default="20"
            min="5"
            max="100"
        />

        <field
            name="show_author"
            type="radio"
            class="btn-group"
            label="COM_EXAMPLE_CONFIG_SHOW_AUTHOR"
            default="1"
        >
            <option value="0">JNO</option>
            <option value="1">JYES</option>
        </field>
    </fieldset>

    <fieldset name="permissions"
              label="JCONFIG_PERMISSIONS_LABEL"
              description="JCONFIG_PERMISSIONS_DESC">
        <field
            name="rules"
            type="rules"
            label="JCONFIG_PERMISSIONS_LABEL"
            filter="rules"
            component="com_example"
            section="component"
        />
    </fieldset>
</config>
```

The `permissions` fieldset with `type="rules"` makes the component's `access.xml` actions editable in **Options → Permissions**. Without it, ACL is set globally only via the **Users → Permissions** page.

Read in code:
```php
use Joomla\CMS\Component\ComponentHelper;

$params  = ComponentHelper::getParams('com_example');
$perPage = (int) $params->get('items_per_page', 20);
```

---

## 15. Filter form (`admin/forms/filter_items.xml`)

The filter form is auto-discovered by Joomla when its filename matches `filter_<view>.xml`. See [`JOOMLA5-LIST-FILTERS-GUIDE.md`](JOOMLA5-LIST-FILTERS-GUIDE.md) for the complete pattern (Choices.js on every select, sortable headers, clickable count cards). Minimal example:

```xml
<?xml version="1.0" encoding="utf-8"?>
<form>
    <fields name="filter">
        <field
            name="search"
            type="text"
            inputmode="search"
            label="COM_EXAMPLE_FILTER_SEARCH_LABEL"
            description="COM_EXAMPLE_FILTER_SEARCH_DESC"
            hint="JSEARCH_FILTER"
        />

        <field
            name="published"
            type="status"
            label="JOPTION_SELECT_PUBLISHED"
            onchange="this.form.submit();"
        >
            <option value="">JOPTION_SELECT_PUBLISHED</option>
        </field>
    </fields>

    <fields name="list">
        <field
            name="fullordering"
            type="list"
            label="JGLOBAL_SORT_BY"
            default="a.id DESC"
            onchange="this.form.submit();"
        >
            <option value="">JGLOBAL_SORT_BY</option>
            <option value="a.title ASC">JGLOBAL_TITLE_ASC</option>
            <option value="a.title DESC">JGLOBAL_TITLE_DESC</option>
            <option value="a.id ASC">JGRID_HEADING_ID_ASC</option>
            <option value="a.id DESC">JGRID_HEADING_ID_DESC</option>
        </field>

        <field
            name="limit"
            type="limitbox"
            label="JGLOBAL_LIST_LIMIT"
            default="25"
            onchange="this.form.submit();"
        />
    </fields>
</form>
```

---

## 16. Site views

The site application lives under `site/`. Structure mirrors admin but namespace switches to `…\Site\…`.

### Site display controller

```php
<?php

namespace Cybersalt\Component\Example\Site\Controller;

\defined('_JEXEC') or die;

use Joomla\CMS\MVC\Controller\BaseController;

class DisplayController extends BaseController
{
    protected $default_view = 'items';

    public function display($cachable = false, $urlparams = []): static
    {
        // Site-side responses are cacheable. Declare the URL params that
        // affect output so Joomla's page cache keys them correctly.
        $cachable  = true;
        $urlparams = [
            'id'     => 'INT',
            'catid'  => 'INT',
            'limit'  => 'UINT',
            'format' => 'WORD',
        ];

        return parent::display($cachable, $urlparams);
    }
}
```

### Site list model — apply user access levels

```php
protected function getListQuery(): QueryInterface
{
    $db    = $this->getDatabase();
    $query = $db->createQuery();
    $user  = Factory::getApplication()->getIdentity();

    $query->select($db->quoteName(['a.id', 'a.title', 'a.alias', 'a.description', 'a.access']))
        ->from($db->quoteName('#__example_items', 'a'))
        ->where($db->quoteName('a.published') . ' = 1')
        ->whereIn($db->quoteName('a.access'), $user->getAuthorisedViewLevels());

    return $query;
}
```

`whereIn()` against `getAuthorisedViewLevels()` is the canonical way to honour Joomla's view-level ACL on the site side. Skipping this leaks Registered/Special-only items to guests.

### Site detail view — `prepareDocument()` for SEO + breadcrumbs

```php
protected function prepareDocument(): void
{
    $app     = Factory::getApplication();
    $pathway = $app->getPathway();

    $title = $this->item->title;
    if ($app->get('sitename_pagetitles', 0) == 1) {
        $title = $app->get('sitename') . ' - ' . $title;
    }
    $this->getDocument()->setTitle($title);

    if (!empty($this->item->metadesc)) {
        $this->getDocument()->setDescription($this->item->metadesc);
    }

    $pathway->addItem($this->item->title);
}
```

### Detail-view access enforcement

```php
$user = Factory::getApplication()->getIdentity();

if (!\in_array((int) $this->item->access, $user->getAuthorisedViewLevels(), true)) {
    throw new \RuntimeException(Text::_('JERROR_ALERTNOAUTHOR'), 403);
}
```

Use `\in_array(..., ..., true)` (strict mode). Loose comparison can let `0 == "abc"` slip through.

---

## 17. Access control (`admin/access.xml`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<access component="com_example">
    <section name="component">
        <action name="core.admin"      title="JACTION_ADMIN" />
        <action name="core.options"    title="JACTION_OPTIONS" />
        <action name="core.manage"     title="JACTION_MANAGE" />
        <action name="core.create"     title="JACTION_CREATE" />
        <action name="core.delete"     title="JACTION_DELETE" />
        <action name="core.edit"       title="JACTION_EDIT" />
        <action name="core.edit.state" title="JACTION_EDITSTATE" />
        <action name="core.edit.own"   title="JACTION_EDITOWN" />
    </section>

    <section name="item">
        <action name="core.delete"     title="JACTION_DELETE" />
        <action name="core.edit"       title="JACTION_EDIT" />
        <action name="core.edit.state" title="JACTION_EDITSTATE" />
        <action name="core.edit.own"   title="JACTION_EDITOWN" />
    </section>
</access>
```

The `component` section is global (applies across the whole component). Per-item sections (`item`, etc.) let you set ACL on individual records — `$user->authorise('core.edit', 'com_example.item.' . $itemId)`.

**Custom actions:** add your own `<action name="example.publish.featured" title="…" />` if your component has operations that don't fit the core set. Reference them with `$user->authorise('example.publish.featured', 'com_example')`.

> **A valid Joomla API token does NOT authorise any specific component on its own.** API requests still go through the same `authorise()` checks. Every API controller method must gate. See [`JOOMLA5-WEB-SERVICES-API-GUIDE.md` § Permission gate](JOOMLA5-WEB-SERVICES-API-GUIDE.md).

---

## 18. Webservices API (REST endpoints)

A component publishes REST endpoints by combining:

1. A `plg_webservices_<name>` plugin that calls `$router->createCRUDRoutes(...)` on `onBeforeApiRoute`
2. API controllers under `api/src/Controller/`
3. JSON:API views under `api/src/View/<View>/JsonapiView.php`

**Three-part registration is non-negotiable** — without the plugin, the routes don't exist. See [`JOOMLA5-WEB-SERVICES-API-GUIDE.md`](JOOMLA5-WEB-SERVICES-API-GUIDE.md) for the full implementation including:

- Authentication via `X-Joomla-Token` (NOT `Authorization: Bearer`)
- The `:id` capture quirk on POST routes
- Per-method ACL gating
- JSON:API view configuration (`$fieldsToRenderItem`, `$fieldsToRenderList`)

Quick reference for the endpoints `createCRUDRoutes('v1/example/items', 'items', ['component' => 'com_example'])` produces:

| Method | URL | Controller method |
|---|---|---|
| GET | `/api/index.php/v1/example/items` | `displayList()` |
| GET | `/api/index.php/v1/example/items/{id}` | `displayItem()` |
| POST | `/api/index.php/v1/example/items` | `add()` |
| PATCH | `/api/index.php/v1/example/items/{id}` | `edit()` |
| DELETE | `/api/index.php/v1/example/items/{id}` | `delete()` |

---

## 19. Workflow: adding a new entity

When adding a new "thing" (e.g., a `category` view alongside an existing `item` view), the touch-list is:

1. **SQL** — `admin/sql/install.mysql.utf8.sql` adds the table; `admin/sql/updates/mysql/<version>.sql` adds it for upgraders.
2. **Table class** — `admin/src/Table/<Name>Table.php`.
3. **Form model + list model** — `admin/src/Model/<Name>Model.php` (single) and `<Names>Model.php` (list).
4. **Controllers** — `<Name>Controller.php` (extends `FormController`) and `<Names>Controller.php` (extends `AdminController`).
5. **Views** — `admin/src/View/<Names>/HtmlView.php` (list) and `<Name>/HtmlView.php` (edit).
6. **Templates** — `admin/tmpl/<names>/default.php` and `<name>/edit.php`.
7. **Form XML** — `admin/forms/<name>.xml` and `filter_<names>.xml`.
8. **ACL** — add a `<section name="<name>">` to `access.xml` if items have per-record permissions.
9. **Submenu** — add a `<menu>` entry to the manifest's `<submenu>`.
10. **Site router** — add a `RouterViewConfiguration` entry if the new view should resolve to SEF URLs.
11. **Language strings** — add `COM_EXAMPLE_<NAME>_*` keys to `en-GB.com_example.ini`.
12. **API** — if exposed, add an API controller, a JSON:API view, and a `createCRUDRoutes()` line in the webservices plugin.
13. **Tests** — add a model test and a table test; see [`JOOMLA5-TESTING-GUIDE.md`](JOOMLA5-TESTING-GUIDE.md).

Skipping any of these produces predictable failure modes — the [`JOOMLA5-COMMON-GOTCHAS.md`](JOOMLA5-COMMON-GOTCHAS.md) catalog correlates each missing piece with its symptom.

---

## 20. Pre-release checklist for a new component

- [ ] Manifest `<namespace>` matches `admin/services/provider.php` factory args
- [ ] Service provider registers `MVCFactory` + `ComponentDispatcherFactory` (always) and `RouterFactory` + `CategoryFactory` (if used)
- [ ] Extension class implements every interface whose setter is called in the provider
- [ ] Every controller that mutates data extends `FormController` or `AdminController`, NOT `BaseController`
- [ ] Every controller method that mutates data has a `Session::checkToken()` and `$user->authorise(...)` gate
- [ ] Every list model declares `filter_fields` (the ORDER BY allowlist)
- [ ] `getStoreId()` extended to include every state value used in `getListQuery()`
- [ ] Editor fields carry `filter="JComponentHelper::filterText"`
- [ ] Site list queries call `whereIn('access', $user->getAuthorisedViewLevels())`
- [ ] Templates escape every output (`$this->escape(...)` or `htmlspecialchars(...)`)
- [ ] `form.validate` web asset loaded on edit views
- [ ] List-to-edit links use `task=item.edit&id=N` (not `view=item&layout=edit`)
- [ ] `access.xml` exists and ships with the manifest's `<administration><files>` block
- [ ] Install script (`<scriptfile>`) checks PHP + Joomla minimums in `preflight()`
- [ ] Post-install message renders a Bootstrap card with a clickable link to the component
- [ ] All user-facing strings live in `.ini`; install-time strings live in `.sys.ini`
- [ ] `joomla.asset.json` declared in manifest's `<media>` block
- [ ] `package_*.zip` built with 7-Zip, not PowerShell `Compress-Archive`
- [ ] `security-review` skill run on the working tree → zero HIGH/MEDIUM findings

---

## Related guides

- [`JOOMLA5-COMPONENT-ROUTING.md`](JOOMLA5-COMPONENT-ROUTING.md) — SEF router (the topic that bites everyone)
- [`JOOMLA5-WEB-SERVICES-API-GUIDE.md`](JOOMLA5-WEB-SERVICES-API-GUIDE.md) — REST API endpoints
- [`JOOMLA5-CUSTOM-FIELDS-GUIDE.md`](JOOMLA5-CUSTOM-FIELDS-GUIDE.md) — custom form fields
- [`JOOMLA5-LIST-FILTERS-GUIDE.md`](JOOMLA5-LIST-FILTERS-GUIDE.md) — admin list views, filter bar, count cards
- [`JOOMLA5-WEB-ASSETS-GUIDE.md`](JOOMLA5-WEB-ASSETS-GUIDE.md) — `joomla.asset.json`, WAM, inline assets
- [`JOOMLA5-EDITOR-API-GUIDE.md`](JOOMLA5-EDITOR-API-GUIDE.md) — editor JS API, XTD button plugins, editor form fields
- [`JOOMLA5-TESTING-GUIDE.md`](JOOMLA5-TESTING-GUIDE.md) — PHPUnit + Jest patterns for components
- [`JOOMLA5-COMMON-GOTCHAS.md`](JOOMLA5-COMMON-GOTCHAS.md) — 17 traps that bite real builds
- [`JOOMLA-CODING-STANDARDS.md`](JOOMLA-CODING-STANDARDS.md) — PHPDoc, ESLint, PHP_CodeSniffer
- [`JOOMLA6-CHECKLIST.md`](JOOMLA6-CHECKLIST.md) — J5 → J6 deprecation matrix + modern Toolbar API
- [`NEW-EXTENSION-CHECKLIST.md`](NEW-EXTENSION-CHECKLIST.md) — repo setup, `.gitignore`, submodule, security baseline
