# Joomla 3 Plugin Development Guide

## Overview

Joomla 3 plugins use the legacy `JPlugin` base class with method-based event handlers. No namespaces, no DI container - simpler than Joomla 4/5.

---

## Plugin Structure

```
plg_content_myplugin/
├── myplugin.xml              ← Manifest (filename matches plugin attribute)
├── myplugin.php              ← Main plugin class
├── index.html                ← Security blank file
└── language/
    ├── index.html
    └── en-GB/
        ├── index.html
        └── plg_content_myplugin.ini
```

---

## Manifest XML (Joomla 3)

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="plugin" version="3.1" group="content" method="upgrade">
    <name>PLG_CONTENT_MYPLUGIN</name>
    <author>Your Name</author>
    <creationDate>2025</creationDate>
    <copyright>(C) 2025 Your Company</copyright>
    <license>GNU General Public License version 2 or later</license>
    <authorEmail>you@example.com</authorEmail>
    <authorUrl>https://example.com</authorUrl>
    <version>1.0.0</version>
    <description>PLG_CONTENT_MYPLUGIN_XML_DESCRIPTION</description>

    <files>
        <filename plugin="myplugin">myplugin.php</filename>
        <filename>index.html</filename>
        <folder>language</folder>
    </files>

    <config>
        <fields name="params">
            <fieldset name="basic" label="PLG_CONTENT_MYPLUGIN_SETTINGS">
                <field name="show_feature" type="radio"
                       label="PLG_CONTENT_MYPLUGIN_SHOW_FEATURE"
                       description="PLG_CONTENT_MYPLUGIN_SHOW_FEATURE_DESC"
                       class="btn-group btn-group-yesno"
                       default="1">
                    <option value="1">JYES</option>
                    <option value="0">JNO</option>
                </field>

                <field name="custom_text" type="text"
                       label="PLG_CONTENT_MYPLUGIN_CUSTOM_TEXT"
                       description="PLG_CONTENT_MYPLUGIN_CUSTOM_TEXT_DESC"
                       default="" />
            </fieldset>
        </fields>
    </config>
</extension>
```

**Key Points:**
- `version="3.1"` - Joomla 3 manifest format
- `group="content"` - Plugin group (content, system, authentication, etc.)
- `plugin="myplugin"` attribute on main PHP file identifies the plugin element
- No `element` attribute needed on extension tag

---

## Main Plugin Class (myplugin.php)

```php
<?php
/**
 * @package     Joomla.Plugin
 * @subpackage  Content.Myplugin
 */

defined('_JEXEC') or die;

class PlgContentMyplugin extends JPlugin
{
    /**
     * Auto-load language files
     */
    protected $autoloadLanguage = true;

    /**
     * Database object
     */
    protected $db;

    /**
     * Application object
     */
    protected $app;

    /**
     * onContentPrepare event handler
     *
     * @param   string   $context  The context of the content
     * @param   object   $article  The article object
     * @param   mixed    $params   The article params (Registry or null)
     * @param   integer  $page     The page number
     *
     * @return  boolean
     */
    public function onContentPrepare($context, &$article, &$params, $page = 0)
    {
        // Skip if not in article context
        if ($context !== 'com_content.article') {
            return true;
        }

        // Check if feature is enabled
        if (!$this->params->get('show_feature', 1)) {
            return true;
        }

        // Modify article text
        $customText = $this->params->get('custom_text', '');
        if (!empty($customText)) {
            $article->text .= '<p>' . htmlspecialchars($customText) . '</p>';
        }

        return true;
    }

