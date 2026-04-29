# Joomla 5/6 Testing Guide

PHPUnit + Jest patterns for Cybersalt extensions. Built around the principle that **testing against the real Joomla CMS classes (not stubs of them) is what catches J5 → J6 breaking changes automatically.**

> Why this matters: Joomla 6 introduced API moves (`Joomla\Input\Input` from `Joomla\CMS\Input\Input`), deprecations (`getDbo()` → `getDatabase()`, `getQuery(true)` → `createQuery()`), and removals (`CMSObject`). Tests that stub the framework drift away from reality and silently pass even when the production code would crash on a real install. Real-CMS tests fail loudly and tell you exactly what to fix.

---

## Directory structure

```
tests/
├── Unit/
│   ├── bootstrap.php          # Loads real Joomla CMS classes
│   ├── MyComponentTestCase.php  # Base class with getQueryStub() helper
│   ├── Admin/
│   │   ├── Helper/            # Admin helper tests
│   │   ├── Model/             # Admin model tests
│   │   └── Table/             # Table class tests
│   └── Site/
│       ├── Helper/
│       └── Model/
├── Integration/               # Tests that require a real database
└── js/
    └── *.test.js              # Jest tests for JavaScript
```

Mirror your `admin/src/` and `site/src/` structure inside `tests/Unit/` — predictable test locations save time when something breaks at midnight.

---

## PHPUnit configuration

`phpunit.xml.dist` at the extension root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="tests/Unit/bootstrap.php"
         colors="true"
         cacheDirectory="build/.phpunit.cache">
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory>tests/Integration</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory suffix=".php">admin/src</directory>
            <directory suffix=".php">site/src</directory>
        </include>
    </source>
</phpunit>
```

Once the suite gets large enough, define more granular suites by area (Admin Helper, Site Model, etc.) so individual runs are fast.

---

## Bootstrap: load the real Joomla CMS

The key insight from Joomla core's own test infrastructure: **load the real CMS classes, don't stub them.** Stubs drift from reality. When Joomla 6 removes a method or changes a return type, real-class tests catch it immediately; stub tests silently keep passing.

```php
<?php
// tests/Unit/bootstrap.php

// Point to a Joomla installation (configure via build.properties or env var)
$joomlaPath = getenv('JOOMLA_PATH') ?: '/path/to/joomla';

if (!is_dir($joomlaPath . '/libraries')) {
    throw new RuntimeException(
        'Joomla installation not found. Set JOOMLA_PATH environment variable.'
    );
}

// Define Joomla constants the tests will need
define('JPATH_ROOT', $joomlaPath);
define('JPATH_BASE', JPATH_ROOT);
define('JPATH_SITE', JPATH_ROOT);
define('JPATH_ADMINISTRATOR', JPATH_ROOT . '/administrator');
define('JPATH_LIBRARIES', JPATH_ROOT . '/libraries');

// Load BOTH autoloaders — see "Bootstrap must load Joomla's vendor
// autoloader" in Testing Gotchas below for why both are needed.
require_once JPATH_LIBRARIES . '/loader.php';
require_once JPATH_LIBRARIES . '/vendor/autoload.php';

// Register the extension's own autoloader (composer dump-autoload output)
require_once dirname(__DIR__, 2) . '/vendor/autoload.php';
```

Local convention: keep `JOOMLA_PATH` in `build.properties` (gitignored), or set it via `composer config` so each developer's path is local.

---

## Base test case with `getQueryStub()`

Joomla core's own `UnitTestCase` provides a `getQueryStub()` helper — a minimal concrete `DatabaseQuery` that only needs the two abstract methods stubbed. Far simpler than mocking the entire `DatabaseInterface`:

```php
<?php

namespace Cybersalt\Component\MyComponent\Tests;

use Joomla\Database\DatabaseInterface;
use Joomla\Database\DatabaseQuery;
use Joomla\Database\QueryInterface;
use PHPUnit\Framework\TestCase;

