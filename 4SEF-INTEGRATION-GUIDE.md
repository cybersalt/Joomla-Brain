# 4SEF Integration Guide for Joomla 5 Components

## Overview

4SEF (by Weeblr) replaces Joomla's menu-item-based routing. When building custom components, you need to ensure your URLs work with 4SEF.

## Recommended Approach: "Joomla SEF" Mode

The simplest integration — no native 4SEF plugin needed.

### Setup
1. In 4SEF → Configuration → Extensions, set your component to **"Joomla SEF"**
2. **Purge 4SEF URLs** after any changes
3. 4SEF captures URL pairs from `Route::_()` output and stores them in its database

### Critical Rule: Always Use Route::_()

**4SEF can ONLY intercept URLs that go through Joomla's `Route::_()` function.**

```php
// ✅ CORRECT — 4SEF captures this
$url = Route::_('index.php?option=com_mycomp&view=articles&topic_id=' . $id . '&Itemid=' . $itemId);

// ❌ WRONG — 4SEF never sees this, URLs will 404
$url = Uri::root(true) . '/' . $menuAlias . '/' . $topicAlias;
```

Manual string concatenation bypasses Joomla's routing system entirely. 4SEF has no way to capture or resolve these URLs.

### View Parameter Matters

The `view` parameter in your non-SEF URL determines which view 4SEF resolves to when parsing the SEF URL back.

```php
// ✅ Links to article list filtered by topic
Route::_('index.php?option=com_mycomp&view=articles&topic_id=5&Itemid=100');

// ❌ Links to topics list (wrong view!)
Route::_('index.php?option=com_mycomp&view=topics&topic_id=5&Itemid=100');
```

### After Any URL Change
Always **purge 4SEF URLs** after:
- Installing/updating the component
- Changing URL structure in code
- Switching between Bypass/Joomla SEF/Normal modes
- Moving menu items

---

## 4SEF Modes Explained

| Mode | Description | Plugin Needed? |
|------|-------------|----------------|
| **Bypass** | 4SEF ignores this component entirely. Joomla's native router handles everything. | No |
| **Joomla SEF** | 4SEF stores whatever URL Joomla's `Route::_()` produces. No custom URL building. | No |
| **Normal** | 4SEF uses a native driver plugin to build custom URLs. Most control but most work. | Yes |

**Recommendation:** Start with "Joomla SEF" mode. Only build a native plugin if you need URL structures that Joomla's router can't produce.

---

## Building a Native 4SEF Plugin (Advanced)

Only needed for "Normal" mode with custom URL structures.

### Built-in Driver Reference

4SEF's own drivers are at `/plugins/system/forsef/platform/extensions/`. Study these for working examples:
- `base.php` — Base class all drivers extend
- `content.php` — com_content driver (most complex)
- `contact.php` — com_contact driver (good medium example)

### Driver Structure

```php
namespace Weeblr\Forsef\Platform\Extensions;

use Joomla\CMS\Uri;
use Weeblr\Forsef\Helper;

class Mycomponent extends Base
{
    public function build($uriToBuild, $platformUri, $originalUri)
    {
        $sefSegments = parent::build($uriToBuild, $platformUri, $originalUri);
        
        $view = $uriToBuild->getVar('view');
        $id   = $uriToBuild->getVar('id');
        
        switch ($view) {
            case 'articles':
                // Look up alias from database
                $alias = $this->getAlias($id);
                if ($alias) {
                    $sefSegments[] = $alias;
                }
                break;
        }
        
        // Trailing slash prevents .html suffix
        $sefSegments[] = '/';
        
        return $sefSegments;
    }
    
    public function buildNormalizedNonSef($vars)
    {
        return $this->nonSefHelper->stripFeedVars(
            parent::buildNormalizedNonSef($vars)
        );
    }
    
    public function shouldLeaveNonSef($uriToBuild)
    {
        return false;
    }
}
```

### Key Points
- Class name = component name without `com_` (e.g., `Mycomponent` for `com_mycomponent`)
- Namespace: `Weeblr\Forsef\Platform\Extensions`
- `build()` only handles URL building — 4SEF stores the pair, no parse needed
- Call `parent::build()` first to get any configured prefix
- Available helpers: `$this->menuHelper`, `$this->sefHelper`, `$this->nonSefHelper`, `$this->urlHelper`
- Use `$this->factory->getA(Helper\Slugs::class)` for slug lookups

### Loading the Driver

Three approaches (from 4SEF docs):
1. **Direct inclusion** from your own extension (system plugin)
2. **Hook response** via `forsef_on_load_plugins` event
3. **Separate Joomla plugin** with `group="forsef"`

**Note:** As of March 2026, approaches 1 and 3 were tested but the hook never fired. "Joomla SEF" mode was the working solution. Revisit if a native plugin is needed later.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Topic links 404 | Manual URL building bypasses 4SEF | Use `Route::_()` for all URLs |
| Wrong view loads | `view=topics` instead of `view=articles` in Route URL | Fix the view parameter |
| Old URLs still cached | 4SEF URL cache not purged | Purge URLs in 4SEF dashboard |
| URLs not captured | Component set to "Bypass" | Switch to "Joomla SEF" |
| Plugin not loading | `forsef_on_load_plugins` hook not firing | Use "Joomla SEF" mode instead |

---

## Reference

- 4SEF documentation: https://weeblr.com/doc/products.forsef/current/plugins/
- Contact: Yannick Gaultier (@weeblr, weeblr.com)
