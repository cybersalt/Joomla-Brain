---
name: userback-integration
description: Reference for integrating the Userback.io feedback widget into web applications. Use when embedding Userback, configuring widget options, identifying users, attaching custom context data, troubleshooting missing screenshots, handling CSP issues, or working on the cs-userback-admin Joomla plugin.
---

# Userback.io Integration Skill

Reference for the Userback widget SDK (`https://static.userback.io/widget/v1.js`) — current as of 2026. Applies to direct embed, `Userback.init()`, and the `@userback/widget` NPM package. One workspace access token serves all projects; routing is configured in the dashboard.

## 1. Embed patterns

### A. Async snippet (simplest, what the Joomla plugin uses)
```html
<script>
  window.Userback = window.Userback || {};
  Userback.access_token = 'WIDGET_TOKEN';
  Userback.user_data  = { id: "123", info: { name: "Jane", email: "j@x.com" } };
  Userback.custom_data = { context: "admin", page_url: location.href };
  (function(d){ var s=d.createElement('script'); s.async=true;
    s.src='https://static.userback.io/widget/v1.js';
    (d.head||d.body).appendChild(s);
  })(document);
</script>
```
Pros: zero-setup, works anywhere. Cons: loads async — early-page console errors may be missed.

### B. Sync + `Userback.init()` (recommended when capturing console errors matters)
```html
<script src="https://static.userback.io/widget/v1.js"></script>
<script>
  Userback.init('TOKEN', {
    user_data: { id: "123", info: { name: "Jane", email: "j@x.com" } },
    native_screenshot: true,
    widget_settings: { language: "en", position: "sw" }
  });
</script>
```

### C. NPM / ES modules
```js
import Userback from '@userback/widget';
const ub = await Userback('TOKEN', options);
ub.openForm('bug');
```

## 2. Key configuration

Set before load (on `window.Userback`) or pass as second arg to `init()`.

| Option | Purpose |
|---|---|
| `user_data = { id, info: { name, email, ...any } }` | Identify user; `info` keys become dashboard fields |
| `name`, `email` | Shortcut prefills for form |
| `categories = "Backend"` | Preselect category dropdown |
| `priority = "low\|neutral\|high\|urgent"` | Preselect priority |
| `custom_data = { k: v, ... }` | Arbitrary context — appears in feedback sidebar |
| `native_screenshot: true` | Use browser Screen Capture API (required for dev/localhost/WebGL/iframes) |
| `is_live: true` | Force standard engine on sites the dashboard flags as private |
| `autohide: true` | Hide launcher until `Userback.show()` is called |

### widget_settings (Company plan+ to override dashboard)
```js
widget_settings: {
  language: "en",                 // 24 languages supported
  ui_theme: "light|dark|default",
  style: "text|circle",
  position: "e|w|se|sw",
  trigger_type: "page_load|api|url_match",
  main_button_text: "Feedback",
  main_button_background_colour: "#3E3F3A",
  main_button_text_colour: "#FFFFFF",
  device_type: "desktop,tablet,phone",
  logo: "https://.../logo.png",
  form_settings: { general: {
    rating_type: "star|emoji|heart|thumb|numbers",
    name_field: true, name_field_mandatory: false,
    email_field: true, email_field_mandatory: true,
    comment_field: true, comment_field_mandatory: true,
    display_category: true, display_priority: false,
    display_attachment: true, display_feedback: true
  } }
}
```

### Lifecycle callbacks
```js
Userback.on_load      = () => { /* widget DOM ready */ };
Userback.on_open      = () => { /* widget opened */ };
Userback.on_close     = () => { /* widget closed */ };
Userback.before_send  = () => { /* mutate/inspect before submit */ };
Userback.after_send   = () => { /* post-submit, e.g. redirect/thank */ };
Userback.on_survey_submit = (data) => { /* NPS/survey completed */ };
```

## 3. Runtime API

```js
// Legacy / snippet style
Userback.open(type, destination)     // type: 'general'|'bug'|'feature_request'
                                     // destination: 'screenshot'|'video'|'form'
Userback.close();
Userback.show(); Userback.hide();
Userback.destroy(true);              // full teardown, allows re-init
Userback.init(token, options);
Userback.identify(id, { name, email, ...info });

// NPM / Promise style (same names, instance-based)
ub.openForm('bug', 'screenshot');
ub.showLauncher(); ub.hideLauncher();
ub.identify('123', { name, email, plan: 'Pro' });
ub.setData({ route: '/dashboard' });   // additive custom_data
ub.setTheme('light|dark|auto');
ub.openSurvey(surveyId); ub.closeSurvey();
ub.startSessionReplay({ block_rule, ignore_rule, log_level, tags });
ub.stopSessionReplay();
ub.addCustomEvent(title, details);
```

