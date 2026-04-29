# Joomla 5/6 Editor API Guide

How to read and write to the active WYSIWYG editor from JavaScript, register XTD (extension) buttons that appear below the editor, build modal-based content pickers, and (advanced) implement a custom editor decorator.

> Why this matters for security: anything that injects HTML into the editor is a potential XSS vector if user-supplied content isn't escaped. The patterns in this guide use `replaceSelection()` and `setValue()` which insert raw HTML — make sure any user-supplied data going through them is properly escaped before insertion.

---

## The two APIs

| API | Status | When to use |
|---|---|---|
| `JoomlaEditor` (from `editor-api`) | Modern, preferred | All new code |
| `Joomla.editors.instances['<id>']` | Deprecated, still functional via Proxy wrapper | Existing code being migrated |

The legacy API logs deprecation warnings to the browser console but still works. Don't ship new code against it.

---

## JavaScript: getting and setting editor content

### Modern API

```javascript
import { JoomlaEditor } from 'editor-api';

// Get an editor instance by its underlying textarea ID
const editor = JoomlaEditor.get('jform_description');

// Get the currently focused/active editor (when there are multiple)
const active = JoomlaEditor.getActive();

// Read content
const html = editor.getValue();

// Replace ALL content
editor.setValue('<p>New content</p>');

// Get currently selected text
const selection = editor.getSelection();

// Insert at cursor / replace selection
editor.replaceSelection('<hr id="system-readmore">');

// Disable / enable input
editor.disable(false);  // disable
editor.disable(true);   // enable

// Get the underlying editor library instance (e.g., the raw tinymce object)
const raw = editor.getRawInstance();

// Get the editor type identifier
const type = editor.getType(); // 'tinymce', 'codemirror', 'none'
```

### Legacy API (deprecated)

```javascript
// Logs deprecation warnings to console; behavior identical to modern API
const editor = Joomla.editors.instances['jform_description'];
editor.getValue();
editor.setValue('content');
editor.replaceSelection('inserted text');
```

---

## XTD buttons (extension buttons below the editor)

XTD buttons are the row of buttons that appear underneath an editor field — "Read More", "Article", "Image", "Page Break". They're plugins in the `editors-xtd` group.

### Plugin structure

```
plugins/editors-xtd/mybutton/
├── mybutton.xml
├── services/
│   └── provider.php
├── src/
│   └── Extension/
│       └── MyButton.php
├── language/
│   └── en-GB/
│       ├── en-GB.plg_editors-xtd_mybutton.ini
│       └── en-GB.plg_editors-xtd_mybutton.sys.ini
└── media/
    └── js/
        └── button.min.js
```

### The plugin class

```php
<?php

namespace Cybersalt\Plugin\EditorsXtd\MyButton\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Editor\Button\Button;
use Joomla\CMS\Event\Editor\EditorButtonsSetupEvent;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;

final class MyButton extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return ['onEditorButtonsSetup' => 'onEditorButtonsSetup'];
    }

    public function onEditorButtonsSetup(EditorButtonsSetupEvent $event): void
    {
        // Respect the form field's hide list
        $disabled = $event->getDisabledButtons();
        if (\in_array($this->_name, $disabled, true)) {
            return;
        }

        // Register the button's JS handler
        $wa = $this->getApplication()->getDocument()->getWebAssetManager();
        $wa->registerScript(
            'editor-button.' . $this->_name,
            'plg_editors-xtd_mybutton/button.min.js',
            [],
            ['type' => 'module'],
            ['editors']                          // depends on editor API
        );

        $button = new Button($this->_name, [
            'action' => 'insert-mywidget',       // matches registerAction() name
            'text'   => Text::_('PLG_MYBUTTON_BUTTON_TEXT'),
            'icon'   => 'star',
            'name'   => $this->_type . '_' . $this->_name,
        ]);

        $event->getButtonsRegistry()->add($button);
    }
}
```

### The JavaScript handler

```javascript
// build/media_source/plg_editors-xtd_mybutton/js/button.es6.js
import { JoomlaEditorButton } from 'editor-api';

JoomlaEditorButton.registerAction('insert-mywidget', (editor, options) => {
    editor.replaceSelection('<div class="my-widget">Widget content</div>');
});
```

The handler receives the active editor instance plus any options the button passed. `editor.replaceSelection()` does the insertion. Return value is ignored.

---

## Button action types

