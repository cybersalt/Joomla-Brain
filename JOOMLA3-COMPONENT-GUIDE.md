# Joomla 3 Component Development Guide

## Overview

Joomla 3 uses the legacy MVC pattern with `JModel*`, `JView*`, and `JController*` base classes. No namespaces or DI container - simpler but less organized.

---

## Component Structure

```
com_mycomponent/
├── mycomponent.xml              ← Manifest (at ZIP root)
├── script.php                   ← Install/update script (at ZIP root)
└── admin/                       ← All admin files in this folder
    ├── mycomponent.php          ← Entry point
    ├── controller.php           ← Main controller
    ├── controllers/
    │   └── forms.php            ← Sub-controller
    ├── models/
    │   └── forms.php            ← List model
    ├── views/
    │   └── forms/
    │       ├── view.html.php    ← View class
    │       └── tmpl/
    │           └── default.php  ← Template
    ├── helpers/
    │   └── mycomponent.php
    ├── sql/
    │   ├── install.mysql.utf8.sql
    │   └── uninstall.mysql.utf8.sql
    └── language/
        └── en-GB/
            ├── en-GB.com_mycomponent.ini
            └── en-GB.com_mycomponent.sys.ini
```

---

## Manifest XML (Joomla 3)

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="component" version="3.1" method="upgrade">
    <name>com_mycomponent</name>
    <author>Your Name</author>
    <creationDate>2025</creationDate>
    <copyright>(C) 2025 Your Company</copyright>
    <license>GNU General Public License version 2 or later</license>
    <authorEmail>you@example.com</authorEmail>
    <authorUrl>https://example.com</authorUrl>
    <version>1.0.0</version>
    <description>COM_MYCOMPONENT_DESCRIPTION</description>

    <!-- Install script -->
    <scriptfile>script.php</scriptfile>

    <!-- SQL files -->
    <install>
        <sql>
            <file driver="mysql" charset="utf8">admin/sql/install.mysql.utf8.sql</file>
        </sql>
    </install>
    <uninstall>
        <sql>
            <file driver="mysql" charset="utf8">admin/sql/uninstall.mysql.utf8.sql</file>
        </sql>
    </uninstall>

    <!-- Admin section -->
    <administration>
        <menu img="class:cogs">COM_MYCOMPONENT</menu>
        <files folder="admin">
            <filename>mycomponent.php</filename>
            <filename>controller.php</filename>
            <folder>controllers</folder>
            <folder>helpers</folder>
            <folder>models</folder>
            <folder>sql</folder>
            <folder>views</folder>
            <folder>language</folder>
        </files>
    </administration>
</extension>
```

**Key Points:**
- `version="3.1"` in extension tag indicates Joomla 3 manifest format
- Use `folder="admin"` attribute on `<files>` tag
- No namespace declaration (Joomla 3 doesn't use PSR-4)
- Language files can be inside component folder or in global language folder

---

## Entry Point (mycomponent.php)

```php
<?php
/**
 * Entry point for component
 */
defined('_JEXEC') or die;

// Load the controller
$controller = JControllerLegacy::getInstance('Mycomponent');

// Execute the task
$controller->execute(JFactory::getApplication()->input->get('task'));

// Redirect if set
$controller->redirect();
```

---

## Main Controller (controller.php)

```php
<?php
defined('_JEXEC') or die;

class MycomponentController extends JControllerLegacy
{
    /**
     * Default view
     */
    protected $default_view = 'forms';

    /**
     * Display method
     */
    public function display($cachable = false, $urlparams = array())
    {
        return parent::display($cachable, $urlparams);
    }
}
```

---

## Sub-Controller (controllers/forms.php)

```php
<?php
defined('_JEXEC') or die;

class MycomponentControllerForms extends JControllerAdmin
{
    /**
     * Proxy for getModel
     */
    public function getModel($name = 'Form', $prefix = 'MycomponentModel', $config = array('ignore_request' => true))
    {
        return parent::getModel($name, $prefix, $config);
    }

