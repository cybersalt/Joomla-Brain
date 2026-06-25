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

## 18. `DatabaseQuery::bind()` takes its `$value` parameter by reference

`Joomla\Database\DatabaseQuery::bind(string $name, mixed &$value, int $dataType = ParameterType::STRING)` declares its second parameter as a **reference**. PHP refuses to bind a reference to anything that isn't a real variable, and the failure is a fatal at execute time:

```
Joomla\Database\DatabaseQuery::bind(): Argument #2 ($value) could not be passed by reference
```

Anything that isn't a plain variable triggers it:

```php
// WRONG — every line below fatals at execute time
$query->bind(':state', 'running');                                   // string literal
$query->bind(':id', 5);                                              // int literal
$query->bind(':base', basename($path));                              // function call result
$query->bind(':name', $obj->getName());                              // method call result
$query->bind(':orphan', $hits === 0 ? 1 : 0, ParameterType::INTEGER); // ternary
$query->bind(':like', '%' . $db->escape($q, true) . '%');            // concatenation
$query->bind(':type', SOMECONST);                                    // constant
$query->bind(':id', (int) $rawId);                                   // cast result

// CORRECT — assign to a real variable first
$state = 'running';
$query->bind(':state', $state);

$base = basename($path);
$query->bind(':base', $base);

$orphan = $hits === 0 ? 1 : 0;
$query->bind(':orphan', $orphan, ParameterType::INTEGER);
```

What's safe without a temporary variable: plain variables (`$x`), property access on stdClass loaded from the DB (`$row->id`), and array-element access (`$row['id']`, `$arr[$i]`) — those all yield assignable references.

### Bind-in-loop trap (related)

`bind()` stores the **reference**, not the value. If you reuse a single loop variable, every parameter ends up pointing at whatever it held in the last iteration:

```php
// WRONG — all :c0..:cN end up bound to the LAST $like value
foreach ($candidates as $i => $cand) {
    $like = '%' . $db->escape($cand, true) . '%';
    $query->bind(':c' . $i, $like);
}

// CORRECT — distinct array slot per iteration
$likes = [];
foreach ($candidates as $i => $cand) {
    $likes[$i] = '%' . $db->escape($cand, true) . '%';
    $query->bind(':c' . $i, $likes[$i]);
}
```

The query "doesn't fatal but returns wrong rows" is the symptom — easy to misdiagnose as a SQL bug. Discovered while building cs-image-sentinel's reference finder.

---

## 19. UTF-8 BOM in `.php` files breaks the autoloader

PHP refuses to tokenise any byte that lands before `<?php`. A UTF-8 byte-order mark (`0xEF 0xBB 0xBF`) is exactly that — three "invisible" bytes of output ahead of the open tag. The fatal it produces is misleading:

```
Symfony\Component\ErrorHandler\Error\FatalError
in /…/com_yourext/src/Extension/YourExtComponent.php (line 9)
```

…where line 9 is the `namespace` declaration. The actual root cause is the BOM at offset 0; the line number is whatever the tokenizer happens to land on after the failure.

Symptoms:

- Component or plugin throws a 500 immediately on the first hit after install
- Error points at a `namespace` line, a `use` statement, or a class declaration that is syntactically valid
- The error message is a generic `FatalError` with no underlying explanation in the "Show exception properties" panel
- Stripping any BOM-bearing file with `dos2unix` / re-saving as "UTF-8 (no BOM)" makes the error vanish

Where they come from:

- VSCode / Notepad++ "Save with BOM" defaults
- PowerShell 5.1's `Out-File` and `Set-Content` default encoding
- Linter or formatter passes that re-write the file with BOM
- Some IDE auto-format-on-save settings

### One-shot bulk strip (PowerShell)

Run from the repo root before building the ZIP:

```powershell
$exts = @("*.php","*.ini","*.xml","*.sql","*.json","*.css","*.js","*.md","*.html","*.ps1")
$stripped = 0
Get-ChildItem -Path . -Recurse -File -Include $exts | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $newBytes = New-Object byte[] ($bytes.Length - 3)
        [Array]::Copy($bytes, 3, $newBytes, 0, $newBytes.Length)
        [System.IO.File]::WriteAllBytes($_.FullName, $newBytes)
        $stripped++
    }
}
"BOM stripped from $stripped files."
```

