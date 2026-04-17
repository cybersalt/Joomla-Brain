# Joomla 5/6 Admin List Views — Filter Bar, Sortable Columns, Pagination

This guide captures the pattern for building admin list views (articles, users, categories, logs, or any custom list) so they look and behave **exactly like Joomla's native Article Manager / User Manager / Category Manager**.

Every example here is battle-tested in `cs-copy-to-j` (`com_copytoj`) — look at [admin/tmpl/copy/default.php](../cs-copy-to-j/admin/tmpl/copy/default.php) for the full working template.

---

## The non-negotiable rules

1. **Use the `js-stools` / `js-stools-container-bar` / `js-stools-container-list` markup.** These are Joomla's own class names — Atum and other admin templates style them specifically. Custom classes won't match.
2. **Wrap every `<select>` in the filter bar with Choices.js.** The native admin does this to every single filter dropdown, regardless of single- or multi-select. It's the reason the native filter bar has that unified chips / pill / search-inside-select feel.
3. **Drop `form-control-sm` / `form-select-sm` / `btn-sm` inside the filter bar.** Choices.js renders at the default Bootstrap size; mixing the small variant makes the Choices-wrapped selects taller than the buttons around them. Just use `form-control`, `form-select`, `btn btn-primary` (no `-sm`).
4. **Dropdowns auto-submit on change** (`onchange="this.form.submit()"`); the search box submits on Enter or the magnifier button. No "Apply" button needed.
5. **Make every column header a sort link** — don't provide Sort / Direction dropdowns in the filter bar. Click a header to sort ascending, click again to flip. Arrow indicator shows the current direction.
6. **Filter state lives in the URL** so deep-links, back/forward, and page refreshes all preserve the filter.
7. **Server-side pagination** — load a page at a time, not the whole list. Joomla's native pattern defaults to 20 rows per page with a limit dropdown (20 / 50 / 100 / 200).

---

## The HTML skeleton

```php
<form method="get" action="<?php echo Route::_($viewUrl); ?>" class="js-stools-form">
    <input type="hidden" name="option" value="com_example">
    <input type="hidden" name="view" value="<?php echo htmlspecialchars($currentView); ?>">
    <!-- Hidden inputs for sort state (set by column-header links) and
         any cross-panel state you need to preserve -->
    <input type="hidden" name="sort" value="<?php echo htmlspecialchars($filter['sort']); ?>">
    <input type="hidden" name="dir"  value="<?php echo htmlspecialchars($filter['direction']); ?>">

    <div class="js-stools clearfix">
        <!-- TOP BAR: search + filter toggle + clear + limit -->
        <div class="js-stools-container-bar d-flex flex-wrap gap-2 align-items-center mb-2">
            <div class="btn-group" role="group">
                <input type="search" class="form-control"
                       name="search" value="<?php echo htmlspecialchars($filter['search']); ?>"
                       placeholder="<?php echo Text::_('JSEARCH_FILTER'); ?>"
                       style="max-width:240px">
                <button type="submit" class="btn btn-primary" title="<?php echo Text::_('JSEARCH_FILTER_SUBMIT'); ?>">
                    <span class="icon-search" aria-hidden="true"></span>
                </button>
            </div>

            <button type="button" class="btn btn-primary"
                    data-bs-toggle="collapse" data-bs-target="#example-filterbar" aria-expanded="false">
                <?php echo Text::_('JOPTION_SELECT_FILTER'); /* or your own key */ ?>
                <span class="icon-caret-down" aria-hidden="true"></span>
            </button>

            <a class="btn btn-danger" href="<?php echo Route::_($viewUrl); ?>"
               title="<?php echo Text::_('JSEARCH_FILTER_CLEAR'); ?>">
                <?php echo Text::_('JSEARCH_FILTER_CLEAR'); ?>
            </a>

            <div class="js-stools-field-list ms-auto">
                <select name="limit" class="form-select" data-example-choices
                        style="max-width:110px"
                        onchange="this.form.submit()"
                        aria-label="<?php echo Text::_('JGLOBAL_LIST_LIMIT'); ?>">
                    <?php foreach ([20, 50, 100, 200] as $lim) : ?>
                        <option value="<?php echo $lim; ?>" <?php echo (int) $filter['limit'] === $lim ? 'selected' : ''; ?>><?php echo $lim; ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
        </div>

        <!-- COLLAPSED FILTER OPTIONS (opens when a filter is active) -->
        <div id="example-filterbar" class="js-stools-container-list collapse<?php echo $hasActiveFilter ? ' show' : ''; ?>">
            <div class="d-flex flex-wrap gap-2 py-2">
                <div class="js-stools-field-filter">
                    <select name="status" class="form-select" data-example-choices
                            style="min-width:240px"
                            onchange="this.form.submit()"
                            aria-label="Status">
                        <option value="">&mdash; Any status &mdash;</option>
                        <option value="published"   <?php echo $filter['status'] === 'published'   ? 'selected' : ''; ?>>Published</option>
                        <option value="unpublished" <?php echo $filter['status'] === 'unpublished' ? 'selected' : ''; ?>>Unpublished</option>
                    </select>
                </div>

                <!-- Multi-select filter (category, tag, etc) -->
                <div class="js-stools-field-filter" style="min-width:280px">
                    <select name="categories[]" class="form-select" data-example-choices multiple
                            data-placeholder="Categories"
                            onchange="this.form.submit()">
                        <?php foreach ($categories as $c) : ?>
                            <option value="<?php echo (int) $c['id']; ?>" <?php echo $c['selected'] ? 'selected' : ''; ?>>
                                <?php echo htmlspecialchars($c['label']); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
            </div>
        </div>
    </div>
</form>
```

