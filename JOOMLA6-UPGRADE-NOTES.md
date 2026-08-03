# Joomla 5 → 6 Upgrade Notes (running a real site through it)

`JOOMLA6-CHECKLIST.md` covers **building an extension for** Joomla 6. This file covers the other
half: **taking an existing Joomla 5 site up to Joomla 6** — the preconditions the CLI enforces, the
step that crashes, the migrations that silently do not run, and the failure that leaves a site
looking healthy while a third of its pages are 500ing.

Everything here was measured on real 5.4.7 → 6.1.2 upgrades, not read from release notes.

> **The one-line summary:** the upgrade is *recoverable but not clean*. `core:update` dies partway
> on every run we have done, and the documented recovery (`maintenance:database --fix`) repairs
> **structure only** — it silently skips every data migration and then stamps the schema as current.

---

## 1. The backward-compatibility plugin gates the whole upgrade

Joomla 6 **refuses to install** while the J3 compatibility shim is enabled:

```
Check pre-conditions for a major upgrade to version 6.1.2...
 [ERROR] The 'Behaviour - Backward Compatibility' plugin is enabled.
 [INFO] The pre-conditions for a major upgrade are not fulfilled.
```

Why this matters more than it looks:

|  | Joomla 5.4 | Joomla 6.x |
|---|---|---|
| Where the J3 class aliases live | `plg_behaviour_compat` → `src/classmap/classmap.php` | `plg_behaviour_compat6` → `src/classmap/classmap.php` |
| `classes_aliases` default | **`1` — ON** | **`0` — OFF** |
| Code calling `JFactory` | works | **fatal: `Class "JFactory" not found`** |

So a J3-era API call is **latent on J5 and live on J6**. And because Joomla forces the shim off as a
*precondition*, the sequence for a site with legacy calls is:

1. Try to upgrade → blocked.
2. Disable the compat plugin to proceed.
3. **The site breaks right there, still on Joomla 5**, before the upgrade even runs.

The breakage presents as *"disabling a plugin broke my site"*, not *"upgrading broke my site"*.

**Therefore: sweep legacy APIs FIRST, prove every view renders with the shim off, and only then
upgrade.** Not the other way round.

### Deriving the alias map

On a J5 box you cannot read `compat6`'s classmap — J5 ships `plg_behaviour_compat6` as a **no-op
placeholder** (`getSubscribedEvents()` returns `[]`, no classmap directory) purely so the row exists
to carry forward. The real ~441-entry classmap only lands with the J6 files.

Use **J5's own `plugins/behaviour/compat/src/classmap/classmap.php`** (443 entries) to build the
rename map, and never hand-write the list — hand-listing is how `JDocumentHTML`, `JPluginHelper` and
`JComponentHelper` get missed. Matching must be **case-insensitive** (`JURI` vs the classmap's
`JUri`).

Classes with **no alias in any classmap** need hand fixes, not renames:

| Removed | Replacement |
|---|---|
| `JError` | `throw new \Exception(Text::_('…'), 404)` |
| `JRequest` | `Factory::getApplication()->getInput()` |
| `JResponse` | the application object |
| `jimport()` | delete the call — Joomla autoloads |

### A class-level sweep is not a clean bill of health

Renaming classes exposes **method-level** J3-isms that a class sweep cannot see:

```php
$config =& JFactory::getConfig();          // becomes Factory::getConfig()
$config->getValue('config.sitename');      // …and NOW fatals: no such method
```

| J3 idiom | Modern form | Why a class sweep misses it |
|---|---|---|
| `->getValue('config.x')` | `->get('x')` | method rename, not a class rename |
| `$x =& Factory::getFoo()` | `$x = Factory::getFoo()` | PHP 8 notice, not a class reference |

Grep for both after any sweep:

```bash
grep -rnE -- '->(getValue|setValue|loadINI|loadJSON)\(' <path> --include='*.php'
grep -rnE -- '=& *[A-Za-z\\]+::' <path> --include='*.php'
```

**Fix `error.php` first.** If the fatal is raised while rendering the error page, the displayed
error describes the error handler and masks the real fault underneath.

