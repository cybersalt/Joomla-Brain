<?php

/*
 * Repository checks for a Cybersalt Joomla extension, run by GitHub Actions
 * on every push (.github/workflows/ci.yml) and by hand: php tests/check.php
 * (or php check.php <repo folder>). Exit code 1 and a list when something
 * is wrong.
 *
 * Copied from Joomla-Brain templates/tests/check.php. It finds the manifests
 * and language folders itself, so most repos need no changes. If yours does,
 * change the settings below and say why in a comment.
 *
 *  - every XML and JSON file parses
 *  - no byte order mark in PHP or INI files (one in PHP is output before
 *    the headers; one in an INI file breaks its first string)
 *  - every file and folder a manifest lists is in the repository, in the
 *    exact case (Linux servers care, Windows and macOS don't)
 *  - optionally, every manifest has the package's version
 *  - Joomla can read every language file, and each translation has every
 *    English string and no others, with the same placeholders
 *
 * It checks the files git would commit (tracked, plus new files that are not
 * ignored), which is what CI sees. Submodules are left out.
 */

// ---- Settings ----

// Files a manifest lists that the build writes, so they are not in git
$buildFiles = ['integrity.json'];

// true when every manifest in the repo carries the package's version (StageIt,
// Page Protector). Leave false when the sub-extensions have versions of their
// own (MCP for J, Release Manager).
$sameVersion = false;

// English language files not checked against the translations, as regular
// expressions on the path from the repo root. Say why for each one.
$skipLanguageFiles = [];

// ---- Helpers ----

$root   = rtrim(str_replace('\\', '/', realpath($argv[1] ?? dirname(__DIR__))), '/');
$errors = [];
$fail   = function ($file, $message) use (&$errors, $root) {
    $errors[] = ltrim(substr(str_replace('\\', '/', $file), strlen($root)), '/') . ': ' . $message;
};

// git ls-files leaves out ignored files and lists a submodule as one entry
// (a folder), so is_file() drops it
exec('git -C ' . escapeshellarg($root) . ' ls-files -z --cached --others --exclude-standard', $out, $code);
if ($code !== 0) {
    echo "Needs git and a git repository\n";
    exit(1);
}
$all = [];
foreach (explode("\0", implode("\n", $out)) as $rel) {
    if ($rel !== '' && is_file($root . '/' . $rel)) $all[] = $root . '/' . $rel;
}
$all = array_values(array_unique($all));
sort($all);
$files = function ($pattern) use ($all) {
    return array_values(array_filter($all, function ($p) use ($pattern) {
        return preg_match($pattern, basename($p));
    }));
};

// In git, in the exact case (also on Windows and macOS), as a file or a folder
$known = [];
foreach ($all as $path) {
    for ($p = $path; strlen($p) > strlen($root); $p = dirname($p)) $known[$p] = true;
}
$exists = function ($path) use ($known) {
    $path = rtrim(preg_replace('#/(\./)+|/{2,}#', '/', str_replace('\\', '/', $path)), '/');
    return isset($known[$path]);
};

// ---- XML, JSON, byte order marks ----

libxml_use_internal_errors(true);
$manifests = [];
foreach ($files('/\.xml$/i') as $file) {
    $xml = simplexml_load_file($file);
    if ($xml === false) {
        $fail($file, 'XML: ' . trim(libxml_get_errors()[0]->message ?? 'cannot be read'));
        libxml_clear_errors();
        continue;
    }
    if ($xml->getName() === 'extension') $manifests[$file] = $xml;
}
foreach ($files('/\.json$/i') as $file) {
    json_decode((string) file_get_contents($file));
    if (json_last_error() !== JSON_ERROR_NONE) $fail($file, 'JSON: ' . json_last_error_msg());
}
foreach ($files('/\.(php|ini)$/i') as $file) {
    if ((string) file_get_contents($file, false, null, 0, 3) === "\xEF\xBB\xBF") $fail($file, 'has a byte order mark');
}

// ---- Manifests ----

if (!$manifests) $errors[] = 'No extension manifest found (an XML file whose root is <extension>)';