    /**
     * Custom task example
     */
    public function convert()
    {
        // Check token
        JSession::checkToken() or jexit(JText::_('JINVALID_TOKEN'));

        $app = JFactory::getApplication();
        $input = $app->input;
        $cid = $input->get('cid', array(), 'array');

        if (empty($cid)) {
            $app->enqueueMessage(JText::_('COM_MYCOMPONENT_NO_ITEM_SELECTED'), 'warning');
        } else {
            // Process items
            $model = $this->getModel();
            foreach ($cid as $id) {
                $model->processItem($id);
            }
            $app->enqueueMessage(JText::sprintf('COM_MYCOMPONENT_ITEMS_PROCESSED', count($cid)));
        }

        $this->setRedirect(JRoute::_('index.php?option=com_mycomponent&view=forms', false));
    }
}
```

---

## List Model (models/forms.php)

```php
<?php
defined('_JEXEC') or die;

jimport('joomla.application.component.modellist');

class MycomponentModelForms extends JModelList
{
    /**
     * Constructor
     */
    public function __construct($config = array())
    {
        if (empty($config['filter_fields'])) {
            $config['filter_fields'] = array(
                'id', 'a.id',
                'title', 'a.title',
                'published', 'a.published',
            );
        }
        parent::__construct($config);
    }

    /**
     * Method to auto-populate the model state
     */
    protected function populateState($ordering = 'a.title', $direction = 'ASC')
    {
        $app = JFactory::getApplication();

        // Load filter state
        $search = $app->getUserStateFromRequest($this->context . '.filter.search', 'filter_search', '', 'string');
        $this->setState('filter.search', $search);

        // List state
        parent::populateState($ordering, $direction);
    }

    /**
     * Build the query
     */
    protected function getListQuery()
    {
        $db = $this->getDbo();
        $query = $db->getQuery(true);

        $query->select('a.*')
              ->from($db->quoteName('#__mytable', 'a'));

        // Filter by search
        $search = $this->getState('filter.search');
        if (!empty($search)) {
            $search = $db->quote('%' . $db->escape($search, true) . '%');
            $query->where('(a.title LIKE ' . $search . ')');
        }

        // Ordering
        $orderCol = $this->state->get('list.ordering', 'a.title');
        $orderDirn = $this->state->get('list.direction', 'ASC');
        $query->order($db->escape($orderCol . ' ' . $orderDirn));

        return $query;
    }
}
```

---

## View Class (views/forms/view.html.php)

```php
<?php
defined('_JEXEC') or die;

class MycomponentViewForms extends JViewLegacy
{
    protected $items;
    protected $pagination;
    protected $state;

    /**
     * Display the view
     */
    public function display($tpl = null)
    {
        $this->items = $this->get('Items');
        $this->pagination = $this->get('Pagination');
        $this->state = $this->get('State');

        // Check for errors
        if (count($errors = $this->get('Errors'))) {
            throw new Exception(implode("\n", $errors), 500);
        }

        // Add toolbar
        $this->addToolbar();

        // Add sidebar (Joomla 3 style)
        JHtmlSidebar::setAction('index.php?option=com_mycomponent&view=forms');
        $this->sidebar = JHtmlSidebar::render();

        parent::display($tpl);
    }

    /**
     * Add toolbar buttons
     */
    protected function addToolbar()
    {
        JToolbarHelper::title(JText::_('COM_MYCOMPONENT_FORMS'), 'list');
        JToolbarHelper::custom('forms.convert', 'refresh', '', 'Convert', true);
        JToolbarHelper::preferences('com_mycomponent');
    }
}
```

---

## Template (views/forms/tmpl/default.php)

```php
<?php
defined('_JEXEC') or die;

JHtml::_('bootstrap.tooltip');
JHtml::_('behavior.multiselect');
JHtml::_('formbehavior.chosen', 'select');

$listOrder = $this->escape($this->state->get('list.ordering'));
$listDirn = $this->escape($this->state->get('list.direction'));
?>

<form action="<?php echo JRoute::_('index.php?option=com_mycomponent&view=forms'); ?>"
      method="post" name="adminForm" id="adminForm">

<?php if (!empty($this->sidebar)): ?>
    <div id="j-sidebar-container" class="span2">
        <?php echo $this->sidebar; ?>
    </div>
    <div id="j-main-container" class="span10">
