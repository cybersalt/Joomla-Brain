<#
.SYNOPSIS
    Writes integrity.json (size + SHA-256 of every file Joomla will install)
    into an extension's source folder. Run it from the build script just
    before that folder is zipped.

.DESCRIPTION
    Reads the extension's XML manifest, works out where Joomla will install
    every file (components, plugins, modules, templates, libraries, plus
    <media>), and writes the list next to the files it ships with:

      component -> the <administration><files folder="..."> source folder
      plugin / module / template / library -> the root <files folder="..."> folder

    The manifest must list the file in that same <files> block:
        <filename>integrity.json</filename>
    The script stops the build with the exact line to add if it is missing.

    The extension's IntegrityCheck class (tools/integrity/php, copied in by
    Install-IntegrityCheck.ps1) reads the installed list and reports missing,
    empty and changed files. See INTEGRITY-CHECK.md in the Brain root.

    <languages> blocks are skipped: those files go to the shared language
    folders and site owners override them on purpose.

.PARAMETER ExtensionDir
    The folder that holds the extension's XML manifest (the folder you zip).

.PARAMETER Manifest
    The manifest file, only needed when ExtensionDir holds more than one
    <extension> XML.

.PARAMETER Exclude
    Wildcard patterns for files the site owner is meant to edit, matched
    against the path inside the install folder (forward slashes), e.g.
    'css/user.css'. Templates always exclude */user.css, */custom.css,
    */user.js and */custom.js.

.EXAMPLE
    & "$brain\tools\integrity\New-IntegrityList.ps1" -ExtensionDir "$root\packages\com_example"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ExtensionDir,
    [string]$Manifest = '',
    [string[]]$Exclude = @()
)

$ErrorActionPreference = 'Stop'

