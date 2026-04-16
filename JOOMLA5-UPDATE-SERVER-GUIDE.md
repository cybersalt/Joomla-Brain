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

**Warning**: Joomla's "Rebuild Update Sites" feature (in System > Update Sites) can wipe `extra_query`. Akeeba handles this by re-setting it on every page load via a system plugin.

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
