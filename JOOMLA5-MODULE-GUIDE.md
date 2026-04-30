# Joomla 5 Module Development Guide

This guide covers best practices for building native Joomla 5 modules. Joomla 5 supports two patterns:

1. **Dispatcher Pattern** (Recommended) - No entry point file, uses DI container - this is what Joomla core modules use
2. **Helper Pattern** (Legacy) - Uses `mod_*.php` entry point with explicit require

**Use the Dispatcher pattern for new modules.** It's the modern Joomla 5 approach and has been battle-tested through painful trial and error. The Helper pattern is documented for reference when working with existing modules.

---

## Pattern 1: Dispatcher Pattern (Recommended)

### File Structure

```
mod_example/
├── mod_example.xml              # Manifest file (NO mod_example.php needed!)
├── services/
│   └── provider.php             # Dependency injection provider
├── src/
│   └── Dispatcher/
│       └── Dispatcher.php       # Main module logic
├── tmpl/
│   └── default.php              # Output template
├── media/
│   ├── css/
│   │   └── example.css          # Module styles
│   └── js/
│       └── example.js           # Module scripts
└── language/
    └── en-GB/
        ├── mod_example.ini      # Frontend strings
        └── mod_example.sys.ini  # Installer/admin strings
```

**IMPORTANT**: Joomla 5 modules using the Dispatcher pattern do NOT need a `mod_example.php` entry point file. Joomla core modules (e.g., `mod_articles_category`, `mod_breadcrumbs`) have no PHP entry file - just the XML manifest, services folder, src folder, and tmpl folder.

### Namespace to File Path Mapping

This is critical to understand:

- **Manifest namespace**: `YourCompany\Module\Example` (with `path="src"`)
- **ModuleDispatcherFactory receives**: `\\YourCompany\\Module\\Example`
- **Joomla looks for class**: `YourCompany\Module\Example\Site\Dispatcher\Dispatcher`
- **Actual file location**: `src/Dispatcher/Dispatcher.php`

The `Site` in the namespace is **automatically added by Joomla's ModuleDispatcherFactory** - it does NOT correspond to an actual folder! The factory builds the class name as:

```
\{namespace}\{Site|Administrator}\Dispatcher\Dispatcher
```

So the Dispatcher file goes in `src/Dispatcher/`, NOT `src/Site/Dispatcher/`.

## Manifest File (mod_example.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<extension type="module" client="site" method="upgrade">
    <name>MOD_EXAMPLE</name>
    <author>Your Name</author>
    <creationDate>2025-01</creationDate>
    <copyright>(C) 2025 Your Company. All rights reserved.</copyright>
    <license>GNU General Public License version 2 or later</license>
    <authorEmail>you@example.com</authorEmail>
    <authorUrl>https://example.com</authorUrl>
    <version>1.0.0</version>
    <description>MOD_EXAMPLE_DESC</description>
    <namespace path="src">YourCompany\Module\Example</namespace>

    <files>
        <folder module="mod_example">services</folder>
        <folder>src</folder>
        <folder>tmpl</folder>
    </files>

    <languages>
        <language tag="en-GB">language/en-GB/mod_example.ini</language>
        <language tag="en-GB">language/en-GB/mod_example.sys.ini</language>
    </languages>

    <media destination="mod_example" folder="media">
        <folder>css</folder>
        <folder>js</folder>
    </media>

    <config>
        <fields name="params">
            <fieldset name="basic">
                <!-- Your configuration fields here -->
            </fieldset>

            <fieldset name="advanced">
                <!-- Module class suffix -->
                <field
                    name="moduleclass_sfx"
                    type="textarea"
                    label="COM_MODULES_FIELD_MODULECLASS_SFX_LABEL"
                    description="COM_MODULES_FIELD_MODULECLASS_SFX_DESC"
                    rows="3"
                />

                <!-- REQUIRED: Custom CSS field per Joomla Brain standards -->
                <field
                    name="custom_css"
                    type="textarea"
                    label="MOD_EXAMPLE_FIELD_CUSTOM_CSS_LABEL"
                    description="MOD_EXAMPLE_FIELD_CUSTOM_CSS_DESC"
                    rows="10"
                    filter="raw"
                    class="input-xxlarge"
                />
            </fieldset>
        </fields>
    </config>
</extension>
```

### Key Manifest Points

1. **Namespace declaration**: Must match the base namespace used in your PHP files (without `\Site\Dispatcher`)
2. **`client="site"`**: For frontend modules; use `client="administrator"` for admin modules
3. **`method="upgrade"`**: Allows reinstallation without uninstalling first
4. **`module` attribute**: Goes on the `services` folder, NOT on a PHP entry file
5. **Media folders**: Use `<folder>` tags for directories, NOT `<filename>` tags
6. **Language files**: Declared separately, NOT inside `<files>` section
7. **No entry point file**: Modern Joomla 5 modules don't need `mod_example.php`

### Files Section - Critical Details

```xml
<files>
    <folder module="mod_example">services</folder>
    <folder>src</folder>
    <folder>tmpl</folder>