### Detect from one file

```powershell
$bytes = [System.IO.File]::ReadAllBytes($file)
"{0:X2} {1:X2} {2:X2}" -f $bytes[0], $bytes[1], $bytes[2]
# "EF BB BF" ⇒ has BOM
```

### Prevention

- **PowerShell**: pass `-Encoding utf8NoBom` to `Out-File` / `Set-Content` when writing files programmatically. Default encoding in 5.1 is the wrong one.
- **VSCode**: set `"files.encoding": "utf8"` (NOT `"utf8bom"`) in workspace `.vscode/settings.json`.
- **Editor pre-commit hook**: many teams add a check that fails if any tracked file starts with `EF BB BF`.

This isn't Joomla-specific (the same issue affects any PHP project), but Joomla extensions are particularly prone to hitting it because the install pipeline copies many files at once and the first one PHP autoloads is whichever class the request needs — so the failure surfaces at runtime, far from where it would be obvious during development.

Discovered while building cs-image-sentinel: 96 of 126 source files were BOM-tainted by the editor's auto-format pass after the initial commit.

---

## 20. Media field stores `path#joomlaImage://adapter/path?w=&h=` — strip everything from `#` onwards

When you read a media-field value back from `params`, you get the path with a fragment appended for the media manager's internal preview/transform metadata. Example:

```
images/design.jpg#joomlaImage://local-images/design.jpg?width=1248&height=667
```

The **real repo-relative path is the part before the `#`**. Everything after is adapter+transform noise that's irrelevant to filesystem operations. If you don't strip it, `is_file()`/`file_exists()` will fail because no such path exists on disk.

Robust normalization for any code that needs to use a media-field value as a filesystem path:

```php
$path = (string) $params->get('placeholder_image', '');
// 1. Strip the hash fragment (joomlaImage:// adapter metadata)
if (str_contains($path, '#')) {
    $path = substr($path, 0, strpos($path, '#'));
}
// 2. Strip any legacy colon-form adapter prefix (local-images:foo/bar.png)
if (str_contains($path, ':')) {
    $path = substr($path, strpos($path, ':') + 1);
}
// 3. Strip any legacy slash-form adapter prefix (local-images/foo/bar.png)
$path = preg_replace('#^local-[^/]+/#', '', $path);
// 4. Strip any query string
if (str_contains($path, '?')) {
    $path = substr($path, 0, strpos($path, '?'));
}
$path = trim($path, '/');
```

Discovered while building cs-image-sentinel: a "placeholder image" media-field value that looked fine in the Joomla Options UI was failing `is_file()` because the stored DB value had the `#joomlaImage://...?width=...&height=...` fragment appended. The earlier attempt to strip only the colon-form prefix produced a path like `local-images/design.jpg?width=1248&height=667` — still not on disk.

---

## 21. Joomla 5 quickstart installer (`custom.sql`) — the four-layer corruption chain

The Joomla 5 web installer loads SQL in a fixed order:

1. `installation/sql/mysql/base.sql` — creates core tables + seeds them with default rows (sample categories, modules, menu items, template_styles, usergroups, viewlevels, schemas, extensions).
2. `installation/sql/mysql/supports.sql` — Joomla framework support tables.
3. `installation/sql/mysql/<lang>/sample_<flavor>.sql` — the sample-data flavor the user picked (blog, brochure, default, etc.).
4. `installation/sql/mysql/custom.sql` — **optional**, loads last. This is the slot template vendors use to deliver a "quickstart" (donor site DB dump pre-converted to layer 4 SQL).

Producing a working `custom.sql` from a real donor `mysqldump` is harder than it looks. The pre-seeded core rows from step 1 collide with donor rows from step 4 in four distinct ways. Solving one layer often reveals the next; we hit all four in succession building the Avant J5.4.5 quickstart 2026-05-22 → 2026-05-23.

### Layer 1: base-install row collisions in structural tables → `INSERT INTO` PK conflicts