---

## Required web assets

Register these in the template:

```php
$wa = $this->document->getWebAssetManager();
$wa->useScript('bootstrap.collapse');   // Filter Options toggle
$wa->useScript('choicesjs');            // All filter dropdowns
$wa->useStyle('choicesjs');
```

---

## Initialising Choices.js on every filter select

Mark each filter `<select>` with a marker attribute and init in one loop. One config handles single and multi.

```js
document.addEventListener('DOMContentLoaded', function () {
    if (typeof Choices === 'undefined') return;
    document.querySelectorAll('select[data-example-choices]').forEach(function (el) {
        if (el._exampleChoices) return;    // idempotent — init once
        try {
            var cfg = {
                shouldSort: false,
                itemSelectText: '',
                searchPlaceholderValue: 'Type to filter...'
            };
            if (el.multiple) {
                cfg.removeItemButton = true;                  // chip X
                cfg.placeholderValue = el.getAttribute('data-placeholder') || '';
            } else {
                cfg.searchEnabled = false;                     // no search on single selects
            }
            el._exampleChoices = new Choices(el, cfg);
        } catch (e) { /* noop */ }
    });
});
```

---

## Clickable sort column headers

The sort dropdowns are **redundant** when column headers are clickable. Use this helper:

```php
$sortLink = function (string $column, string $label, string $currentSort, string $currentDir, string $sortParam, string $dirParam, string $extraParams) use ($viewUrl): string {
    $isActive = $currentSort === $column;
    $nextDir  = ($isActive && $currentDir === 'asc') ? 'desc' : 'asc';
    $arrow    = $isActive
        ? ($currentDir === 'desc' ? ' <span class="icon-caret-down"></span>' : ' <span class="icon-caret-up"></span>')
        : '';
    $cls      = 'example-sort-link' . ($isActive ? ' example-sort-active' : '');
    $url      = \Joomla\CMS\Router\Route::_(
        $viewUrl . $extraParams
        . '&' . $sortParam . '=' . urlencode($column)
        . '&' . $dirParam  . '=' . urlencode($nextDir)
    );
    return '<a class="' . $cls . '" href="' . $url . '">' . htmlspecialchars($label) . $arrow . '</a>';
};
```

Use on every column that's worth sorting:

```php
<th><?php echo $sortLink('id',     'ID',     $filter['sort'], $filter['direction'], 'sort', 'dir', $extraQS); ?></th>
<th><?php echo $sortLink('title',  'Title',  $filter['sort'], $filter['direction'], 'sort', 'dir', $extraQS); ?></th>
<th><?php echo $sortLink('author', 'Author', $filter['sort'], $filter['direction'], 'sort', 'dir', $extraQS); ?></th>
<!-- etc -->
```

### Supporting CSS

