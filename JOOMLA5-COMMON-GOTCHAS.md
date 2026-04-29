# Joomla 5/6 Common Gotchas & Pitfalls

Hard-won lessons from real Joomla 5/6 extension development. These are easy to get wrong because IDE autocompletion, documentation gaps, and reasonable assumptions all lead you astray.

This file catalogs the everyday programming-API gotchas. For environmental edge cases (hosting, CDNs, third-party extensions affecting your code), see [`JOOMLA5-EDGE-CASE-SCENARIOS.md`](JOOMLA5-EDGE-CASE-SCENARIOS.md). For UI / asset-pipeline traps see [`JOOMLA5-UI-PATTERNS.md`](JOOMLA5-UI-PATTERNS.md) and [`JOOMLA5-WEB-ASSETS-GUIDE.md`](JOOMLA5-WEB-ASSETS-GUIDE.md). For routing-specific traps see [`JOOMLA5-COMPONENT-ROUTING.md`](JOOMLA5-COMPONENT-ROUTING.md).

> Why these gotchas matter for security: several of them (CSRF token check failure, ACL bypass, SQL injection through wrong-API-by-mistake) start as "the form doesn't save" but end as security findings. Picking the right base class and routing pattern is the foundation that lets the rest of your security review pass.

---

## 1. `BaseController` vs `FormController` vs `AdminController` — pick the right parent

**Never extend `BaseController` for controllers that handle form submissions.** `BaseController` only supports `display()` — no form handling, no checkin/checkout, no save/cancel/apply workflow, and **no automatic CSRF token validation on POST**. Using `BaseController` for a form is a security hole, not just a convenience problem.

| Controller parent | Use when |
|---|---|
| `BaseController` | Display-only controllers (list views, read-only pages, GET-only AJAX endpoints) |
| `FormController` | Single-item CRUD (edit, save, apply, cancel) — handles checkout, redirect, form validation, CSRF |
| `AdminController` | List operations (publish, unpublish, delete, reorder, checkin, batch) |

```php
// WRONG — no save(), no apply(), no cancel(), no CSRF on POST
class ItemController extends BaseController { }

// CORRECT — full form lifecycle with checkout, redirect, CSRF
class ItemController extends FormController { }

// CORRECT — list operations with batch, publish, ordering
class ItemsController extends AdminController { }
```

If you need a custom action on a form controller (e.g., `export`), extend `FormController` and add your method. Don't drop down to `BaseController` just because you want a simpler class — you'll lose the security hooks.

---

## 2. Controller API differences in Joomla 5

`BaseController` in Joomla 5 does **NOT** have `getInput()` or `getApplication()` methods. Use the protected properties directly:

```php
// WRONG — throws "method not found" on Joomla 5
$input = $this->getInput();
$app   = $this->getApplication();

// CORRECT — works on both Joomla 5 and 6
$input = $this->input;
$app   = $this->app;
```

`CMSApplication::getInput()` does exist, so `$app->getInput()` works fine. The trap is specifically *on the controller*.

---

## 3. Event dispatching — Joomla 5 compatibility

Typed event classes (`ContentPrepareEvent`, etc.) with `->getResult()` are **NOT available in Joomla 5**. If your extension must support both J5 and J6, use the legacy `triggerEvent()` shape:

```php
// WRONG on Joomla 5 — typed event classes don't exist there
$event   = new ContentPrepareEvent('onContentPrepare', ['context' => $context, 'subject' => $item]);
$this->getDispatcher()->dispatch($event->getName(), $event);
$results = $event->getResult();

// CORRECT for J5 + J6 compatibility — array results
$results = $app->triggerEvent('onContentPrepare', [$context, &$item, &$params, $page]);
```