abstract class MyComponentTestCase extends TestCase
{
    /**
     * Create a real DatabaseQuery with only the two abstract methods stubbed.
     * Gives you a working query builder with a proper __toString().
     *
     * @param   DatabaseInterface  $db  The database stub the query is bound to.
     *
     * @return  QueryInterface
     *
     * @since  1.0.0
     */
    protected function getQueryStub(DatabaseInterface $db): QueryInterface
    {
        return new class ($db) extends DatabaseQuery {
            public function groupConcat($expression, $separator = ','): string
            {
                return '';
            }

            public function processLimit($query, $limit, $offset = 0): string
            {
                return (string) $query;
            }
        };
    }
}
```

The anonymous-class trick is the cleanest way to satisfy `DatabaseQuery`'s abstract surface without writing a top-level helper class.

---

## Model test pattern

Stub `DatabaseDriver` (NOT `DatabaseInterface` — see gotcha below), wire `getQueryStub()` into `createQuery()`, pass the stub via the model's config array:

```php
<?php

use Joomla\Database\DatabaseDriver;
use Joomla\CMS\MVC\Factory\MVCFactoryInterface;

class MyItemModelTest extends MyComponentTestCase
{
    public function testGetListQueryFilters(): void
    {
        $db = $this->createStub(DatabaseDriver::class);
        $db->method('createQuery')->willReturn($this->getQueryStub($db));
        $db->method('getPrefix')->willReturn('jos_');

        $model = new MyItemModel(
            ['dbo' => $db],
            $this->createStub(MVCFactoryInterface::class)
        );

        $this->assertInstanceOf(MyItemModel::class, $model);
    }
}
```

Key points:

- Models accept `['dbo' => $db]` in their config array — no need to mock the entire DI container.
- `getQueryStub()` returns a real query builder, so `$query->select()`, `$query->where()`, `$query->__toString()` all behave correctly.
- Stub additional methods on the DB only as your test exercises them: `loadObject()`, `loadObjectList()`, `execute()`, `quoteName()`, `quote()`, etc.

---

## Table test pattern

```php
$db = $this->createStub(DatabaseDriver::class);
$db->method('createQuery')->willReturn($this->getQueryStub($db));
$db->method('getPrefix')->willReturn('jos_');

$dispatcher = $this->createStub(\Joomla\Event\DispatcherInterface::class);
$table = new MyTable($db, $dispatcher);

// Test check() validation
$table->title = '';
$this->expectException(\UnexpectedValueException::class);
$table->check();
```

For `Table::store()` round-trip tests, prefer Integration tests (against a real database) over Unit tests with deeply-mocked DB calls.

---

## Helper / utility test pattern

Pure functions are the easiest case — no database stubs needed:

```php
class MyHelperTest extends MyComponentTestCase
{
    public function testFormatDuration(): void
    {
        $this->assertSame('1:30:00', MyHelper::formatDuration(5400));
        $this->assertSame('0:05:30', MyHelper::formatDuration(330));
    }
}
```

If your helper depends on `Factory::getApplication()`, `Factory::getUser()`, etc., either refactor it to accept those as injected parameters, or set up the application stub in `setUp()` (see [Testing Gotchas](#testing-gotchas) for `CMSApplication` vs `CMSApplicationInterface`).

---

## JavaScript tests (Jest)

Jest with jsdom is the right shape for testing front-end JavaScript that touches the DOM. Configure in `package.json`:

```json
{
  "jest": {
    "testEnvironment": "jsdom",
    "testMatch": ["<rootDir>/tests/js/**/*.test.js"],
    "coverageDirectory": "build/reports/coverage-js"
  }
}
```

For code that depends on `Joomla.Text._()` or other Joomla globals, mock them per-test or in a shared setup file:

```javascript
beforeEach(() => {
    window.Joomla = {
        Text: {
            _: jest.fn((key) => key),
            strings: {}
        },
        getOptions: jest.fn(() => ({})),
        renderMessages: jest.fn()
    };
});
```

The `_: jest.fn((key) => key)` pattern returns the language key as the value, which is fine for assertions — your test isn't validating translations, it's validating that the right key was requested.

---

## What to test (and what not to)

**Do test:**
- Helper/utility methods (pure logic, formatting, calculations)
- Model query construction and filtering logic
- Table `check()` validation rules
- Custom form-field logic
- JavaScript UI helpers and data transformations
- Any code that handles user input or builds SQL — these are security-relevant and should have explicit tests for the malicious-input cases

**Don't test:**
- Joomla framework internals (MVC routing, form binding, ACL checks). The framework has its own test suite.
- Simple getters/setters with no logic.
- Template HTML output. Use end-to-end (Cypress / Playwright) tests for that.

---

## Testing gotchas

### 1. `DatabaseInterface` does NOT have `createQuery()`

`createQuery()` lives on the abstract `DatabaseDriver` class, **not** on `DatabaseInterface`. PHPUnit will throw `MethodCannotBeConfiguredException` if you try to configure `createQuery()` on a `DatabaseInterface` stub.

```php
// WRONG — createQuery() is not on DatabaseInterface
$db = $this->createStub(DatabaseInterface::class);
$db->method('createQuery')->willReturn(...); // Throws!

