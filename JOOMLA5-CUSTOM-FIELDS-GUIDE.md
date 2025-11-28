# Creating Custom Fields Programmatically in Joomla 5

## Overview

This guide documents how to create custom field groups and fields programmatically during plugin/component installation in Joomla 5.

**Important**: Do NOT use raw SQL INSERT statements. The `#__fields` and `#__fields_groups` tables have many required columns that vary between Joomla versions. Use Joomla's Table classes instead.

---

## Using MVCFactory and Table Classes (Recommended)

### Creating a Field Group

```php
use Joomla\CMS\Factory;

$app = Factory::getApplication();
$mvcFactory = $app->bootComponent('com_fields')->getMVCFactory();
$groupTable = $mvcFactory->createTable('Group', 'Administrator');

$groupData = [
    'title'       => 'My Field Group',
    'context'     => 'com_content.article',  // or 'com_users.user', etc.
    'state'       => 1,
    'language'    => '*',
    'access'      => 1,
    'ordering'    => 0,
    'note'        => '',
    'description' => '',
    'params'      => '{}',
];

if (!$groupTable->bind($groupData)) {
    throw new \Exception('Group bind failed: ' . $groupTable->getError());
}
if (!$groupTable->store()) {
    throw new \Exception('Group store failed: ' . $groupTable->getError());
}

$groupId = $groupTable->id;
```

### Creating a Field

```php
$fieldTable = $mvcFactory->createTable('Field', 'Administrator');

// Field parameters for a radio/yes-no field
$fieldparams = [
    'options' => [
        'options0' => ['name' => 'No', 'value' => '0'],
        'options1' => ['name' => 'Yes', 'value' => '1'],
    ],
    'class' => 'btn-group btn-group-yesno',
    'layout' => 'joomla.form.field.radio.switcher',
];

$fieldData = [
    'id'            => 0,
    'asset_id'      => 0,
    'title'         => 'Is this article sponsored?',
    'name'          => 'sponsored-article',    // Used in queries
    'label'         => 'Is this article sponsored?',
    'type'          => 'radio',
    'context'       => 'com_content.article',
    'group_id'      => (int) $groupId,
    'state'         => 1,
    'required'      => 0,
    'only_use_in_subform' => 0,
    'default_value' => '0',
    'language'      => '*',
    'access'        => 1,
    'ordering'      => 0,
    'note'          => '',
    'description'   => '',
    'params'        => '{}',
    'fieldparams'   => json_encode($fieldparams),
];

if (!$fieldTable->bind($fieldData)) {
    throw new \Exception('Field bind failed: ' . $fieldTable->getError());
}

if (!$fieldTable->check()) {
    throw new \Exception('Field check failed: ' . $fieldTable->getError());
}

if (!$fieldTable->store()) {
    throw new \Exception('Field store failed: ' . $fieldTable->getError());
}
```

---

## Complete Installation Script Example