<?php else: ?>
    <div id="j-main-container">
<?php endif; ?>

        <!-- Filters -->
        <div id="filter-bar" class="btn-toolbar">
            <div class="filter-search btn-group pull-left">
                <input type="text" name="filter_search" id="filter_search"
                       placeholder="<?php echo JText::_('JSEARCH_FILTER'); ?>"
                       value="<?php echo $this->escape($this->state->get('filter.search')); ?>" />
            </div>
            <div class="btn-group pull-left">
                <button type="submit" class="btn hasTooltip" title="<?php echo JText::_('JSEARCH_FILTER_SUBMIT'); ?>">
                    <i class="icon-search"></i>
                </button>
                <button type="button" class="btn hasTooltip" title="<?php echo JText::_('JSEARCH_FILTER_CLEAR'); ?>"
                        onclick="document.getElementById('filter_search').value='';this.form.submit();">
                    <i class="icon-remove"></i>
                </button>
            </div>
        </div>

        <?php if (empty($this->items)): ?>
            <div class="alert alert-info">
                <?php echo JText::_('JGLOBAL_NO_MATCHING_RESULTS'); ?>
            </div>
        <?php else: ?>
            <table class="table table-striped" id="itemList">
                <thead>
                    <tr>
                        <th width="1%" class="center">
                            <?php echo JHtml::_('grid.checkall'); ?>
                        </th>
                        <th>
                            <?php echo JHtml::_('grid.sort', 'JGLOBAL_TITLE', 'a.title', $listDirn, $listOrder); ?>
                        </th>
                        <th width="1%" class="nowrap center">
                            <?php echo JHtml::_('grid.sort', 'JGRID_HEADING_ID', 'a.id', $listDirn, $listOrder); ?>
                        </th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($this->items as $i => $item): ?>
                        <tr class="row<?php echo $i % 2; ?>">
                            <td class="center">
                                <?php echo JHtml::_('grid.id', $i, $item->id); ?>
                            </td>
                            <td>
                                <?php echo $this->escape($item->title); ?>
                            </td>
                            <td class="center">
                                <?php echo (int)$item->id; ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>

            <?php echo $this->pagination->getListFooter(); ?>
        <?php endif; ?>
    </div>

    <input type="hidden" name="task" value="" />
    <input type="hidden" name="boxchecked" value="0" />
    <input type="hidden" name="filter_order" value="<?php echo $listOrder; ?>" />
    <input type="hidden" name="filter_order_Dir" value="<?php echo $listDirn; ?>" />
    <?php echo JHtml::_('form.token'); ?>
</form>
```

---

## Helper Class (helpers/mycomponent.php)

```php
<?php
defined('_JEXEC') or die;

class MycomponentHelper
{
    /**
     * Get component parameter
     */
    public static function getParam($key, $default = null)
    {
        $params = JComponentHelper::getParams('com_mycomponent');
        return $params->get($key, $default);
    }

    /**
     * Add submenu items
     */
    public static function addSubmenu($vName)
    {
        JHtmlSidebar::addEntry(
            JText::_('COM_MYCOMPONENT_SUBMENU_FORMS'),
            'index.php?option=com_mycomponent&view=forms',
            $vName == 'forms'
        );
    }
}
```

---

## Install Script (script.php)

```php
<?php
defined('_JEXEC') or die;

class Com_MycomponentInstallerScript
{
    /**
     * Runs after install/update
     */
    public function postflight($type, $parent)
    {
        if ($type === 'install') {
            echo '<p>Component installed successfully!</p>';
        }
        return true;
    }

    /**
     * Runs before uninstall
     */
    public function uninstall($parent)
    {
        return true;
    }

    /**
     * Check requirements before install
     */
    public function preflight($type, $parent)
    {
        // Check Joomla version
        if (version_compare(JVERSION, '3.0.0', '<')) {
            JFactory::getApplication()->enqueueMessage('Requires Joomla 3.0+', 'error');
            return false;
        }
        return true;
    }
}
```

---

## Key Joomla 3 APIs

### Database Operations

```php
$db = JFactory::getDbo();
$query = $db->getQuery(true);

// SELECT
$query->select('*')
      ->from($db->quoteName('#__table'))
      ->where($db->quoteName('id') . ' = ' . (int)$id);
