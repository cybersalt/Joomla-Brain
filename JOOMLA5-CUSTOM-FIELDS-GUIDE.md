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

## Registering a Custom Field Context for Your Component

To allow custom fields on your component's own entities (e.g., topics, products), register a custom field context.

### Required Interface and Trait

```php
use Joomla\CMS\Fields\FieldsFormServiceInterface;
use Joomla\CMS\Fields\FieldsServiceTrait;

class MyComponent extends MVCComponent implements FieldsFormServiceInterface
{
    use FieldsServiceTrait;

    public function validateSection($section, ?Form $form = null): ?string
    {
        if ($section === 'topic') {
            return 'topic';
        }
        return null;
    }

    public function getContexts(): array
    {
        Factory::getLanguage()->load('com_mycomp', JPATH_ADMINISTRATOR);
        return [
            'com_mycomp.topic' => Text::_('COM_MYCOMP_CONTEXT_TOPIC'),
        ];
    }
}
```

### Model Requirements

The model must set `$typeAlias` for custom fields to save/load:

```php
class TopicModel extends AdminModel
{
    public $typeAlias = 'com_mycomp.topic';
}
```

### ⚠️ CRITICAL WARNING: Version Compatibility

**`FieldsFormServiceInterface` may not exist in all Joomla 5.x versions.** In Joomla 5.4.3, importing this interface caused a fatal error that crashed the entire site (ERR_HTTP2_PROTOCOL_ERROR — no error page, just a connection drop).

**If the interface causes a fatal error:** Fall back to storing the data in your component's own table columns instead of using Joomla custom fields. This is simpler and guaranteed to work:

```sql
ALTER TABLE #__mycomp_topics ADD COLUMN show_quiz TINYINT(1) DEFAULT 0;
ALTER TABLE #__mycomp_topics ADD COLUMN quiz_passing_score VARCHAR(10) DEFAULT '';
```

Then add the fields to your form XML and they save/load through the normal Table class.

---

## Subform Custom Field (Repeatable Fields)

Subform fields allow repeatable groups of fields — e.g., multiple quiz questions per article. **This is the most complex custom field type to set up programmatically.**

### CRITICAL: How Subform Fields Work

Joomla's `SubformField` class reads `multiple`, `min`, `max`, `buttons`, and `layout` from the **field's XML attributes**, NOT from `fieldparams` JSON. This means:

- Setting `"multiple":"true"` in `fieldparams` JSON **DOES NOTHING**
- Setting attributes via `onContentPrepareForm` / `setFieldAttribute()` **DOES NOT WORK** because custom fields are added to the form AFTER that event fires
- The ONLY way to control subform behavior is via `onCustomFieldsPrepareDom` in a fields plugin

### The Correct Approach: Custom Field Type via Fields Plugin

**Step 1:** Create a custom field type (e.g., `cslearningquiz`) — NOT `subform`

**Step 2:** Register the type in your fields plugin:

```php
class MyFieldsPlugin extends FieldsPlugin
{
    // THIS is the method that tells Joomla which types this plugin handles
    // It is NOT getTypesInfo() — that method doesn't exist!
    public function onCustomFieldsGetTypes(): array
    {
        return [
            ['type' => 'mytopics'],
            ['type' => 'myquiz'],    // Our subform type
        ];
    }
}
```

**Step 3:** In `onCustomFieldsPrepareDom`, set the subform attributes on the DOM node:

```php
public function onCustomFieldsPrepareDom($field, \DOMElement $parent, Form $form)
{
    if ($field->type === 'myquiz') {
        $fieldNode = parent::onCustomFieldsPrepareDom($field, $parent, $form);
        if (!$fieldNode) return $fieldNode;

        // Transform this custom field type into a subform with repeatable
        $fieldNode->setAttribute('type', 'subform');
        $fieldNode->setAttribute('formsource', 'plugins/system/myplugin/forms/quiz_question.xml');
        $fieldNode->setAttribute('multiple', 'true');
        $fieldNode->setAttribute('min', '0');
        $fieldNode->setAttribute('max', '50');
        $fieldNode->setAttribute('buttons', 'add,remove,move');
        $fieldNode->setAttribute('layout', 'joomla.form.field.subform.repeatable');
        $fieldNode->setAttribute('groupByFieldset', '0');

        return $fieldNode;
    }

    // Handle other field types...
    return parent::onCustomFieldsPrepareDom($field, $parent, $form);
}
```