```php
<?php
defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Installer\InstallerAdapter;
use Joomla\CMS\Log\Log;

class PlgSystemMypluginInstallerScript
{
    public function postflight(string $type, InstallerAdapter $parent): bool
    {
        if ($type === 'install' || $type === 'update') {
            try {
                $this->createCustomField();
            } catch (\Exception $e) {
                Log::add('MyPlugin: Failed to create custom field - ' . $e->getMessage(), Log::WARNING, 'jerror');
            }
        }
        return true;
    }

    private function createCustomField(): void
    {
        $db = Factory::getContainer()->get('DatabaseDriver');

        // Check if field group already exists
        $query = $db->getQuery(true)
            ->select($db->quoteName('id'))
            ->from($db->quoteName('#__fields_groups'))
            ->where($db->quoteName('title') . ' = ' . $db->quote('My Group'))
            ->where($db->quoteName('context') . ' = ' . $db->quote('com_content.article'));

        $db->setQuery($query);
        $groupId = $db->loadResult();

        // Create field group if it doesn't exist
        if (!$groupId) {
            $app = Factory::getApplication();
            $mvcFactory = $app->bootComponent('com_fields')->getMVCFactory();
            $groupTable = $mvcFactory->createTable('Group', 'Administrator');

            $groupData = [
                'title'       => 'My Group',
                'context'     => 'com_content.article',
                'state'       => 1,
                'language'    => '*',
                'access'      => 1,
                'ordering'    => 0,
                'note'        => '',
                'description' => '',
                'params'      => '{}',
            ];

            if (!$groupTable->bind($groupData)) {
                throw new \Exception('Group bind failed: ' . $groupTable->getError());
            }
            if (!$groupTable->store()) {
                throw new \Exception('Group store failed: ' . $groupTable->getError());
            }
            $groupId = $groupTable->id;
        }

        // Check if field already exists
        $query = $db->getQuery(true)
            ->select($db->quoteName('id'))
            ->from($db->quoteName('#__fields'))
            ->where($db->quoteName('name') . ' = ' . $db->quote('my-field'))
            ->where($db->quoteName('context') . ' = ' . $db->quote('com_content.article'));

        $db->setQuery($query);
        $fieldId = $db->loadResult();

        // Create field if it doesn't exist
        if (!$fieldId) {
            $app = Factory::getApplication();
            $mvcFactory = $app->bootComponent('com_fields')->getMVCFactory();
            $fieldTable = $mvcFactory->createTable('Field', 'Administrator');

            $fieldparams = [
                'options' => [
                    'options0' => ['name' => 'No', 'value' => '0'],
                    'options1' => ['name' => 'Yes', 'value' => '1'],
                ],
                'class' => 'btn-group btn-group-yesno',
                'layout' => 'joomla.form.field.radio.switcher',
            ];

            $fieldData = [
                'id'            => 0,
                'asset_id'      => 0,
                'title'         => 'My Field',
                'name'          => 'my-field',
                'label'         => 'My Field Label',
                'type'          => 'radio',
                'context'       => 'com_content.article',
                'group_id'      => (int) $groupId,
                'state'         => 1,
                'required'      => 0,
                'only_use_in_subform' => 0,
                'default_value' => '0',
                'language'      => '*',
                'access'        => 1,
                'ordering'      => 0,
                'note'          => '',
                'description'   => '',
                'params'        => '{}',
                'fieldparams'   => json_encode($fieldparams),
            ];

            if (!$fieldTable->bind($fieldData)) {
                throw new \Exception('Field bind failed: ' . $fieldTable->getError());
            }

            if (!$fieldTable->check()) {
                throw new \Exception('Field check failed: ' . $fieldTable->getError());
            }

            if (!$fieldTable->store()) {
                throw new \Exception('Field store failed: ' . $fieldTable->getError());
            }
        }
    }
}
```

---

## Available Field Types

Common field types for the `type` property:
- `text` - Single line text
- `textarea` - Multi-line text
- `radio` - Radio buttons (yes/no, etc.)
- `list` - Dropdown select
- `checkboxes` - Multiple checkboxes
- `integer` - Number input
- `calendar` - Date picker
- `color` - Color picker
- `editor` - WYSIWYG editor
- `media` - Media selector
- `user` - User selector

---

## Available Contexts

Common contexts for the `context` property:
- `com_content.article` - Articles
- `com_users.user` - Users
- `com_contact.contact` - Contacts
- `com_categories.category` - Categories

---

## Querying Custom Field Values

To find items with a specific custom field value:

```php
$db = Factory::getContainer()->get('DatabaseDriver');

$query = $db->getQuery(true)
    ->select($db->quoteName('c.alias'))
    ->from($db->quoteName('#__content', 'c'))
    ->join('INNER', $db->quoteName('#__fields_values', 'fv')
        . ' ON ' . $db->quoteName('fv.item_id') . ' = ' . $db->quoteName('c.id'))
    ->join('INNER', $db->quoteName('#__fields', 'f')
        . ' ON ' . $db->quoteName('f.id') . ' = ' . $db->quoteName('fv.field_id'))
    ->where($db->quoteName('c.state') . ' = 1')
    ->where($db->quoteName('f.name') . ' = ' . $db->quote('my-field'))
    ->where($db->quoteName('f.context') . ' = ' . $db->quote('com_content.article'))
    ->where($db->quoteName('fv.value') . ' = ' . $db->quote('1'));

$db->setQuery($query);
$results = $db->loadColumn();
```

---

## Common Errors

### "Unknown column 'created' in 'INSERT INTO'"
**Cause**: Using raw SQL INSERT with incorrect column names.
**Solution**: Use the Table class approach shown above - it handles all column mappings automatically.

### "Field 'modified' doesn't have a default value"
**Cause**: Missing required columns in raw SQL INSERT.
**Solution**: Use the Table class approach - Joomla handles default values.

### Field group created but field not created
**Cause**: Missing required fields like `id`, `asset_id`, or `only_use_in_subform`.
**Solution**: Include all fields shown in the example above, and use `check()` before `store()` to catch validation errors.

---

## Notes

1. Always check if the field/group already exists before creating to avoid duplicates on reinstall/update
2. Use `try/catch` and log errors - don't let field creation failures break the installation
3. The `name` field is used for database queries; the `title` and `label` are for display
4. Field params (`fieldparams`) control the field's behavior; params (`params`) are for additional metadata
