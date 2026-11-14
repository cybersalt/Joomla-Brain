<?php
/**
 * Does an extension need Joomla's "Behaviour - Backward Compatibility" plugins, and what will Joomla 7 break?
 *
 * usage: php tools/compat-scan.php <joomla-root> <code-dir> [<code-dir> ...]
 *
 * Checks every class an extension references (use statements and fully qualified names, comments
 * ignored) against a real Joomla 5 or 6 tree:
 *   COMPAT-ONLY  the class exists there only through compat / compat6 (class aliases, compat6 legacy classes)
 *   NOT FOUND    no core file defines it (removed, or a typo)
 *   ASSET        a web asset that is only a compat stub
 *   J7           a call Joomla marks "removed in 7.0" (see JOOMLA7-READINESS.md), or getQuery(true)
 * Run it against the oldest and newest Joomla you support. Then test for real with both compat
 * plugins switched off (JOOMLA7-READINESS.md, "Prove it on a site").
 */
[$_, $jroot] = $argv + [null, null];
$dirs = array_slice($argv, 2);
if (!$jroot || !$dirs) {
    fwrite(STDERR, "usage: php compat-scan.php <joomla-root> <code-dir> [...]\n");
    exit(2);
}
$jroot = rtrim($jroot, '/\\');

// 1. What only the compat plugins provide on this Joomla
$compat = [];
foreach (glob("$jroot/plugins/behaviour/compat*/src/classmap/*.php") as $f) {
    preg_match_all("/registerAlias\(\s*'([^']+)'\s*,\s*'([^']+)'/", file_get_contents($f), $m, PREG_SET_ORDER);
    foreach ($m as $x) {
        $compat[strtolower(ltrim($x[1], '\\'))] = basename(dirname($f, 3)) . ' alias of ' . $x[2];
    }
}
$legacyDir = "$jroot/plugins/behaviour/compat6/classes";
if (is_dir($legacyDir)) {
    foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($legacyDir, FilesystemIterator::SKIP_DOTS)) as $f) {
        if (substr($f, -4) === '.php') {
            $rel = str_replace(['/', '.php'], ['\\', ''], substr(str_replace('\\', '/', (string) $f), strlen(str_replace('\\', '/', $legacyDir)) + 1));
            $compat[strtolower('Joomla\\CMS\\' . $rel)] = 'compat6 legacy class';
        }
    }
}
$stubAssets = [];
foreach (glob("$jroot/media/plg_behaviour_compat*/*.asset.json") as $f) {
    foreach (json_decode(file_get_contents($f), true)['assets'] ?? [] as $a) {
        $stubAssets[$a['name']] = basename($f);
    }
}

// Calls Joomla 6 marks "removed in 7.0" that turn up in extension code (extend as you meet more).
$j7 = [
    '/(?:\$app|getApplication\(\))\s*->\s*input\b/'      => '$app->input: use $app->getInput()',
    '/->\s*getQuery\s*\(\s*true\s*\)/'                    => 'getQuery(true): use $db->createQuery() (removed in joomla/database 5.0)',
    '/->\s*getCfg\s*\(/'                                  => 'getCfg(): use $app->get()',
    '/\bCMSObject\b/'                                     => 'CMSObject: use stdClass or your own class',
    '/(?:\$app|getApplication\(\))\s*->\s*getRouter\s*\(/' => '$app->getRouter(): inject it or take it from the container',
    '/->\s*getApiRouter\s*\(/'                            => 'getApiRouter(): Factory::getContainer()->get(ApiRouter::class)',
    '/\bFactory::(getDbo|getUser|getLanguage|getDocument|getSession|getMailer|getCache|getConfig)\s*\(/' => 'Factory::getX(): use the container / getApplication()',
    '/->\s*getDbo\s*\(/'                                  => '$model/$table->getDbo(): use getDatabase()',
    '/HTMLHelper::(?:script|stylesheet)\s*\(|HTMLHelper::_\(\s*[\'"](?:script|stylesheet)[\'"]/' => 'HTMLHelper script/stylesheet: use the Web Asset Manager',
];
// Only in plugin classes: CMSPlugin stops filling $app / $db in 7.0.
$pluginProps = '/\$this->(?:app|db)\b(?!\w)/';
// A plugin class that isn't a SubscriberInterface relies on legacy listeners, which go in 7.0.
$legacyListener = '/class\s+\w+\s+extends\s+CMSPlugin\b(?![^{]*SubscriberInterface)/';