```css
.example-sort-link {
    color: inherit;
    text-decoration: none;
    display: inline-flex;
    align-items: center;
    gap: 4px;
}
.example-sort-link:hover    { color: var(--bs-primary, #0d6efd); text-decoration: none; }
.example-sort-active        { color: var(--bs-primary, #0d6efd); font-weight: 600; }
```

---

## URL state convention

All filter/pagination/sort state should be URL-visible. Pick short parameter names and be consistent. For example in com_copytoj's users view:

| Param | Meaning |
| --- | --- |
| `us`     | search |
| `up`     | page number |
| `ulimit` | items per page |
| `ublock` | status (0/1) |
| `ugroup` | group id |
| `usort`  | sort column |
| `udir`   | sort direction |

When building pagination / sort / clear URLs, preserve every *other* state key so filtering one dimension doesn't reset the rest. A small concat helper is enough:

```php
$extraQS = '&us=' . urlencode($filter['search'])
    . '&ublock=' . urlencode($filter['block'])
    . '&ugroup=' . (int) $filter['group_id']
    . '&ulimit=' . (int) $filter['limit'];
```

Pass `$extraQS` into the sort-link helper and concatenate with pagination URLs.

---

## Server-side pagination

Three things the list model/controller must return:

1. **`rows`** — the page's items (e.g. 20 rows).
2. **`total`** — the count of items matching the filter *before* limit/offset. Don't count after limiting.
3. The current page / limit / offset so pagination UI can render Prev / Next + "Showing X–Y of Z".

Pagination snippet:

```php
<nav>
    <ul class="pagination pagination-sm mb-0">
        <li class="page-item <?php echo $page <= 1 ? 'disabled' : ''; ?>">
            <a class="page-link" href="<?php echo $prevUrl; ?>"><?php echo Text::_('JPREV'); ?></a>
        </li>
        <li class="page-item disabled">
            <span class="page-link"><?php echo $page; ?> / <?php echo $pages; ?></span>
        </li>
        <li class="page-item <?php echo $page >= $pages ? 'disabled' : ''; ?>">
            <a class="page-link" href="<?php echo $nextUrl; ?>"><?php echo Text::_('JNEXT'); ?></a>
        </li>
    </ul>
</nav>
```

---

## Clickable summary-count cards

Above the filter bar, native Joomla list screens often show overview counts. Make them clickable if they point at a filtered view:

```php
<?php
$cardLink = function (string $view, int $count, string $label): string {
    $href = \Joomla\CMS\Router\Route::_('index.php?option=com_example&view=' . $view);
    return '<a class="card text-center text-decoration-none example-count-card" href="' . $href . '">
        <div class="card-body py-2">
            <div class="display-6 lh-1">' . number_format($count) . '</div>
            <div class="small text-muted">' . htmlspecialchars($label) . ' <span class="icon-arrow-right"></span></div>
        </div>
    </a>';
};
?>
<div class="row g-2 mb-4">
    <div class="col-sm-4"><?php echo $cardLink('users', $stats['users'], 'Users'); ?></div>
    <div class="col-sm-4"><?php echo $cardLink('articles', $stats['articles'], 'Articles'); ?></div>
    <div class="col-sm-4"><?php echo $cardLink('categories', $stats['categories'], 'Categories'); ?></div>
</div>
```

```css
.example-count-card { color: inherit; transition: transform .1s ease, box-shadow .1s ease; }
.example-count-card:hover {
    transform: translateY(-1px);
    box-shadow: 0 0.25rem 0.75rem rgba(0,0,0,0.12);
    color: var(--bs-primary, #0d6efd);
}
```

---

## Language keys

Reuse Joomla's built-in keys where they exist — they're already translated in every language pack.

| Use | Key |
| --- | --- |
| Search placeholder | `JSEARCH_FILTER` |
| Search submit title | `JSEARCH_FILTER_SUBMIT` |
| Clear button | `JSEARCH_FILTER_CLEAR` |
| Prev / Next pagination | `JPREV` / `JNEXT` |
| Limit label | `JGLOBAL_LIST_LIMIT` |
| Sort by label | `JGLOBAL_SORT_BY` |
| Direction | `JGLOBAL_ORDER` |

**Don't use `JOPTION_SELECT_FILTER`** — it's not translated in most language packs and shows as the raw key. Define your own `COM_<EXT>_FILTER_OPTIONS` instead.

