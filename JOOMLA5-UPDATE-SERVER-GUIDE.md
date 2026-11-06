# Joomla 5 Update Server Guide

## Overview

Joomla's extension updater checks registered update servers to find available updates. Understanding how this system works is critical for building extensions that serve updates, especially authenticated/paid extensions.

---

## How Joomla Constructs the Update Check URL

### The Two-Phase System

Joomla uses `extra_query` at two **different** stages:

**Phase 1 — Update Check (checking for available updates):**
- Joomla reads `#__update_sites.location` and fetches that URL **directly**
- `extra_query` is **NOT appended** to this URL during the check phase
- The response must be valid XML in `<updates>` format

**Phase 2 — Download (actually downloading the ZIP):**
- Joomla uses the `<downloadurl>` from the update XML
- `extra_query` **IS appended** to the download URL:
```php
if ($extra_query = $update->get('extra_query')) {
    $url .= (!str_contains($url, '?')) ? '?' : '&';
    $url .= $extra_query;
}
```

**Key insight**: `extra_query` is for authenticating the **download**, not the update check.

---

## The `/extension.xml` Append Behavior

### When It Happens

Joomla's `UpdateAdapter::getUpdateSiteResponse()` has this logic:

1. First attempt: fetch the URL exactly as stored in `#__update_sites.location`
2. If the request **fails** (non-200 response OR invalid XML) AND the URL doesn't end in `.xml`:
   - Append `/extension.xml` to the URL
   - Retry the request

**Joomla does NOT always append `/extension.xml`.** It only does so as a **fallback** when the first request fails.

### Why This Causes Problems

If your dynamic endpoint returns an error (e.g., 400 because auth params are missing), Joomla sees the failure and retries with `/extension.xml` appended, producing broken URLs like:

```
https://example.com/index.php?option=com_myext&task=api.check&format=raw/extension.xml
```

### How to Prevent It

**Your update check endpoint MUST return HTTP 200 with valid XML on the first try.** If it does, Joomla will never append `/extension.xml`.

This means the update check should be **public** — no authentication. Return the version info to anyone who asks. Authentication happens at download time.

---

## The Standard Pattern for Paid Extensions

### Public Update Check, Authenticated Download

This is the pattern used by Akeeba, RSJoomla, and most commercial Joomla extensions:

1. **Update check URL** returns XML publicly — anyone can see what version is available
2. **Download URL** in the XML points to a protected endpoint
3. `extra_query` contains the authentication token (download ID, installation ID, etc.)
4. When the user clicks "Update", Joomla appends `extra_query` to the download URL

### Manifest Setup

```xml
<updateservers>
    <server type="extension" name="My Extension Updates">
        https://example.com/index.php?option=com_myupdater&amp;task=api.updatexml&amp;format=raw&amp;element=com_myext
    </server>
</updateservers>
```

### Database Records

**`#__update_sites`:**

| Column | Value |
|---|---|
| `name` | Extension name |
| `type` | `extension` |
| `location` | Public update XML URL (with query string) |
| `enabled` | `1` |
| `extra_query` | `installation_id=XXX&email_hash=XXX` (auth for download) |

### Update XML Response

The public endpoint returns:

```xml
<?xml version="1.0" encoding="utf-8"?>
<updates>
  <update>
    <name>My Extension Pro</name>
    <description>My Extension Pro update</description>
    <element>com_myext</element>
    <type>component</type>
    <version>2.1.0</version>
    <downloads>
      <downloadurl type="full" format="zip">https://example.com/downloads/com_myext_v2.1.0.zip</downloadurl>
    </downloads>
    <targetplatform name="joomla" version="5\.[0-9]+" />
    <php_minimum>8.1</php_minimum>
    <tags>
      <tag>stable</tag>
    </tags>
  </update>
</updates>
```

Return empty `<updates></updates>` when the package doesn't exist or is unpublished.

---

## type="extension" vs type="collection"

| Type | URL Points To | Use Case |
|---|---|---|
| `extension` | XML with `<updates><update>...</update></updates>` | Single extension update check |
| `collection` | XML with `<extensionset><extension detailsurl="...">` | Multiple extensions, Joomla follows each `detailsurl` |

Both types go through the same URL fetch logic and have the same `/extension.xml` fallback behavior.

---

## Setting extra_query Programmatically

Extensions typically set `extra_query` when the user enters their credentials (download ID, email, etc.):

