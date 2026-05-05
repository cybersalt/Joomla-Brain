# Joomla 5/6 Library Extension Guide

A **library** in Joomla is an installable PHP code package that lives at `<joomla_root>/libraries/<libraryname>/` and is autoloaded under a PSR-4 namespace declared in its manifest. Once installed, every other extension on the site (your own and third-party) can `use` its classes without touching `require`, Composer, or autoloaders.

If you maintain a Cybersalt project where the same domain logic shows up in a component, a content plugin, *and* a scheduled task plugin — that's the signal to extract it into a library.

---

## Table of Contents

1. [When to use a library (and when not to)](#when-to-use-a-library)
2. [Directory structure](#directory-structure)
3. [Manifest XML](#manifest-xml)
4. [Namespace mapping rules](#namespace-mapping-rules)
5. [Library PHP classes](#library-php-classes)
6. [Database access from a library](#database-access-from-a-library)
7. [Consuming a library from other extensions](#consuming-a-library-from-other-extensions)
8. [Custom form fields shipped from a library](#custom-form-fields-shipped-from-a-library)
9. [Language files](#language-files)
10. [Packaging](#packaging)
11. [Bundling a library inside a package extension](#bundling-a-library-inside-a-package-extension)
12. [Multiple libraries vs. one library with sub-namespaces](#multiple-libraries-vs-one-library-with-sub-namespaces)
13. [Pre-release checklist](#pre-release-checklist)
14. [Related guides](#related-guides)

---

## When to use a library

**Good fits:**

- Domain logic shared by a component **and** one or more plugins or modules in the same project (e.g., a `LicenseValidator` used by both `com_proclaim` and `plg_content_proclaim`).
- A wrapper around a third-party PHP library that you want to install/update through Joomla's extension manager rather than via Composer-on-the-server.
- Reusable utilities (logging adapters, formatters, validators) that don't logically belong to any single extension.

**Bad fits — don't reach for a library if:**

- The code is only consumed by one component. Put it in that component's `Helper/` or `Service/` namespace and keep the surface small. A library you only call from one place is just indirection.
- You only need Composer packages. Bundle them under your component's `libraries/vendor/` (handled by the component's own Composer setup) — don't ship them as a Joomla library extension.
- You're tempted to use it as a "kitchen drawer" for unrelated helpers across unrelated projects. That's a versioning trap. One library = one cohesive purpose.

---

## Directory structure

```
lib_mylib/                              # Source/package root
├── mylib.xml                           # Manifest at package root
└── libraries/
    └── mylib/                          # Matches <libraryname>
        ├── src/
        │   ├── MyClass.php
        │   ├── AnotherClass.php
        │   └── SubNamespace/
        │       └── Helper.php
        └── language/
            └── en-GB/
                └── lib_mylib.sys.ini
```

When Joomla installs the package:

- The contents of `libraries/mylib/` are copied to `<joomla_root>/libraries/mylib/`.
- The manifest is copied to `<joomla_root>/administrator/manifests/libraries/mylib.xml`.

> [!CAUTION]
> **Never use `libraries/vendor/` as your library's `<libraryname>`.** That path is reserved for Joomla core's Composer autoloader. Installing a library called `vendor` will collide with core in ways that are very hard to debug.

---

## Manifest XML

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="library" method="upgrade">
    <name>lib_mylib</name>
    <libraryname>mylib</libraryname>
    <version>1.0.0</version>
    <creationDate>2026-01</creationDate>
    <author>Cybersalt Consulting Ltd</author>
    <authorEmail>dev@cybersalt.com</authorEmail>
    <authorUrl>https://cybersalt.com</authorUrl>
    <copyright>(C) 2026 Cybersalt Consulting Ltd</copyright>
    <license>GPL-2.0-or-later</license>
    <description>LIB_MYLIB_XML_DESCRIPTION</description>

    <namespace path="src">Cybersalt\Library\MyLib</namespace>

    <files folder="libraries/mylib">
        <folder>src</folder>
        <folder>language</folder>
    </files>
</extension>
```

### Element reference

| Element | Purpose |
|---|---|
| `type="library"` | Marks this as a library extension (vs. component, plugin, module). |
| `<name>` | Human-facing extension name. Conventionally `lib_<libraryname>`. |
| `<libraryname>` | The directory name that will appear under `<joomla_root>/libraries/`. **Must match the folder name inside `libraries/` in your package.** |
| `<namespace path="src">` | PSR-4 autoload registration. The `path` attribute is **relative to the installed library root** (`<joomla_root>/libraries/<libraryname>/`). |
| `<files folder="...">` | Tells the installer where in the ZIP to find the library files. The `folder` attribute is relative to the ZIP root. |

> [!IMPORTANT]
> **Without `<namespace>`, Joomla will not autoload your classes.** You'd be forced to `require_once` files manually from every consumer, which defeats the point of building a library. Always include the namespace tag.

---

## Namespace mapping rules

Given:

```xml
<namespace path="src">Cybersalt\Library\MyLib</namespace>
```

Joomla maps:

| Class FQCN | File path |
|---|---|
| `Cybersalt\Library\MyLib\MyClass` | `libraries/mylib/src/MyClass.php` |
| `Cybersalt\Library\MyLib\Validator\EmailValidator` | `libraries/mylib/src/Validator/EmailValidator.php` |
| `Cybersalt\Library\MyLib\Api\Client\HttpClient` | `libraries/mylib/src/Api/Client/HttpClient.php` |

This is standard PSR-4: namespace segments after the registered prefix become directory segments under the registered path. File names match class names case-sensitively (it'll work on Windows in dev and break on Linux in production if you're sloppy here).

---

## Library PHP classes

Library classes are plain PHP — there is no base class to extend. Follow PSR-4 file/class layout and PSR-12 style:

```php
<?php

declare(strict_types=1);

namespace Cybersalt\Library\MyLib;

\defined('_JEXEC') or die;

/**
 * Example utility class shipped from a Joomla library.
 */
final class MyClass
{
    /**
     * Process input by uppercasing and trimming.
     */
    public function process(string $input): string
    {
        return strtoupper(trim($input));
    }
}
```

**House style notes:**

- `declare(strict_types=1);` at the top of every file.
- Use `\defined('_JEXEC') or die;` if the class might ever be loaded from a context where Joomla's bootstrap has run. It's a no-op overhead and a safety net against accidental direct hits.
- Prefer `final class` unless you genuinely need extension. You can always relax `final` later; it's much harder to add it once consumers are subclassing.
- Constructor property promotion + `readonly` for immutable dependencies (PHP 8.1+, fine on Joomla 5+).

---

## Database access from a library

Library classes don't extend any Joomla MVC base class, so `$this->getDatabase()` isn't available. Two options, in order of preference:

### Option A — Constructor injection (recommended)

```php
<?php

declare(strict_types=1);

namespace Cybersalt\Library\MyLib;

\defined('_JEXEC') or die;

use Joomla\Database\DatabaseInterface;

final class DataHelper
{
    public function __construct(
        private readonly DatabaseInterface $db
    ) {
    }

    public function getItemCount(string $tableName): int
    {
        $query = $this->db->createQuery()
            ->select('COUNT(*)')
            ->from($this->db->quoteName($tableName));

        $this->db->setQuery($query);

        return (int) $this->db->loadResult();
    }
}
```

Caller:

```php
use Cybersalt\Library\MyLib\DataHelper;
use Joomla\CMS\Factory;
use Joomla\Database\DatabaseInterface;

$db     = Factory::getContainer()->get(DatabaseInterface::class);
$helper = new DataHelper($db);
$count  = $helper->getItemCount('#__mycomponent_items');
```

### Option B — Service-locator (only if injection is genuinely awkward)

```php
use Joomla\CMS\Factory;
use Joomla\Database\DatabaseInterface;

$db = Factory::getContainer()->get(DatabaseInterface::class);
```

Use sparingly — pulling from the container inside a library class makes it harder to test and couples the library to `Factory`. Inject when you can.

---

## Consuming a library from other extensions

Once installed with a proper `<namespace>`, library classes are autoloaded everywhere on the site automatically.

**From a component model:**

```php
use Cybersalt\Library\MyLib\MyClass;
use Joomla\CMS\MVC\Model\AdminModel;

class ItemModel extends AdminModel
{
    public function processTitle(string $title): string
    {
        return (new MyClass())->process($title);
    }
}
```

**From a plugin:**

```php
namespace Cybersalt\Plugin\Content\Foo\Extension;

\defined('_JEXEC') or die;

use Cybersalt\Library\MyLib\MyClass;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Event\SubscriberInterface;

final class Foo extends CMSPlugin implements SubscriberInterface
{
    public static function getSubscribedEvents(): array
    {
        return ['onContentPrepare' => 'onContentPrepare'];
    }

    public function onContentPrepare(string $context, object &$article): void
    {
        $article->title = (new MyClass())->process($article->title);
    }
}
```

**From a module helper:** identical — just `use` the class.

No registration boilerplate, no service provider wiring on the consumer side. The library's manifest already told Joomla how to autoload it.

---

## Custom form fields shipped from a library

If your library exposes a custom form field (`type="mylib.myfield"`), consumers can reference it directly in form XML by setting `addfieldprefix`:

```xml
<field
    name="myfield"
    type="mylib.customfield"
    addfieldprefix="Cybersalt\Library\MyLib\Field"
    label="My Custom Field"
/>
```

The class file in your library:

```
libraries/mylib/src/Field/CustomfieldField.php
```

```php
<?php

declare(strict_types=1);

namespace Cybersalt\Library\MyLib\Field;

\defined('_JEXEC') or die;

use Joomla\CMS\Form\Field\TextField;

final class CustomfieldField extends TextField
{
    protected $type = 'Customfield';

    // ...
}
```

> [!TIP]
> `addfieldprefix` lets you ship custom fields from a library **without needing a system plugin** to register field path prefixes. This is the cleanest pattern for fields that travel with library code.

---

## Language files

```ini
; libraries/mylib/language/en-GB/lib_mylib.sys.ini
LIB_MYLIB="My Library"
LIB_MYLIB_XML_DESCRIPTION="Shared utility library for Cybersalt extensions."
```

Library language files are typically **`.sys.ini` only** — they show up in the admin extensions list but libraries usually have no frontend UI of their own. If your library does emit user-visible strings (rare, but possible for shared field/widget code), add a regular `.ini` too.

---

## Packaging

```bash
cd /path/to/lib_mylib
zip -r ../lib_mylib-1.0.0.zip mylib.xml libraries/
```

Resulting ZIP layout:

```
lib_mylib-1.0.0.zip
├── mylib.xml
└── libraries/
    └── mylib/
        ├── src/
        └── language/
```

Install it via **System → Install → Upload Package File** like any other extension.

---

## Bundling a library inside a package extension

When a project ships a component + plugins + library together, wrap them in a package extension:

```xml
<?xml version="1.0" encoding="utf-8"?>
<extension type="package" method="upgrade">
    <name>pkg_myproject</name>
    <packagename>myproject</packagename>
    <version>1.0.0</version>
    <author>Cybersalt Consulting Ltd</author>
    <license>GPL-2.0-or-later</license>

    <files>
        <file type="library" id="lib_mylib">lib_mylib.zip</file>
        <file type="component" id="com_mycomponent">com_mycomponent.zip</file>
        <file type="plugin" id="plg_content_mycomponent" group="content">plg_content_mycomponent.zip</file>
    </files>
</extension>
```

> [!IMPORTANT]
> **List the library before any extension that depends on it.** Joomla installs the files in the order they appear. If `com_mycomponent`'s install script tries to instantiate a class from `lib_mylib`, the library must already be on disk and registered first.

> [!IMPORTANT]
> **The `<files>` element needs a `folder` attribute if the child zips live in a subdirectory inside the package zip.** If you build the package zip with the child zips at the root, the manifest above (no `folder=`) is fine. If your build script puts them in `packages/` (a common convention used by Akeeba and many others), the manifest must say `<files folder="packages">`. Mismatch produces this Joomla error on install:
>
> ```
> Install path does not exist.
> Package Install: There was an error installing an extension: com_xxx.zip
> ```
>
> The error means Joomla looked for `com_xxx.zip` at the package zip root and didn't find it because the build script put it in `packages/com_xxx.zip`. Either flatten the child zips to the package root, or add `folder="packages"` to the `<files>` element.

---

## Multiple libraries vs. one library with sub-namespaces

You have two ways to organise larger shared codebases.

### Option A — Multiple independent libraries

Each gets its own manifest, its own `<libraryname>`, its own ZIP, its own version:

```
lib_mylib_core/    → libraries/mylib_core/   namespace Cybersalt\Library\MyLibCore
lib_mylib_api/     → libraries/mylib_api/    namespace Cybersalt\Library\MyLibApi
lib_mylib_sync/    → libraries/mylib_sync/   namespace Cybersalt\Library\MyLibSync
```

Use this when the libraries can sensibly version independently — e.g., the API client gets frequent updates while the core utilities are stable.

You **cannot** nest multiple installable libraries under a single `<libraryname>`. Each is a separate extension as far as Joomla is concerned.

### Option B — One library, multiple sub-namespaces (simpler)

```
libraries/mylib/src/
├── Core/
│   └── BaseClass.php       → Cybersalt\Library\MyLib\Core\BaseClass
├── Api/
│   └── Client.php          → Cybersalt\Library\MyLib\Api\Client
└── Sync/
    └── SyncService.php     → Cybersalt\Library\MyLib\Sync\SyncService
```

One manifest, one ZIP, one version. Use this when the code naturally ships and versions together — which is most of the time.

**Default to Option B.** Reach for Option A only if you have a real reason to version pieces independently. Joomla's installer doesn't reward fragmentation.

---

## Pre-release checklist

Before you ship a library to a client site or to the wider world:

- [ ] `<libraryname>` matches the folder name inside `libraries/` in your package.
- [ ] `<namespace path="src">` is present and points at a real directory.
- [ ] Namespace declarations in source files match the manifest's namespace prefix exactly (case-sensitive).
- [ ] No file lives in `libraries/vendor/` inside the package.
- [ ] Every public class has `declare(strict_types=1);` and `\defined('_JEXEC') or die;` at the top.
- [ ] No hard-coded references to `Factory::getDbo()`, `JFactory`, or other deprecated/legacy APIs. Inject `DatabaseInterface` via constructor.
- [ ] `lib_<name>.sys.ini` exists with `LIB_<NAME>` and `LIB_<NAME>_XML_DESCRIPTION` keys.
- [ ] If shipping inside a package: the library's `<file type="library">` line is **before** any consumer's line.
- [ ] Version string in manifest matches the ZIP filename and any release tag.
- [ ] Tested: install, uninstall, then re-install on a fresh Joomla — the autoloader picks up the namespace on first install with no clear-cache dance.
- [ ] License file (`LICENSE` or `LICENSE.txt`) included in the ZIP root if license is anything other than the implied GPL-2.0+.

---

## Related guides

- [[JOOMLA5-COMPONENT-GUIDE.md]] — building the component that consumes your library.
- [[JOOMLA5-PLUGIN-GUIDE.md]] — plugins are the most common library consumers.
- [[JOOMLA5-CUSTOM-FIELDS-GUIDE.md]] — if your library ships custom form fields, that guide covers field internals end-to-end.
- [[JOOMLA5-CODING-STANDARDS.md]] — house style for PHP code, namespaces, and file headers.
- [[JOOMLA5-COMMON-GOTCHAS.md]] — autoloader and namespace pitfalls that bite library authors hardest.
- [[JOOMLA6-CHECKLIST.md]] — forward-compat considerations when libraries cross the J5→J6 boundary.