Bind to your own button (hide default via `trigger_type: 'api'` or dashboard "Don't show launcher"):
```js
document.querySelector('#feedback-btn')
  .addEventListener('click', () => Userback.open('bug', 'screenshot'));
```

## 4. Screenshots — how they actually work

Two engines:

| Engine | How | When | Fails on |
|---|---|---|---|
| **Standard (default)** | Userback's servers (`screenshot.userback.io`, IPs `52.22.55.105` / `52.7.16.85`) fetch your URL and re-render it | Publicly reachable production sites | Firewalled/auth-protected pages, WebGL, iframes, CORS-tainted assets |
| **Native** | Browser Screen Capture API (`getDisplayMedia`) | `native_screenshot: true`, auto on localhost | Mobile browsers (unsupported) |

**Missing-screenshot checklist**:
1. **Private / staged site?** — set `native_screenshot: true` (or allowlist the two Userback IPs)
2. **CORS errors?** — add `Access-Control-Allow-Origin: *` (or the Userback origins) on images/fonts
3. **HTTP auth?** — configure credentials in project → Settings → Screenshots
4. **CSP blocking?** — see section 6
5. **User dismissed the browser permission prompt** (native mode) — feedback submits without screenshot

Standard engine is NOT html2canvas — it's a server-side headless re-render, so client-side CSP does not affect screenshot quality, but CORS on your assets absolutely does.

## 5. Session Replay & advanced (Business plan+)

- **Session Replay** — last ~3 min before a submission, auto-attached
- **User Sessions** (Business Plus) — full visits up to 6h, browsable separately
- Captures: clicks, mouse, scroll, form input, console, network (HTTP), custom events, rage clicks
- Privacy classes: `.userback-block` (omit element+children), `.userback-ignore` (keep visible, ignore input); passwords/emails auto-masked
- DOM > 5 MB won't record; no iframe/video/audio/canvas capture

```js
ub.startSessionReplay({
  block_rule: '.secret,[data-pii]',
  ignore_rule: '.inputs',
  log_level: ['error','warn'],
  tags: ['checkout-flow']
});
ub.addCustomEvent('clicked_checkout', { cart_total: 123 });
```

## 6. CSP directives

Unofficial (compiled from runtime behavior + support articles):

```
script-src   https://static.userback.io
connect-src  https://api.userback.io https://static.userback.io
img-src      https://static.userback.io data: blob:
style-src    https://static.userback.io 'unsafe-inline'
frame-src    https://static.userback.io
media-src    blob:
worker-src   blob:
```

Notes:
- Widget injects inline styles → `'unsafe-inline'` in `style-src` usually needed
- `'unsafe-eval'` NOT required in modern `v1.js`
- Native screenshot uses browser APIs, not a domain — no CSP entry needed for it

## 7. Multi-instance / multi-tab

Not formally documented, but from SDK shape:

- **One token per workspace** — running the widget in two tabs (admin + frontend, same origin) is supported; both post to the same workspace
- `localStorage` is shared per-origin → user identification can bleed between tabs on the same origin
- **Rule: always call `identify()` / set `user_data` on every page load.** Never rely on persisted state from a prior tab
- Always set `custom_data.context` to distinguish `admin` vs `site` submissions — critical when the same workspace receives feedback from both places
- If admin and frontend are different subdomains, `localStorage` is isolated — no cross-contamination, but also no shared identity, so `identify()` per page is still required

## 8. Integrations / routing

Destinations (Company plan+ for most; webhooks on lower plans):
- **PM:** Jira (2-way sync), Trello, Asana, ClickUp, Basecamp, Monday, Teamwork, Notion, Wrike, GitHub, GitLab, Azure DevOps, Linear, Intercom, Zendesk
- **Chat:** Slack, Microsoft Teams
- **Automation:** Webhooks (generic POST), Zapier, WordPress

Routing modes: **Manual** (user picks destination), **Automatic** (all forwarded), **Auto-Resolve** (forwarded + closed). Rules can route by category — e.g., "Bug" → Jira, "General" → Slack.

## 9. Best practices — identifying context for clear feedback

For any multi-context embed (CMS admin + public site, Electron + web, staging + prod), ALWAYS inject:

```js
Userback.user_data = {
  id: String(userId),                  // stable unique id
  info: {
    name: userName,
    email: userEmail,
    role: 'Super User',                // role/group
    app_version: '5.2.1'
  }
};

Userback.custom_data = {
  context: 'admin',                    // 'admin' | 'site' | 'mobile' | ...
  page_url: location.href,
  page_title: document.title,
  environment: 'production',           // 'production' | 'staging' | 'dev'
  // app-specific keys for debugging
  route: '/some/path',
  feature_flag_X: true
};

Userback.categories = 'Admin Backend';  // or derived from page
```