</files>
```

- The `module="mod_example"` attribute goes on the **services folder**, not a PHP file
- Do NOT include a `mod_example.php` file - it's not needed with the Dispatcher pattern
- Do NOT include the `media` folder here - it has its own `<media>` section

### Media Section - Critical Details

```xml
<media destination="mod_example" folder="media">
    <folder>css</folder>
    <folder>js</folder>
</media>
```

- Use `<folder>` tags for directories containing assets
- Do NOT use `<filename>` tags for directories (causes installation issues)

## Service Provider (services/provider.php)

```php
<?php

/**
 * @package     YourCompany.Module
 * @subpackage  mod_example
 *
 * @copyright   (C) 2025 Your Company. All rights reserved.
 * @license     GNU General Public License version 2 or later
 */

\defined('_JEXEC') or die;

use Joomla\CMS\Extension\Service\Provider\Module;
use Joomla\CMS\Extension\Service\Provider\ModuleDispatcherFactory;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;

return new class implements ServiceProviderInterface
{
    /**
     * Registers the service provider with a DI container.
     *
     * @param   Container  $container  The DI container.
     *
     * @return  void
     */
    public function register(Container $container): void
    {
        $container->registerServiceProvider(new ModuleDispatcherFactory('\\YourCompany\\Module\\Example'));
        $container->registerServiceProvider(new Module());
    }
};
```

### Critical Notes

- Use `new class implements ServiceProviderInterface` syntax (anonymous class)
- The namespace in `ModuleDispatcherFactory` must match your manifest's `<namespace>` declaration
- Use double backslashes for the namespace string

## Dispatcher Class (src/Dispatcher/Dispatcher.php)

**CRITICAL**: The namespace includes `\Site\Dispatcher` even though the file is at `src/Dispatcher/`. This is because Joomla's autoloader maps the `Site` portion automatically for frontend modules.

```php
<?php

/**
 * @package     YourCompany.Module
 * @subpackage  mod_example
 *
 * @copyright   (C) 2025 Your Company. All rights reserved.
 * @license     GNU General Public License version 2 or later
 */

namespace YourCompany\Module\Example\Site\Dispatcher;

\defined('_JEXEC') or die;

use Joomla\CMS\Dispatcher\AbstractModuleDispatcher;
use Joomla\CMS\Factory;
use Joomla\CMS\WebAsset\WebAssetManager;

/**
 * Dispatcher class for mod_example
 */
class Dispatcher extends AbstractModuleDispatcher
{
    /**
     * Returns the layout data.
     *
     * @return  array
     */
    protected function getLayoutData(): array
    {
        $data = parent::getLayoutData();

        $params = $data['params'];
        $module = $data['module'];

        // Add your custom data here
        $data['myCustomData'] = $this->processData($params);
        $data['moduleId'] = $module->id;
        $data['customCss'] = $params->get('custom_css', '');

        // Register assets
        $this->registerAssets($data);

        return $data;
    }

    /**
     * Register CSS and JavaScript assets
     *
     * @param   array  $data  The layout data
     *
     * @return  void
     */
    protected function registerAssets(array $data): void
    {
        /** @var WebAssetManager $wa */
        $wa = Factory::getApplication()->getDocument()->getWebAssetManager();

        // Register and use CSS
        $wa->registerAndUseStyle(
            'mod_example',
            'media/mod_example/css/example.css',
            ['version' => 'auto']
        );

        // Register and use JavaScript
        $wa->registerAndUseScript(
            'mod_example',
            'media/mod_example/js/example.js',
            ['version' => 'auto'],
            ['defer' => true]
        );

        // Pass configuration to JavaScript if needed
        $config = [
            'moduleId' => $data['moduleId'],
            // Add other config as needed
        ];

        $wa->addInlineScript(
            'window.ModExample = window.ModExample || {};'
            . 'window.ModExample["module' . $data['moduleId'] . '"] = ' . json_encode($config) . ';',
            ['position' => 'before'],
            [],
            ['mod_example']
        );

        // Add custom CSS if provided (scoped to module instance)
        if (!empty($data['customCss'])) {
            $wa->addInlineStyle(
                '#mod-example-' . $data['moduleId'] . ' { ' . $data['customCss'] . ' }'
            );
        }
    }

    /**
     * Process module data
     *
     * @param   \Joomla\Registry\Registry  $params  Module parameters
     *
     * @return  mixed
     */
    protected function processData($params)
    {
        // Your business logic here
        return [];
    }
}
```

### Dispatcher-side Helper Injection (HelperFactoryAware)

If your module's data retrieval lives in a Helper class (not inline in the Dispatcher), wire the Helper into the Dispatcher via Joomla's `HelperFactoryAwareInterface` + `HelperFactoryAwareTrait` rather than instantiating it manually. This is the pattern Joomla core uses and the cleanest way to keep data logic out of `getLayoutData()`.

**Provider** (`services/provider.php`) — register both factories:

```php
use Joomla\CMS\Extension\Service\Provider\HelperFactory;
use Joomla\CMS\Extension\Service\Provider\Module;
use Joomla\CMS\Extension\Service\Provider\ModuleDispatcherFactory;