// CORRECT
$db = $this->createStub(DatabaseDriver::class);
$db->method('createQuery')->willReturn($this->getQueryStub($db));
```

### 2. `CMSApplicationInterface` does NOT have `getSession()`

`getSession()` is defined on `SessionAwareWebApplicationInterface` (from the framework) and mixed in via `SessionAwareWebApplicationTrait`. The interface alone doesn't expose it. To stub an application with `getSession()`, use the concrete `CMSApplication` class:

```php
// WRONG
$app = $this->createStub(CMSApplicationInterface::class);
$app->method('getSession')->willReturn($session); // Throws!

// CORRECT
$app = $this->createStub(CMSApplication::class);
$app->method('getSession')->willReturn($session);
```

### 3. Bootstrap must load Joomla's vendor autoloader (BOTH autoloaders)

A PSR-4 autoloader for `Joomla\CMS\*` classes (from `libraries/src/`) is **not enough**. Framework packages — `Joomla\Database\*`, `Joomla\Event\*`, `Joomla\Session\*`, `Joomla\Input\*` — live in `libraries/vendor/` and need `libraries/vendor/autoload.php`. Without it, any test stubbing a framework interface fails with "Class or interface does not exist".

```php
// In bootstrap.php — load BOTH autoloaders
require_once $joomlaCmsPath . '/libraries/vendor/autoload.php'; // Framework packages
require_once $joomlaCmsPath . '/libraries/loader.php';          // Joomla\CMS\* loader
```

### 4. `createMock()` vs `createStub()` for expectations

PHPUnit's `createStub()` does NOT support `expects()`. If you want to assert that a method *is* (or *isn't*) called, you need `createMock()`:

```php
// WRONG — expects() on a stub triggers a deprecation warning in modern PHPUnit
$db = $this->createStub(DatabaseDriver::class);
$db->expects($this->never())->method('loadObject');

// CORRECT
$db = $this->createMock(DatabaseDriver::class);
$db->expects($this->never())->method('loadObject');
```

Rule of thumb: if you only configure return values, `createStub()` is fine. If you assert on call counts or parameters, use `createMock()`.

### 5. Tests for code that uses `Factory::getApplication()` need an application registered

`Factory::getApplication()` returns whatever was set on the static factory. In a test context, you usually want to inject a stub:

```php
use Joomla\CMS\Factory;
use Joomla\CMS\Application\CMSApplication;

protected function setUp(): void
{
    parent::setUp();
    $app = $this->createStub(CMSApplication::class);
    $app->method('getInput')->willReturn(new \Joomla\Input\Input([]));
    $app->method('getLanguage')->willReturn($this->createStub(\Joomla\CMS\Language\Language::class));
    Factory::$application = $app;
}

protected function tearDown(): void
{
    Factory::$application = null;
    parent::tearDown();
}
```

Always reset in `tearDown()` so cross-test state doesn't leak.

---

## Composer scripts

Wire the test commands into `composer.json` so the build pipeline can call them:

```json
{
  "scripts": {
    "test": "@test:unit",
    "test:unit": "phpunit --testsuite Unit",
    "test:integration": "phpunit --testsuite Integration",
    "check": ["@lint", "@test"]
  }
}
```

Then your release-gate script (`build-and-validate.ps1` or equivalent) calls `composer check` before producing the package ZIP.

---

## Related

- [`JOOMLA-CODING-STANDARDS.md`](JOOMLA-CODING-STANDARDS.md) — phpcs ruleset that should pass before tests run
- [`JOOMLA6-CHECKLIST.md`](JOOMLA6-CHECKLIST.md) — deprecation matrix; tests against real CMS catch most of these automatically
- [`VERSION-BUMP-CHECKLIST.md`](VERSION-BUMP-CHECKLIST.md) — release-time gate including the test pass requirement
