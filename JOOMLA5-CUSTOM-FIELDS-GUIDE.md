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

### Subform via Core `plg_fields_subform` (No Custom Plugin Needed) — 2026-05-25

When you don't want to ship your own fields plugin and just need a repeatable group of fields on com_content articles, Joomla's bundled **`plg_fields_subform`** does this entirely via the field manager UI / Web Services API. The setup has multiple non-obvious gotchas worth documenting:

#### Setup pattern (programmatic via cs-mcp-for-j v1.9+)

```
1. create_field_group(title="Changelog", context="com_content.article")
   → returns group_id

2. For each subfield (e.g. release_date, version, notes):
   create_custom_field(name=..., type=calendar/text/editor,
                       context="com_content.article", group_id=<group_id>)
   update_custom_field(id=<new>, only_use_in_subform=1, assigned_cat_ids=[-1])

3. create_custom_field(name="changelog", type="subform",
                       context="com_content.article", group_id=<group_id>,
                       fieldparams={
                         "options": {
                           "options0": {"customfield": "<sub1_id>", "render_values": "1"},
                           "options1": {"customfield": "<sub2_id>", "render_values": "1"},
                           "options2": {"customfield": "<sub3_id>", "render_values": "1"}
                         },
                         "multiple": "1", "min": "0", "max": "",
                         "layout": "joomla.form.field.subform.repeatable-table",
                         "buttons": {"add":"1","remove":"1","move":"1"},
                         "groupByFieldset": "0"
                       })
   update_custom_field(id=<subform_id>, assigned_cat_ids=[<target_cat_id>])
```

Subfields scoped to `assigned_cat_ids=[-1]` (no category) + `only_use_in_subform=1` is what prevents them from rendering standalone on every article in the site. The Subform parent is the only field with a real category assignment.

#### Storage format (writing values via `set_custom_field_value`)

The Subform field's `#__fields_values.value` is JSON:

```json
{
  "row0": {"field<sub1_id>": "...", "field<sub2_id>": "...", "field<sub3_id>": "..."},
  "row1": {"field<sub1_id>": "...", "field<sub2_id>": "...", "field<sub3_id>": "..."}
}
```

**Critical:** subfield value keys are `field<ID>` (e.g. `field1`, `field2`, `field3`) — NOT the subfield machine names like `release_date`. The `plg_fields_subform` plugin's `getSubfieldsFromField()` method renames `->name` to `field<ID>` for input-name-collision avoidance and stores the original machine name as `->fieldname`. Writing values keyed by machine names will land 9 empty rows in the admin UI (Joomla parses the JSON, sees N entries, creates N rows, but can't map the keys to any subfield).

#### Reading values in a frontend template override

The override at `templates/<template>/html/plg_fields_subform/subform.php` receives `$field->subform_rows` which is keyed by the subfield's **original `fieldname`** (machine name like `release_date`), with each value being a subfield object:

```php
foreach ($field->subform_rows as $subform_row) {
    // Either access by fieldname-key directly:
    $date    = $subform_row['release_date']->rawvalue ?? '';
    $version = $subform_row['version']->rawvalue ?? '';
    $notes   = $subform_row['notes']->rawvalue ?? '';

    // Or iterate and look up by ->fieldname (NOT ->name — ->name is "fieldN"):
    foreach ($subform_row as $sf) {
        if ($sf->fieldname === 'release_date') { ... }
    }
}
```

**Use `->rawvalue` for editor / text** (raw stored value) and parse calendar `->rawvalue` yourself if you need full timezone control — the auto-rendered `->value` for calendar applies the site's display timezone, which can day-shift dates stored at midnight UTC (see next item).

#### Calendar field timezone day-shift

A Calendar subfield with `fieldparams.filter=SERVER_UTC` and `showtime=0` will silently day-shift values when the site's display timezone is offset from UTC. Storing `2025-08-18 00:00:00` displays as `2025-08-17` in any US timezone (UTC−5 to −8). Workaround: **store dates at noon UTC** (`12:00:00`) so any timezone within ±12h still renders the same day. Doesn't matter for date-only displays; matters for sort, which strcmp'd naturally either way.

#### v1.8 → v1.9 field-name normalization gotcha (cs-mcp-for-j specific)

cs-mcp-for-j v1.9's `create_custom_field` normalizes underscores in machine names to hyphens (passed `name=release_date`, stored `name=release-date`). v1.8 preserved underscores. `update_custom_field` doesn't expose `name` as updatable, so a v1.9-created field can't be renamed via API. **Make override code key-agnostic** by normalizing both forms:

```php
foreach ($field->subform_rows as $subform_row) {
    $by_name = [];
    foreach ($subform_row as $key => $sf) {
        $raw  = is_string($key) ? $key : (string) ($sf->fieldname ?? '');
        $norm = str_replace('-', '_', $raw);
        $by_name[$norm] = $sf;
    }
    // now $by_name['release_date'] works on both v1.8 and v1.9 sites
}
```

Reference deployment: VMT `transform` + ET `xeno` template overrides (2026-05-25 changelog refactor). Documented because the same override file is intended to ship across both v1.8 and v1.9 sites.

---

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