$container->registerServiceProvider(new ModuleDispatcherFactory('\\Cybersalt\\Module\\Example'));
$container->registerServiceProvider(new HelperFactory('\\Cybersalt\\Module\\Example\\Site\\Helper'));
$container->registerServiceProvider(new Module());
```

**Dispatcher** — implement the interface, use the trait, pull the helper:

```php
namespace Cybersalt\Module\Example\Site\Dispatcher;

\defined('_JEXEC') or die;

use Joomla\CMS\Dispatcher\AbstractModuleDispatcher;
use Joomla\CMS\Helper\HelperFactoryAwareInterface;
use Joomla\CMS\Helper\HelperFactoryAwareTrait;

class Dispatcher extends AbstractModuleDispatcher implements HelperFactoryAwareInterface
{
    use HelperFactoryAwareTrait;

    protected function getLayoutData(): array
    {
        $data = parent::getLayoutData();

        // Joomla injects the HelperFactory automatically — pull a helper by name.
        $data['items'] = $this->getHelperFactory()
            ->getHelper('ExampleHelper')
            ->getItems($data['params'], $this->getApplication());

        return $data;
    }
}
```

**Helper** — pure data retrieval, with `DatabaseAwareTrait` for DB access:

```php
namespace Cybersalt\Module\Example\Site\Helper;

\defined('_JEXEC') or die;

use Joomla\CMS\Application\CMSApplicationInterface;
use Joomla\Database\DatabaseAwareInterface;
use Joomla\Database\DatabaseAwareTrait;
use Joomla\Registry\Registry;

class ExampleHelper implements DatabaseAwareInterface
{
    use DatabaseAwareTrait;

    public function getItems(Registry $params, CMSApplicationInterface $app): array
    {
        $count = (int) $params->get('count', 5);
        $db    = $this->getDatabase();

        $query = $db->createQuery()
            ->select($db->quoteName(['id', 'title', 'alias']))
            ->from($db->quoteName('#__example_items'))
            ->where($db->quoteName('published') . ' = 1')
            ->order($db->quoteName('created') . ' DESC')
            ->setLimit($count);

        $db->setQuery($query);

        return $db->loadObjectList() ?: [];
    }
}
```

> [!IMPORTANT]
> The helper **must** implement `DatabaseAwareInterface`, not just `use` the trait. The container only injects `$db` when the interface is present — otherwise `$this->getDatabase()` returns `null` and every query fails silently. Same gotcha that bites com_ajax helpers below.

**Why use this over manual instantiation?** The dispatcher's helper factory is preconfigured with the module's namespace, so `getHelper('ExampleHelper')` resolves to `Cybersalt\Module\Example\Site\Helper\ExampleHelper` automatically. You don't `new` anything, you don't `use` the FQCN at the top of the dispatcher, and switching helpers is a one-string change.

---

## Template File (tmpl/default.php)

```php
<?php

/**
 * @package     YourCompany.Module
 * @subpackage  mod_example
 *
 * @copyright   (C) 2025 Your Company. All rights reserved.
 * @license     GNU General Public License version 2 or later
 */

\defined('_JEXEC') or die;

// Variables available from Dispatcher::getLayoutData()
/** @var array $myCustomData */
/** @var int $moduleId */

// Don't render if no content (per Joomla Brain standards)
if (empty($myCustomData)) {
    return;
}

$moduleClass = $params->get('moduleclass_sfx', '');
?>
<div id="mod-example-<?php echo $moduleId; ?>"
     class="mod-example <?php echo htmlspecialchars($moduleClass); ?>">

    <!-- Your module output here -->

</div>
```

### Template Best Practices

1. **Conditional rendering**: Output nothing when there's no content to display
2. **Unique wrapper ID**: Use `mod-{name}-{moduleId}` pattern for CSS scoping
3. **Escape output**: Always use `htmlspecialchars()` for user-provided content
4. **Module class suffix**: Support the standard `moduleclass_sfx` parameter

## Language Files

### Frontend Strings (language/en-GB/mod_example.ini)

```ini
; Module Name - Language Strings
; Copyright (C) 2025 Your Company. All rights reserved.
; License GNU General Public License version 2 or later

MOD_EXAMPLE="Example Module"
MOD_EXAMPLE_DESC="Description of what this module does."

; Field labels and descriptions
MOD_EXAMPLE_FIELD_CUSTOM_CSS_LABEL="Custom CSS"
MOD_EXAMPLE_FIELD_CUSTOM_CSS_DESC="Add custom CSS styles for this module instance."

; Add all your translatable strings here
```

### System Strings (language/en-GB/mod_example.sys.ini)

```ini
; Module Name - System strings (installer/admin)
; Copyright (C) 2025 Your Company. All rights reserved.
; License GNU General Public License version 2 or later