```php
$db = Factory::getContainer()->get(DatabaseInterface::class);

// Find the extension ID
$query = $db->getQuery(true)
    ->select($db->quoteName('extension_id'))
    ->from($db->quoteName('#__extensions'))
    ->where($db->quoteName('element') . ' = ' . $db->quote('com_myext'))
    ->where($db->quoteName('type') . ' = ' . $db->quote('component'));
$extensionId = (int) $db->setQuery($query)->loadResult();

// Find the update site
$query = $db->getQuery(true)
    ->select($db->quoteName('update_site_id'))
    ->from($db->quoteName('#__update_sites_extensions'))
    ->where($db->quoteName('extension_id') . ' = ' . (int) $extensionId);
$updateSiteId = (int) $db->setQuery($query)->loadResult();

// Set extra_query
$extraQuery = 'installation_id=' . urlencode($installationId)
            . '&email_hash=' . urlencode($emailHash);

$query = $db->getQuery(true)
    ->update($db->quoteName('#__update_sites'))
    ->set($db->quoteName('extra_query') . ' = ' . $db->quote($extraQuery))
    ->where($db->quoteName('update_site_id') . ' = ' . (int) $updateSiteId);
$db->setQuery($query)->execute();
```

**Warning**: Joomla's "Rebuild Update Sites" feature (in System > Update Sites) can wipe `extra_query`. Joomla also recreates the update site record when the extension is upgraded — wiping `extra_query` again. Akeeba handles this by re-setting it on every page load via a system plugin. For extensions where users link credentials via a dashboard, re-running the link action sets it again.

---

## targetplatform Regex Gotcha

**This is a common cause of "no update detected" issues** even when the XML returns correctly.

The `<targetplatform>` element uses a **regex** that must match the user's Joomla version. A common mistake is to use the user's specified minimum version directly:

```xml
<!-- WRONG: only matches Joomla 5.0.x, blocks 5.1+, 5.2+, etc. -->
<targetplatform name="joomla" version="5.0\.[0-9]+" />

<!-- CORRECT: matches any 5.x version -->
<targetplatform name="joomla" version="5\.[0-9]+" />
```

When generating the regex from a `min_joomla_version` field, extract only the **major** version number:

```php
$minJoomla = $version->min_joomla_version ?: '5.0';
$majorVersion = (int) explode('.', $minJoomla)[0];
$xml .= '<targetplatform name="joomla" version="' . $majorVersion . '\.[0-9]+" />';
```

**Symptom**: The update XML returns a valid `<update>` block, but Joomla shows no updates available. The targetplatform regex didn't match the running Joomla version.

### Joomla 5 → Joomla 6 transition: empty max field collapses to J5-only

When supporting **both** Joomla 5 and Joomla 6 from the same package, the regex builder needs **both** majors in the output. Pattern: `(5|6)\.[0-9]+`. **Don't leave `max_joomla_version` empty thinking it means "unbounded"** — most regex builders interpret missing-max as "max = min", which collapses the regex back to single-major (`5\.[0-9]+`) and J6 sites silently never get the update.

If the regex builder follows the cs-release-manager pattern:

```php
$minMajor = (int) $minJoomla;        // e.g. 5 from "5.0"
$maxMajor = (int) $maxJoomla;        // e.g. 0 from "" — empty parses as 0
if ($maxMajor < $minMajor) {
    $maxMajor = $minMajor;           // empty → maxMajor = 5 → single-major output
}
```