---

## Filter types to offer by list context

| List | Standard filters |
| --- | --- |
| Articles | Search, Status (Published/Unpublished/Archived/Trashed), Category (multi), Author, Tag, Access level, Language |
| Users | Search, Status (Active/Blocked), Group, Access level, Last-visit range |
| Categories | Search, Extension, Level, Parent, Access |
| Logs | Search, Operation type, Status, Date range |

If your data includes an "imported" or "processed" flag, add a yes/no/any filter for that too. Pre-fetch the relevant ID set from the destination log table and pass it to the source query as `IN (…)` / `NOT IN (…)` so pagination totals stay correct.

---

## Migration from custom filter bars

If you already have a hand-rolled filter bar, migrate in this order:

1. Wrap the whole thing in `<div class="js-stools">` with the two inner containers (`-container-bar` and `-container-list`).
2. Remove every `-sm` size modifier from `form-select` / `form-control` / `btn`.
3. Add `data-<ext>-choices` to every `<select>` and register the init loop.
4. Swap static Sort / Direction dropdowns for column-header sort links.
5. Add `onchange="this.form.submit()"` to every dropdown.
6. Wire `$wa->useScript('bootstrap.collapse')` + `$wa->useScript('choicesjs')` + `$wa->useStyle('choicesjs')` in the template.

---

## Pagination limit options — mirror Joomla core

Joomla 5 and Joomla 6 use the same set of limit values everywhere (`HTMLHelper::_('select.limitbox', …)`). Your list view must offer the **same options** or it'll stand out. Use:

```php
protected array $limitOptions = [5, 10, 15, 20, 25, 30, 50, 100, 500, 0];
// 0 renders as "All" (display the total with no LIMIT clause)
```

Rendering:

```php
<?php foreach ($this->limitOptions as $lim) : ?>
    <option value="<?php echo $lim; ?>" <?php echo (int) $filter['limit'] === $lim ? 'selected' : ''; ?>>
        <?php echo $lim === 0 ? Text::_('JALL') : (int) $lim; ?>
    </option>
<?php endforeach; ?>
```

In the model / adapter, treat `$limit = 0` as "no LIMIT" so queries honour the "All" choice:

```php
$limitClause = $limit > 0 ? "LIMIT {$offset}, {$limit}" : '';
```

---

## Mapping screens — safe defaults and bulk actions

If your component has a **mapping table** (a per-row action picker deciding how each source record lands in the destination — e.g. per-category routing, per-user-group routing), these rules keep it safe and usable.

### Default every row to "Skip"

When the user first lands on the mapping screen, **every row's action must default to Skip** (or an equivalent no-op). A source with hundreds of categories / groups must not automatically clone all of them just because the page rendered.

```php
// In the template
$override = $overrides[$sourceId] ?? ['action' => 'skip'];   // not 'auto'
$action   = $override['action'];
```

```php
// In the mapper helper
$action = $this->overrides[$sourceId]['action'] ?? 'skip';
```

### Offer a "Set all to…" bulk dropdown

Paired with the safe default, give users who want the old auto-create-everything behaviour a one-click path:

```html
<div class="btn-group" role="group">
    <button type="button" class="btn btn-sm btn-outline-primary dropdown-toggle"
            data-bs-toggle="dropdown" aria-expanded="false">
        Set all to…
    </button>
    <ul class="dropdown-menu">
        <li><button type="button" class="dropdown-item"
                    data-example-action="setAllMappingAction" data-example-arg="skip">
            <strong>Skip</strong>
            <br><small class="text-muted">Reset everything to do-nothing.</small>
        </button></li>
        <li><button type="button" class="dropdown-item"
                    data-example-action="setAllMappingAction" data-example-arg="auto">
            <strong>Auto</strong>
            <br><small class="text-muted">Smart: match existing by path / title, create if missing.</small>
        </button></li>
        <li><button type="button" class="dropdown-item"
                    data-example-action="setAllMappingAction" data-example-arg="create">
            <strong>Create new</strong>
            <br><small class="text-muted">Force-create a brand-new destination for every source.</small>
        </button></li>
        <li><hr class="dropdown-divider"></li>
        <li><button type="button" class="dropdown-item"
                    data-example-action="setAllMappingAction" data-example-arg="auto-matching-only">
            <strong>Auto for matching, Skip for the rest</strong>
            <br><small class="text-muted">Sets Auto on rows whose auto-match badge shows a match, leaves the rest on Skip.</small>
        </button></li>
    </ul>
</div>
```