| `action` value | Behavior | Use case |
|---|---|---|
| `insert` | Built-in. Inserts `options.content` at cursor without any custom JS handler | Static content (e.g., a fixed shortcode) |
| `modal` | Opens a `JoomlaDialog` iframe. Listens for `postMessage` from the iframe and inserts the returned HTML | Content selection — pick an article, contact, image, etc. |
| Custom name (e.g., `insert-mywidget`) | Calls your `JoomlaEditorButton.registerAction()` handler | Any custom logic |

---

## Modal button pattern (content selection)

Most non-trivial XTD buttons open a modal that lets the user pick something, then insert a representation of that thing into the editor. The pattern uses `action: 'modal'` plus a `postMessage` from the iframe back to the parent.

### PHP — define the button with `action: 'modal'`

```php
use Joomla\CMS\Session\Session;

$link = 'index.php?option=com_example&view=items&layout=modal&tmpl=component&'
      . Session::getFormToken() . '=1'
      . '&editor=' . $event->getEditorId();

$button = new Button(
    $this->_name,
    [
        'action' => 'modal',
        'link'   => $link,
        'text'   => Text::_('PLG_MYBUTTON_SELECT_ITEM'),
        'icon'   => 'list',
        'name'   => $this->_type . '_' . $this->_name,
    ],
    [
        'popupType'   => 'iframe',
        'textHeader'  => Text::_('PLG_MYBUTTON_MODAL_TITLE'),
        'modalWidth'  => '800px',
        'modalHeight' => '400px',
    ]
);
```

**Security note:** the URL includes `Session::getFormToken() . '=1'` as a CSRF token check. The component view that handles the modal layout must verify it with `Session::checkToken('get')` — see [`README.md`](README.md) Security section for the rule.

### JavaScript in the modal iframe — send selection via `postMessage`

```javascript
// In the modal's layout template (default_modal.php or similar)
document.querySelectorAll('.select-link').forEach((el) => {
    el.addEventListener('click', (event) => {
        event.preventDefault();

        const title = event.target.dataset.title;
        const url   = event.target.dataset.uri;

        // The parent window's modal action handler picks this up automatically
        window.parent.postMessage({
            messageType: 'joomla:content-select',
            html: `<a href="${url}">${title}</a>`,
        });
    });
});
```

The parent window's `modal` action handler:

1. Receives the `joomla:content-select` `postMessage`
2. Calls `editor.replaceSelection(message.html)` (or `message.text` if `text` is sent instead)
3. Closes the dialog

You don't write the parent-side handler — it's built into the editor API.

**Security note:** template literals in the `html` payload — like `` `<a href="${url}">${title}</a>` `` above — must escape `title` and `url` if either is user-supplied. For data attributes set from server-rendered PHP this is usually fine because PHP escaped them at render time, but if you're constructing the HTML from form input on the client, escape with a small helper:

```javascript
function escapeHtml(s) {
    return s.replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
}

window.parent.postMessage({
    messageType: 'joomla:content-select',
    html: `<a href="${escapeHtml(url)}">${escapeHtml(title)}</a>`,
});
```

---

## Editor form field (PHP)

The `editor` form field type in XML automatically renders the configured WYSIWYG editor:

```xml
<field
    name="description"
    type="editor"
    label="JGLOBAL_DESCRIPTION"
    filter="JComponentHelper::filterText"
    buttons="true"
    height="400"
    width="100%"
/>
```

### Common attributes

| Attribute | Values | Purpose |
|---|---|---|
| `buttons` | `true`, `false`, or comma-separated allow-list | Show/hide XTD buttons. A list shows ONLY the named buttons |
| `hide` | Comma-separated deny-list | Hide specific XTD buttons (e.g., `hide="readmore,pagebreak"`) |
| `height` | Pixels (e.g., `500`) | Editor height |
| `width` | CSS value (e.g., `100%`) | Editor width |
| `editor` | Pipe-separated list | Force specific editor(s): `tinymce\|codemirror\|none` |
| `filter` | `JComponentHelper::filterText` | **Server-side HTML filtering — always set this for user-editable rich content** |
| `asset_field` | Field name | Other field on the form holding the asset ID (used for ACL on filtering) |
| `created_by_field` | Field name | Other field on the form holding the author ID |
| `syntax` | `html`, `css`, `php`, etc. | Syntax-highlighting mode for CodeMirror |

