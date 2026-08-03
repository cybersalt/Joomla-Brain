# Regular Labs Sourcerer — Embedding Code in Joomla Content

Sourcerer (Regular Labs) lets you embed PHP / HTML / JS / CSS inside Joomla content (articles, `mod_custom` modules, etc.) using `{source}…{/source}` tags, so the code survives being opened and re-saved in the WYSIWYG editor. It ships as **System - Regular Labs - Sourcerer** (+ the **Button - Regular Labs - Sourcerer** editor button and the **System - Regular Labs Library** dependency).

This file catalogs the non-obvious behaviours that bite when you use it to carry a `<script>` / JSON-LD / PHP snippet in a module or article. Distilled from placing a self-contained schema.org JSON-LD Organization block into a copyright-position `mod_custom` on a live migration (2026-07). Every claim below was reproduced on a real J6 site.

---

## Mental model (the one thing to get right)

**Sourcerer embeds EXECUTABLE CODE — PHP that _echoes_ its output. It does NOT "protect" an existing HTML tag.**

- ✅ Right: `{source}<?php echo '<script> … </script>'; ?>{/source}` — the PHP runs, echoes the `<script>`, the browser executes it.
- ❌ Wrong: `{source}<script> … </script>{/source}` — Sourcerer renders the `<script>` as **visible code text** on the page; it does not execute.

If your goal is "make an existing inline `<script>` module editor-safe", Sourcerer is the wrong tool unless you rewrite the script as a PHP `echo`. For plain set-and-forget script modules it is usually simpler to leave the raw `<script>` and just never open the module in the WYSIWYG editor.

---

## Gotchas

### 1. Wrapping a raw `<script>` (or other HTML tag) → shows as literal code text
- **Symptom:** the JS/HTML appears as visible text on the front end instead of running. (Two `mod_custom` script modules sharing the `copyright` position dumped their JS as text after the copyright content.)
- **Cause:** Sourcerer treats `{source}` content as code to embed/echo, not HTML to pass through. A bare tag is shown, not rendered.
- **Fix:** echo it from PHP — `{source}<?php echo '<script> … </script>'; ?>{/source}` — or don't use Sourcerer for it.

### 2. JSON object literals `{ }` collide with Sourcerer's tag characters
- **Symptom:** a `{source}` block containing literal `{…}` (e.g. a static JSON-LD `<script type="application/ld+json">{ "@context": … }</script>`) is silently **stripped** — nothing renders. Happens at `prepare_content` = 0 AND = 1.
- **Cause:** Sourcerer's tag characters ARE the braces (param `tag_characters` = `{.}`). Nested JSON braces derail its tag parser.
- **Fix:** never put a literal `{…}` JSON object inside `{source}`. Build the data with PHP `array()` (no literal braces in the source) and `json_encode()` it at runtime:
  ```php
  {source}<?php echo '<script type="application/ld+json">' . json_encode(array('@type'=>'Organization', /* … */), JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE) . '</script>'; ?>{/source}
  ```
  (Curly braces inside a `<script>` that you _echo_ — including JS function bodies — are fine. The braces only bite when they sit raw in the `{source}` source.)