MOD_EXAMPLE="Example Module"
MOD_EXAMPLE_DESC="Description of what this module does."
MOD_EXAMPLE_XML_DESCRIPTION="Extended description shown during installation."
```

### Language File Requirements

- **UTF-8 encoding without BOM** (byte order mark)
- All user-facing text must use language constants
- Use `UPPERCASE_WITH_UNDERSCORES` naming convention
- Never hardcode text in PHP or template files

## Form Field Best Practices

### Multi-Select Fields (Joomla 5+)

Always use the fancy-select layout for multi-select fields:

```xml
<field
    name="items"
    type="list"
    label="MOD_EXAMPLE_FIELD_ITEMS_LABEL"
    description="MOD_EXAMPLE_FIELD_ITEMS_DESC"
    multiple="true"
    layout="joomla.form.field.list-fancy-select"
    default=""
>
    <option value="item1">MOD_EXAMPLE_ITEM_ONE</option>
    <option value="item2">MOD_EXAMPLE_ITEM_TWO</option>
</field>
```

### Yes/No Radio Buttons

```xml
<field
    name="show_feature"
    type="radio"
    label="MOD_EXAMPLE_FIELD_SHOW_FEATURE_LABEL"
    description="MOD_EXAMPLE_FIELD_SHOW_FEATURE_DESC"
    default="1"
    class="btn-group btn-group-yesno"
>
    <option value="1">JYES</option>
    <option value="0">JNO</option>
</field>
```

### Subform Fields (Repeatable/Sortable Items)

Use subform for lists of items that users can add, remove, and reorder:

```xml
<field
    name="items"
    type="subform"
    label="MOD_EXAMPLE_FIELD_ITEMS_LABEL"
    description="MOD_EXAMPLE_FIELD_ITEMS_DESC"
    multiple="true"
    layout="joomla.form.field.subform.repeatable"
    buttons="add,remove,move"
    max="50"
>
    <form>
        <field
            name="item_type"
            type="list"
            label="MOD_EXAMPLE_FIELD_TYPE_LABEL"
            default="preset"
        >
            <option value="preset">MOD_EXAMPLE_TYPE_PRESET</option>
            <option value="custom">MOD_EXAMPLE_TYPE_CUSTOM</option>
        </field>

        <field
            name="preset_value"
            type="list"
            label="MOD_EXAMPLE_FIELD_PRESET_LABEL"
            showon="item_type:preset"
        >
            <option value="option1">Option 1</option>
            <option value="option2">Option 2</option>
        </field>

        <field
            name="custom_value"
            type="text"
            label="MOD_EXAMPLE_FIELD_CUSTOM_LABEL"
            showon="item_type:custom"
        />
    </form>
</field>
```

**Key attributes**:
- `buttons="add,remove,move"` - Enables drag-and-drop reordering with move handles
- `layout="joomla.form.field.subform.repeatable"` - Modern repeatable layout
- `showon="field_name:value"` - Conditionally show/hide fields based on another field's value
- `max="50"` - Maximum number of items allowed

**Processing subform data in Dispatcher**:

```php
$itemsData = $params->get('items', []);
$items = [];

foreach ($itemsData as $item) {
    $type = $item->item_type ?? 'preset';

    if ($type === 'preset') {
        $items[] = [
            'value' => $item->preset_value,
            'type' => 'preset'
        ];
    } else {
        $items[] = [
            'value' => $item->custom_value,
            'type' => 'custom'
        ];
    }
}
```

### Grouped List Fields (Optgroups)

Use `groupedlist` type when you need dropdown options organized into sections:

```xml
<field
    name="location"
    type="groupedlist"
    label="MOD_EXAMPLE_FIELD_LOCATION_LABEL"
>
    <group label="North America">
        <option value="us">United States</option>
        <option value="ca">Canada</option>
        <option value="mx">Mexico</option>
    </group>
    <group label="Europe">
        <option value="uk">United Kingdom</option>
        <option value="de">Germany</option>
        <option value="fr">France</option>
    </group>
</field>
```

**IMPORTANT**: Do NOT use `list` type with `layout="joomla.form.field.list-fancy-select"` for grouped options. The Choices.js fancy-select doesn't properly handle disabled separator options. Use `groupedlist` which renders native HTML `<optgroup>` elements.

### Conditional Field Display (showon)

The `showon` attribute hides/shows fields based on other field values:

```xml
<!-- Show when another field equals a specific value -->
<field name="details" showon="show_details:1" ... />

<!-- Show when field equals one of multiple values -->
<field name="options" showon="type:option1,option2" ... />

<!-- Show when field does NOT equal a value -->
<field name="other" showon="type!:disabled" ... />

<!-- Multiple conditions (AND) -->
<field name="advanced" showon="show_advanced:1[AND]level:expert" ... />