// 2. Scan the extension code, comments stripped
$refs = [];
$issues = [];
foreach ($dirs as $d) {
    foreach (new RecursiveIteratorIterator(new RecursiveDirectoryIterator($d, FilesystemIterator::SKIP_DOTS)) as $f) {
        $p = str_replace('\\', '/', (string) $f);
        if (substr($p, -4) !== '.php' || preg_match('#/(vendor|node_modules|\.git)/#', $p)) {
            continue;
        }
        $src = '';
        foreach (token_get_all(file_get_contents($p)) as $t) {
            if (is_array($t) && in_array($t[0], [T_COMMENT, T_DOC_COMMENT], true)) {
                $src .= str_repeat("\n", substr_count($t[1], "\n"));
                continue;
            }
            $src .= is_array($t) ? $t[1] : $t;
        }
        $short = preg_replace('#^.*/github/#', '', $p);
        preg_match_all('/\\\\?\b(Joomla\\\\[A-Za-z0-9_\\\\]+)/', $src, $m);
        foreach ($m[1] as $c) {
            $refs[rtrim($c, '\\')][$short] = 1;
        }
        if (preg_match_all('/(?<![\w\\\\$>:])(J[A-Z][A-Za-z]+)\s*(?:::|\()|\bnew\s+(J[A-Z][A-Za-z]+)\b|extends\s+(J[A-Z][A-Za-z]+)\b/', $src, $m)) {
            foreach (array_filter(array_merge($m[1], $m[2], $m[3])) as $c) {
                $refs[$c][$short] = 1;
            }
        }
        if (strpos($src, 'JPATH_PLATFORM') !== false) {
            $issues[] = "COMPAT-ONLY constant JPATH_PLATFORM in $short";
        }
        if (preg_match_all('/(?:useScript|useStyle|usePreset|registerAndUseScript|registerAndUseStyle)\(\s*[\'"]([^\'"]+)/', $src, $m)) {
            foreach ($m[1] as $a) {
                if (isset($stubAssets[$a])) {
                    $issues[] = "ASSET '$a' is only a compat stub ({$stubAssets[$a]}) in $short";
                }
            }
        }
        if (preg_match($legacyListener, $src)) {
            $issues[] = "J7 plugin without SubscriberInterface (legacy listeners are removed in 7.0): $short";
        }
        if (preg_match('/extends\s+CMSPlugin\b/', $src) && ($n = preg_match_all($pluginProps, $src))) {
            $issues[] = "J7 \$this->app / \$this->db in a plugin: use getApplication() / getDatabase(): {$n}x in $short";
        }
        foreach ($j7 as $rx => $why) {
            if ($n = preg_match_all($rx, $src)) {
                $issues[] = "J7 $why: {$n}x in $short";
            }
        }
    }
}

// 3. Resolve every referenced class against this Joomla
$skip = '/^(Joomla\\\\(Component|Module|Plugin)\\\\(?!(?:\w+)\\\\(?:Administrator|Site|Api)\\\\)|Cybersalt)/';
foreach ($refs as $c => $files) {
    $where = implode(', ', array_keys($files));
    $lc = strtolower($c);
    if (isset($compat[$lc])) {
        $issues[] = "COMPAT-ONLY $c ({$compat[$lc]}) in $where";
        continue;
    }
    if ($c === 'JConfig') {
        continue; // the site's configuration.php class, not a legacy alias
    }
    if ($c[0] === 'J' && strpos($c, '\\') === false) {
        $issues[] = "LEGACY name $c in $where";
        continue;
    }
    $found = false;
    if (stripos($c, 'Joomla\\CMS\\') === 0) {
        $rel = str_replace('\\', '/', substr($c, 11));
        $found = is_file("$jroot/libraries/src/$rel.php") || is_dir("$jroot/libraries/src/$rel");
    } elseif (preg_match('#^Joomla\\\\Component\\\\(\w+)\\\\(Administrator|Site|Api)\\\\(.+)$#', $c, $mm)) {
        $base = ['Administrator' => 'administrator/components', 'Site' => 'components', 'Api' => 'api/components'][$mm[2]] . '/com_' . strtolower($mm[1]);
        if (!is_dir("$jroot/$base")) {
            continue; // not a core component: the extension's own or a third party's
        }
        $rel = str_replace('\\', '/', $mm[3]);
        $found = is_file("$jroot/$base/src/$rel.php") || is_dir("$jroot/$base/src/$rel");
    } elseif (preg_match('#^Joomla\\\\(\w+)(?:\\\\(.*))?$#', $c, $mm) && !preg_match('#^(Component|Module|Plugin|Template)$#', $mm[1])) {
        $pkg = "$jroot/libraries/vendor/joomla/" . strtolower($mm[1]) . '/src';
        $rel = str_replace('\\', '/', $mm[2] ?? '');
        $found = !is_dir($pkg) ? null : ($rel === '' || is_file("$pkg/$rel.php") || is_dir("$pkg/$rel"));
        if ($found === null) {
            continue; // not a framework package name: leave it
        }
    } else {
        continue;
    }
    if (!$found) {
        $issues[] = "NOT FOUND in core: $c in $where";
    }
}

preg_match_all('/(MAJOR|MINOR|PATCH)_VERSION = (\d+)/', file_get_contents("$jroot/libraries/src/Version.php"), $v);
echo 'Joomla ' . implode('.', $v[2]) . ": " . count($refs) . ' classes referenced, ' . count($compat) . ' compat-only names known, ' . count($stubAssets) . " stub assets\n";
echo $issues ? implode("\n", array_unique($issues)) . "\n" : "No compat dependencies and no known Joomla 7 removals found.\n";
exit($issues ? 1 : 0);
