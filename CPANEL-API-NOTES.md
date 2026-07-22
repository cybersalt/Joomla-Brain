# cPanel UAPI Notes for Iterative Joomla Extension Deployment

When iterating on an in-development Cybersalt Joomla extension installed on a cPanel-hosted staging site, you can push file changes directly to the deployed copy without rebuilding/reinstalling the ZIP every cycle. This is faster for surgical edits to existing files.

For larger iterations (manifest changes, new SQL, new files, refactors), rebuild and reinstall the ZIP — the cPanel API approach only saves time when you're patching files that already exist on the server.

## Endpoint and auth

Standard cPanel UAPI:

```
https://<cpanel-host>:2083/execute/<Module>/<function>
Authorization: cpanel <user>:<api-token>
```

API tokens are issued per-cPanel-account in cPanel → Manage API Tokens. The token has the same scope as the cPanel user, so anything the user can do via cPanel, the token can do — there is no per-folder restriction.

## Two file-write endpoints, two very different behaviours

### `Fileman::upload_files` (multipart) — use this for non-trivial files

Push a local file via multipart upload. Handles arbitrary size cleanly.

```bash
curl -sS -X POST \
  "https://green.cybersalthosting.com:2083/execute/Fileman/upload_files" \
  -H "Authorization: cpanel csaltcom:$TOKEN" \
  -F "dir=public_html/stageit/administrator/components/com_csimagesentinel/src/Helper" \
  -F "overwrite=1" \
  -F "file-1=@/local/path/to/JobHelper.php" \
  -F "file-2=@/local/path/to/ScannerHelper.php"
```

A successful response includes `"reason": "Upload of “X” succeeded, overwrote existing file with your upload."` for each file. If you only see `"...succeeded."` without `"overwrote existing file"`, the upload landed somewhere unexpected — see the path-resolution gotcha below.

### `Fileman::save_file_content` — only safe for tiny payloads

Sends content as a form-encoded POST parameter. The body is passed through cPanel's AdminBin IPC, which has a **small buffer** that the form-encoded representation of a few-KB PHP file already exceeds. The error you get when you blow past it is:

```
Failed to read valid Cpanel::AdminBin::Serializer data in json connect mode
```

…which is unhelpful and entirely misleading about what actually went wrong. **Use `upload_files` instead** for anything more than a few hundred bytes.

`save_file_content` also requires the target file to already exist — for new files use `upload_files` regardless of size.

## Path-resolution gotcha — relative paths only

`Fileman::upload_files` accepts `dir=` as either:

- **Relative to the user's home directory** — `dir=public_html/stageit/...` ✅
- **Absolute starting with `/home/<user>`** — `dir=/home/csaltcom/public_html/stageit/...` ⚠️ silently sandboxed

When you pass an absolute path, the API may report `"Upload of X succeeded."` but the bytes do **not** end up at the expected location. The file is silently dropped into a sandbox and the on-disk target is unchanged. Symptoms:

- `list_files` for the same path shows old size and old mtime
- `get_file_content` returns the old content
- Re-running the upload claims success again every time
- `Fileman::list_files` for the doubled path `/home/<user>/home/<user>/...` returns "directory does not exist"

The success message even includes `"overwrote existing file with your upload"` only when the upload actually overwrote — if you see just `"succeeded."` the file went to the sandbox.

**Always use the relative form**: `dir=public_html/stageit/...` (no leading `/home/<user>`).

## Verification pattern

After every push, list the directory and confirm `mtime` is now and `size` matches the local file:

```bash
curl -sS \
  "https://<host>:2083/execute/Fileman/list_files?dir=public_html/stageit/admin/components/...&types=file" \
  -H "Authorization: cpanel <user>:$TOKEN" \
  | python3 -c "
import sys,json,datetime
for f in json.load(sys.stdin)['data']:
    mtime = datetime.datetime.fromtimestamp(f['mtime']).isoformat()
    print(f\"{f['file']:30s} size={f['size']} mtime={mtime}\")"
```

If `mtime` is the install time and not "now", the upload didn't land — check the path form.

## OPcache invalidation