$listName     = 'integrity.json'
$formatNumber = 1
$ExtensionDir = (Resolve-Path $ExtensionDir).Path.TrimEnd('\', '/')

if (-not $Manifest) {
    $candidates = @(Get-ChildItem $ExtensionDir -Filter '*.xml' -File | Where-Object {
        try { ([xml](Get-Content $_.FullName -Raw -Encoding UTF8)).DocumentElement.LocalName -eq 'extension' } catch { $false }
    })

    if ($candidates.Count -ne 1) {
        throw "Found $($candidates.Count) <extension> manifests in $ExtensionDir; pass -Manifest."
    }

    $Manifest = $candidates[0].FullName
}

$Manifest = (Resolve-Path $Manifest).Path

[xml]$xml = Get-Content $Manifest -Raw -Encoding UTF8
$ext      = $xml.DocumentElement
$type     = $ext.GetAttribute('type')
$client   = $ext.GetAttribute('client')

function Get-ManifestText([string]$xpath) {
    $node = $ext.SelectSingleNode($xpath)
    if ($node) { return $node.InnerText.Trim() }
    return ''
}

$version = Get-ManifestText 'version'

# The element attribute Joomla reads off a <files> child (plugin="x" / module="x").
function Get-AttributeElement([string]$attribute) {
    foreach ($node in $ext.SelectNodes("files/*[@$attribute]")) {
        return $node.GetAttribute($attribute).Trim()
    }
    return ''
}

# Each block: the <files>/<media> node, its install folder (relative to the
# Joomla root), and whether the list lives there.
$blocks       = @()
$element      = ''
$manifestDest = ''

switch ($type) {
    'component' {
        $element = (Get-ManifestText 'element')
        if (-not $element) { $element = (Get-ManifestText 'name') }
        $element = $element.ToLowerInvariant() -replace '[^a-z0-9_.-]', ''
        if (-not $element.StartsWith('com_')) { $element = "com_$element" }

        $blocks += @{ Node = $ext.SelectSingleNode('files');                Dest = "components/$element";               List = $false }
        $blocks += @{ Node = $ext.SelectSingleNode('administration/files'); Dest = "administrator/components/$element"; List = $true }
        $blocks += @{ Node = $ext.SelectSingleNode('api/files');            Dest = "api/components/$element";           List = $false }
        $manifestDest = "administrator/components/$element"
    }
    'plugin' {
        $group   = $ext.GetAttribute('group')
        $element = Get-AttributeElement 'plugin'
        if (-not $element) { $element = Get-ManifestText 'element' }
        if (-not $group -or -not $element) { throw "Plugin manifest needs group=`"..`" and a plugin=`"..`" attribute or <element>." }

        $blocks += @{ Node = $ext.SelectSingleNode('files'); Dest = "plugins/$group/$element"; List = $true }
        $manifestDest = "plugins/$group/$element"
    }
    'module' {
        $element = Get-AttributeElement 'module'
        if (-not $element) { $element = Get-ManifestText 'element' }
        if (-not $element) { throw 'Module manifest needs a module="..." attribute or <element>.' }
        $base = if ($client -eq 'administrator') { 'administrator/modules' } else { 'modules' }

        $blocks += @{ Node = $ext.SelectSingleNode('files'); Dest = "$base/$element"; List = $true }
        $manifestDest = "$base/$element"
    }
    'template' {
        $element = Get-ManifestText 'element'
        if (-not $element) { $element = ((Get-ManifestText 'name') -replace ' ', '_') }
        $element = $element.ToLowerInvariant()
        $base    = if ($client -eq 'administrator') { 'administrator/templates' } else { 'templates' }

        $blocks += @{ Node = $ext.SelectSingleNode('files'); Dest = "$base/$element"; List = $true }
        $manifestDest = "$base/$element"
        $Exclude += @('*/user.css', 'user.css', '*/custom.css', 'custom.css', '*/user.js', 'user.js', '*/custom.js', 'custom.js')
    }
    'library' {
        $element = Get-ManifestText 'libraryname'
        if (-not $element) { throw 'Library manifest needs <libraryname>.' }

        $blocks += @{ Node = $ext.SelectSingleNode('files'); Dest = "libraries/$element"; List = $true }
    }
    'package' {
        throw 'Run this on each extension inside the package, not on the package manifest.'
    }
    default {
        throw "Extension type '$type' is not supported (component, plugin, module, template, library)."
    }
}

foreach ($media in $ext.SelectNodes('media')) {
    $destination = $media.GetAttribute('destination').Trim('/')
    if (-not $destination) { $destination = $element }
    $blocks += @{ Node = $media; Dest = "media/$destination"; List = $false }
}

$listBlock = $blocks | Where-Object { $_.List -and $_.Node } | Select-Object -First 1

if (-not $listBlock) {
    throw "No <files> block found to hold $listName in $Manifest."
}

$listedInManifest = $false
foreach ($node in $listBlock.Node.SelectNodes('filename')) {
    if ($node.InnerText.Trim() -eq $listName) { $listedInManifest = $true }
}

if (-not $listedInManifest) {
    $where = if ($type -eq 'component') { '<administration><files folder="...">' } else { '<files>' }
    throw "$Manifest must list the integrity file. Add <filename>$listName</filename> inside $where."
}

$listSource = Join-Path (Join-Path $ExtensionDir $listBlock.Node.GetAttribute('folder')) $listName
$listSource = [IO.Path]::GetFullPath($listSource)

function Test-Excluded([string]$relative, [string]$installed) {
    foreach ($pattern in $Exclude) {
        if ($relative -like $pattern -or $installed -like $pattern) { return $true }
    }
    return $false
}

$files = @{}

function Add-File([string]$source, [string]$installed, [string]$relative) {
    $full = [IO.Path]::GetFullPath($source)

    if ($full -eq $listSource) { return }
    if (Test-Excluded $relative $installed) { return }

    if ($files.ContainsKey($installed)) {
        Write-Warning "Two manifest entries install to $installed; keeping the last."
    }

    $item = Get-Item -LiteralPath $full
    $script:files[$installed] = [ordered]@{
        size   = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

foreach ($block in $blocks) {
    if (-not $block.Node) { continue }

    $sourceBase = Join-Path $ExtensionDir $block.Node.GetAttribute('folder')

    foreach ($child in $block.Node.ChildNodes) {
        if ($child.NodeType -ne 'Element') { continue }

        $name = $child.InnerText.Trim().Trim('/')
        if (-not $name) { continue }

        $source = Join-Path $sourceBase $name

        switch ($child.LocalName) {
            'filename' {
                if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
                    if ($name -eq $listName) { continue }
                    throw "Manifest lists $name but $source does not exist."
                }
                Add-File $source "$($block.Dest)/$name" $name
            }
            'folder' {
                if (-not (Test-Path -LiteralPath $source -PathType Container)) {
                    throw "Manifest lists folder $name but $source does not exist."
                }
                $sourceRoot = (Resolve-Path -LiteralPath $source).Path.TrimEnd('\', '/')
                foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force) {
                    $inner    = $file.FullName.Substring($sourceRoot.Length + 1) -replace '\\', '/'
                    $relative = "$name/$inner"
                    Add-File $file.FullName "$($block.Dest)/$relative" $relative
                }
            }
        }
    }
}

# Joomla copies the manifest itself into the extension folder.
if ($manifestDest) {
    $manifestName = Split-Path $Manifest -Leaf
    Add-File $Manifest "$manifestDest/$manifestName" $manifestName
}

$sorted = [ordered]@{}
foreach ($key in ($files.Keys | Sort-Object { $_ } -CaseSensitive)) {
    $sorted[$key] = $files[$key]
}

$list = [ordered]@{
    format    = $formatNumber
    generator = 'Joomla-Brain tools/integrity/New-IntegrityList.ps1'
    extension = $element
    type      = $type
    version   = $version
    generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    files     = $sorted
}

$json = $list | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($listSource, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "  integrity list: $($sorted.Count) files -> $listSource" -ForegroundColor Gray