…then to support J5+J6 you must set `max_joomla_version` to **any string starting with "6"** — `"6"`, `"6.0"`, `"6.99"` all work because `(int)` of any of them is `6`. **`"6"` is the cleanest value** (no fake decimal precision, no confusing "6.99" that suggests an upper bound that doesn't exist). Reserve **empty** for "this release really is J5-only and shouldn't show up on J6 sites at all" — which is rare.

Documented after cs-mcp-for-j v1.10.x publishing flow: leaving `max_joomla_version` empty rebuilt the regex as J5-only and no Joomla 6 site ever saw the update XML announcement, even though the package itself was J6-compatible.

---

## SHA256 Checksum (Best Practice)

Without a `<sha256>` element in your update XML, Joomla shows this warning during update:

> *"This extension does not provide a checksum for validation of the integrity of the downloaded file."*

Compute the hash when storing/uploading the ZIP and include it in the update XML:

```php
// On file upload, compute and store the hash:
$hash = hash_file('sha256', $targetPath);
$data['sha256'] = $hash;

// In the update XML:
$xml .= '<sha256>' . htmlspecialchars($version->sha256) . '</sha256>';
```

The element goes inside `<update>`, not inside `<downloads>` — the same level as `<element>`, `<version>`, etc.

---

## The Changelog Button (`changelog.xml` + `<changelogurl>`)

**Required on every extension with an update server.** `CHANGELOG.md` and `CHANGELOG.html` are for people. Joomla can't read them. Its Changelog buttons read a separate XML file, and so do mySites.guru's release notes.

**Source:** Phil Taylor's [How to add a changelog to a Joomla extension](https://mysites.guru/blog/add-changelog-to-joomla-extension/) (2026-11-06), which asked for this on StageIt. The group names and the exact version match were checked against Joomla's `libraries/src/Changelog/Changelog.php` (5.4-dev). The mySites.guru limits below are from the article.

### The three pieces, on every release

| Piece | Read by | If it's missing or wrong |
|---|---|---|
| `<changelogurl>` in the **manifest** | Changelog button on System → Manage → Extensions (stored in `#__extensions`) | No button |
| `<changelogurl>` in **each `<update>` entry** | Changelog button on System → Update → Extensions (stored in `#__updates`). This is the one that matters most: it's what people read before updating | Shows N/A |
| The **changelog file**, with an entry for that exact version | Both buttons | Modal opens empty |

```xml
<?xml version="1.0" encoding="utf-8"?>
<changelogs>
  <changelog>
    <element>pkg_example</element>
    <type>package</type>
    <version>1.1.0</version>
    <security>
      <item><![CDATA[Fixed a stored XSS in image captions]]></item>
    </security>
    <fix>
      <item><![CDATA[Captions & alt text are kept when an image is replaced]]></item>
    </fix>
    <addition>
      <item><![CDATA[WebP and AVIF thumbnails]]></item>
    </addition>
  </changelog>
</changelogs>
```

**The groups are exactly these seven:** `<security>`, `<fix>`, `<language>`, `<addition>`, `<change>`, `<remove>`, `<note>`. Joomla ignores anything else.

### Rules

- **The version must match exactly.** Joomla uses `version_compare(..., '==')`, so `1.1` doesn't match `1.1.0`. Copy the string from the manifest. **Every released version needs an entry, security releases most of all.** A version with no entry opens an empty modal.
- **Wrap every `<item>` in CDATA, on one line, and keep the text plain.** Without CDATA, items containing `&`, `<`, an entity or a non-ASCII character split into several bullets (joomla-cms #48392): "Bjørn" becomes "Bj" + "ørn". `Changelog::characterData()` does `$this->items[] = $data` on every parser callback. This isn't only Joomla 6.2: the same code is in 5.4-dev, and the split was seen on a live 6.1.4 site. In a PHP 8.4 parser test, the escaped form split into 8 pieces and the CDATA form stayed whole. HTML inside CDATA renders as HTML in the modal.
- **No whitespace or line break around the URL** in either `<changelogurl>`. Joomla doesn't trim it. Write it on one line, and escape `&` as `&amp;` in the manifest.
- **The URL must return HTTP 200 to Joomla's server-side request.** A raw.githubusercontent.com URL on a **private repo returns 404** for every customer site. CORS doesn't matter.
- **Never point it at `CHANGELOG.html`.** A 200 with HTML still gives an empty modal.
- **Skipped versions don't show.** Joomla shows only the entry for the version on offer, so a site two releases behind sees only the newest. mySites.guru's Updates popup lists up to 15 entries between installed and offered, security first.
- **`<infourl>` in the `<update>` entry** should be a public page for that release, not a homepage, sales page or login-walled download. It shows as a link under the extension name.
- **Security releases also set the security level in the same `<update>` entry**, e.g. `<security>3</security>` (read by Joomla 5.4.9, 6.1.4 and 6.2).

### Older Joomla versions

- **Joomla 4.4 saves a package's `<changelogurl>` on a fresh install only**, and both of its Changelog modals read the saved `#__extensions.changelogurl`. The feed's URL only makes the button appear. So a site that updates keeps an empty value and an empty modal. If an extension still supports J4, write the URL in `postflight()` (`$parent->getManifest()->changelogurl`, wrapped in try/catch so it can never fail the install). Proven on a 4.4.14 sandbox while preparing StageIt-6 #3; see `refreshChangelogUrl()` in `StageIt-legacy-j3-j4/j4/package/pkg_stageit_enterprise/script.php`.
- **Joomla 5.4.1 and 6.1.4 save the URL on update** with no script help (tested with real installs). Older J5 versions weren't checked.
- **Joomla 3.10 has no changelog code**, so the tag does nothing there.
- **If a feed offers one package's entry to another line** (StageIt's J5 feed also offers 6.6.2), each `<update>` entry needs the `<changelogurl>` for its own package, or the modal has no entry for that version.

### releases.mysites.guru

A row gets its Notes chip only when the changelog URL is http or https, at most 1,024 characters, and **on the same registrable domain as the update feed** (`cdn.example.com` and `www.example.com` count as the same). It fetches over ports 80 and 443, follows up to three redirects, reads at most 1 MB and caches for six hours.

### Which URL to use

| How the extension is served | `<changelogurl>` |
|---|---|
| **Release Manager** | `https://<store>/index.php?option=com_csreleasemanager&amp;task=api.changelogxml&amp;format=raw&amp;element=<element>`, plus `&amp;package=<key>` when several packages share an element (StageIt). The XML is built from each version's release notes, so **a version with empty notes gets no entry.** Use the store that serves the update feed (php-web-design.com for PHP Web Design products). |
| **Public GitHub repo** | `https://raw.githubusercontent.com/<owner>/<repo>/main/changelog.xml`, in the manifest and in `updates.xml` |
| **Private GitHub repo** | Serve it through Release Manager. Raw URLs 404 for customers. |

### Test it

1. `curl -s "<url>" | grep "<version>"` shows the version you're about to release.
2. The feed shows it: `curl -s "<feed url>" | grep changelogurl`.
3. On a site one version behind, click Changelog on System → Update → Extensions, and on System → Manage → Extensions after updating. Both modals show the notes, as single clean bullets.

---

## Updating the Update Server Location

The manifest `<updateservers>` URL is written to `#__update_sites.location` on install. If you need to change it programmatically (e.g., user configures a server URL):

```php
$query = $db->getQuery(true)
    ->update($db->quoteName('#__update_sites'))
    ->set($db->quoteName('location') . ' = ' . $db->quote($newUrl))
    ->where($db->quoteName('update_site_id') . ' = ' . (int) $updateSiteId);
$db->setQuery($query)->execute();
```

---

## Common Update Server Errors

| Error | Cause | Fix |
|---|---|---|
| URL has `/extension.xml` appended | Endpoint returned non-200 or invalid XML | Make update check public, return valid XML with HTTP 200 |
| "Could not open update site" | URL unreachable, SSL error, or server error | Check URL is accessible, verify SSL cert, check server logs |
| Update shown but download fails | `extra_query` not set, or download URL incorrect | Verify `extra_query` in `#__update_sites`, check download endpoint |
| No update shown despite new version | XML `<element>` doesn't match installed extension element | Ensure `<element>` in XML exactly matches manifest element |
| Update shown for wrong extension | XML `<element>` matches a different extension | Check element name uniqueness |
| `extra_query` disappears | User clicked "Rebuild Update Sites" | Re-set via system plugin or on component load |
| Changelog shows N/A on the Update screen | No `<changelogurl>` in the `<update>` entry | Add it to the feed, not only the manifest |
| Changelog modal opens empty | URL is HTML, returns non-200, or has no entry for that exact version | See "The Changelog Button" |

---

## Key Joomla Source Files

- `libraries/src/Updater/Updater.php` — Orchestrator; reads `#__update_sites`
- `libraries/src/Updater/UpdateAdapter.php` — Base class; `getUpdateSiteResponse()` handles HTTP fetch with `/extension.xml` fallback
- `libraries/src/Updater/Adapter/ExtensionAdapter.php` — Parses `<updates>` XML
- `libraries/src/Updater/Adapter/CollectionAdapter.php` — Parses `<extensionset>` XML
- `administrator/components/com_installer/src/Model/UpdateModel.php` — Handles download; appends `extra_query` to download URL

---

## References

- [Joomla Docs: Deploying an Update Server](https://docs.joomla.org/Deploying_an_Update_Server)
- [Joomla Manual: Update Servers](https://manual.joomla.org/docs/4.4/building-extensions/install-update/update-server/)
- [Akeeba: Working around Joomla's broken extensions updater](https://www.akeeba.com/news/1746-working-around-joomla-s-broken-extensions-updater.html)
- [Digigreg: Joomla Update System for paid extensions](https://www.digigreg.com/en/blog/joomla-update-system-implementation-for-paid-extensions.html)