If your extension is J6-only (no J5 support claimed in the manifest's `<targetplatform>`), you can use the typed-event API freely.

---

## 4. Plugin manifest XML naming

Plugin manifest files **must** be named `{element}.xml` — matching the plugin element name — for discover-install to work. For a plugin with element `example`, the manifest is `example.xml`, NOT `plg_content_example.xml`.

**CRITICAL:** having BOTH `example.xml` and `plg_content_example.xml` in the plugin directory causes Joomla's Discover to create duplicate extension records. Only `{element}.xml` should exist in the source. The build/packaging step can rename to `plg_{group}_{element}.xml` for the installable ZIP if your installer requires that name on disk.

---

## 5. Plugin language files — locale prefix + `$autoloadLanguage`

Plugin language files in the plugin's own `language/` directory **must** use the locale-prefixed naming convention:

```
plugins/content/example/language/en-GB/en-GB.plg_content_example.ini
plugins/content/example/language/en-GB/en-GB.plg_content_example.sys.ini
```

NOT `plg_content_example.ini` (without the `en-GB.` prefix). The unprefixed form only works when files are located in `administrator/language/en-GB/`.

The plugin class **must** also set `$autoloadLanguage = true`:

```php
final class Example extends CMSPlugin implements SubscriberInterface
{
    protected $autoloadLanguage = true;
    // ...
}
```

Without this property, Joomla won't load the language files from the plugin directory and language strings render as raw keys (`PLG_CONTENT_EXAMPLE_TITLE`).

See [`JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`](JOOMLA5-LANGUAGE-FILES-GOTCHAS.md) for the system-vs-bundled language path rules and the `.sys.ini` requirements.

---

## 6. Task plugin language keys need `_TITLE` and `_DESC` suffixes

`TaskPluginTrait` automatically appends `_TITLE` and `_DESC` to whatever `langConstPrefix` you declare in `TASKS_MAP`. The language file MUST have both suffix variants:

```php
protected const TASKS_MAP = [
    'myplugin.my_task' => [
        'langConstPrefix' => 'PLG_TASK_MYPLUGIN_TASK_MYTASK',
        'method'          => 'doMyTask',
    ],
];
```

```ini
PLG_TASK_MYPLUGIN_TASK_MYTASK_TITLE="My Task Name"
PLG_TASK_MYPLUGIN_TASK_MYTASK_DESC="Description of what this task does."
```

Defining only `PLG_TASK_MYPLUGIN_TASK_MYTASK` (without the suffix) silently fails — the task type selector in Scheduled Tasks shows the raw language key.

---

## 7. Always use `AdminModel` + `Table` for CRUD

**Never bypass Joomla's Table save workflow** with direct `$db->insertObject()` / `$db->updateObject()` in model `save()` methods. The full `AdminModel::save()` → `Table::bind()` → `Table::check()` → `Table::store()` chain handles:

- Setting `$this->setState('item.id', $newId)` so `FormController::save()` can redirect to the right edit URL afterwards
- Checkout / checkin management
- Session state cleanup
- `onContentBeforeSave` / `onContentAfterSave` event dispatching (which other plugins rely on)
- ACL asset tracking

```php
// WRONG — breaks FormController redirects, ID tracking, checkout, events
public function save($data): bool
{
    $db = $this->getDatabase();
    $db->insertObject('#__mytable', (object) $data);
    return true;
}

// CORRECT — delegates to Table class via parent::save()
public function save($data): bool
{
    $data['modified'] = Factory::getDate()->toSql();
    return parent::save($data);
}
```

Direct `insertObject()` is also where SQL-injection findings creep in — `Table::bind()` runs Joomla's input filtering, raw `insertObject()` doesn't.

---

## 8. List-to-edit links must use `task=` routing

Links from list views to edit views **must** use `task={entity}.edit&id=X`, NOT `view={entity}&layout=edit&id=X`:

```php
// WRONG — bypasses FormController, no checkout, broken session state
Route::_('index.php?option=com_mycomponent&view=item&layout=edit&id=' . $item->id)

// CORRECT — routes through FormController::edit() which sets layout + checks out
Route::_('index.php?option=com_mycomponent&task=item.edit&id=' . $item->id)
```

`FormController::edit()` handles setting the layout, checking out the record, and managing the user state. Skipping that means concurrent editors can both save without conflict detection.

---

## 9. Load `form.validate` web asset on form views

Any view that renders a form with `class="form-validate"` **must** load the `form.validate` web asset, or `Joomla.submitbutton()` throws an `isValid` error in the browser console and the form silently doesn't submit:

```php
// In HtmlView::display()
$this->getDocument()->getWebAssetManager()->useScript('form.validate');
```

This used to be auto-loaded with Bootstrap. In J5/6 it's a separate asset and you have to opt in.

---

## 10. `Table::check()` and `DatabaseModel::fix()`

- In `Table::check()`, **throw `\UnexpectedValueException`** with `Text::_()` language keys for validation errors. Don't return false silently — the FormController treats the exception message as the user-facing error.

  ```php
  public function check(): void
  {
      parent::check();
      if (empty($this->title)) {
          throw new \UnexpectedValueException(Text::_('COM_MYCOMPONENT_ERROR_TITLE_REQUIRED'));
      }
  }
  ```

- **`DatabaseModel::fix()` only executes DDL** (ALTER TABLE, CREATE INDEX, etc.). For DML (INSERT, UPDATE, DELETE that modifies user data), use a separate PHP migration step in your update script. Mixing the two breaks Joomla's idempotency guarantees on the schema-fix tool.

---

## 11. `HttpFactory` lives in `Joomla\CMS\Http`, not `Joomla\Http`

```php
// CORRECT — this is the right namespace
use Joomla\CMS\Http\HttpFactory;
$http = HttpFactory::getHttp();

// WRONG — this class does not exist
use Joomla\Http\HttpFactory;
```

IDE autocompletion frequently suggests the framework-package namespace (`Joomla\Http`) because that's where most other framework classes live. **Don't let the linter "auto-fix" the import.** `HttpFactory` is one of the few HTTP utilities that's specifically a CMS wrapper.

---

## 12. `Registry::get()` defaults — always provide one

`$params->get('key')` returns `null` when the key is missing from the stored JSON. Common with component / module / plugin params, especially right after install when the user hasn't visited the config page yet.

```php
// Dangerous — returns null if 'items_per_page' was never saved
$limit = $params->get('items_per_page');

// Safe — explicit default
$limit = $params->get('items_per_page', 10);
```

`null` then propagates into `LIMIT NULL` in SQL queries, into PHP type errors when the value is type-hinted, etc. Always provide a default.

---

## 13. `Text::script()` registration location

JavaScript language strings via `Joomla.Text._('KEY')` only work if the key was registered server-side with `Text::script()`. Register in the right place:

- **Components**: in `HtmlView::display()` before the template renders
- **Modules**: in `Dispatcher::dispatch()` before the module template loads
- **Plugins**: in the event handler that emits the JS (typically `onAfterRoute` or similar)

```php
// In HtmlView::display() or Dispatcher::dispatch()
Text::script('COM_MYCOMPONENT_CONFIRM_DELETE');
Text::script('COM_MYCOMPONENT_SAVING');
```

Calling `Text::script()` AFTER the document is rendered does nothing — the strings need to be in the registry by the time `media/system/js/core.js` reads them out.

---

## 14. `Joomla.Text._()` returns the raw key when unregistered (truthy fallback trap)

`Joomla.Text._('SOME_KEY')` returns the raw key string (e.g., `"SOME_KEY"`) when the key was never registered. This is **truthy**, so the common JS fallback pattern silently breaks:

```javascript
// WRONG — fallback never fires because unregistered keys return the key string (truthy)
const msg = Joomla.Text._('COM_MYCOMP_LABEL') || 'Default Label';

// CORRECT — detect missing registration
const key = 'COM_MYCOMP_LABEL';
const translated = Joomla.Text._(key);
const msg = (translated !== key) ? translated : 'Default Label';
```

The same logic applies if you want a sentinel to detect "translation missing" in QA — comparing the return value against the input key is the only reliable check.

---

## 15. Batch task routing — only on `FormController`

`AdminController` (the plural list controller) does **NOT** have a `batch()` method. Only `FormController` (the singular edit controller) has it. If batch operations aren't working, check that:

1. Your form controller (e.g., `ItemController`) exists and extends `FormController`.
2. The list view's batch form posts to `task=item.batch` (singular controller name + `.batch`), NOT `task=items.batch` (plural).

A common refactor breaks this when someone moves the `batch` task from a singular controller to the plural one to "tidy up" — the plural controller silently doesn't have the method, batch task POSTs land back at the list view with no feedback, and users assume it worked.

---

## 16. Bootstrap 5 dynamic modal cleanup

When creating modals programmatically with `new bootstrap.Modal()`, do NOT rely on `bsModal.hide()` for teardown — it doesn't reliably clean up the backdrop, `aria-hidden`, and body scroll-lock. After enough open/close cycles, you get a stuck dimmed background, a body that won't scroll, and stacked aria-hidden states that break screen readers.

Use full manual cleanup:

```javascript
const cleanup = () => {
    bsModal.dispose();
    modalEl.remove();
    document.querySelectorAll('.modal-backdrop').forEach(n => n.remove());
    document.body.classList.remove('modal-open');
    document.body.style.removeProperty('overflow');
    document.body.style.removeProperty('padding-right');
};
```

This affects any Joomla extension that creates confirmation dialogs, AJAX editors, or wizard modals via JavaScript rather than static HTML markup. Static markup `<div class="modal">…</div>` driven by `data-bs-toggle="modal"` doesn't have this problem — it's only the programmatic case.

---

## 17. `getStoreId()` in `ListModel` — override when adding state

`ListModel::getStoreId()` generates a hash key that distinguishes cached data sets. **If you add custom filters or state to your list model, you MUST override this method** — otherwise the model returns stale cached results when filters change, and users see "the page didn't update".

```php
protected function getStoreId($id = ''): string
{
    $id .= ':' . $this->getState('filter.search');
    $id .= ':' . $this->getState('filter.published');
    $id .= ':' . $this->getState('filter.category_id');
    $id .= ':' . serialize($this->getState('filter.access')); // arrays need serialize()

    return parent::getStoreId($id);
}
```

Rule of thumb: every state key your `getListQuery()` reads must contribute to the `getStoreId()` hash. Forgetting one means that filter is silently broken on any page load after the first.

For multi-value filters (arrays) use `serialize()` so the hash key is deterministic.

---

## Related

- [`JOOMLA5-EDGE-CASE-SCENARIOS.md`](JOOMLA5-EDGE-CASE-SCENARIOS.md) — environmental edge cases (hosting, CDNs, third-party extensions)
- [`JOOMLA5-UI-PATTERNS.md`](JOOMLA5-UI-PATTERNS.md) — UI / asset-pipeline traps including the `defer` options-vs-attribs lesson
- [`JOOMLA5-WEB-ASSETS-GUIDE.md`](JOOMLA5-WEB-ASSETS-GUIDE.md) — Web Asset Manager URI rules and inline asset patterns
- [`JOOMLA5-COMPONENT-ROUTING.md`](JOOMLA5-COMPONENT-ROUTING.md) — SEF router 3-part registration, callback naming, hidden menu items
- [`JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`](JOOMLA5-LANGUAGE-FILES-GOTCHAS.md) — language file paths, `.sys.ini`, INI encoding traps
- [`COMPONENT-TROUBLESHOOTING.md`](COMPONENT-TROUBLESHOOTING.md) — install / load / configuration diagnostics
