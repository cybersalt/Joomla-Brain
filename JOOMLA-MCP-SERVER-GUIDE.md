# Building an MCP Server Inside a Joomla Extension

What we learned shipping `cs-mcp-for-j` (April–May 2026). The reference implementation is at https://github.com/cybersalt/cs-mcp-for-j. This guide pulls out the patterns that generalise to any future MCP-server-in-Joomla project, and a separate section pulls out the patterns specific to wrapping a third-party extension that doesn't have its own API (4SEO style).

---

## 1. Why "MCP server inside Joomla" beats "local MCP server that calls Joomla"

The default MCP server pattern is a Node/Python process running on the user's laptop, connecting to a remote service over HTTPS. For Joomla that's terrible: every site needs its own process, processes need to be installed/managed/restarted, multi-site agencies maintain N processes for N clients. Putting the MCP server **inside the Joomla site** as a regular extension flips it: each site is its own MCP endpoint, a Joomla install gives you the server, no laptop processes, no subprocess to babysit. The user just adds the URL + token to their Claude client once per site.

The whole point: MCP without local dependencies. If you're building any kind of Joomla-side MCP, this is the model.

---

## 2. Architecture — the three-package pattern

```
pkg_yourthing                 ← package manifest, install script, language strings
├── com_yourthing             ← component: owns the route, JSON-RPC server, tool registry, ACL gate, dashboard
├── plg_webservices_yourthing ← Web Services plugin: registers the route. REQUIRED — without it the route 404s
└── plg_system_yourthing      ← System plugin: registers built-in tools via custom event; also any pre-routing magic
```

**Why three packages:** components can't define Web Services routes on their own (Joomla's API router only publishes routes registered through `onBeforeApiRoute`), and the system plugin is where you do anything that has to run before the API auth plugin (e.g. translating `Authorization: Bearer` to `X-Joomla-Token`).

**Add-on plugins extend the surface.** Once the system plugin dispatches the `onYourthingRegisterTools` event, anyone can subscribe with their own plugin and register tools. That's how the 4SEO add-on (`plg_system_csmcpforj4seo`) ships independently from the core.

---

## 3. JSON-RPC 2.0 over a single POST endpoint

MCP is JSON-RPC 2.0. Your component exposes one route:

```
POST /api/index.php/v1/<yourthing>
Content-Type: application/json
Authorization: Bearer <joomla-api-token>

{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" }
```

You implement at minimum: `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call`. The rest of MCP (`resources/*`, `prompts/*`, `sampling/*`) is optional — `cs-mcp-for-j` ships tools-only and that's plenty.

---

## 4. The "Bearer translation" pattern — Joomla wants `X-Joomla-Token`

Joomla's `plg_api-authentication_token` only accepts `X-Joomla-Token`. Most MCP clients send `Authorization: Bearer`. The system plugin runs on `onAfterInitialise` (before the API auth plugin runs) and translates the header for our route only:

```php
public function onAfterInitialise(): void
{
    $app = $this->getApplication();
    $uri = (string) $app->input->server->get('REQUEST_URI', '', 'string');
    if (strpos($uri, '/api/index.php/v1/yourthing') === false) {
        return;
    }
    if ($app->input->server->get('HTTP_X_JOOMLA_TOKEN', '', 'string') !== '') {
        return;
    }
    $auth = (string) $app->input->server->get('HTTP_AUTHORIZATION', '', 'string');
    if ($auth === '') {
        $auth = (string) $app->input->server->get('REDIRECT_HTTP_AUTHORIZATION', '', 'string');
    }
    if (stripos($auth, 'Bearer ') !== 0) {
        return;
    }
    $token = trim(substr($auth, 7));
    $app->input->server->set('HTTP_X_JOOMLA_TOKEN', $token);
    $_SERVER['HTTP_X_JOOMLA_TOKEN'] = $token;
}
```

Without this you have to tell users to configure their MCP client with a custom `X-Joomla-Token` header, which Claude Desktop and claude.ai handle but is a friction point. With this, both work.