    /**
     * onContentBeforeDisplay event handler
     *
     * @param   string   $context  The context
     * @param   object   $article  The article
     * @param   mixed    $params   The params
     * @param   integer  $page     The page
     *
     * @return  string   HTML to add before content
     */
    public function onContentBeforeDisplay($context, &$article, &$params, $page = 0)
    {
        if ($context !== 'com_content.article') {
            return '';
        }

        return '<div class="my-plugin-output">Before Content</div>';
    }
}
```

---

## Plugin Groups and Events

### Content Plugins (`group="content"`)

| Event | When Triggered | Use Case |
|-------|----------------|----------|
| `onContentPrepare` | Before content is displayed | Text replacement, shortcodes |
| `onContentBeforeDisplay` | Before article display | Add custom HTML before |
| `onContentAfterDisplay` | After article display | Add custom HTML after |
| `onContentBeforeSave` | Before content is saved | Validation, modification |
| `onContentAfterSave` | After content is saved | Notifications, logging |
| `onContentAfterTitle` | After title, before intro | Display above intro |

### System Plugins (`group="system"`)

| Event | When Triggered | Use Case |
|-------|----------------|----------|
| `onAfterInitialise` | After Joomla initializes | Early processing |
| `onAfterRoute` | After routing | URL manipulation |
| `onBeforeRender` | Before output renders | Add scripts/styles |
| `onAfterRender` | After output renders | Modify final HTML |
| `onBeforeCompileHead` | Before head compiles | Add meta tags |

### Authentication Plugins (`group="authentication"`)

| Event | When Triggered | Use Case |
|-------|----------------|----------|
| `onUserAuthenticate` | During login | Custom auth methods |

### User Plugins (`group="user"`)

| Event | When Triggered | Use Case |
|-------|----------------|----------|
| `onUserLogin` | After successful login | Post-login actions |
| `onUserLogout` | After logout | Cleanup |
| `onUserAfterSave` | After user is saved | Profile sync |

---

## Accessing Plugin Parameters

```php
// In plugin class
class PlgContentMyplugin extends JPlugin
{
    public function onContentPrepare($context, &$article, &$params, $page)
    {
        // Get plugin parameters
        $showFeature = $this->params->get('show_feature', 1);
        $customText = $this->params->get('custom_text', '');
        $maxItems = $this->params->get('max_items', 10);

        // Parameters are type-cast based on field type
        // Radio/list fields return string values ('0', '1')
        // Use explicit comparison or casting
        if ((int)$showFeature === 1) {
            // Feature is enabled
        }
    }
}
```

---

## Common Field Types in Plugin Config

```xml
<config>
    <fields name="params">
        <fieldset name="basic">
            <!-- Yes/No Radio Toggle -->
            <field name="enabled" type="radio"
                   label="Enable Feature"
                   class="btn-group btn-group-yesno"
                   default="1">
                <option value="1">JYES</option>
                <option value="0">JNO</option>
            </field>

            <!-- Text Input -->
            <field name="title" type="text"
                   label="Title"
                   default=""
                   filter="string" />

            <!-- Textarea -->
            <field name="description" type="textarea"
                   label="Description"
                   rows="5"
                   cols="50" />

            <!-- Select/Dropdown -->
            <field name="style" type="list"
                   label="Style"
                   default="default">
                <option value="default">Default</option>
                <option value="modern">Modern</option>
                <option value="classic">Classic</option>
            </field>

            <!-- Number -->
            <field name="count" type="number"
                   label="Count"
                   default="5"
                   min="1"
                   max="100" />

            <!-- Color Picker -->
            <field name="color" type="color"
                   label="Color"
                   default="#000000" />

            <!-- Category Selection -->
            <field name="catid" type="category"
                   label="Category"
                   extension="com_content"
                   published="1"
                   default="">
                <option value="">- Select -</option>
            </field>

            <!-- User Groups -->
            <field name="access" type="accesslevel"
                   label="Access Level"
                   default="1" />

            <!-- Editor -->
            <field name="content" type="editor"
                   label="Content"
                   filter="safehtml"
                   buttons="true" />
        </fieldset>
    </fields>
