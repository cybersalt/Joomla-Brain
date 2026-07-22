# Joomla 5/6 Scheduled Tasks — Plugin Author Guide

This is the recipe for adding a Scheduled-Tasks routine to a Cybersalt Joomla 5/6 extension. Battle-tested in `cs-template-integrity` v2.4.0 (`plg_task_cstemplateintegrity` — purges old `#__cstemplateintegrity_backups` rows on a cron schedule).

The pattern follows Joomla core's own task plugins (`plg_task_check_files`, `plg_task_sessiongc`, `plg_task_sitestatus`). Once you've built one, the rest are copy-paste plus the routine body.

---

## 1. What a task plugin actually is

A **task plugin** is a regular Joomla plugin in the `task` group that:

1. Advertises one or more named **routines** in the `com_scheduler` task-type dropdown (`onTaskOptionsList`).
2. Loads the per-task **parameters form XML** into the task edit screen (`onContentPrepareForm`).
3. **Executes** the routine when `com_scheduler` fires the task (`onExecuteTask`).

Each routine has a unique id like `myext.doSomething`. The id is stored on the task row in `#__scheduler_tasks` and dispatched back to the plugin at execution time.

---

## 2. Directory layout

```
plg_task_myext/
├── myext.xml                          ← plugin manifest
├── services/provider.php              ← DI service provider
├── src/Extension/Myext.php            ← plugin class (the only PHP file you write)
├── forms/<routine>.xml                ← per-routine parameters form
└── language/en-GB/
    ├── plg_task_myext.ini             ← strings used at runtime (UI labels)
    └── plg_task_myext.sys.ini         ← strings used at install/admin-list time
```

Plugin **element name** matches the second slug in the routine id — `plg_task_myext` advertises routines like `myext.<routineName>`. Joomla doesn't enforce this, but it makes the wiring obvious.

---

## 3. The manifest

```xml
<?xml version="1.0" encoding="UTF-8"?>
<extension type="plugin" group="task" method="upgrade">
    <name>plg_task_myext</name>
    <author>Cybersalt</author>
    <creationDate>2026</creationDate>
    <copyright>Copyright (C) 2026 Cybersalt. All rights reserved.</copyright>
    <license>GNU General Public License version 2 or later</license>
    <version>1.0.0</version>
    <description>PLG_TASK_MYEXT_XML_DESCRIPTION</description>

    <targetplatform name="joomla" version="5\.[0-9]+|6\.[0-9]+" />

    <namespace path="src">Cybersalt\Plugin\Task\Myext</namespace>

    <files>
        <folder plugin="myext">services</folder>
        <folder>forms</folder>
        <folder>src</folder>
    </files>

    <languages>
        <language tag="en-GB">language/en-GB/plg_task_myext.ini</language>
        <language tag="en-GB">language/en-GB/plg_task_myext.sys.ini</language>
    </languages>
</extension>
```

Group is `task` — Joomla 5 introduced this group specifically for `com_scheduler` routines. `<folder plugin="myext">services</folder>` tells Joomla which folder contains the service provider for the plugin element.

---

## 4. The service provider

`services/provider.php`:

```php
<?php
defined('_JEXEC') or die;

use Cybersalt\Plugin\Task\Myext\Extension\Myext;
use Joomla\CMS\Extension\PluginInterface;
use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\PluginHelper;
use Joomla\DI\Container;
use Joomla\DI\ServiceProviderInterface;
use Joomla\Event\DispatcherInterface;

return new class () implements ServiceProviderInterface {
    public function register(Container $container): void
    {
        $container->set(
            PluginInterface::class,
            function (Container $container) {
                $dispatcher = $container->get(DispatcherInterface::class);
                $plugin     = new Myext(
                    $dispatcher,
                    (array) PluginHelper::getPlugin('task', 'myext')
                );
                $plugin->setApplication(Factory::getApplication());

                return $plugin;
            }
        );
    }
};
```