$db->setQuery($query);
$result = $db->loadObject();       // Single row as object
$results = $db->loadObjectList(); // Multiple rows

// INSERT
$record = new stdClass();
$record->title = 'Test';
$record->published = 1;
$db->insertObject('#__table', $record, 'id');
$newId = $record->id;

// UPDATE
$db->updateObject('#__table', $record, 'id');
```

### Application & Input

```php
$app = JFactory::getApplication();
$input = $app->input;

// Get values
$id = $input->getInt('id', 0);
$title = $input->getString('title', '');
$ids = $input->get('cid', array(), 'array');

// Messages
$app->enqueueMessage('Success!', 'success');
$app->enqueueMessage('Warning!', 'warning');
$app->enqueueMessage('Error!', 'error');

// Redirect
$app->redirect(JRoute::_('index.php?option=com_mycomponent'));
```

### User & Session

```php
$user = JFactory::getUser();
$userId = $user->id;
$isAdmin = $user->authorise('core.admin', 'com_mycomponent');

// Check form token (CSRF protection)
JSession::checkToken() or jexit(JText::_('JINVALID_TOKEN'));
```

---

## Common Issues

### 1. View's `$this->get('Xxx')` Not Working

**Cause**: In Joomla 3, `$this->get('Xxx')` in a view calls `getXxx()` on the model. The method name MUST start with `get`.

**Wrong**:
```php
// In model - this won't work with $this->get('ChronoformsInstalled')
public function isChronoformsInstalled() { ... }
```

**Correct**:
```php
// In model - use getXxx pattern
public function getChronoformsInstalled() { ... }

// In view
$this->chronoformsInstalled = $this->get('ChronoformsInstalled'); // calls getChronoformsInstalled()
```

### 2. Database Table Detection Issues

**Cause**: Using regex or hardcoded prefixes instead of configured database prefix

**Wrong**:
```php
// This matches tables with ANY prefix, not just your site's
foreach ($tables as $table) {
    if (preg_match('/mytable$/i', $table)) { ... }
}
```

**Correct**:
```php
// Use the configured prefix from Joomla
$db = $this->getDbo();
$prefix = $db->getPrefix();  // Gets prefix from configuration.php
$tableName = $prefix . 'mytable';
if (in_array($tableName, $tables)) { ... }
```

### 3. Component Not Appearing in Menu

**Cause**: Missing `<menu>` tag or wrong menu icon class

**Fix**:
```xml
<administration>
    <menu img="class:cogs">COM_MYCOMPONENT</menu>
    <!-- ... -->
</administration>
```

### 2. Views Not Loading

**Cause**: File/class naming mismatch

**Rule**: View folder name, view class name, and URL view parameter must match (case-insensitive)
- URL: `?option=com_mycomponent&view=forms`
- Folder: `views/forms/`
- Class: `MycomponentViewForms`

### 3. Models Not Found

**Cause**: Model class naming doesn't match

**Rule**: Model class name = Component prefix + "Model" + singular/plural name
- `MycomponentModelForms` (list model)
- `MycomponentModelForm` (single item model)

### 4. Package Installation Fails

**Causes**:
- ZIP created with PowerShell's `Compress-Archive` (missing directory entries)
- Files at wrong level in ZIP

**Fix**: Use 7-Zip to create packages:
```powershell
cd com_mycomponent
& "C:\Program Files\7-Zip\7z.exe" a -tzip "..\com_mycomponent.zip" *
```

---

## Differences from Joomla 4/5

| Feature | Joomla 3 | Joomla 4/5 |
|---------|----------|------------|
| Base Classes | `JModelList`, `JViewLegacy`, etc. | Namespaced classes |
| Namespaces | None | PSR-4 required |
| DI Container | None | Required for components |
| Service Provider | None | `services/provider.php` |
| Autoloading | `jimport()` | Composer autoload |
| Events | Traditional hooks | SubscriberInterface |

---

## Resources

- [Joomla 3 Documentation](https://docs.joomla.org/J3.x:Developing_an_MVC_Component)
- [Joomla 3 API Reference](https://api.joomla.org/cms-3/)
