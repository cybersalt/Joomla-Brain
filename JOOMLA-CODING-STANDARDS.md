# Joomla Coding Standards (PHPDoc, ESLint, PHPCS)

Coding-standards reference for Cybersalt extensions and any other extension built against this Brain. Aligned with the Joomla project's published conventions for PHPDoc/DocBlocks, JavaScript/ESLint, and PHP_CodeSniffer.

> Why this matters: Joomla CMS code must pass the Joomla `phpcs` ruleset for any contribution upstream, and extensions that match the same standards are easier to read, easier to onboard new developers onto, and play nicely with editors that auto-format docblocks against the Joomla rule. **Most importantly: a clean, well-aligned docblock surface area is what a security review reads first.** Sloppy or missing `@param`/`@return` types are the #1 reason a reviewer can't tell whether a method validates its input.

---

## PHPDoc / DocBlocks

All PHP code must include proper docblocks. **Whitespace inside docblocks uses real spaces, not tabs.** The minimum spacing between tag elements (type, variable name, description) is **two spaces**, aligned to the longest element in the block.

### File header

Required on **every** PHP file in an extension. Including layout templates, language overrides, install scripts — every `.php` file:

```php
<?php

/**
 * @package     Cybersalt.Administrator
 * @subpackage  com_mycomponent
 *
 * @copyright   (C) 2025 Cybersalt Consulting Ltd. <https://cybersalt.com>
 * @license     GNU General Public License version 2 or later; see LICENSE.txt
 */
```

`@package` follows `Vendor.Side` form (`.Administrator`, `.Site`, or `.Library`). `@subpackage` is the extension's element name. The blank `*` line between `@subpackage` and `@copyright` is required.

### Class docblock

```php
/**
 * Model for a single booking item.
 *
 * @since  1.0.0
 */
class BookingModel extends AdminModel
```

`@since` is **required** on every class. Use the version of the extension when the class was introduced — not the current shipping version.

### Property docblock

```php
/**
 * The prefix to use with controller messages.
 *
 * @var    string
 * @since  1.0.0
 */
protected $text_prefix = 'COM_BOOKINGS';
```

### Method docblock

```php
/**
 * Method to get the record form.
 *
 * @param   array    $data      Data for the form.
 * @param   boolean  $loadData  True if the form is to load its own data.
 *
 * @return  Form|boolean  A Form object on success, false on failure.
 *
 * @since   1.0.0
 * @throws  \Exception
 */
public function getForm($data = [], $loadData = true)
```

Rules:

- **`@param`** — `@param`, three spaces, type, two+ spaces, `$variable`, two+ spaces, description. Align ALL `@param` entries in the block to the same column for type, variable, and description.
- **Blank `*` line after the last `@param`** before `@return`.
- **`@return`** — type and description. Always required. Use `void` for no return value.
- **Blank `*` line after `@return`** before `@since`.
- **`@since`** — required on every public/protected method. Version when introduced.
- **`@throws`** — list each exception type the method can throw. No description needed.
- **`@deprecated`** — include when deprecating, with `@see` pointing to the replacement.

### Deprecated method example

```php
/**
 * Get the database driver.
 *
 * @return  DatabaseInterface
 *
 * @since       1.0.0
 * @deprecated  2.0.0  Use getDatabase() instead.
 * @see         getDatabase()
 */
public function getDbo()
```

### Tags NOT used in Cybersalt / Joomla code

- **`@author`** — Joomla project rule: prohibited in core code, allowed in third-party extensions but discouraged. Cybersalt convention is to leave it off; copyright + the `CONTRIBUTORS.md` file in the relevant repo carry attribution. The git log carries the rest.
- **`@category`** — rarely used and not part of the Joomla rule. Skip.

### Single-line vs multi-line blocks

For trivial getters and constants, a single-line docblock is acceptable:

```php
/** @var  string  The component's option name. */
public const COMPONENT = 'com_mycomponent';
```

But anything that has parameters, a meaningful return, or any chance of being called from another extension's code must use a multi-line block with proper `@param` / `@return` / `@since`.

---

## JavaScript / ESLint

Joomla core uses ESLint flat config (`eslint.config.mjs` since ESLint 9). Match these conventions in extension JavaScript.

### Recommended `eslint.config.mjs`

```javascript
import { defineConfig } from 'eslint/config';

export default defineConfig([
    {
        files: ['media/**/*.js', 'build/**/*.js'],
        rules: {
            'no-restricted-globals': 'error',
        },
        languageOptions: {
            globals: {
                Joomla: true,         // Joomla core JS API
                bootstrap: true,      // Bootstrap JS (bundled with Joomla)
            },
        },
    },
]);
```