$versions = [];
$packages = [];
foreach ($manifests as $file => $xml) {
    $versions[$file] = trim((string) $xml->version);
    $isPackage = (string) $xml['type'] === 'package';
    if ($isPackage) $packages[] = $file;

    foreach (['scriptfile', 'installfile', 'uninstallfile'] as $tag) {
        $script = trim((string) $xml->$tag);
        if ($script !== '' && !$exists(dirname($file) . '/' . $script)) $fail($file, 'lists "' . $script . '", which is not there');
    }

    foreach ($xml->xpath('//files | //languages | //media') as $block) {
        $base = dirname($file);
        // Joomla uses folder="" only when that folder is in the package
        if ((string) $block['folder'] !== '' && is_dir($base . '/' . $block['folder'])) $base .= '/' . $block['folder'];
        foreach ($block->children() as $item) {
            // A package's <file> entries are zips the build makes
            if ($isPackage && $item->getName() === 'file') continue;
            $path = trim((string) $item);
            if ($path === '' || in_array(basename($path), $buildFiles, true)) continue;
            if (!$exists($base . '/' . $path)) $fail($file, 'lists "' . $path . '", which is not there');
        }
    }
}
if ($sameVersion && count($packages) !== 1) $errors[] = '$sameVersion is on, but there are ' . count($packages) . ' package manifests (needs exactly 1)';
if ($sameVersion && count($packages) === 1) {
    $want = $versions[$packages[0]];
    foreach ($versions as $file => $version) {
        if ($version !== $want) $fail($file, 'version ' . $version . ', the package is ' . $want);
    }
}

// ---- Language files ----

$load = function ($file) use ($fail) {
    $strings = [];
    $text    = (string) file_get_contents($file);
    if (!mb_check_encoding($text, 'UTF-8')) $fail($file, 'is not UTF-8');

    // The same call Joomla makes (LanguageHelper::parseIniFile), which fails on any warning
    set_error_handler(function ($no, $message) { throw new ErrorException($message); }, E_WARNING);
    try {
        if (parse_ini_file($file, false, INI_SCANNER_RAW) === false) $fail($file, 'Joomla cannot read this file');
    } catch (ErrorException $e) {
        $fail($file, 'Joomla cannot read this file: ' . $e->getMessage());
    }
    restore_error_handler();

    foreach (preg_split('/\r\n|\n|\r/', $text) as $n => $line) {
        if (trim($line) === '' || $line[0] === ';' || $line[0] === '[') continue;
        if (!preg_match('/^([A-Za-z0-9_.\-]+)\s*=\s*"((?:[^"\\\\]|\\\\.)*)"\s*$/', $line, $m)) {
            $fail($file, 'line ' . ($n + 1) . ' is not KEY="value"');
            continue;
        }
        $key = strtoupper($m[1]);
        if (isset($strings[$key])) $fail($file, $key . ' is there twice');
        $strings[$key] = $m[2];
    }
    return $strings;
};
$marks = function ($value) {
    // %s %d %1$s ... in any order, numbered or not ("50% off" is not a placeholder)
    preg_match_all('/%(?:\d+\$)?([sd])/', $value, $m);
    sort($m[1]);
    return implode(' ', $m[1]);
};
foreach ($files('/\.ini$/i') as $enFile) {
    if (basename(dirname($enFile)) !== 'en-GB') continue;
    $rel = substr($enFile, strlen($root) + 1);
    foreach ($skipLanguageFiles as $pattern) {
        if (preg_match($pattern, $rel)) continue 2;
    }
    $parent    = dirname($enFile, 2);
    $languages = array_filter(array_map('basename', glob($parent . '/*', GLOB_ONLYDIR)), function ($tag) {
        return $tag !== 'en-GB' && preg_match('/^[a-z]{2,3}-[A-Za-z]{2,4}$/', $tag);
    });
    $english = $load($enFile);
    foreach ($languages as $language) {
        // Joomla 4+ names have no tag in front; older ones start with en-GB.
        $name = basename($enFile);
        if (strncmp($name, 'en-GB.', 6) === 0) $name = $language . substr($name, 5);
        $file = $parent . '/' . $language . '/' . $name;
        if (!$exists($file)) {
            $fail($file, 'is missing');
            continue;
        }
        $strings = $load($file);
        foreach (array_diff_key($english, $strings) as $key => $value) $fail($file, $key . ' is missing');
        foreach (array_diff_key($strings, $english) as $key => $value) {
            // A language may have more plural forms than English (Russian has ..._MANY)
            if (!preg_match('/_(0|1|2|3|4|ONE|TWO|FEW|MANY|OTHER|MORE)$/', $key)) $fail($file, $key . ' is not in English');
        }
        foreach (array_intersect_key($strings, $english) as $key => $value) {
            if ($marks($value) !== $marks($english[$key])) $fail($file, $key . ' has placeholders "' . $marks($value) . '", English has "' . $marks($english[$key]) . '"');
        }
    }
}

if ($errors) {
    echo implode("\n", $errors) . "\n\n" . count($errors) . " problem(s)\n";
    exit(1);
}
echo 'All checks passed (' . count($manifests) . " manifest(s))\n";