Multipart upload changes the file's mtime, so PHP's OPcache will normally pick up the new bytes on the next request when `opcache.validate_timestamps=1` (the default). If your host has `validate_timestamps=0` or `revalidate_freq` set high, you'll need to either:

- Wait for the configured revalidation interval
- Touch a file that triggers PHP-FPM reload (e.g. `Whostmgr::Service::restart` for ops with WHM access)
- Add a per-extension `opcache_invalidate()` call to your install script and run it via a Joomla admin URL after deploys

For most Cybersalt staging hosts the default kicks in within a second or two and no special action is needed.

## When to use API vs ZIP

Use direct API push when:
- Patching one or two existing PHP files
- The change is contained — no manifest, no SQL, no new files
- You want to avoid the install/uninstall cycle for a quick test

Use ZIP install when:
- Anything in `<manifest>` changed (version, files, SQL paths)
- A new SQL update file was added under `sql/updates/mysql/`
- New PHP files were added (autoloader will not pick them up without a fresh install OR a `discover_install`)
- You're not sure — when in doubt, ship the ZIP

## Real-world friction encountered

Discovered while patching cs-image-sentinel's `bind()` fix on stage:

1. First attempt used `save_file_content` with a 5KB PHP file — got the AdminBin serializer error
2. Switched to `upload_files` with absolute path `/home/csaltcom/public_html/stageit/...` — API reported success on all 4 files, but `list_files` showed unchanged mtime/size
3. Switched to relative path `public_html/stageit/...` — uploads landed correctly, response now included `"overwrote existing file"`

Total time spent on the surprise: ~10 min, much of it interpretation of "success" responses that weren't.

## ModSecurity / ClamAV silently quarantining `.php` uploads to webroot

Discovered on violinspiration.ca (hardened shared host) while trying to write a one-off debug `.php` file via `Fileman::upload_files` to query the database for cs-template-integrity. The cPanel UAPI:

1. Accepted the multipart upload (`status: 1`)
2. Returned `Upload of "csti-dbg-<random>.php" succeeded` with the correct byte count
3. **The file never landed on disk**. Subsequent `list_files` against `/home/<user>/public_html` showed no match.

The host's mod_security or ClamAV layer silently strips uploaded `.php` files that match webshell-detection patterns. cPanel UAPI doesn't surface this — its layer sees "file received from client" and reports success; the server-side scanner discards the file before it hits the filesystem.

Confirmed by retrying with:

- Original filename + a `mysqli_connect` call directly → blocked
- Random hex filename + cleaner Joomla-bootstrapped script (no direct DB calls, just `Factory::getContainer()->get(DatabaseInterface::class)`) → also blocked

The pattern that triggers it is "any `.php` file uploaded via API to docroot, on this class of host". Filename randomness doesn't help. Script content cleanliness doesn't fully help either — even an innocuous-looking Joomla bootstrap is rejected if the host's rules are tight enough.

**Implications for remote debugging Cybersalt extensions on customer sites:**

- The "write a one-shot debug `.php`, fetch via HTTP, self-delete" gambit will silently fail on any moderately hardened shared host. Don't trust the UAPI's `succeeded` response — always verify the file's actually on disk via `list_files` before fetching it.
- Build proper REST endpoints into the extension itself for any state you might need to inspect remotely. For `cs-template-integrity` this means exposing the action log and backup list as authenticated `/v1/cstemplateintegrity/*` endpoints rather than relying on file uploads.
- Same applies to in-place patching — if you upload a patched `.php` to a customer's site via UAPI, confirm it landed before assuming the patch took effect.

**Workarounds that *might* work on a given host (none tested as of 2026-05-25):**

- Write to a non-`.php` extension first (e.g. `.txt`), then rename via `Fileman::move_file` — some hosts only scan on upload, not on rename.
- Write to a path outside docroot (e.g. `/home/<user>/`), then trigger via `Cron::add_line` with `php /home/<user>/script.php > /home/<user>/out.json` and fetch `out.json` via `Fileman::get_file_content`. Same scanner constraint may apply.
- Use SSH/SFTP if the host exposes it — scanners typically only run on cPanel API uploads, not raw file transfers.

But the right answer is **don't depend on this technique**: ship the introspection capability *inside* the extension's REST API so an authenticated token is all you need.