</config>
```

---

## Adding JavaScript and CSS

```php
public function onBeforeRender()
{
    $document = JFactory::getDocument();

    // Only in HTML documents
    if ($document->getType() !== 'html') {
        return;
    }

    // Add stylesheet
    $document->addStyleSheet(
        JUri::root(true) . '/plugins/content/myplugin/assets/style.css'
    );

    // Add inline CSS
    $document->addStyleDeclaration('
        .my-plugin-class {
            color: red;
        }
    ');

    // Add script
    $document->addScript(
        JUri::root(true) . '/plugins/content/myplugin/assets/script.js'
    );

    // Add inline script
    $document->addScriptDeclaration('
        jQuery(document).ready(function($) {
            console.log("Plugin loaded");
        });
    ');

    // Add script options (Joomla 3.7+)
    $document->addScriptOptions('plg_content_myplugin', array(
        'option1' => 'value1',
        'option2' => 'value2'
    ));
}
```

---

## Database Operations in Plugins

```php
public function onContentAfterSave($context, $article, $isNew)
{
    // Get database object
    $db = JFactory::getDbo();

    // Build query
    $query = $db->getQuery(true);

    // SELECT example
    $query->select('*')
          ->from($db->quoteName('#__content'))
          ->where($db->quoteName('id') . ' = ' . (int)$article->id);

    $db->setQuery($query);
    $result = $db->loadObject();

    // INSERT example
    $query->clear()
          ->insert($db->quoteName('#__mylog'))
          ->columns(array('article_id', 'action', 'created'))
          ->values((int)$article->id . ', ' . $db->quote('save') . ', ' . $db->quote(JFactory::getDate()->toSql()));

    $db->setQuery($query);
    $db->execute();

    return true;
}
```

---

## Language Files

### File Naming
- Format: `plg_{group}_{element}.ini`
- Example: `plg_content_myplugin.ini`
- Location: `language/en-GB/plg_content_myplugin.ini`

### Language File Content

```ini
; Plugin Language File
PLG_CONTENT_MYPLUGIN="My Plugin"
PLG_CONTENT_MYPLUGIN_XML_DESCRIPTION="This plugin does something useful."

; Settings
PLG_CONTENT_MYPLUGIN_SETTINGS="Settings"
PLG_CONTENT_MYPLUGIN_SHOW_FEATURE="Show Feature"
PLG_CONTENT_MYPLUGIN_SHOW_FEATURE_DESC="Enable or disable the feature."
PLG_CONTENT_MYPLUGIN_CUSTOM_TEXT="Custom Text"
PLG_CONTENT_MYPLUGIN_CUSTOM_TEXT_DESC="Enter custom text to display."
```

### Using Language Strings

```php
// In PHP
$text = JText::_('PLG_CONTENT_MYPLUGIN_SHOW_FEATURE');

// With placeholders
$text = JText::sprintf('PLG_CONTENT_MYPLUGIN_COUNT', $count);
// Language string: PLG_CONTENT_MYPLUGIN_COUNT="Found %d items"
```

---

## Package Building

### Use 7-Zip (Required)

PowerShell's `Compress-Archive` doesn't create proper directory entries, causing installation failures.

```powershell
# Navigate to plugin folder
cd plg_content_myplugin

# Create ZIP with 7-Zip
& "C:\Program Files\7-Zip\7z.exe" a -tzip "..\plg_content_myplugin.zip" *
```

### Package Structure in ZIP

```
plg_content_myplugin.zip
├── myplugin.xml         ← Manifest at root
├── myplugin.php         ← Main class at root
├── index.html
└── language/
    ├── index.html
    └── en-GB/
        ├── index.html
        └── plg_content_myplugin.ini
```

---

## Common Issues

### 1. Plugin Not Triggering

**Causes**:
- Plugin not enabled in Plugin Manager
- Event method name doesn't match exactly
- Plugin order/priority

**Fix**:
```php
// Event method must match exactly (case-sensitive)
public function onContentPrepare(...)  // Correct
public function OnContentPrepare(...)  // Wrong - won't trigger
```

### 2. Parameters Not Saving

**Causes**:
- Missing `name="params"` on `<fields>` tag
- Invalid field type
- XML encoding issues

**Fix**:
```xml
<config>
    <fields name="params">  <!-- name="params" is required! -->
        <fieldset name="basic">
            <!-- fields here -->
        </fieldset>
    </fields>
</config>
```

### 3. Language Strings Not Translating

**Causes**:
- `$autoloadLanguage = true` not set
- Wrong language file path
- Wrong language file name format

**Fix**:
```php
class PlgContentMyplugin extends JPlugin
{
    protected $autoloadLanguage = true;  // Add this line
}
```

### 4. Installation Error: "Unable to detect manifest file"

**Cause**: ZIP created with wrong tool (no directory entries)

**Fix**: Use 7-Zip instead of PowerShell's Compress-Archive

---

## Differences from Joomla 4/5

| Feature | Joomla 3 | Joomla 4/5 |
|---------|----------|------------|
| Base Class | `JPlugin` | `CMSPlugin` with namespace |
| Events | Method-based | SubscriberInterface |
| Event Parameters | Direct arguments | Event object with getters |
| Return Values | Return directly | `$event->addResult()` |
| DI Container | None | Required service provider |
| Namespaces | None | PSR-4 required |

### Event Handler Comparison

**Joomla 3:**
```php
public function onContentPrepare($context, &$article, &$params, $page)
{
    $article->text .= ' Modified!';
    return true;
}
```

**Joomla 5:**
```php
public function onContentPrepare(ContentPrepareEvent $event): void
{
    $article = $event->getItem();
    $article->text .= ' Modified!';
}
```

---

## Resources

- [Joomla 3 Plugin Documentation](https://docs.joomla.org/J3.x:Creating_a_Plugin_for_Joomla)
- [Plugin Events Reference](https://docs.joomla.org/Plugin/Events)
- [Joomla 3 API Reference](https://api.joomla.org/cms-3/)