### 3. Email Cloaking mangles literal emails inside `{source}` — at prepare_content = 1
- **Symptom:** a `{source}` block containing a literal `name@domain.tld` silently breaks (renders nothing; a PHP payload parse-fails uncatchably) when the module has **Prepare Content = Yes**.
- **Cause:** with Prepare Content on, the core **Content - Email Cloaking** plugin runs on the module content and rewrites the email (wrapping it in obfuscation JS) *before* Sourcerer processes the block, corrupting the code.
- **Fix (either):**
  - Set **Prepare Content = No** (see #4) — content plugins don't run, so the email is never touched.
  - Build the email with no literal `@`: `'name' . chr(64) . 'domain.tld'`. Email Cloaking's regex needs a literal `@` to match. Belt-and-suspenders: this also survives if Prepare Content is later switched on.

### 4. `{source}` works with Prepare Content OFF — prefer it for code modules
`prepare_content` (module → Advanced) does **not** need to be on. The System - Sourcerer plugin processes `{source}` at the page level regardless. Leaving it **Off** is better for a code-carrying module: the per-item content plugins (Email Cloaking, auto-linkers, etc.) never touch your code. Confirmed with a `{source}<?php echo date('Y'); ?>{/source}` copyright module rendering "© 2026" correctly at `prepare_content = 0`.

### 5. Keep pasted PHP on a SINGLE line
When code is pasted into a content field, newlines inside the PHP are liable to be turned into `<br>` / `<p>` by the editor (or a content plugin at prepare_content=1), breaking the PHP. Keep the `<?php … ?>` on one line — long is fine. Safest default for content-embedded PHP.

### 6. A WAF / mod_security may 404 *scripted* POSTs containing `<?php` — but not a browser save
- **Symptom:** saving a `{source}<?php …` module by POSTing the admin form from a script (curl / `Invoke-WebRequest` / MCP-for-J write tools) returns **404/403**, while the identical content saved by a human in the browser goes through fine.
- **Cause:** a mod_security rule flags `<?php` in the request body; it is commonly scoped to non-browser requests.
- **Implication:** you can automate everything about a Sourcerer code module EXCEPT writing the `<?php` payload — hand that step to a human paste, or temporarily relax the WAF rule.

---

## Canonical working pattern

A single self-contained, environment-proof, editor-safe JSON-LD block — data built with `array()`, dynamic URLs via `Uri::root()`, email via `chr(64)`, one line, Prepare Content off:

```php
{source}<?php $r = rtrim(\Joomla\CMS\Uri\Uri::root(), '/'); $em = 'info' . chr(64) . 'example.com'; echo '<script type="application/ld+json">' . json_encode(array('@context'=>'https://schema.org','@type'=>'Organization','@id'=>$r.'/#/schema/Organization/base','name'=>'Example Ltd','url'=>$r.'/','logo'=>array('@type'=>'ImageObject','url'=>$r.'/images/logo.png'),'email'=>$em /* , … */), JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE) . '</script>'; ?>{/source}
```

Result: no `{source}` / `<?php` leak, valid JSON, absolute URLs that stay correct on any domain (no go-live find/replace, and the logo URL is absolute — fixes the relative-`url` that Joomla's core Schema.org plugin emits), email intact past Email Cloaking, and editor-safe.

Using `Uri::root()` makes the block **environment-proof** — there is no `@id` / domain to swap when the site moves from staging to production.

---

## Plugin settings reference (System - Regular Labs - Sourcerer)

- `enable_php`, `enable_frontend`, `enable_js`, `enable_css` — must be **1** for the respective code types / front-end processing. (PHP inside `{source}` only runs with `enable_php = 1`.)
- `tag_characters` = `{.}` and `syntax_word` = `source` → tags are `{source}…{/source}`. Because the tag characters are braces, a literal `{ }` in the payload is dangerous (gotcha #2).
- `enable_in_head` (default 0) — only relevant when embedding into the template `<head>`.
- `color_code`, `trim`, `place_comments`, `forbidden_php`, `button_text` (default "Code") — display/formatting and a PHP function deny-list.

---

## Quick decision guide

| You want to embed… | Do this |
| --- | --- |
| A `<script>` you wrote (JS)                | Leave it raw + "don't open in WYSIWYG", **or** rewrite as `{source}<?php echo '<script>…</script>'; ?>` |
| JSON-LD / any literal `{…}` JSON           | `{source}<?php echo '<script …>' . json_encode(array(...)) . '</script>'; ?>` — never paste raw JSON in `{source}` |
| A PHP value inline (year, count, price)    | `{source}<?php echo …; ?>` — Sourcerer's native use case |
| Anything containing an email               | `chr(64)` for the `@`, and/or Prepare Content = Off |
| Content saved via a script/API             | expect a WAF 404 on `<?php` — save it by hand in the browser |