Every dropdown item includes a short muted description so users know what they're about to do.

JS — mirrors show/hide of the auxiliary inputs (destination picker, new-title input) so a bulk change behaves exactly like changing each row by hand:

```js
setAllMappingAction(action) {
    const rows = document.querySelectorAll('#mapping-table tr[data-source-id]');
    rows.forEach(row => {
        const sel = row.querySelector('.row-action');
        if (!sel) return;
        let target = action;
        if (action === 'auto-matching-only') {
            const badge = row.querySelector('td.match-col .badge');
            const hasMatch = badge && /bg-(success|info)/.test(badge.className);
            target = hasMatch ? 'auto' : 'skip';
        }
        sel.value = target;
        const dest  = row.querySelector('.row-dest');
        const title = row.querySelector('.row-new-title');
        if (dest)  dest.style.display  = (target === 'map') ? '' : 'none';
        if (title) title.style.display = (target === 'create') ? '' : 'none';
    });
}
```

### Help tooltip on every option + button

Every dropdown option and every header button needs a one-line `title` tooltip explaining what it does. Never assume the user knows the difference between "Auto" and "Map". Language-file suffix convention: `_HINT`.

```ini
COM_EXAMPLE_ACTION_SKIP="Skip"
COM_EXAMPLE_ACTION_SKIP_HINT="Do nothing with this source record. Items in it fall back to the destination default."
COM_EXAMPLE_ACTION_AUTO="Auto"
COM_EXAMPLE_ACTION_AUTO_HINT="Match this source record to a destination with the same path or title. If no match exists, create a new one."
COM_EXAMPLE_ACTION_MAP="Map to existing"
COM_EXAMPLE_ACTION_MAP_HINT="Route this source record into a specific existing destination you pick from the dropdown."
COM_EXAMPLE_ACTION_CREATE="Create new"
COM_EXAMPLE_ACTION_CREATE_HINT="Create a brand-new destination with the title you type."
```

Applied per option:

```php
<option value="skip"   title="<?php echo Text::_('COM_EXAMPLE_ACTION_SKIP_HINT'); ?>">Skip</option>
<option value="auto"   title="<?php echo Text::_('COM_EXAMPLE_ACTION_AUTO_HINT'); ?>">Auto</option>
<option value="map"    title="<?php echo Text::_('COM_EXAMPLE_ACTION_MAP_HINT'); ?>">Map to existing</option>
<option value="create" title="<?php echo Text::_('COM_EXAMPLE_ACTION_CREATE_HINT'); ?>">Create new</option>
```

Put matching `title` attributes on the Save / Copy / Reset buttons in the card header too.

---

## Sanity check

Before shipping a list view, the filter bar should:

- [ ] Top row has search, Filter Options toggle, Clear, Limit (in that order; ms-auto on the limit wrapper).
- [ ] All controls are the same height and font size.
- [ ] Every `<select>` inside the bar is Choices.js-wrapped.
- [ ] Clicking Filter Options toggles the advanced row with Bootstrap collapse.
- [ ] Clear navigates to the plain view URL (empty filter state).
- [ ] Every dropdown auto-submits on change.
- [ ] Column headers are sort links with direction arrow.
- [ ] Pagination preserves filter state.
- [ ] Limit dropdown offers 5 / 10 / 15 / 20 / 25 / 30 / 50 / 100 / 500 / All (matching Joomla core).
- [ ] Count cards at the top (if any) are clickable links.
- [ ] Page looks the same in light and dark admin themes.

If the view has a mapping table:

- [ ] Every row's default override action is Skip (safe no-op).
- [ ] The card header has a "Set all to…" dropdown with at least Skip / Auto / Create new.
- [ ] Each bulk-action dropdown item has a one-line description.
- [ ] Every per-row action `<option>` has a `title` tooltip (key suffix `_HINT`).
- [ ] Save / Copy / Reset buttons in the card header have `title` tooltips.
- [ ] JS bulk-action handler mirrors show/hide of auxiliary inputs (destination picker / new-title input).

Ship it.