The dispatcher inject is **mandatory** for task plugins (unlike most plugin groups where it's optional) — `TaskPluginTrait` expects it.

---

## 5. The plugin class

`src/Extension/Myext.php`:

```php
<?php
declare(strict_types=1);

namespace Cybersalt\Plugin\Task\Myext\Extension;

defined('_JEXEC') or die;

use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Component\Scheduler\Administrator\Event\ExecuteTaskEvent;
use Joomla\Component\Scheduler\Administrator\Task\Status;
use Joomla\Component\Scheduler\Administrator\Traits\TaskPluginTrait;
use Joomla\Event\SubscriberInterface;

final class Myext extends CMSPlugin implements SubscriberInterface
{
    use TaskPluginTrait;

    /**
     * Routine catalogue. Maps routine-id → language-prefix + form +
     * implementation method.
     */
    private const TASKS_MAP = [
        'myext.doSomething' => [
            'langConstPrefix' => 'PLG_TASK_MYEXT_TASK_DO_SOMETHING',
            'form'            => 'do_something',
            'method'          => 'doSomething',
        ],
    ];

    protected $autoloadLanguage = true;

    public static function getSubscribedEvents(): array
    {
        return [
            'onTaskOptionsList'    => 'advertiseRoutines',
            'onContentPrepareForm' => 'enhanceTaskItemForm',
            'onExecuteTask'        => 'standardRoutineHandler',
        ];
    }

    protected function doSomething(ExecuteTaskEvent $event): int
    {
        $params = (object) ($event->getArgument('params') ?? new \stdClass());
        $option = (int) ($params->option ?? 0);

        $this->logTask("Doing something with option={$option}");

        // ... actual work ...

        return Status::OK;
    }
}
```

The three subscribed events all map to methods on `TaskPluginTrait`:

- **`advertiseRoutines`** walks `TASKS_MAP` and adds each entry to the task-type dropdown.
- **`enhanceTaskItemForm`** detects the task edit form and loads the matching XML from `forms/<routine.form>.xml`.
- **`standardRoutineHandler`** reads the routine id off the event and dispatches to `TASKS_MAP[$id]['method']`.

You don't write any of the trait code. You just write the **routine method** (here, `doSomething`).

---

## 6. The form XML — the `<fields name="params">` wrapper

**This is the highest-value gotcha in the whole guide.** Burned a release on it in `cs-template-integrity` v2.4.0.

`forms/do_something.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<form>
    <fields name="params">
        <fieldset name="basic">
            <field name="option" type="number" default="0"
                   label="PLG_TASK_MYEXT_TASK_DO_SOMETHING_OPTION_LABEL"
                   description="PLG_TASK_MYEXT_TASK_DO_SOMETHING_OPTION_DESC"
                   filter="integer" />
        </fieldset>
    </fields>
</form>
```

The **`<fields name="params">` wrapper is mandatory**. Without it:

- ✅ The fields render correctly on the task edit screen.
- ❌ The values are NOT saved.

This happens because `com_scheduler` stores per-task overrides in a single `params` JSON column on `#__scheduler_tasks`. Its save handler only walks fields nested under `<fields name="params">`. Fields outside that wrapper are visible to the form layer but invisible to the save layer — the user edits them, clicks Save, sees the values vanish on reload.

Symptom: user edits `option`, clicks Save, reopens, value is back to the default. You'll waste hours suspecting form validation, the filter attribute, the field type — none of those are the issue. The wrapper is.

---

## 7. The language files

`language/en-GB/plg_task_myext.ini`:

```ini
PLG_TASK_MYEXT="My Extension — Scheduled tasks"
PLG_TASK_MYEXT_XML_DESCRIPTION="Adds Scheduled-Tasks routines for My Extension."

PLG_TASK_MYEXT_TASK_DO_SOMETHING_TITLE="My Extension: Do something"
PLG_TASK_MYEXT_TASK_DO_SOMETHING_DESC="Detailed description of what the routine does, shown on the task type info screen."

PLG_TASK_MYEXT_TASK_DO_SOMETHING_OPTION_LABEL="An option"
PLG_TASK_MYEXT_TASK_DO_SOMETHING_OPTION_DESC="What this option controls."

; Shim for a Joomla core string missing on some 5.x en-GB packs.
; Renders as the raw key on the task edit screen otherwise.
COM_SCHEDULER_PARAMETERS_FIELDSET_LABEL="Parameters"
```

The `langConstPrefix` in `TASKS_MAP` is `PLG_TASK_MYEXT_TASK_DO_SOMETHING`. Joomla expects:

- `<prefix>_TITLE` — what shows in the dropdown
- `<prefix>_DESC` — what shows on the task type info screen
- `<prefix>_<FIELD_NAME>_LABEL` / `_DESC` — for each field in the form XML

`sys.ini` ships a stripped-down version of the same strings (used at install / admin list time before runtime language is loaded). At minimum: `PLG_TASK_MYEXT`, `PLG_TASK_MYEXT_XML_DESCRIPTION`, `<prefix>_TITLE`.

**Language-key shim** (last line): on some Joomla 5.x point releases the core `com_scheduler` en-GB pack is missing `COM_SCHEDULER_PARAMETERS_FIELDSET_LABEL`, so the "Parameters" tab on the task edit screen renders as the raw key. Define it in your plugin's `.ini` and Joomla's global string pool resolves it. If the core pack later starts shipping the key, the core version wins — no conflict. See [`JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`](JOOMLA5-LANGUAGE-FILES-GOTCHAS.md) for the broader pattern.

---

## 8. Package-installer integration

If the task plugin ships inside a package (`pkg_*`), the package's `script.php` should do two things in `postflight`:

### 8.1 Auto-enable the plugin

Joomla installs third-party plugins **disabled** by default. The task plugin won't appear in the task-type dropdown until the admin manually flips it on. Auto-enable it in postflight:

```php
private function enableTaskPlugin(): void
{
    $db = Factory::getContainer()->get(DatabaseInterface::class);
    try {
        $query = $db->getQuery(true)
            ->update($db->quoteName('#__extensions'))
            ->set($db->quoteName('enabled') . ' = 1')
            ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'))
            ->where($db->quoteName('element') . ' = ' . $db->quote('myext'))
            ->where($db->quoteName('folder') . ' = ' . $db->quote('task'));
        $db->setQuery($query)->execute();
    } catch (\Throwable $e) {
        Log::add('Could not auto-enable plg_task_myext: ' . $e->getMessage(),
                 Log::WARNING, 'pkg_myext');
    }
}
```

### 8.2 Seed a default task instance (optional)

If the extension is more usable with a pre-configured task, seed one in `#__scheduler_tasks` so the admin has a ready-made starting point. **State = 0 (unpublished)** so the very first cron tick doesn't fire before the admin has reviewed the config:

```php
private function seedDefaultTask(): void
{
    $db = Factory::getContainer()->get(DatabaseInterface::class);
    try {
        $taskType = 'myext.doSomething';

        // Idempotency check — never create duplicates on re-install / update.
        $check = $db->getQuery(true)
            ->select('COUNT(*)')
            ->from($db->quoteName('#__scheduler_tasks'))
            ->where($db->quoteName('type') . ' = :type')
            ->bind(':type', $taskType, ParameterType::STRING);
        if ((int) $db->setQuery($check)->loadResult() > 0) {
            return;
        }

        $now = Factory::getDate()->toSql();
        $row = (object) [
            'title'           => 'My Extension: Do something',
            'type'            => $taskType,
            'execution_rules' => json_encode([
                'rule-type'      => 'interval-hours',
                'interval-hours' => 24,
                'exec-day'       => '*',
                'exec-time'      => '00:00',
            ]),
            'cron_rules'      => json_encode(['type' => 'interval', 'exp' => 'PT24H']),
            'state'           => 0,                        // UNPUBLISHED
            'last_exit_code'  => -1,
            'times_executed'  => 0,
            'times_failed'    => 0,
            'priority'        => 0,
            'ordering'        => 0,
            'note'            => 'Seeded by installer. Review params and publish.',
            'params'          => json_encode([
                'option' => 0,
            ]),
            'created'         => $now,
            'created_by'      => Factory::getApplication()->getIdentity()?->id ?? 0,
        ];

        $db->insertObject('#__scheduler_tasks', $row, 'id');
    } catch (\Throwable $e) {
        Log::add('Could not seed default task: ' . $e->getMessage(),
                 Log::WARNING, 'pkg_myext');
    }
}
```

Failure is non-fatal — log a warning and let the install continue. The admin can build the task by hand if seeding fails.

---

## 9. Status return codes

The routine method must return an integer from `Joomla\Component\Scheduler\Administrator\Task\Status`:

| Constant | When to return |
|---|---|
| `Status::OK` | Routine ran cleanly, no special handling needed |
| `Status::WILL_RESUME` | Routine is split across multiple ticks — `com_scheduler` will fire it again |
| `Status::KNOCKOUT_OK` | Ran but should not run again on this tick (e.g., nothing to do) |
| `Status::KNOCKOUT_FAIL` | Ran but failed in a way that shouldn't retry immediately |
| `Status::NO_TIME` | Couldn't finish in the allotted time budget |

For most one-shot routines: `return Status::OK;`. Exceptions bubble out of the routine and `com_scheduler` records them automatically — no need to wrap your own work in try/catch unless you want graceful degradation.

---

## 10. Reading task params

```php
$params = (object) ($event->getArgument('params') ?? new \stdClass());
$option = (int) ($params->option ?? 0);
```

`$event->getArgument('params')` returns the task's `params` column decoded as a stdClass (or array depending on PHP/Joomla version — the `(object)` cast normalises). **Always provide defaults** with `?? <default>` — a task could be saved without ever opening the params form, in which case the field is absent from the JSON entirely (not just empty).

`max()`/`min()` clamps on numeric params are good defense in depth — even though the form XML's `min` / `max` attributes guard the UI, a malformed JSON write to the DB could put any value in `params`.

---

## 11. Common verification checklist

After building a new task plugin, verify in order:

1. **Install** — package script.php auto-enables the plugin (System → Plugins → search for it, confirm green check).
2. **Task type appears** — System → Scheduled Tasks → New → type dropdown contains the new routine.
3. **Form renders** — pick the type, Parameters tab shows all fields.
4. **Save persists** — change a param, Save & Close, reopen, value sticks. *If it doesn't, you're missing `<fields name="params">`.*
5. **Manual run works** — set the trigger to On-execution, click Run, status goes Success.
6. **Action effects** — verify the routine actually did its job (check DB rows / files / Action log).
7. **Scheduled run works** — set the trigger to interval / cron, wait a tick, confirm next_execution updated.

---

## 12. Cross-references

- Package script.php auto-enable pattern: [`JOOMLA5-COMPONENT-GUIDE.md`](JOOMLA5-COMPONENT-GUIDE.md) (postflight section)
- Core-string language shimming: [`JOOMLA5-LANGUAGE-FILES-GOTCHAS.md`](JOOMLA5-LANGUAGE-FILES-GOTCHAS.md)
- Plugin manifest patterns: [`JOOMLA5-PLUGIN-GUIDE.md`](JOOMLA5-PLUGIN-GUIDE.md)
- Working reference implementation: `packages/plg_task_cstemplateintegrity/` in [`cs-template-integrity`](https://github.com/cybersalt/cs-template-integrity)