The wizard's stock data + the donor's data both populated `#__assets` / `#__usergroups` / `#__viewlevels` / `#__template_styles` / `#__modules` / `#__modules_menu` / `#__menu` / `#__menu_types` / `#__categories` / `#__content` with **non-overlapping primary keys**. Donor `INSERT INTO` raised duplicate-PK errors *or* (after switching to `REPLACE INTO`) left the stock rows alongside the donor rows because REPLACE only replaces by PK match — non-PK-overlapping rows survive. Result: dual home-page styles published at once, broken nested-set trees in `#__assets`, ACL chaos, and a "Component not found" error on the first dashboard click after install.

**Fix:** convert all donor `INSERT INTO` → `REPLACE INTO` AND `TRUNCATE` the 10 structural tables at the top of `custom.sql` (after any `ALTER TABLE` schema-prep statements, before the donor `REPLACE INTO` statements). The `TRUNCATE` wipes the wizard's seed rows so the donor data lands on a clean slate.

```sql
-- ============================================================
-- TRUNCATE structural tables before donor REPLACE INTO loads them.
-- Fixes Layer 1: base-install row collisions for structural tables.
-- ============================================================
TRUNCATE TABLE `#__assets`;
TRUNCATE TABLE `#__usergroups`;
TRUNCATE TABLE `#__viewlevels`;
TRUNCATE TABLE `#__template_styles`;
TRUNCATE TABLE `#__modules`;
TRUNCATE TABLE `#__modules_menu`;
TRUNCATE TABLE `#__menu`;
TRUNCATE TABLE `#__menu_types`;
TRUNCATE TABLE `#__categories`;
TRUNCATE TABLE `#__content`;
```

### Layer 2: `_extensions` schema drift between donor and target → `state=NULL` everywhere → "Component not found"

`_extensions` schema in different Joomla 5 minor versions has the same columns in **different orders**. J5.1.x has `locked` at column position 20 (last); J5.4.5 has `locked` at column position 12. A `mysqldump` without `--complete-insert` emits **positional** `VALUES (...)` — every column from `locked` onward shifts when the target schema differs from the donor. `state` ends up populated with what was supposed to be `note`; `note` ends up populated with what was supposed to be `state`; `params` ends up populated with what was supposed to be something else.

Joomla's component dispatcher does `WHERE state=0 AND enabled=1` on `_extensions` — with `state=NULL`, that filter never matches → "Component not found" on every dashboard click. Diagnostic SQL on the broken install: 328 of 516 extensions had `state=NULL` (vs 6 in donor).

**Fix:** add `--complete-insert` to `mysqldump`. MySQL then names each column in every `INSERT/REPLACE`:

```sql
REPLACE INTO `#__extensions` (`extension_id`, `package_id`, `name`, …, `locked`, `manifest_cache`, …)
VALUES (22, 0, 'com_content', …, 0, '{"…"}', …);
```

— the target maps by **name** instead of position, and schema drift becomes harmless.

### Layer 3: `--skip-add-locks` removes the `LOCK TABLES` markers your strip-filter depends on

The standard donor → custom.sql transformer (any awk/sed/PHP script that processes a `mysqldump`) typically uses the `LOCK TABLES \`<prefix><table>\` WRITE;` lines as **table boundaries** — it needs to know which table each `INSERT` belongs to so it can apply per-table rules (strip user/session/order-history data, keep product-catalog data, etc.). 

`mysqldump` ships LOCK TABLES wrappers by default. **`--skip-add-locks` removes them.** Easy to add by accident if you're thinking "we don't need LOCK wrappers in a single-file SQL replay." The cost: your strip filter sees a stream of `INSERT INTO` without ever knowing which table it's in, so STRIP_DATA never fires, so rows you intended to drop (e.g. the `_schemas` row `(700, '5.4.0-2025-08-02')` that conflicts with the wizard's identical seed) get carried into custom.sql → duplicate-key error mid-install.

**Confusing pair to keep straight:**
- `--skip-add-locks` → **removes** `LOCK TABLES \`<table>\` WRITE; ... UNLOCK TABLES;` wrappers from the dump output. **Don't use** if your transformer depends on them.
- `--skip-lock-tables` → tells mysqldump not to issue `LOCK TABLES ... READ` for **runtime locking during the dump** (read-consistency, blocks writes). Safe and recommended on a live donor where you don't want to block traffic. Does **not** affect dump output.

**Fix:** drop `--skip-add-locks`. Keep `--skip-lock-tables` if you don't want the dump to block live writes.