### Conventions

- **ES6+ module syntax** (`import` / `export`). No `var` — use `const` for things that don't reassign, `let` for those that do.
- **The `Joomla` global is always available** on frontend and admin pages. Use `Joomla.Text`, `Joomla.submitform`, `Joomla.renderMessages`, `Joomla.JText` (legacy alias), etc., directly without import.
- **Source goes in `build/media_source/`**, compiled output in `media/com_mycomponent/js/`. Don't ship un-bundled source as the production asset; Joomla's own build pipeline compiles & minifies. For Cybersalt extensions that don't use a bundler, source = production is acceptable but the file should still pass ESLint.
- **JSDoc on exported functions** is required:

```javascript
/**
 * Refresh the items list via AJAX.
 *
 * @param {HTMLElement} container       The list container element.
 * @param {Object}      options         Configuration options.
 * @param {number}      options.page    Page number to load.
 *
 * @returns {Promise<void>}
 *
 * @since 1.0.0
 */
export async function refreshList(container, options = {}) {
    // ...
}
```

JSDoc indentation rule mirrors PHPDoc: align type, name, and description columns to the longest entry.

---

## PHP_CodeSniffer

Joomla publishes its own ruleset via the `joomla/coding-standards` Composer package.

### Install

```bash
composer require --dev joomla/coding-standards
```

### Run

```bash
./vendor/bin/phpcs --standard=Joomla admin/src site/src
```

### Project ruleset (`phpcs.xml` at extension root)

```xml
<?xml version="1.0"?>
<ruleset name="My Component">
    <rule ref="Joomla"/>
    <file>admin/src</file>
    <file>site/src</file>
    <exclude-pattern>*/vendor/*</exclude-pattern>
    <exclude-pattern>*/node_modules/*</exclude-pattern>
    <exclude-pattern>*/media/*</exclude-pattern>
</ruleset>
```

For Cybersalt extensions, also exclude the build artefacts directory and the temporary 7-Zip staging folder if they exist at the repo root:

```xml
<exclude-pattern>*/build/*</exclude-pattern>
<exclude-pattern>*/dist/*</exclude-pattern>
```

### Pre-release gate

Add a `composer run phpcs` script entry and call it from your build script before any release ZIP is produced. **A `phpcs` failure should be a hard release blocker**, same priority as the security review pass.

```json
{
    "scripts": {
        "phpcs": "phpcs --standard=Joomla admin/src site/src",
        "phpcs:fix": "phpcbf --standard=Joomla admin/src site/src"
    }
}
```

`phpcbf` (the bundled auto-fixer) handles whitespace, alignment, and most docblock spacing automatically. Run it before manual review.

---

## Inline Comments

- **C++ style (`// `)** — preferred for code comments. Always a space after `//`.
- **C-style block (`/* */`)** — **only** for file headers, class docblocks, and method docblocks. Don't use block comments inline.
- **Perl/shell (`#`)** — **never** in PHP files. Joomla `phpcs` flags these.

```php
// Good — C++ style with space after //
$query->where($db->quoteName('state') . ' = 1');

# Bad — perl/shell style, will fail phpcs
$query->where($db->quoteName('state') . ' = 1');

/* Bad — block-style inline comment */
$query->where($db->quoteName('state') . ' = 1');
```

---

## Where this lives in your build pipeline

Cybersalt's build script chain is:

1. `phpcbf --standard=Joomla` (auto-fix)
2. `phpcs --standard=Joomla` (verify clean)
3. `eslint media/ build/` (verify clean)
4. `composer test` (PHPUnit — see [`JOOMLA5-TESTING-GUIDE.md`](JOOMLA5-TESTING-GUIDE.md))
5. `security-review` skill (zero HIGH or MEDIUM findings)
6. Build the package ZIP via 7-Zip (see [`PACKAGE-BUILD-NOTES.md`](PACKAGE-BUILD-NOTES.md))
7. Validate the package (`validate-package.ps1`)

Steps 1–4 should already be running locally during development. Steps 5–7 are the release gate. **Don't tag a release with any of those failing.**

---

## Related

- [`NEW-EXTENSION-CHECKLIST.md`](NEW-EXTENSION-CHECKLIST.md) — full new-extension checklist including the security baseline
- [`JOOMLA5-TESTING-GUIDE.md`](JOOMLA5-TESTING-GUIDE.md) — PHPUnit setup that consumes the same docblock annotations
- [`VERSION-BUMP-CHECKLIST.md`](VERSION-BUMP-CHECKLIST.md) — release-time gate that includes the phpcs check