Rules:
- `custom_data` keys: snake_case, no dots/brackets
- Values: string/number/boolean only — stringify arrays/objects
- Staging: set `environment: 'staging'`, prefix `categories` with `[STAGING]`
- Native screenshot: auto-enable when `location.hostname` matches localhost / `.local` / `staging.`
- Use `before_send` to redact sensitive `custom_data` keys if user lacks admin rights
- Use `after_send` to flash a thank-you toast

## 10. Joomla-specific guidance (cs-userback-admin plugin)

This skill's primary consumer. Relevant context:

- **Plugin repo:** https://github.com/cybersalt/cs-userback-admin
- **Injection point:** `onBeforeCompileHead` adds a script declaration with the embed snippet
- **Token validation:** regex `^[A-Za-z0-9_-]{1,128}$` before interpolation + `json_encode` for safety (v1.3.0+)
- **Dual context:** widget runs in both admin and frontend based on per-side toggles + user-group restrictions
- **Current gap:** no user identification or custom_data is set — feedback arrives without source context

### Recommended Joomla payload

In `onBeforeCompileHead`, before emitting the embed snippet:

```php
$user = $app->getIdentity();
$isAdmin = $app->isClient('administrator');
$doc = $app->getDocument();

$userData = [
    'id'   => (string) ($user->id ?? 0),
    'info' => [
        'name'          => $user->name ?? 'Guest',
        'email'         => $user->email ?? '',
        'user_groups'   => implode(',', $user->getAuthorisedGroups()),
        'joomla_version'=> JVERSION,
    ],
];

$customData = [
    'context'      => $isAdmin ? 'admin' : 'site',
    'page_url'     => Uri::getInstance()->toString(),
    'option'       => $app->input->get('option', '', 'cmd'),
    'view'         => $app->input->get('view', '', 'cmd'),
    'layout'       => $app->input->get('layout', '', 'cmd'),
    'item_id'      => (int) $app->input->get('id', 0),
    'template'     => $app->getTemplate(),
    'environment'  => (defined('JDEBUG') && JDEBUG) ? 'dev' : 'production',
];

$userJs   = json_encode($userData,   JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT);
$customJs = json_encode($customData, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS|JSON_HEX_QUOT);

$script = <<<JS
    window.Userback = window.Userback || {};
    Userback.access_token = {$tokenJs};
    Userback.user_data    = {$userJs};
    Userback.custom_data  = {$customJs};
    Userback.categories   = "{$isAdminCat}";
    (function(d){ var s=d.createElement('script'); s.async=true;
      s.src='https://static.userback.io/widget/v1.js';
      (d.head||d.body).appendChild(s);
    })(document);
JS;
```

Where `$isAdminCat` is e.g. `'Admin Backend'` or `'Public Site'`.

### Plugin troubleshooting (common user complaints)

| Symptom | Cause | Fix |
|---|---|---|
| Feedback arrives without screenshot | Site is behind auth / on staging | Enable `native_screenshot: true` via a plugin param |
| Screenshot broken on one page only | CORS on a specific image/font | Fix `Access-Control-Allow-Origin` on the asset |
| Widget doesn't appear in admin | Plugin disabled, user not in allowed group, or token validation rejected the pasted value | Check `enable_backend`, user group, check token matches `^[A-Za-z0-9_-]+$` |
| Widget appears on both tabs but submissions carry wrong user | `identify()` not called per-page — localStorage reused | Always set `user_data` on every page load (already fixed if using the recommended payload above) |
| CSP blocks widget | Strict CSP header in place | Add Userback domains to allowlist (see section 6) |

### Plugin feature opportunities

- Add a `native_screenshot_on_local` plugin param (auto-sets `native_screenshot: true` when hostname is localhost / contains `staging`)
- Add a `custom_data_extras` textarea (JSON) merged into `custom_data` for per-site customization
- Add a `categories_backend` / `categories_frontend` param so admin vs site feedback is pre-categorized
- Add a `before_send_redact_keys` param to strip sensitive keys for non-admin users

---

## Sources

- [Userback Docs — Widget Installation](https://docs.userback.io/docs/widget-installation-methods)
- [JavaScript SDK Reference](https://docs.userback.io/docs/javascript-sdk)
- [User Identification](https://docs.userback.io/docs/user-identification)
- [Attach Custom Data](https://docs.userback.io/docs/attach-custom-data)
- [Events / Callbacks](https://docs.userback.io/docs/events)
- [Native Screenshot](https://support.userback.io/en/articles/9417749-native-screenshot)
- [CORS Troubleshooting](https://support.userback.io/en/articles/9417977-troubleshoot-cors-errors-when-sending-feedback-to-userback)
- [Session Replay](https://support.userback.io/en/articles/5762135-session-replay)
- [NPM Package](https://docs.userback.io/docs/npm)