### Layer 4: `set -e` bash + `grep -c` returning 0 → script aborts on a *desired* outcome

Many quickstart-build scripts validate the strip-result with lines like:

```bash
S=$(grep -c "REPLACE INTO .#__schemas" custom.sql)
echo "  _schemas REPLACE: $S (should be 0)"
```

When the strip worked correctly and `$S` should be `0`, `grep -c` exits with status **1** (which means "no matches"). Under `set -e`, the script aborts mid-build on what is actually the success case.

**Fix:** append `|| true` to every diagnostic `grep -c`:

```bash
S=$(grep -c "REPLACE INTO .#__schemas" custom.sql || true)
```

The count still lands in `$S`; the `|| true` swallows the exit-1, `set -e` stays happy.

### Final correct mysqldump flags for a J5 quickstart custom.sql

```bash
mysqldump \
  -u "$DUSER" "$DDB" \
  --complete-insert \        # Layer 2: name columns in every INSERT
  --default-character-set=utf8mb4 \
  --no-tablespaces \
  --skip-lock-tables \       # OK: only skips runtime locking
  --skip-comments \
  > raw.sql
# --add-locks is the DEFAULT and MUST stay default. LOCK TABLES markers in the
# output stay where they are. Never add --skip-add-locks. (Layer 3.)
```

### Why this matters across the Cybersalt brands

The same pipeline produces quickstarts for any of Tim's theme-selling brands (VirtueMart Templates, Easy Templates, BasicJoomla). The four layers above are donor-data-shape-agnostic — they bite any team that's building from a real Joomla DB dump rather than hand-curating sample data. The complete recipe + reusable build script are captured in the vault's [Build a Joomla 5 Quickstart Install Package](https://e.onedrive.com/) skill — see the 2026-05-23 Avant v10→v14 entry.

Locked in 2026-05-23 after the four-version Avant quickstart rebuild loop cracked the chain.

---

## 22. Empty `<schemapath>` folder → `Folder::files: Path is not a folder` install error

When your component manifest declares an update path:

```xml
<update>
    <schemas>
        <schemapath type="mysql">sql/updates/mysql</schemapath>
    </schemas>
</update>
```

Joomla's installer enumerates files in that directory via `\Joomla\Filesystem\Folder::files()` and runs the schema-version tracker against them. If the directory ships **empty** (which is natural for a v1.0.0 release — there's nothing to migrate from yet), the install aborts with:

```
Joomla\Filesystem\Folder::files: Path is not a folder.
Path: [ROOT]/administrator/components/com_cscronmaster/sql/updates/mysql
```