**Step 4:** Create the subform XML definition (e.g., `plugins/system/myplugin/forms/quiz_question.xml`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<form>
    <field name="question_type" type="list" label="Question Type" default="multiple_choice">
        <option value="multiple_choice">Multiple Choice</option>
        <option value="true_false">True / False</option>
    </field>
    <field name="question_text" type="textarea" label="Question" rows="3" />
    <field name="option_a" type="text" label="Option A" />
    <field name="option_b" type="text" label="Option B" />
    <field name="correct_answer" type="list" label="Correct Answer">
        <option value="a">Option A</option>
        <option value="b">Option B</option>
    </field>
    <field name="explanation" type="textarea" label="Explanation" rows="2" />
</form>
```

**Step 5:** Create the field programmatically with the custom type:

```php
$field = (object) [
    'title'       => 'Quiz Questions',
    'name'        => 'my-quiz-questions',
    'type'        => 'myquiz',  // NOT 'subform' — use your custom type
    'context'     => 'com_content.article',
    'group_id'    => $groupId,
    'state'       => 1,
    'fieldparams' => '{}',  // Subform attributes are set in onCustomFieldsPrepareDom, NOT here
    // ... other standard field properties
];
$db->insertObject('#__fields', $field, 'id');
```

### Subform Layout Options

| Layout | Description |
|--------|-------------|
| `joomla.form.field.subform.repeatable` | Stacked/card layout — fields vertically within each row |
| `joomla.form.field.subform.repeatable-table` | Table layout — fields as columns, rows as table rows |

### What DOES NOT Work (Common Mistakes)

| Approach | Why It Fails |
|----------|-------------|
| Setting `"multiple":"true"` in `fieldparams` JSON | SubformField reads from XML attributes, not fieldparams |
| Using `onContentPrepareForm` to `setFieldAttribute()` | Custom fields are added AFTER this event fires |
| Using `getXml()->xpath()` to modify the form XML | Same timing issue — fields not yet added |
| Using `type="subform"` directly as custom field type | Works but renders as single non-repeatable row with no buttons |
| Overriding `getTypesInfo()` | This method doesn't exist — use `onCustomFieldsGetTypes()` |

### Reading Subform Values on the Frontend

Subform data is stored as JSON in `#__fields_values.value`. To read it:

```php
$db = Factory::getContainer()->get('DatabaseDriver');

// Get the field ID
$query = $db->getQuery(true)
    ->select('id')
    ->from('#__fields')
    ->where('name = ' . $db->quote('my-quiz-questions'))
    ->where('context = ' . $db->quote('com_content.article'));
$db->setQuery($query);
$fieldId = (int) $db->loadResult();

// Get the JSON value for a specific article
$query = $db->getQuery(true)
    ->select('value')
    ->from('#__fields_values')
    ->where('field_id = ' . $fieldId)
    ->where('item_id = ' . $db->quote((string) $articleId));
$db->setQuery($query);
$json = $db->loadResult();

$questions = json_decode($json, true);
// $questions is an array of arrays, each containing the subform field values
```

### Trashed Fields Gotcha

When a user deletes a custom field via the Joomla UI, it goes to **trash** (`state = -2`), not permanently deleted. Your `ensureField` check must account for this:

```php
// Check for existing field INCLUDING trashed ones
$query->select(['id', 'state'])
    ->from('#__fields')
    ->where('name = ' . $db->quote($fieldName))
    ->where('context = ' . $db->quote('com_content.article'));

// If found but trashed, republish it
if ($existing && (int) $existing->state !== 1) {
    // UPDATE state = 1
}
```

---

## Notes

For multi-select UI (fancy-select layout), see `JOOMLA5-MODULE-GUIDE.md` Form Field Best Practices section.

1. Always check if the field/group already exists before creating to avoid duplicates on reinstall/update
2. Use `try/catch` and log errors - don't let field creation failures break the installation
3. The `name` field is used for database queries; the `title` and `label` are for display
4. Field params (`fieldparams`) control the field's behavior; params (`params`) are for additional metadata
5. For subform fields, use a **custom field type** handled by your fields plugin — do NOT use `type="subform"` directly
6. The `onCustomFieldsGetTypes()` method (NOT `getTypesInfo()`) is what Joomla's FieldsPlugin uses to determine supported types