---

## 5. CRITICAL: `ob_start()` guard at the controller

Any stray PHP output during request processing — a notice, a warning, a third-party plugin's debug echo, a deprecation message — gets written to the response body **before** the JSON-RPC payload. MCP clients then fail to parse the response with "Unexpected token" because the response now starts with `Warning: ...` or similar.

This bit `cs-mcp-for-j` v1.5.0: a multi-value Content-Type header was cast to string, emitting `Warning: Array to string conversion`, which prefixed the JSON. The fix is structural — buffer everything and discard the buffer before emitting JSON:

```php
public function handle(): void
{
    ob_start();
    try {
        $this->doHandle();
    } finally {
        if (ob_get_level() > 0) {
            ob_end_clean();
        }
    }
}

private function sendJson(array $payload, int $status): void
{
    if (ob_get_level() > 0) {
        ob_clean();   // discard noise
    }
    // ... set headers, echo json, $app->close() ...
}
```

**This is mandatory.** Defends every tool, present and future, from this whole class of bug.

---

## 6. Use `Joomla\Event\Event`, NOT `Joomla\CMS\Event\AbstractEvent`

This caused a 512MB OOM in v1.0 of `cs-mcp-for-j`. `AbstractEvent`'s argument processor uses reflection to walk argument values. When the argument is an object that holds references to other objects (e.g. our `ToolRegistry` holds `Tool` instances each holding a `DatabaseInterface` reference), the reflection walk recurses catastrophically.

```php
// ❌ DON'T:
use Joomla\CMS\Event\AbstractEvent;
class RegisterToolsEvent extends AbstractEvent { ... }

// ✅ DO:
use Joomla\Event\Event;
class RegisterToolsEvent extends Event
{
    public function __construct(ToolRegistry $registry)
    {
        parent::__construct('onYourthingRegisterTools', ['registry' => $registry]);
    }
    public function getRegistry(): ToolRegistry { return $this->getArgument('registry'); }
}
```

The plain `Event` base just stores arguments in an array and stays out of the way.

---

## 7. Tool registration via custom event