<!-- Multiple conditions (OR) -->
<field name="either" showon="type:a[OR]type:b" ... />
```

### Custom CSS Field (REQUIRED)

Per Joomla Brain standards, all modules MUST include a custom CSS field:

```xml
<field
    name="custom_css"
    type="textarea"
    label="MOD_EXAMPLE_FIELD_CUSTOM_CSS_LABEL"
    description="MOD_EXAMPLE_FIELD_CUSTOM_CSS_DESC"
    rows="10"
    filter="raw"
    class="input-xxlarge"
/>
```

## CSS Best Practices

### Use CSS Variables for Theme Compatibility

```css
.mod-example {
    --mod-bg: var(--body-bg, #ffffff);
    --mod-text: var(--body-color, #333333);
    --mod-border: var(--border-color, #dee2e6);
    --mod-accent: var(--link-color, #0d6efd);
}

.mod-example__content {
    background: var(--mod-bg);
    color: var(--mod-text);
    border: 1px solid var(--mod-border);
}
```

### Dark Mode Support

For Joomla's Atum admin template dark mode:

```css
background: var(--atum-bg-dark, var(--body-bg, #fafafa));
```

## Live Preview in Admin Forms

For modules with styling options, implement live preview using a combination of techniques:

### HTML Preview Element

Add a spacer field with preview HTML in your manifest:

```xml
<field
    name="style_preview"
    type="spacer"
    label="MOD_EXAMPLE_PREVIEW_HTML"
/>
```

Language string with embedded HTML:

```ini
MOD_EXAMPLE_PREVIEW_HTML="<div id='mod-example-preview' style='padding:20px;border:1px solid #ddd;border-radius:8px;margin:10px 0;'><div class='preview-element'>Preview Content</div></div>"
```

### JavaScript Live Preview

Use MutationObserver + click events + polling for reliable updates:

```javascript
document.addEventListener('DOMContentLoaded', function() {
    const preview = document.getElementById('mod-example-preview');
    if (!preview) return;

    function updatePreview() {
        // Get current form values
        const bgColor = document.querySelector('[name="jform[params][bg_color]"]')?.value || '';
        const fontSize = document.querySelector('[name="jform[params][font_size]"]')?.value || '';

        // Apply to preview element
        if (bgColor) preview.style.backgroundColor = bgColor;
        if (fontSize) preview.querySelector('.preview-element').style.fontSize = fontSize;
    }

    // Method 1: MutationObserver for DOM changes
    const observer = new MutationObserver(updatePreview);
    const form = document.querySelector('#module-form');
    if (form) {
        observer.observe(form, { childList: true, subtree: true, attributes: true });
    }

    // Method 2: Click events on inputs
    document.querySelectorAll('.options-form input, .options-form select').forEach(el => {
        el.addEventListener('click', () => setTimeout(updatePreview, 100));
        el.addEventListener('change', updatePreview);
        el.addEventListener('input', updatePreview);
    });

    // Method 3: Polling fallback (for color pickers and other widgets)
    setInterval(updatePreview, 500);

    // Initial update
    updatePreview();
});
```

**Why all three methods?**
- **MutationObserver**: Catches Joomla's dynamic form field updates
- **Click events**: Immediate response for simple inputs
- **Polling**: Catches color picker updates and other widgets that don't fire standard events

## Package Building

**CRITICAL**: Never use PowerShell's `Compress-Archive` or .NET's `ZipFile.CreateFromDirectory`. These fail to create proper directory entries, causing installation errors.

### Always Use 7-Zip

```powershell
# From the module root directory
& 'C:\Program Files\7-Zip\7z.exe' a -tzip '../mod_example_v1.0.0.zip' *
```

### Verify Package Structure

```powershell
& 'C:\Program Files\7-Zip\7z.exe' l 'mod_example_v1.0.0.zip'
```

Look for `D....` markers indicating proper directory entries:

```
   Date      Time    Attr         Size   Compressed  Name
------------------- ----- ------------ ------------  ------------------------
2025-01-01 12:00:00 D....            0            0  services
2025-01-01 12:00:00 D....            0            0  src
2025-01-01 12:00:00 D....            0            0  src\Dispatcher
```

## Common Installation Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Unexpected token '<'... is not valid JSON" | ZIP created without directory entries | Rebuild using 7-Zip |
| "Unable to detect manifest file" | Malformed XML or missing files | Validate XML syntax; check all files exist |
| "Class not found" | Namespace mismatch | Verify namespace in manifest matches provider.php and Dispatcher.php |
| Module shows raw language keys | Language files not loading | Check file paths in manifest; verify UTF-8 encoding |
| Module not displaying (no errors) | Wrong Dispatcher location or namespace | File must be at `src/Dispatcher/Dispatcher.php` with namespace `...\Site\Dispatcher` |
| "Cannot declare class... already in use" | Entry point manually boots module | Remove manual bootModule() calls; use Dispatcher pattern only |
| Media files not loading | Wrong media section syntax | Use `<folder>` tags not `<filename>` for directories |

## Checklist Before Release

- [ ] No `mod_example.php` entry point file (use Dispatcher pattern)
- [ ] Dispatcher at `src/Dispatcher/Dispatcher.php` (NOT `src/Site/Dispatcher/`)
- [ ] Dispatcher namespace includes `\Site\Dispatcher` (e.g., `YourCompany\Module\Example\Site\Dispatcher`)
- [ ] `module` attribute on services folder in manifest
- [ ] Media section uses `<folder>` tags (not `<filename>`)
- [ ] All text uses language constants (no hardcoded strings)
- [ ] Custom CSS fieldset is present
- [ ] Multi-select fields use `fancy-select` layout
- [ ] Language files are UTF-8 without BOM
- [ ] Package built with 7-Zip (not PowerShell)
- [ ] Namespace consistent across all files
- [ ] Conditional rendering when no content
- [ ] CSS uses variables for theme compatibility
- [ ] Module outputs nothing when empty (no wrapper divs)

---

## Pattern 2: Helper Pattern (Legacy)

This older pattern uses an entry point file with explicit `require_once`. Documented here for reference when maintaining existing modules, but **use the Dispatcher pattern for new development**.

### File Structure

```
mod_mymodule/
├── mod_mymodule.xml          # Module manifest
├── mod_mymodule.php          # Entry point
├── src/
│   └── Site/                 # IMPORTANT: Site subfolder for frontend modules
│       └── Helper/
│           └── MymoduleHelper.php
├── tmpl/
│   └── default.php           # Default template
└── language/
    └── en-GB/
        ├── mod_mymodule.ini
        └── mod_mymodule.sys.ini
```

**IMPORTANT**: For site (frontend) modules, helper classes go in `src/Site/Helper/`, not just `src/Helper/`. The `Site` folder is part of the Joomla 5 namespace convention.

### Manifest (mod_mymodule.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<extension type="module" client="site" method="upgrade">
    <name>MOD_MYMODULE</name>
    <author>Your Name</author>
    <creationDate>2025-01</creationDate>
    <copyright>(C) 2025 Your Company. All rights reserved.</copyright>
    <license>GNU General Public License version 2 or later</license>
    <authorEmail>you@example.com</authorEmail>
    <authorUrl>https://example.com</authorUrl>
    <version>1.0.0</version>
    <description>MOD_MYMODULE_DESC</description>
    <namespace path="src">YourCompany\Module\MyModule</namespace>

    <files>
        <filename module="mod_mymodule">mod_mymodule.php</filename>
        <folder>src</folder>
        <folder>tmpl</folder>
    </files>

    <languages>
        <language tag="en-GB">language/en-GB/mod_mymodule.ini</language>
        <language tag="en-GB">language/en-GB/mod_mymodule.sys.ini</language>
    </languages>

    <config>
        <fields name="params">
            <fieldset name="basic">
                <!-- Your parameter fields here -->
            </fieldset>
        </fields>
    </config>
</extension>
```

### Entry Point (mod_mymodule.php)

```php
<?php
/**
 * @package     YourCompany.Module.MyModule
 * @subpackage  mod_mymodule
 *
 * @copyright   (C) 2025 Your Company. All rights reserved.
 * @license     GNU General Public License version 2 or later
 */

\defined('_JEXEC') or die;

use Joomla\CMS\Helper\ModuleHelper;
use YourCompany\Module\MyModule\Site\Helper\MymoduleHelper;

// IMPORTANT: Explicit require - Joomla's namespace autoloader is unreliable for modules
require_once __DIR__ . '/src/Site/Helper/MymoduleHelper.php';

/** @var \Joomla\Registry\Registry $params */
/** @var \stdClass $module */

// Get data from helper
$items = MymoduleHelper::getItems($params);
$moduleclass_sfx = htmlspecialchars($params->get('moduleclass_sfx', ''), ENT_COMPAT, 'UTF-8');

// Load the template
require ModuleHelper::getLayoutPath('mod_mymodule', $params->get('layout', 'default'));
```

**Why require_once?** Joomla 5's namespace autoloader (declared via `<namespace>` in the manifest) does **not reliably work for modules** in all hosting environments. The `use` statement provides IDE autocompletion while `require_once` ensures the class loads.

### Helper Class (src/Site/Helper/MymoduleHelper.php)

```php
<?php
/**
 * @package     YourCompany.Module.MyModule
 * @subpackage  mod_mymodule
 *
 * @copyright   (C) 2025 Your Company. All rights reserved.
 * @license     GNU General Public License version 2 or later
 */

namespace YourCompany\Module\MyModule\Site\Helper;

\defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\Registry\Registry;

class MymoduleHelper
{
    public static function getItems(Registry $params): array
    {
        // Your logic here
        return [];
    }
}
```

### Common "Class Not Found" Error (Helper Pattern)

If you get `Class "...\Site\Helper\MymoduleHelper" not found`:

1. **Check file location**: Must be `src/Site/Helper/`, not `src/Helper/`
2. **Check namespace in PHP file**: Must include `Site` - `namespace YourCompany\Module\MyModule\Site\Helper;`
3. **Add require_once**: The autoloader is unreliable - add explicit require in entry point
4. **Uninstall and reinstall**: Namespace registration happens at install time

---

## Detecting Current Page Context

Modules often need to know what category or article is being displayed:

```php
use Joomla\CMS\Factory;

public static function getCurrentCategoryId(): ?int
{
    $app = Factory::getApplication();
    $input = $app->getInput();

    $option = $input->getCmd('option', '');
    $view = $input->getCmd('view', '');
    $id = $input->getInt('id', 0);

    if ($option !== 'com_content' || $id === 0) {
        return null;
    }

    // On category blog/list view, the id IS the category id
    if ($view === 'category') {
        return $id;
    }

    // On article view, query the database for the article's category
    if ($view === 'article') {
        try {
            $db = Factory::getContainer()->get('DatabaseDriver');
            $query = $db->getQuery(true)
                ->select($db->quoteName('catid'))
                ->from($db->quoteName('#__content'))
                ->where($db->quoteName('id') . ' = ' . $id);
            $db->setQuery($query);

            $catId = $db->loadResult();
            return $catId ? (int) $catId : null;
        } catch (\Exception $e) {
            return null;
        }
    }

    return null;
}
```

---

## Dynamic Inline Styles

For modules with configurable CSS, generate unique IDs:

```php
// In mod_mymodule.php or Dispatcher
$moduleId = 'mod-mymodule-' . $module->id;

$cssParams = [
    'bg_color'    => $params->get('bg_color', '#ffffff'),
    'text_color'  => $params->get('text_color', '#000000'),
];
```

```php
// In tmpl/default.php
?>
<style>
#<?php echo $moduleId; ?> {
    background-color: <?php echo htmlspecialchars($cssParams['bg_color'], ENT_QUOTES, 'UTF-8'); ?>;
    color: <?php echo htmlspecialchars($cssParams['text_color'], ENT_QUOTES, 'UTF-8'); ?>;
}
</style>

<div id="<?php echo $moduleId; ?>" class="mod-mymodule<?php echo $moduleclass_sfx; ?>">
    <!-- content -->
</div>
```

---

## Building URL Links

### Using Joomla's Router

```php
use Joomla\CMS\Router\Route;

$url = 'index.php?option=com_content&view=category&id=' . $categoryId;
$url .= '&letter=' . urlencode($letter);

$routedUrl = Route::_($url);
```

### With Menu Item

```php
$menuItemId = $params->get('target_menu_item', '');

$url = 'index.php';
if (!empty($menuItemId)) {
    $url .= '?Itemid=' . (int) $menuItemId;
    $url .= '&myfilter=' . urlencode($value);
} else {
    $url .= '?myfilter=' . urlencode($value);
}

return Route::_($url);
```

---

## Template Variables (Dispatcher Pattern)

With the Dispatcher pattern, `getLayoutData()` returns an array. In the template, these are available as **extracted variables** — NOT as `$displayData`.

### WRONG — Will produce "Undefined variable $displayData"

```php
$hotspots = $displayData['hotspots'];  // WRONG!
$moduleId = $displayData['module']->id; // WRONG!
```

### CORRECT — Variables are extracted directly

```php
// Variables from getLayoutData() are available directly:
$myData    = $myData ?? [];           // Use null coalescing for safety
$moduleId  = $module->id ?? 0;        // $module is always available
$params    = $params;                 // $params is always available
```

Also, `$this->escape()` is NOT available in module templates. Use a local helper:

```php
$e = function (string $text): string {
    return htmlspecialchars($text, ENT_QUOTES, 'UTF-8');
};
// Then use: <?php echo $e($value); ?>
```

---

## Custom Form Field Types

Modules can define custom form field types in `src/Field/`. The class name must match the type with `Field` suffix and lowercase type in the `$type` property.

### File Location

```
src/Field/ImagemapeditorField.php  → type="imagemapeditor"
src/Field/ViewerbuttonField.php    → type="viewerbutton"
```

### Namespace

```php
namespace Cybersalt\Module\Example\Site\Field;
```

Note: `Site` is in the namespace but NOT in the file path (same rule as Dispatcher).

### Manifest Registration

Add `addfieldprefix` to the `<fields>` tag:

```xml
<fields name="params" addfieldprefix="Cybersalt\Module\Example\Site\Field">
    <fieldset name="basic">
        <field
            name="myfield"
            type="imagemapeditor"
            label="MY_FIELD_LABEL"
            filter="raw"
        />
    </fieldset>
</fields>
```

### Passing Data to JavaScript

When building complex admin UIs (visual editors, pickers, etc.), embed data as HTML data attributes rather than using AJAX:

```php
class ImagemapeditorField extends FormField
{
    protected function getInput(): string
    {
        // Query data server-side
        $items = $this->getMenuItems();

        // Embed as data attributes — no AJAX needed
        $itemsJson = $this->escape(json_encode($items));
        $strings   = json_encode(['save' => Text::_('MY_SAVE'), ...]);

        return <<<HTML
        <div id="{$this->id}-editor"
             data-strings='{$strings}'
             data-items='{$itemsJson}'>
            <!-- Editor UI -->
        </div>
        <input type="hidden" name="{$this->name}" id="{$this->id}" value="{$this->escape($this->value)}">
        HTML;
    }
}
```

In JavaScript, read the data:

```javascript
var editor = document.querySelector('#myfield-editor');
var items  = JSON.parse(editor.getAttribute('data-items') || '[]');
var strings = JSON.parse(editor.getAttribute('data-strings') || '{}');
```

**Why not AJAX?** We tried three AJAX approaches that all failed:
1. **com_ajax with HelperFactory** — requires the module to be **published** on the site side. Useless when configuring a module that isn't published yet. Returns `[]` otherwise.
2. **Standalone ajax.php bootstrapping Joomla** — fragile path resolution, session sharing issues between admin and site apps, CSP restrictions on some hosts.
3. **Popup window with Joomla modal views** — `window.parent` doesn't work from popups (it's itself, not the opener), callback injection is unreliable across page navigations.

The data-attribute approach is instant, needs zero network requests, works regardless of module publish state, and has no session/CSRF issues since it's rendered server-side in the admin form.

---

## com_ajax for Modules

If you DO need AJAX for a module (e.g., the module is always published), here's the setup:

### 1. Register HelperFactory in provider.php

```php
use Joomla\CMS\Extension\Service\Provider\HelperFactory;

$container->registerServiceProvider(new HelperFactory('\\YourCompany\\Module\\Example\\Site\\Helper'));
```

### 2. Create Helper class

```php
namespace YourCompany\Module\Example\Site\Helper;

use Joomla\Database\DatabaseAwareInterface;
use Joomla\Database\DatabaseAwareTrait;

class ExampleHelper implements DatabaseAwareInterface
{
    use DatabaseAwareTrait;

    public function myMethodAjax(): string
    {
        $db = $this->getDatabase();
        // ... query and return JSON string
        return json_encode($result);
    }
}
```

**CRITICAL**: The Helper class MUST implement `DatabaseAwareInterface` (not just use the trait), otherwise the database connection is never injected and all queries fail silently.

### 3. Call from JavaScript

```
GET /index.php?option=com_ajax&module=example&method=myMethod&format=raw&{csrf_token}=1
```

### Gotchas

- The module **must be published** (enabled) on the site for com_ajax to find it
- The URL is site-side (`/index.php`), not admin-side (`/administrator/index.php`)
- Return type should be `string` (pre-encoded JSON), not `array` — com_ajax wraps arrays in its own response structure
- The response format with `format=raw` is: the raw return value. With `format=json` it's `{success:true, data:["your_string"]}`

---

## script.php: Handling Uninstall

The `postflight()` method runs for ALL types including uninstall. Always check the type:

```php
public function postflight(string $type, InstallerAdapter $adapter): void
{
    if ($type === 'uninstall') {
        return;
    }

    $this->showPostInstallMessage($type);
}
```

Without this check, uninstalling shows the "successfully installed" message with a link to open the (now-deleted) extension.

---

## Image Path Handling

Joomla's media field stores paths in various formats depending on version and context:

| Stored value | What it means |
|---|---|
| `images/imagemaps/photo.jpg` | Full path from site root (includes `images/`) |
| `imagemaps/photo.jpg` | Relative to `images/` directory |
| `/images/imagemaps/photo.jpg` | Absolute path |

### Normalizing for frontend output

```php
$imageSrc = $image;
if (strpos($imageSrc, 'http') !== 0 && strpos($imageSrc, '/') !== 0) {
    if (strpos($imageSrc, 'images/') !== 0) {
        $imageSrc = 'images/' . $imageSrc;
    }
    $imageSrc = '/' . $imageSrc;
}
```

### Normalizing for admin JS preview

```javascript
if (src.indexOf('http') === 0 || src.indexOf('//') === 0) {
    // Full URL — use as-is
} else if (src.indexOf('/') === 0) {
    // Absolute path — use as-is
} else if (src.indexOf('images/') === 0) {
    src = '/' + src;
} else {
    src = '/images/' + src;
}
```

### Watching for media field changes

Joomla's media field updates unpredictably. Use multiple detection methods:

```javascript
var imageInput = document.querySelector('[name="jform[params][image]"]');
// 1. Change event
imageInput.addEventListener('change', function () { updateImage(this.value); });
// 2. MutationObserver on parent joomla-field-media element
var observer = new MutationObserver(function () { updateImage(imageInput.value); });
observer.observe(imageInput.closest('joomla-field-media') || imageInput, { attributes: true, childList: true, subtree: true });
// 3. Polling fallback
setInterval(function () { /* check imageInput.value */ }, 500);
```

---

## Example Repositories

- [cs-world-clocks](https://github.com/cybersalt/cs-world-clocks) - World Clocks module using Dispatcher pattern
- [cs-image-map-hotlinking](https://github.com/cybersalt/cs-image-map-hotlinking) - Image map module with visual editor, custom form fields, inline data embedding
