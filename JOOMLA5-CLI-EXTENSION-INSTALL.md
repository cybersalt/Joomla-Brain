# Joomla 5 CLI Extension Install on cPanel — Gotchas + JCE Pro Update Pattern

When patching a Joomla 5 extension on a cPanel server from the command line (e.g., for security-driven upgrades like JCE Pro 2.9.89 → 2.9.99.7 to close the 2026-06 vulnerability window), there are three landmines that will silently waste an hour of your day. This note captures all three plus the canonical recipe.

## The canonical recipe

```bash
# 1. Stage the package somewhere readable by the cPanel user (NOT in a path matching
#    /_cs_quarantine_/ — Imunify scans those and will re-flag malware inside the zip)
ls -la /home/<cpanel-user>/cs-jce-staging/pkg_jce_pro_29997.zip

# 2. Run the install with the EXPLICIT EA-PHP CLI binary path (not generic `php`)
sudo -u <cpanel-user> -- /opt/cpanel/ea-php81/root/usr/bin/php \
  /home/<cpanel-user>/<install>/cli/joomla.php \
  extension:install \
  --path=/home/<cpanel-user>/cs-jce-staging/pkg_jce_pro_29997.zip

# 3. Expected output (Joomla 5.x):
#    Install Extension
#    =================
#     [OK] Extension installed successfully.
```

The PHP version (`ea-php81`) must match what the cPanel runs. List available:

```bash
ls /opt/cpanel/ea-php*/root/usr/bin/php
```

## Gotcha 1 — `php` on cPanel is PHP-CGI, not PHP-CLI

Cybersalt's cPanel servers (s11 confirmed 2026-06-30) have multiple PHP binaries installed. The generic `/usr/local/bin/php` (and `/bin/php`, `/usr/bin/php`) all route to **PHP-CGI**, which expects HTTP request context (`$_SERVER`, query string, etc.) and outputs a `Content-type: text/html; charset=UTF-8` header before doing anything useful.

If you run `php cli/joomla.php extension:install ...` you'll see:

```
Content-type: text/html; charset=UTF-8

```

And then nothing happens. **No error. No install. No log entry.** The script exited because PHP-CGI couldn't make sense of the CLI argv.

**Fix**: use the explicit EA-PHP CLI binary at `/opt/cpanel/ea-php<NN>/root/usr/bin/php`. That's the per-EasyApache-version CLI variant. Confirm the PHP version your account runs (cPanel UAPI `Variables/get_user_information` returns `phpversion` or just check the `php` output `phpinfo()` from a probe), then use the matching EA path.

**On CloudLinux servers with Alt-PHP**: the path is `/opt/alt/php<NN>/usr/bin/php` instead. `which -a php` won't tell you whether the binary is CGI or CLI — only running it does.

## Gotcha 2 — Joomla 5 `extension:install` flags are NOT what older docs say

Joomla's own published examples (including some from 2024) suggest flags like `--type=package` and `--uri=site`. **Joomla 5.3+ rejects these.** The actual help output reveals:

```
extension:install [--path PATH] [--url URL] [-h|--help] [-q|--quiet]
                  [-v|vv|vvv|--verbose] [-V|--version] [--ansi] [--no-ansi]
                  [-n|--no-interaction] [--live-site [LIVE-SITE]] [--] <command>
```

So the only relevant flags for a local-zip install are:

- `--path=/absolute/path/to/package.zip` — for a local zip
- `--url=https://...` — for a remote URL fetch

No `--type` (auto-detected from zip contents). No `--uri` (extensions install for both site + administrator from a package). No `--method` (just one method: extract + install).

**If you pass `--uri`, Joomla 5.3+ errors out with**:

```
The "--uri" option does not exist.
```

The `<command>` positional shown in help is the Symfony Console framework's noise — `extension:install` IS the command, no further positional needed.

## Gotcha 3 — Programmatic install via PHP-FPM probe doesn't work for Joomla 5

You can NOT install a Joomla 5 extension by bootstrapping the framework from a one-off PHP probe served through PHP-FPM and calling `Joomla\CMS\Installer\Installer::install()` directly. Tested 2026-06-30 with two variants:

1. **Bootstrap + AdministratorApplication** — throws `Resource 'Joomla\Session\SessionInterface' has not been registered with the container.`
2. **Bootstrap + ConsoleApplication + session.cli alias** (mirroring `cli/joomla.php`) — silently dies with HTTP 500 + zero output + no PHP error log entry, somewhere inside `Installer::install()`. Joomla calls something during install that requires a full CLI environment.

**The Joomla CLI script (`cli/joomla.php`) is the only supported path.** Don't fight this — just invoke it via the EA-PHP CLI binary as shown above.

## JCE Pro license key — extracting from #__update_sites

JCE Pro packages require a license key in the download URL. The key lives in the Joomla `#__update_sites` table for any install that already had JCE Pro registered:

```sql
SELECT update_site_id, name, location, extra_query
FROM <prefix>_update_sites
WHERE location LIKE '%joomlacontenteditor%';

-- Result example:
-- name        = "JCE Editor Package"
-- location    = "https://cdn.joomlacontenteditor.net/updates/xml/editor/pkg_jce_pro.xml"
-- extra_query = "key=WFF39BDF81D1F326CD10973D13B23B69EF"
```

The `extra_query` field stores the key in `key=XXX` form. Strip the `key=` prefix to get the raw key.

## JCE Pro download URL pattern

The Pro update XML feed at `https://cdn.joomlacontenteditor.net/updates/xml/editor/pkg_jce_pro.xml` advertises the latest version + its filename. The actual download URL puts the license key in the URL **path**, not as a query string:

```
https://updates.joomlacontenteditor.net/download/pkg_jce_pro_<version-flat>.zip/<LICENSE_KEY>
```

For 2.9.99.7 → `pkg_jce_pro_29997.zip`. Without the key in the URL path, you get HTTP 403. With the key, you get a 301 redirect to the actual download with the key still in the path.

## SHA256 verification

The Pro update XML feed includes a `<sha256>` element per version. Always verify after download:

```bash
# server-side via PHP probe
$expected = 'a6c26e598736ff2586ee3dbe943d1f17de6dd1f72c556880fe9290243159902e';
$actual = hash_file('sha256', $downloaded);
if ($actual !== $expected) { /* abort */ }
```

## Free vs Pro determination

Both Free and Pro JCE installs ship a `pkg_jce.xml` manifest at `<install>/administrator/manifests/packages/pkg_jce.xml`. To distinguish:

| Marker | Free | Pro |
|---|---|---|
| `<variant>` element | absent | `<variant>pro</variant>` |
| `<dlid prefix="key=" .../>` | absent | present |
| Packages list includes `plg_system_jcepro.zip` | no | yes |
| Update server URL | `pkg_jce.xml` | `pkg_jce_pro.xml` |
| Component dir `administrator/components/com_jcepro/` | absent | absent (Pro uses same `com_jce` dir; differentiator is `plg_system_jcepro`) |

The `PKG_JCE` package name is shared between Free and Pro — the `<variant>` element is the canonical signal.

## Where to stage the download — avoid Imunify scan paths

If you stage the package zip inside `/home/<user>/_cs_quarantine_<date>/` (the Skill 27 forensic-quarantine convention), Imunify will scan it on its next pass and re-flag any malware-pattern-matching contents of the zip. Bad UX — your "cleanup is done" report keeps getting contradicted by Imunify.

**Stage outside any path matching `_cs_quarantine_*` or `quarantine` substrings**. Recommended:

- `/home/<user>/cs-jce-staging/`
- `/home/<user>/.cs-staging/`  (hidden)
- A root-owned dir if accessible (`/var/cs-staging/`)

Imunify's per-user scan still covers the whole `$HOME` so even the alternative names will be scanned — but as long as they're not active malware (just a vendor-signed package zip), Imunify treats them as opaque archives, not threats.

## Origin

Pattern captured during the 2026-06-30 Project Mr. Clean engagement on AMGraphix's torontos cPanel — see [[../../OneDrive/Documents/obsidian/Cybersalt%20Consulting%20Ltd/04.knowledge/incidents/2026-06-29-torontos-mrclean/README.md]] for the full engagement record including the failed approaches that led to discovering each gotcha.