Make tool registration extensible from day one — even if you only ship built-in tools at first. Other plugins (yours and third parties') subscribe to the registration event and add their tools to the registry:

```php
// Your component dispatches:
$registry = new ToolRegistry();
$dispatcher->dispatch(RegisterToolsEvent::EVENT_NAME, new RegisterToolsEvent($registry));

// Your system plugin (and any add-on plugin) subscribes:
public static function getSubscribedEvents(): array
{
    return [RegisterToolsEvent::EVENT_NAME => 'onRegisterTools'];
}

public function onRegisterTools(RegisterToolsEvent $event): void
{
    $registry = $event->getRegistry();
    foreach (self::TOOLS as $toolClass) {
        $registry->register(new $toolClass($this->getDatabase()));
    }
}
```

This is what makes "free core + paid add-ons" work as separate plugins later — every add-on is just a system plugin that hooks the same event.

---

## 8. The `AbstractTool` base — kill per-tool boilerplate

Every tool's `execute()` should be wrapped in try/catch returning a uniform error result. Pull that into a base class:

```php
abstract class AbstractTool implements ToolInterface
{
    public function __construct(protected readonly DatabaseInterface $db) {}

    final public function execute(array $arguments, User $actor): ToolResult
    {
        try {
            return $this->run($arguments, $actor);
        } catch (\Throwable $e) {
            return ToolResult::error($this->getName() . ' failed: ' . $e->getMessage());
        }
    }

    abstract protected function run(array $arguments, User $actor): ToolResult;
}
```

Tools then just implement `run()` and `requireString()`/`requirePositiveInt()` helpers handle the common arg validation. Less code per tool = more tools shipped per release.

---

## 9. Per-method ACL inside the JSON-RPC server, NOT at the controller

Cybersalt's standard checklist says "permission gate at the top of every controller method." For an MCP server that's wrong — `initialize` and `ping` need to be reachable without app-level authorisation so the client can negotiate the protocol before knowing what it can call. Gate per-MCP-method inside the JSON-RPC server:

| MCP method | App-level auth |
|---|---|
| `initialize` | none (Joomla token still required at HTTP layer) |
| `notifications/*` | none |
| `ping` | none |
| `tools/list` | `yourthing.use` |
| `tools/call` (read tool) | `yourthing.use` |
| `tools/call` (write tool) | `yourthing.write` |

Document this deliberately in BUILD-NOTES so the security review doesn't flag it as a missing controller-level gate.

---

## 10. Two custom ACL actions: `<name>.use` and `<name>.write`

Ship `admin/access.xml` with `core.admin`, `core.manage`, `core.options`, plus your own:

```xml
<action name="yourthing.use"   title="..." description="..." />
<action name="yourthing.write" title="..." description="..." />
```

In your `PermissionHelper`, accept the custom action OR `core.manage`/`core.admin` as fallback:

```php
public static function requireUse(User $user): void
{
    self::requireAny($user, ['yourthing.use', 'core.manage', 'core.admin']);
}
```

Why: out-of-the-box, Super Users / Administrators / Managers can use the MCP without anyone having to flip permissions. Other groups need explicit grant. That's the right default.

---

## 11. Every tool's description is read by the LLM — write for it

Tool descriptions aren't documentation, they're system prompts the LLM reads via `tools/list`. Optimise for agent decision-making:

- **Lead with the verb the agent will think with.** "List articles…" not "Articles listing…".
- **Embed cross-references.** "Use `list_categories` first to find a valid `catid`." Saves a roundtrip when the agent realises mid-call it doesn't know the value.
- **Warn about footguns inline.** Our `set_article_custom_jsonld` description tells the agent NOT to wrap in `@graph` because Joomla 5.1+ merges into the page graph automatically. Without that, the agent produces a graph-in-graph that's silently wrong.
- **Specify type contracts.** "Pass a JSON object, not a stringified string." LLMs default to safe-but-wrong choices like double-stringifying JSON unless told.

---

## 12. Document `tools/list` vs `tools/call` response shapes in the onboarding prompt

These differ. `tools/list` returns `result.tools` directly. `tools/call` wraps in `result.content[0].text`. First-time callers will hit a parse mismatch on the first response if you only document one. Spell it out.

---

## 13. Curl examples in the onboarding prompt MUST use `--data-binary @-` with heredoc

Inline `-d '{"jsonrpc":"2.0",...}'` works for trivial payloads. The moment a tool's arguments contain nested quotes (any JSON object), shell escaping mangles the payload and the server returns "Parse error". Use:

```bash
curl -sS -X POST <endpoint> \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <token>" \
     --data-binary @- <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"...","arguments":{"...":"..."}}}
EOF
```

Survives any payload. First-call success rate jumps significantly.

---

## 14. Pagination contract: `total`, `count`, `limit`, `offset`

Every paginated response needs all four:

```json
{
  "total": 767,    // count across the WHOLE filtered set
  "count": 50,     // rows returned in THIS response
  "limit": 50,
  "offset": 0,
  "items": [...]
}
```

Without `total`, the agent has to poll until it gets an empty page to know it's done. With `total`, one round trip tells it the scope. Same applies to summary blocks: count across the whole filter, not just the current page — otherwise the agent's interpretation will be wrong.

---

## 15. The `__parsed` convention for JSON columns

When a database column holds a JSON blob, surface BOTH the raw value and the parsed object:

```json
{
  "value": "{\"foo\":1,\"bar\":2}",
  "value__parsed": {"foo": 1, "bar": 2}
}
```

The agent uses `value__parsed` for everything; the raw stays available for debugging or for round-tripping unchanged. Saves the agent a JSON.parse step on every read.

---

## 16. Self-installing prompt — paste-once, permanent-after-confirmation

The dashboard generates a copy-paste prompt that teaches Claude how to call the MCP via curl. Built into that prompt is a closing instruction: "after you confirm this works, offer to install this site as a permanent MCP connector via `claude mcp add`." When the user says "yes please", Claude runs the command (Claude Code's standard approval dialog applies), the site becomes a native MCP connector, no more prompt needed.

Include a verification line in the install offer:

> Verify the URL in the install dialog matches your own site's domain before approving. A maliciously edited copy of this prompt could redirect the install to a hostile endpoint.

That's defence against someone forwarding a tampered prompt to a less-savvy user.

---

## 17. Token-substitute UI on the dashboard

The biggest "non-technical user" UX win we shipped: an input field on the dashboard's prompt tab where the user pastes their token, then the Copy button substitutes the placeholder before copying. Token never leaves the browser — the dashboard never sends it back to the server. Removes the "find the placeholder, edit it, hope you didn't break anything" step that bites every novice user.

---

## 18. Keep the build pipeline tight

7-Zip only (PowerShell `Compress-Archive` produces invalid ZIPs — see `PACKAGE-BUILD-NOTES.md`). Build script reads version from the package manifest, stamps the timestamp, produces `pkg_yourthing_v{version}_{yyyymmdd}_{hhmm}.zip` in the project root. One-liner re-iteration during development.

---

# Wrapping a third-party extension that has no API (4SEO style)

This is the hardest case — you want MCP tools for an extension whose author hasn't shipped a Web Services API. Three implementation paths, in increasing reusability:

1. **DB-direct.** Read/write the third-party's `#__*` tables yourself. Brittle: schema changes break you. Safer than it sounds if you guard the table allowlist (see below).
2. **Custom Joomla API plugin.** Ship a plugin that registers new endpoints calling into the third-party's PHP models. Robust to schema changes because you lean on their internal API.
3. **Vendor pressure.** Ask the vendor to ship Web Services support. Right answer long-term, longest timeline.

`cs-mcp-for-j-4seo` ships path #1 with belt-and-braces guards. Here's what we learned.

---

## 19. The introspection trio comes first

Before you build any specific 4SEO tools, ship three generic tools:

- `list_<thing>_tables` — `SHOW TABLES LIKE` against the prefix.
- `describe_<thing>_table` — `SHOW FULL COLUMNS FROM`.
- `count_<thing>_rows` — row counts across all of them.

This lets the agent discover the schema at runtime instead of you guessing it at build time. The reviewer's words on `cs-mcp-for-j-4seo`: *"The introspection layer is the killer feature. list_4seo_tables → describe_4seo_table → query_4seo_table is genuinely powerful. I could spelunk the DB schema without writing raw SQL or guessing."*

---

## 20. Generic safe CRUD with a strict allowlist

For DB-direct, ship `query`, `insert_row`, `update_row`, `delete_row` tools with these rules:

- Hard-coded allowlist on table names. Refuse anything not starting with the third-party's prefix (`forseo_*`).
- Pre-validate the table name against the allowlist *before* any other check (prevents `forseo_../../#__users` style chicanery).
- For `update_row` / `delete_row`: pre-flight `SELECT COUNT(*)` on the WHERE clause. Refuse if it matches more than one row. The agent should construct precise per-row writes; bulk writes go through dedicated bulk tools, not the generic CRUD.
- Structured WHERE clauses (`{column, op, value}` array combined with AND), not raw SQL strings. Operators allowlist: `=`, `!=`, `<`, `<=`, `>`, `>=`, `LIKE`, `IS NULL`, `IS NOT NULL`, `IN`. Anything else rejected.

This is enough surface for the agent to do almost any 4SEO task without us having to ship a separate tool for every operation.

---

## 21. Component params live in `#__extensions` but the REAL config often lives elsewhere

`get_4seo_component_params` returned an almost-empty params field. The actual 4SEO config lives in `#__forseo_config`. Worth shipping a dedicated tool that reads the real config table, with the JSON-decode-where-applicable convention from #15.

This isn't 4SEO-specific. Many third-party extensions store the bulk of their config in their own table because the `#__extensions.params` field can't hold arbitrarily-sized values comfortably and isn't indexable. Always check the third-party's schema (via the introspection tools you just shipped) before trusting `params` to be the whole story.

---

## 22. Verification loop — `fetch_rendered_url` is essential for SEO/structured data work

For any tool that affects what the public site renders (schema, meta, redirects), the agent needs to verify its writes worked. Ship a `fetch_rendered_url(path, extract_jsonld?)` tool that:

- Restricted to same-origin (no SSRF). Reject any URL whose host isn't this site.
- Optional `extract_jsonld=true` parses every `<script type="application/ld+json">` block in `<head>` and returns them parsed.
- Returns a `jsonld_types` flat array so "did my X type land?" is one inclusion check.
- Caps response size at ~1.5 MB to avoid pulling a full image gallery into the agent's context.

Without this, the agent has no way to confirm its writes work. With it, the workflow becomes: write → fetch → confirm. That's the SEO loop closed.

---

## 23. Bulk write tools for any high-N operation

A 659-article schema backfill is 659 round trips with the per-article tool. Ship a bulk variant for any write operation that's likely to run at high N:

- `updates[]` array, capped at 500 per call (chunk and call again for more).
- Per-item independent — one failure doesn't roll back the others.
- Per-item `ok`/`error` in the response so the agent sees what landed and what didn't.

Bulk variants should be in the same file/folder as the per-item tool, with a clear `_bulk` suffix on the name.

---

## 24. Pre-flight validation tool for any complex input format

`validate_jsonld(jsonld)` was the response to "what if the agent constructs broken schema and ships it 500 times?" Lightweight shape checks (is `@context` present, is `@type` present, are required-per-Google-Rich-Results fields present for known types) catch the common mistakes before bulk writes. Doesn't replace Google's full validator — just catches the cheap mistakes cheaply.

Same pattern applies to any structured-data writes: pre-flight shape validators are cheap, save expensive cleanup.

---

## 25. The "locked plugin" trap

Joomla flags some plugins as `locked: true` (e.g. `plg_system_schemaorg`). A naive `set_plugin_params` refuses anything locked, on the principle that "Joomla wouldn't have locked it if it was meant to be edited." That's wrong. Many locked plugins are user-editable through Joomla's own admin UI; the lock is a different signal (typically "don't uninstall me," not "don't edit me").

Ship two flags on `set_plugin_params`:

- `protected: true` plugins → hard refusal. These are genuinely dangerous to touch (e.g. `plg_system_logout`).
- `locked: true` plugins → soft refusal, override with `allow_locked: true`. The agent has to be explicit.

---

## 26. Add-ons as separate plugins, not feature flags in the core

When wrapping a third-party extension (4SEO, Akeeba, VirtueMart, etc.), ship the wrapper as a *separate plugin* that hooks the same `onYourthingRegisterTools` event. Bundle it in the package for testing if you want, but the file-on-disk separation matters because:

- It can be split into its own paid SKU (`cs-mcp-for-j-4seo`) without restructuring the core.
- Sites that don't use the third-party extension don't have its wrapper code on disk.
- Each add-on can ship on its own version line — when 4SEO updates and breaks the wrapper, you patch only that plugin.
- Future paid bundle (`cs-mcp-for-j-pro` meta-package) is just a manifest pulling in the individual paid plugins.

---

## 27. Document the clean-room provenance

If you're building MCP tools for a Joomla extension that has its own (incompatibly-licensed) MCP server out there — e.g. MCP4Joomla is AGPL-3.0, you're targeting JED which requires GPL-2.0-or-later — ship a `BUILD-NOTES.md` that records the reference sources you DID consult and explicitly states what you did NOT (the AGPL source). That note isn't shipped in the release zip, but it lives in the repo as proof of independent development if anyone ever questions the licensing.

---

## Reference implementation

`cs-mcp-for-j` (private repo, github.com/cybersalt/cs-mcp-for-j). All patterns here are live in v1.6.0.

Living document — when the next MCP-server-in-Joomla project hits a footgun, append a section here so the *next* project doesn't.