**The folder DOES get created on disk** (Joomla's installer copies the directory entry from the ZIP). The error message is misleading — it's not really saying "path doesn't exist", it's saying "path enumerates to zero readable files and that's not allowed in this context." In older Joomla versions this would emit a warning and continue; in Joomla 5.x+ it's a fatal install error.

**Fix:** ship at least one no-op SQL file matching your v1.0.0 manifest version. The schema-version tracker will create a row with `version_id = '1.0.0'` so future migrations (e.g. `1.1.0.sql` adding a column) can be applied incrementally:

```
admin/sql/updates/mysql/1.0.0.sql:

-- v1.0.0 baseline migration.
-- Initial schema is created by sql/install.mysql.utf8.sql on first install;
-- this empty migration exists so Joomla's schema-version tracker has a 1.0.0
-- row to anchor future migrations against.
SELECT 1;
```

A `SELECT 1;` no-op is enough — Joomla doesn't care what the SQL does, only that the file is there.

**Same class of bug:** ANY empty directory shipped in the ZIP whose path is referenced by Joomla's installer or framework code (template `media/css`, `media/js`, schema paths, language folders) is a latent error. Empty directories with `D....` markers in the ZIP do install as empty folders on disk — they just blow up the first time framework code tries to enumerate them. **Rule of thumb:** if you have an empty directory in your component scaffold whose purpose is "this is where X files will eventually live," drop a placeholder file in it (or a `.gitkeep` won't survive Joomla's filename filters — use a real `1.0.0.sql` / `placeholder.txt` / etc.).

**Diagnostic check for your build script:** before zipping, scan the staging tree for empty directories and either drop placeholders or remove them:

```powershell
Get-ChildItem -Path $stage -Recurse -Directory | Where-Object {
    @(Get-ChildItem -Path $_.FullName -Recurse -File).Count -eq 0
} | ForEach-Object { Write-Warning "Empty dir in package: $($_.FullName)" }
```

Discovered 2026-05-23 while installing cs-cron-master v1.0.0 on Virtuemarttemplates.net. The component's mkdir-scaffold step created the `sql/updates/mysql` directory in anticipation of future migrations; the install bombed on the first upload to a real Joomla site even though the local PHP syntax check and 7-Zip directory-entry check both passed.

---

## 23. View `HtmlView` properties must be `public`, not `protected`

**Symptom:** the moment you visit a list view that uses Joomla's standard `joomla.searchtools.default` layout (i.e. any list view with filter chips at the top), the page errors out with:

```
0 Cannot access protected property
Cybersalt\Component\YourComponent\Administrator\View\Items\HtmlView::$filterForm
```

Same shape of error for `$items`, `$pagination`, `$state`, `$activeFilters` — any property the layout reads from outside the class.

**Cause:** PHP-21+ enforces protected-vs-public visibility strictly. Joomla's `LayoutHelper::render('joomla.searchtools.default', ['view' => $this])` passes the view object into a generic layout, which then reads `$displayData->filterForm`. The layout is not a method of your view class, so protected properties are inaccessible.

**Fix:** every property your view exposes to a layout MUST be `public`:

```php
final class HtmlView extends BaseHtmlView
{
    public $items;
    public $pagination;
    public $state;
    public $filterForm;
    public $activeFilters;
    // ...
}
```

Joomla's own core components (`com_content`, `com_users`, etc.) declare these as `public` for exactly this reason. PHPDoc-only documentation of "intended visibility" doesn't change runtime enforcement.

**Don't be fooled by a local dev test passing.** If you only test your view by visiting it on a Joomla instance whose searchtools layout was overridden, or by render-mocking it in unit tests, you won't hit this error until production. Always test list views with searchtools active on a clean Joomla install.

Discovered 2026-05-23 installing cs-cron-master v1.0.0 on Virtuemarttemplates.net. Errored on the first click of "Jobs" in the admin menu.

---

## 24. Package `.sys.ini` does NOT auto-load in the package's own `script.php` postflight

**Symptom:** the package's post-install card renders raw language constants instead of translated text:

```
PKG_YOURPKG_POSTINSTALL_INSTALLED
PKG_YOURPKG_POSTINSTALL_OPEN
```

…where you expected:

```
Your Package has been installed successfully.
Open Extension
```

**Cause:** Joomla's package installer copies the package's `language/<tag>/pkg_yourpkg.sys.ini` file into `administrator/language/<tag>/<tag>.pkg_yourpkg.sys.ini` as part of the install steps. But the active `Language` object — the one `Text::_()` queries — was built BEFORE that copy happened. The new file is on disk but the in-memory language store doesn't know about it yet. The next page load (or next request) would see the translated strings; the postflight echo doesn't.

This is different from a component's `.sys.ini` (which is loaded earlier in the install chain) and different from a plugin's `.sys.ini` (which Joomla loads automatically when the plugin executes its own events). Packages are the odd one out.

**Fix:** force-load the package's `.sys.ini` at the top of `postflight()` before calling `Text::_()`:

```php
public function postflight(string $type, InstallerAdapter $adapter): bool
{
    if (!\in_array($type, ['install', 'update', 'discover_install'], true)) {
        return true;
    }

    // Joomla's Language object at postflight() time was built before our
    // pkg_*.sys.ini was copied to administrator/language. Force-load so
    // Text::_() resolves package keys instead of rendering raw constants.
    Factory::getApplication()->getLanguage()->load(
        'pkg_yourpkg.sys',
        JPATH_ADMINISTRATOR
    );

    // ... now Text::_('PKG_YOURPKG_POSTINSTALL_INSTALLED') works ...
}
```

**Belt-and-braces alternative:** wrap every `Text::_()` call in a defensive `$lang->load()` before each use. The single load at the top of `postflight()` is cleaner and works as long as you don't redirect or re-render mid-function.

**Tangentially related:** if your package script.php AND your component script.php both echo a "Your extension is installed!" card, the user sees TWO stacked cards on the install screen. Pick one as the owner — usually the package script.php since it's the outermost — and strip the duplicate from the inner extensions' postflights.

Discovered 2026-05-23 installing cs-cron-master v1.0.0 on Virtuemarttemplates.net.

---

## 25. On cPanel / EasyApache 4, `/usr/bin/php` is PHP-CGI, not PHP-CLI

**Symptom:** a Joomla CLI script (`cli/joomla.php`, custom component CLI, `cli/cs-cron-master.php`, etc.) runs cleanly from your local dev box but fails when invoked from cron on a cPanel-hosted server. Either:

- The cron log fills with `Status: 500 Internal Server Error / Content-type: text/html; charset=UTF-8` repeating per firing, OR
- Cron emails you "Status: 500 Internal Server Error" on each tick, OR
- Nothing visible happens, but your Joomla `#__schemas`/`#__cscronmaster_log`/whatever tables never get the row you expected.

**Cause:** on cPanel + EasyApache 4 servers, `/usr/bin/php` is symlinked to the **CGI** binary, not the **CLI** binary. CGI is the right binary when Apache invokes PHP for a web request; CLI is the right binary for cron / shell scripts. They differ in what `PHP_SAPI` reports (`cgi-fcgi` vs `cli`), what output convention they use (CGI wraps everything in HTTP headers; CLI doesn't), and how they handle non-zero exit codes (CGI translates exit-non-zero into HTTP 500).

A Joomla CLI script that does:

```php
if (\PHP_SAPI !== 'cli') {
    \fwrite(\STDERR, "This script can only be run from the command line.\n");
    exit(1);
}
```

…will trip the guard under CGI and `exit(1)`. PHP-CGI then emits a `Status: 500 Internal Server Error / Content-type: text/html; charset=UTF-8` response (because the script "errored"). Cron captures that as the script's output. Your bootstrap never runs.

**Fix:** point cron at the explicit CLI binary for the user's selected PHP version:

```cron
*/5 * * * * /opt/cpanel/ea-php83/root/usr/bin/php /home/USER/public_html/cli/your-script.php
```

The format is `/opt/cpanel/ea-php{XX}/root/usr/bin/php` where `XX` matches the cPanel "MultiPHP Manager" version configured for the account (80/81/82/83/84/etc). This is the **CLI** binary inside the ea-phpXX RPM. Verify it exists with `Fileman::list_files` against `/opt/cpanel/ea-php83/root/usr/bin/`.

`/usr/local/bin/php` is *also* CLI on most cPanel boxes (it points to whatever PHP version was last installed by cPanel), but the explicit `/opt/cpanel/ea-php83/...` path is more reliable when the box has multiple PHP versions installed — it pins to the version you tested against. Use it.

**Don't trust working examples from other extensions' cron entries on the same box.** Akeeba Backup's nightly cron on VMT also uses `/usr/bin/php` — and might be silently failing the same way for months because nobody reads cron output. Just because another cron is "set up that way" on the same server doesn't mean it works.

**Detection helper:** if cron output is opaque (redirected to `/dev/null` or unread), add a one-liner to the top of your CLI script that writes a probe entry early:

```php
\fwrite(\STDERR, '[' . date('c') . '] SAPI=' . \PHP_SAPI . "\n");
```

Run the cron once, check the log: if you see `SAPI=cli` you're golden; if you see `SAPI=cgi-fcgi` (or no output at all + an HTTP 500), you're hitting this gotcha.

Discovered 2026-05-23 setting up cs-cron-master's CLI cron on Virtuemarttemplates.net (green.cybersalthosting.com, ea-php83 cPanel box).

---

## 26. Custom Joomla CLI script: alias `SessionInterface` to `session.cli` BEFORE requesting `ConsoleApplication`

**Symptom:** a custom CLI script for a component (e.g. `cli/yourext-cli.php`) crashes on every invocation with:

```
[yourext] FATAL: Resource 'Joomla\Session\SessionInterface' has not been registered with the container.
#0 .../libraries/src/Service/Provider/Application.php(133): Joomla\DI\Container->get('Joomla\\Session\\...')
#1 .../libraries/vendor/joomla/di/src/ContainerResource.php(162): {closure}(...)
#2 .../libraries/vendor/joomla/di/src/Container.php(95): Joomla\DI\ContainerResource->getInstance()
#3 .../cli/yourext-cli.php:LINE: Joomla\DI\Container->get('Joomla\\CMS\\Appl...')
```

**Cause:** Joomla 5/6's `ConsoleApplication` (and its `Joomla\Console\Application` alias) requires `Joomla\Session\SessionInterface` as a constructor dependency, the same way the web app does. The web bootstrap registers a real HTTP-session service for this. The CLI bootstrap registers `session.cli` (a no-op session that just satisfies the type contract) but does NOT automatically alias it to the `SessionInterface` key. Your script asks the container for `ConsoleApplication`, the container tries to autowire `SessionInterface`, finds no binding, throws.

**Fix:** mirror Joomla core's own `cli/joomla.php` bootstrap exactly. Specifically, between `require framework.php` and `Factory::getContainer()->get(...)`, add the session-alias block:

```php
require_once JPATH_BASE . '/includes/framework.php';

$container = \Joomla\CMS\Factory::getContainer();

// Alias session keys to the CLI session backend BEFORE asking for ConsoleApplication.
// Without these aliases, the container has no provider for SessionInterface (sessions
// are an HTTP concept) and the next line throws "Resource has not been registered."
$container->alias('session', 'session.cli')
    ->alias('JSession', 'session.cli')
    ->alias(\Joomla\CMS\Session\Session::class, 'session.cli')
    ->alias(\Joomla\Session\Session::class, 'session.cli')
    ->alias(\Joomla\Session\SessionInterface::class, 'session.cli');

$app = $container->get(\Joomla\Console\Application::class);
\Joomla\CMS\Factory::$application = $app;

// ... your CLI logic here ...
```

**Why both `Session::class` and `SessionInterface::class` aliases?** Different parts of Joomla core ask for different keys. Aliasing only `SessionInterface::class` will get you past the first error and into a second one. Mirror the core block verbatim.

**Don't try `$app = new ConsoleApplication(...)` instead.** Direct instantiation bypasses the DI container, leaves Factory::$application unset, and breaks every `Factory::getApplication()` call downstream — most Joomla extension code assumes Factory works.

**Don't call `$app->execute()` from your custom CLI** unless you actually want Symfony's command-line argv parsing. For a script that runs a single dispatch loop (cron-style "run any due jobs"), just set `Factory::$application = $app` and call your business logic directly.

**Reference:** [`cli/joomla.php`](https://github.com/joomla/joomla-cms/blob/5.4-dev/cli/joomla.php) in Joomla core is the canonical CLI bootstrap. Read it, copy the structure.

Discovered 2026-05-23 setting up cs-cron-master's CLI on Virtuemarttemplates.net. Caught right after the §25 CGI-vs-CLI fix produced the first cron output we could actually read.

---

## 27. `CategoryServiceTrait` + `FieldsServiceTrait` both define `prepareForm()` — must use `insteadof`

If your component's Extension class implements **both** `CategoryServiceInterface` (items belong in Joomla categories) **and** `FieldsServiceInterface` (items support Joomla custom fields), the natural `use CategoryServiceTrait; use FieldsServiceTrait;` line **fatals on first dispatch** with:

```
PHP Fatal error: Trait method Joomla\CMS\Fields\FieldsServiceTrait::prepareForm
has not been applied as <YourComponent>::prepareForm, because of collision with
Joomla\CMS\Categories\CategoryServiceTrait::prepareForm
```

Both traits define `prepareForm()`, and PHP refuses to silently pick one. You have to resolve the collision explicitly with `insteadof`:

```php
class GroundedinventoryComponent extends MVCComponent implements
    BootableExtensionInterface,
    CategoryServiceInterface,
    FieldsServiceInterface
{
    use HTMLRegistryAwareTrait;
    use CategoryServiceTrait, FieldsServiceTrait {
        CategoryServiceTrait::prepareForm insteadof FieldsServiceTrait;
    }
    // ...
}
```

**Why pick `CategoryServiceTrait`'s version?** That's what Joomla core's `com_content` does — and the custom-fields rendering still happens via the separate `plg_system_fields` subscriber on `onContentPrepareForm` (which is dispatched by your form load), so you don't lose field rendering on edit views by dropping the trait's `prepareForm`.

**Symptom shape:** the component's manifest installs cleanly, the post-install card shows, the menu entry appears under Components — but the first click into the component returns HTTP 500. Joomla's standard error.php log doesn't capture the fatal (PHP terminates before Joomla's logger fires), so check the **per-domain PHP error log** at `~/logs/<domain>.php.error.log` on cPanel hosts.

**Reference implementation:** `com_groundedinventory` v0.1.1, `admin/src/Extension/GroundedinventoryComponent.php`. Identical pattern in Joomla core's `com_content`/`com_contact` extension classes.

---

## 28. `ONLY_FULL_GROUP_BY` rejects HAVING on a column not in the SELECT/GROUP BY

MySQL 5.7+ and MariaDB 10.x ship with `ONLY_FULL_GROUP_BY` in the default `sql_mode`. After a `GROUP BY`, a `HAVING` clause may **only** reference:

1. Columns in the GROUP BY list
2. Columns from the SELECT projection
3. Aggregate function results

A subquery like this will fatal with **"Unknown column 'i.reorder_threshold' in 'having clause'"** even though the column clearly exists in the inner table:

```sql
SELECT COUNT(*) FROM (
  SELECT i.id, COALESCE(SUM(s.qty), 0) AS oh
  FROM #__example_items i
  LEFT JOIN #__example_stock s ON s.item_id = i.id
  WHERE i.published = 1 AND i.reorder_threshold > 0
  GROUP BY i.id
  HAVING oh <= i.reorder_threshold       -- ← FATAL under ONLY_FULL_GROUP_BY
) AS sub;
```

**Fix: pull the threshold column into the inner SELECT and reference it by alias:**

```sql
SELECT COUNT(*) FROM (
  SELECT i.id, i.reorder_threshold AS rt, COALESCE(SUM(s.qty), 0) AS oh
  FROM #__example_items i
  LEFT JOIN #__example_stock s ON s.item_id = i.id
  WHERE i.published = 1 AND i.reorder_threshold > 0
  GROUP BY i.id, i.reorder_threshold
  HAVING oh <= rt                         -- ← references the projected alias
) AS sub;
```

**Alternative — when the aggregate is pre-computed in a subquery JOIN, drop the GROUP BY entirely and use a WHERE:**

```php
// Item list with low-stock filter — stk is already aggregated in the JOIN, so:
$query->where($db->quoteName('a.reorder_threshold') . ' > 0')
      ->where('COALESCE(stk.on_hand, 0) <= ' . $db->quoteName('a.reorder_threshold'));
```

This avoids the GROUP BY trap entirely.

**Why this bites on prod but not dev:** XAMPP / MAMP default MySQL configs sometimes ship without `ONLY_FULL_GROUP_BY`, so the query runs locally but fatals on the production cPanel host where the strict mode is on. Always test against MySQL 8 / MariaDB 10.4+ with default `sql_mode` before shipping.

**Reference:** `com_groundedinventory` v0.1.1 `Model/DashboardModel.php` (subquery alias fix) and `Model/ItemsModel.php` (drop-GROUP-BY fix). Hit live on groundedirrigation.ca 2026-06-24.

---

## Related

- [`JOOMLA5-EDGE-CASE-SCENARIOS.md`](JOOMLA5-EDGE-CASE-SCENARIOS.md) — environmental edge cases (hosting, CDNs, third-party extensions)
- [`JOOMLA5-UI-PATTERNS.md`](JOOMLA5-UI-PATTERNS.md) — UI / asset-pipeline traps including the `defer` options-vs-attribs lesson
- [`JOOMLA5-WEB-ASSETS-GUIDE.md`](JOOMLA5-WEB-ASSETS-GUIDE.md) — Web Asset Manager URI rules and inline asset patterns
- [`JOOMLA5-COMPONENT-ROUTING.md`](JOOMLA5-COMPONENT-ROUTING.md) — SEF router 3-part registration, callback naming, hidden menu items
- [`JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`](JOOMLA5-LANGUAGE-FILES-GOTCHAS.md) — language file paths, `.sys.ini`, INI encoding traps
- [`COMPONENT-TROUBLESHOOTING.md`](COMPONENT-TROUBLESHOOTING.md) — install / load / configuration diagnostics