---

## 2. Orphan J3 components take down *every* page

A single removed-in-J4 component still sitting on disk **and registered in `#__extensions`** will
fatal the whole site once the shim is off, whether or not anything links to it:

```
Class "JComponentRouterBase" not found      ← components/com_search/router.php
```

Joomla loads every component's router for SEF routing, so one piece of migration debris is enough.

**Detect:** after the code sweep reaches zero refs, disable the shim and walk the views. If pages
still 500, the class in the error is the pointer:

```bash
grep -rln '<ClassName>' <root> --include='*.php'   # ignore classmap.php and vendor compat shims
```

**Fix:** quarantine (don't delete) the orphan tree, disable its `#__extensions` rows and update
site, and **repoint menu items rather than unpublishing them** — repointing a "Search" item from
`com_search` to `com_finder` keeps the label and therefore keeps navigation identical. Unpublishing
silently changes the rendered menu.

> **Check `component_id`, not just `link`.** Joomla resolves the component from
> `#__menu.component_id`. A menu row whose `link` says `com_finder` while `component_id` still
> points at the old component will serve a 404.

---

## 3. `core:update` crashes on finalize — recover, do not roll back

Every upgrade we have run ends the same way. The CLI copies all the J6 files, then dies:

```
Too few arguments to function Joomla\CMS\Installer\Installer::setAdapter(),
1 passed … and exactly 2 expected
```

**This is recoverable and not fatal.** The files are J6; only the finalize step (schema + manifest
refresh) is missing. Do **not** roll back. Run:

```bash
php cli/joomla.php maintenance:database --fix        # without --fix it only REPORTS
php cli/joomla.php update:joomla:remove-old-files
```

### `--fix` contradicts itself in its own output

It prints the **stale** problem table (captured *before* the repair) and then
`[INFO] All database table structures are up to date.` in the same output. The two disagree and it
reads like a failed fix. Verify directly instead of reading the printout:

```sql
SELECT version_id FROM #__schemas WHERE extension_id = 700;   -- want the 6.1.x date-stamp
SHOW COLUMNS FROM #__history;                                  -- want is_current + is_legacy
SELECT JSON_EXTRACT(manifest_cache, '$.version')
  FROM #__extensions WHERE name = 'files_joomla';              -- want the full 6.1.2
```

A CMS DB version of `6.1.0-<date>` against manifest `6.1.2` is **normal** — schema files only go to
6.1.0.

---

## 4. ⚠️ `--fix` applies STRUCTURE ONLY — every data migration is skipped

This is the dangerous half, and it invalidates "the fix worked" as a conclusion.

`maintenance:database --fix` runs Joomla's *schema checker*, which compares table **structure** and
applies only what alters structure. Its own output says so, and it is easy to read past:

```
[INFO] 18 database changes did not alter table structure and were skipped.
```

Those "skipped" changes are the `INSERT` / `UPDATE` / `DELETE` statements — **the data migrations**.
`--fix` then stamps `#__schemas` to the current version anyway, so the site *claims* to be fully
updated while carrying J5-era data under J6 structure.

**Scale on a 5.4.7 → 6.1.2 upgrade: 18 of the 20 `6.*.sql` files contain data statements. None run.**

The visible symptom is raw language constants in the admin (e.g. `COM_GUIDEDTOURS_TOUR_WHATSNEW_5_2_TITLE`
under **Take a Tour**) — J6 no longer defines the J5 tour keys, and the `DELETE` that should have
removed those rows never ran.

**Rewinding `#__schemas` and re-running `--fix` does NOT help.** The checker will never execute a
non-structural statement.

### Repair: apply the update SQL yourself, in version order

```bash
SQLDIR=$SITE/administrator/components/com_admin/sql/updates/mysql
mkdir -p /tmp/j6sql
for f in $(cd $SQLDIR && ls 6.*.sql | sort -V); do
  sed 's/`#__/`<yourprefix>_/g' $SQLDIR/$f > /tmp/j6sql/$f
done
for f in $(cd /tmp/j6sql && ls *.sql | sort -V); do
  mysql --force -h localhost -u <user> -p<pw> <db> < /tmp/j6sql/$f 2>>/tmp/j6sql-errors.txt
done
grep -oE 'ERROR [0-9]+' /tmp/j6sql-errors.txt | sort | uniq -c
```

`--force` is required: statements whose structural half already ran raise **ERROR 1060 (duplicate
column)**. That is the *expected* noise — the signature on every run we have done is exactly
`3 × ERROR 1060` and nothing else. Joomla's update SQL is written defensively
(`INSERT … WHERE NOT EXISTS`), so re-running is safe. **Back the database up first regardless.**

### Gate

```sql
-- must be 0: tours whose language constant J6 no longer defines
SELECT COUNT(*) FROM #__guidedtours WHERE title LIKE '%WHATSNEW_5_%';
-- must be 2: the J6 tours
SELECT COUNT(*) FROM #__guidedtours WHERE uid IN ('joomla-whatsnew-6-0','joomla-whatsnew-6-1');
```

Generalise it: **a raw `COM_*` / `MOD_*` / `PLG_*` constant visible anywhere in the admin is the
symptom of skipped data migrations, not a language-pack problem.** Sweep the dashboard for
`/\b(COM|MOD|PLG|TPL|JGLOBAL)_[A-Z0-9_]{6,}\b/` after every upgrade; 0 is the gate.

---

## 5. ⭐ The manual SQL repair leaves NEW J6 core extensions half-registered

Direct consequence of §4, and the nastiest failure in this document because **the site looks fine**.

After applying the data migrations, `com_content` **article and category views return HTTP 500**
while the home page and featured view stay **200**:

```
Class "Joomla\Plugin\Fields\Note\Extension\Note" not found
  from plugins/fields/note/services/provider.php
```

The class file is present on disk. Two separate things are wrong, both downstream of the finalize
crash plus the manual-SQL workaround:

1. **`manifest_cache` is empty on every row the SQL inserted.** The `6.*.sql` files `INSERT` rows
   for core extensions that are *new in J6*, but they cannot populate `manifest_cache` — only a real
   install does. Observed set: `plg_fields_note`, `plg_fields_number`, `plg_captcha_powcaptcha`,
   `cassiopeia_extended`.
2. **`administrator/cache/autoload_psr4.php` is stale.** It still predates the upgrade and contains
   none of the new extensions' namespaces, so their classes cannot autoload at all.

`plg_fields_note` ships **enabled by default** and loads on content views, so #2 alone is enough to
500 every article and category page.

### Fix — in this order

```bash
rm administrator/cache/autoload_psr4.php     # regenerates on the next request
```

That alone restores the views; the regenerated file then contains `Fields\Note` / `Fields\Number`.
Then repair the manifests, either way:

**Option A — let Joomla re-register them** (cleanest when the stub rows are the only problem):

```bash
# DELETE the stub rows the SQL inserted, then:
php cli/joomla.php extension:discover
php cli/joomla.php extension:discover:install
```

**Option B — refresh in place** via Joomla's own API. A minimal CLI bootstrap works but note **two
traps**: it must alias the session services to `session.cli` (copy the alias block from
`cli/joomla.php`) or it dies on `SessionInterface`, and the Installer must be handed a database —
`new Installer()` does not self-wire:

```php
$installer = new \Joomla\CMS\Installer\Installer();
$installer->setDatabase($db);
$installer->refreshManifestCache((int) $extensionId);
```

### Gate — run on every upgrade that hit the finalize crash

```sql
SELECT COUNT(*) FROM #__extensions WHERE manifest_cache = '' OR manifest_cache IS NULL;  -- must be 0
```

```bash
ls -la administrator/cache/autoload_psr4.php    # mtime MUST post-date the upgrade
```

**And curl an article view specifically.** `/` and `com_content&view=featured` both stay **200**
throughout, so a home-page-only smoke test reports a clean site. Add these to the standard walk:

```
index.php?option=com_content&view=article&id=<n>
index.php?option=com_content&view=category&layout=blog&id=<n>
```

---

## 6. Smaller things that cost a debug cycle

### `cassiopeia_extended` is new core furniture

Joomla 6.1 ships a second core site template, `cassiopeia_extended` (`locked=1`, refuses
uninstall). Any "expected installed template count" gate written against J5 numbers will now read
one higher. It is not cruft — do not try to remove it.

### Read `@deprecated` annotations from the TARGET tree, never the source tree

Joomla 5.4.7's `libraries/src/Factory.php` says:

```
@deprecated  4.3 will be removed in 6.0
```

for `getUser` / `getDocument` / `getLanguage` / `getDbo` / `getConfig` / `getSession` / `getCache` /
`getMailer`. Taken at face value that makes every such call fatal on Joomla 6.

**It is stale text.** Checked against a real 6.1.2 tree: all eight methods still exist and every
annotation there reads `4.3 will be removed in 7.0`. Joomla revised the target version and the J5
file was never back-updated. These are **deprecations, not fatals** — clean them to be J7-ready, but
do not let the J5 wording trigger a false emergency.

Same discipline as the classmap: when an annotation drives a decision, read it from the version you
are moving **to**.

### "Zero deprecations under maxdebug" is unachievable — use an A/B delta

Joomla 6 deprecates heavily against itself (Cassiopeia alone: ~1000 entries over a 5-view walk), and
the deprecation log records only the *raising* core file, never the calling extension — so grepping
the log for your own path is a **false green**; it can never match. Two gates that work:

1. **Code-level** — grep your code for the `@deprecated` methods listed in the target tree's
   `Factory.php`.
2. **A/B delta** — walk N views with your template/extension active, then with a core default
   active, and compare counts and message mix. Attribute only what you uniquely add.

> ⚠️ **Self-tripping filter warning:** deprecation entries are logged at priority `WARNING`. An SSH
> pipeline that filters `grep -v WARNING` (e.g. to suppress OpenSSH's post-quantum banner) silently
> eats every entry and reports a clean log.

### The update channel must be set to "next"

`com_joomlaupdate`'s `updatesource` defaults to `default`, which will never offer a major upgrade:

```sql
UPDATE #__extensions
   SET params = JSON_SET(params, '$.updatesource', 'next')
 WHERE element = 'com_joomlaupdate';
```

---

## 7. Order of operations (the whole thing on one page)

1. **Snapshot** — full file tree + database. The finalize crash is recoverable, but the manual SQL
   pass is not something you want to attempt without a restore point.
2. **Sweep legacy APIs** to zero — classes, then the method-level greps. `php -l` everything.
3. **Sweep the SITE, not just your code** — orphan J3 components, their `#__extensions` rows and
   update sites, and any menu items pointing at them (`component_id`, not just `link`).
4. **Disable the compat shim** (`classes_aliases = 0`) and **prove every view returns 200** —
   home, featured, login, contact, finder, **article**, **category blog**, and the administrator.
   This is the precondition for being allowed to upgrade, not a post-upgrade check.
5. **Set the update channel to `next`**, then run `core:update`.
6. **Expect the finalize crash.** Recover with `maintenance:database --fix` +
   `update:joomla:remove-old-files`. Verify by SQL, not by the printout.
7. **Apply the skipped data migrations** by hand, in version order. Expect `3 × ERROR 1060`.
8. **Repair the half-registered new extensions** — clear `autoload_psr4.php`, refresh
   `manifest_cache`, then re-walk the views *including an article page*.
9. **Leave the demo/site with `classes_aliases = 0`.** That is Joomla's own default, so the site
   then represents a real J6 install and any regression fails loudly instead of being silently
   papered over by the shim.

---

## See also

- `JOOMLA6-CHECKLIST.md` — building an extension **for** Joomla 6, plus the full J5→J6 deprecation matrix.
- `JOOMLA5-LANGUAGE-FILES-GOTCHAS.md` — including how one malformed tag in a language string can break an entire admin form.
- `JOOMLA5-UI-PATTERNS.md` § 13 — colour form fields, and the jQuery dependency that disappears with them.
