# Company Information

Use this information when creating Joomla extensions.

## Primary Company
- **Company Name:** Cybersalt Consulting Ltd.
- **Author:** Cybersalt
- **Developer:** Tim Davis
- **Email:** support@cybersalt.com
- **Website:** https://cybersalt.com
- **Copyright:** Copyright (C) [YEAR] Cybersalt. All rights reserved.
- **License:** GNU General Public License version 2 or later

## Manifest XML Example

```xml
<author>Cybersalt</author>
<creationDate>January 2026</creationDate>
<copyright>Copyright (C) 2026 Cybersalt. All rights reserved.</copyright>
<license>GNU General Public License version 2 or later</license>
<authorEmail>support@cybersalt.com</authorEmail>
<authorUrl>https://cybersalt.com</authorUrl>
```

## Language File Header Example

```ini
; Cybersalt [Extension Name] - English Language File
; Copyright (C) 2026 Cybersalt. All rights reserved.
; License: GNU General Public License version 2 or later
```

## Naming convention: `cs` prefix vs. "Cybersalt" full name

Cybersalt extensions ship with `cs` (or `cs_`) as the technical prefix on every code-side identifier — directories, namespaces, language string keys, manifest filenames, etc. **But user-facing display titles must spell out "Cybersalt" in full.** The `cs` short form is for the engine, "Cybersalt" is for the human.

| Where | Use |
|---|---|
| Directory names (`cs-template-integrity`, `com_cstemplateintegrity`) | `cs` prefix |
| Namespace (`Cybersalt\Component\Cstemplateintegrity\…`) | `Cstemplateintegrity` (no `Cybersalt` doubling) |
| Language string KEYS (`COM_CSTEMPLATEINTEGRITY_DASHBOARD_TITLE`) | `CSTEMPLATEINTEGRITY` |
| Database tables (`#__cstemplateintegrity_sessions`) | `cstemplateintegrity` |
| File paths, asset bundle names, CSS classes | `cs` / `cstemplateintegrity` / `csti` |
| **VALUES of language strings** that render as page titles, toolbar titles, modal headers, breadcrumbs, postinstall messages, error messages | **"Cybersalt Template Integrity"** (or "Cybersalt [Name]") — full name |
| `<server name="…">` in update server manifest | "Cybersalt [Name] Updates" |
| `.sys.ini` `COM_*` constant value (extension manager listing) | "Cybersalt [Name]" |
| `api/language/*.ini` `COM_*` constant value | "Cybersalt [Name]" |
| Inline strings in PHP that get echoed (e.g. `"Components → … → Action log"` directives) | "Cybersalt [Name]" |

### Sweep checklist when starting a new extension OR rebranding an existing one

Run these grep patterns over the repo — anything that prints to a user must use "Cybersalt", anything that's a code identifier stays as the `cs` short form:

- `grep -rn 'CS Template'` (or whatever the short marketing name is)
- `grep -rn '"CS '` (catches values like `="CS Template Integrity"`)
- `grep -rn '>CS '` (catches XML element values like `<server name="CS …">`)

Why this matters: Tim caught the dashboard view showing the right name ("Cybersalt Template Integrity") while Sessions / Action log / File backups still showed "CS Template Integrity" because their toolbar-title language strings had the short form. Inconsistent branding inside the same extension reads as sloppy.