**`filter="JComponentHelper::filterText"` is not optional for user-editable rich content.** It runs the editor output through Joomla's text-filter ACL (Global Configuration → Text Filters). Without it, an editor with relaxed permissions can submit `<script>` tags into your component's stored content, which becomes XSS the next time anyone views it. **This is the #1 source of XSS in Joomla extensions that ship rich-content forms.**

---

## Editor plugin registration (PHP) — implementing a custom editor

Most extensions never need this. It's here for completeness — when you're building an alternative WYSIWYG editor (a fourth option alongside TinyMCE / CodeMirror / None).

### Plugin structure

```
plugins/editors/myeditor/
├── myeditor.xml
├── services/provider.php
├── src/
│   ├── Extension/MyEditor.php
│   └── Provider/MyEditorProvider.php
└── ...
```

### The plugin class

```php
<?php

namespace Cybersalt\Plugin\Editors\MyEditor\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Event\Editor\EditorSetupEvent;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;
use Cybersalt\Plugin\Editors\MyEditor\Provider\MyEditorProvider;

final class MyEditor extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return ['onEditorSetup' => 'onEditorSetup'];
    }

    public function onEditorSetup(EditorSetupEvent $event): void
    {
        $event->getEditorsRegistry()->add(
            new MyEditorProvider(
                $this->params,
                $this->getApplication(),
                $this->getDispatcher()
            )
        );
    }
}
```

### The provider

`MyEditorProvider` extends `AbstractEditorProvider` and implements:

- `display()` — returns the HTML that renders the editor's UI (textarea + JS bootstrap)
- `getName()` — returns the editor identifier like `'myeditor'`

The `display()` method is responsible for rendering a `<textarea>` (the underlying form input that holds the value), plus any JS or styles needed to upgrade it into your custom editor experience. Joomla calls `display()` once per editor field on the page.

---

## JavaScript: implementing a custom editor decorator

If you're shipping a custom editor (the rare case above), wire it into Joomla's JS API so other plugins (XTD buttons, etc.) can talk to it through the standard interface. Subclass `JoomlaEditorDecorator` and implement the abstract methods:

```javascript
import JoomlaEditorDecorator from 'editor-decorator';
import { JoomlaEditor } from 'editor-api';

class MyEditorDecorator extends JoomlaEditorDecorator {
    getValue() {
        return this.instance.getContent(); // your editor's get method
    }

    setValue(value) {
        this.instance.setContent(value);
        return this;
    }

    getSelection() {
        return this.instance.getSelectedText();
    }

    replaceSelection(value) {
        this.instance.insertAtCursor(value);
        return this;
    }

    disable(enable) {
        this.instance.setReadOnly(!enable);
        return this;
    }
}

// Register with Joomla's editor registry
const decorator = new MyEditorDecorator(editorInstance, 'myeditor', textareaId);
JoomlaEditor.register(decorator);
```

Required methods: `getValue()`, `setValue()`, `getSelection()`, `replaceSelection()`, `disable()`. Anything else inherits sensible defaults from `JoomlaEditorDecorator`.

---

## Common editor-API mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Forgetting `filter="JComponentHelper::filterText"` on an `editor` field | `<script>` tags from editors with high permissions land in the database, get rendered → XSS | Always set the filter unless you have a specific reason not to |
| Using `Joomla.editors.instances` in new code | Deprecation warnings in browser console | Use `JoomlaEditor.get()` from `editor-api` |
| Not registering the XTD button JS as a module | Console error about `import` outside module context | Pass `['type' => 'module']` as the 4th arg of `registerScript()` |
| Forgetting the `editor=` parameter in modal-button URLs | Modal opens but the editor target is unknown when `postMessage` arrives | Always append `&editor=' . $event->getEditorId()` to the modal URL |
| Calling `editor.setValue()` with un-escaped user data | Stored XSS via the editor field | Escape before insertion, or use a sanitiser like DOMPurify on the client side |

---

## Related

- [`JOOMLA5-PLUGIN-GUIDE.md`](JOOMLA5-PLUGIN-GUIDE.md) — general plugin patterns (`SubscriberInterface`, the `services/provider.php` shape)
- [`JOOMLA5-WEB-ASSETS-GUIDE.md`](JOOMLA5-WEB-ASSETS-GUIDE.md) — `registerScript` options/attribs, especially the `type: 'module'` requirement for modern editor button JS
- [`JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`](JOOMLA5-LANGUAGE-FILES-GOTCHAS.md) — plugin needs both `.ini` and `.sys.ini` for the Extension Manager to display the button name
- [`README.md`](README.md) Security section — CSRF token check on modal-iframe URLs
