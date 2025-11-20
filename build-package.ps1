# Generic Joomla 5 Package Builder Script
# This script automatically creates Joomla installation packages
# Run from the parent repo root: .\shared\build-package.ps1

param(
    [string]$ProjectName = ""
)

# Detect parent repo directory
$submoduleDir = $PSScriptRoot
$parentDir = Split-Path $submoduleDir -Parent
Set-Location $parentDir

Write-Host "Building Joomla Package..." -ForegroundColor Green
Write-Host "Working directory: $parentDir" -ForegroundColor Gray

# Auto-detect project name from package manifest
if (-not $ProjectName) {
    $pkgManifest = Get-ChildItem -Path $parentDir -Filter "pkg_*.xml" | Select-Object -First 1
    if ($pkgManifest) {
        $ProjectName = $pkgManifest.BaseName -replace '^pkg_', ''
        Write-Host "Auto-detected project: $ProjectName" -ForegroundColor Cyan
    } else {
        Write-Host "ERROR: No pkg_*.xml found. Please specify -ProjectName parameter." -ForegroundColor Red
        exit 1
    }
}

# Run validation first
Write-Host "Running pre-build validation..." -ForegroundColor Blue
& "$submoduleDir\validate-package.ps1"
if ($LASTEXITCODE -eq 1) {
    Write-Host "Build cancelled due to validation errors" -ForegroundColor Red
    exit 1
}

# Get version from package manifest
$pkgXmlPath = "pkg_$ProjectName.xml"
if (Test-Path $pkgXmlPath) {
    [xml]$pkgXml = Get-Content $pkgXmlPath
    # Get the version element (not the attribute on extension tag)
    $versionNode = $pkgXml.SelectSingleNode("//extension/version")
    if ($versionNode) {
        $version = $versionNode.InnerText.Trim()
    } else {
        Write-Host "ERROR: Could not find version element in manifest" -ForegroundColor Red
        exit 1
    }
    Write-Host "Version: $version" -ForegroundColor Yellow
} else {
    Write-Host "ERROR: Package manifest not found: $pkgXmlPath" -ForegroundColor Red
    exit 1
}

# Clean up old build files
Write-Host "Cleaning old build files..." -ForegroundColor Blue
Remove-Item "com_$ProjectName.zip", "plg_$ProjectName.zip" -ErrorAction SilentlyContinue
Remove-Item "pkg_${ProjectName}_Joomla_5_v*.zip" -ErrorAction SilentlyContinue

# Function to create ZIP with forward slashes (required for Joomla)
function New-ZipWithForwardSlashes {
    param($SourcePath, $DestinationPath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $DestinationPath) { Remove-Item $DestinationPath -Force }

    $zip = [System.IO.Compression.ZipFile]::Open($DestinationPath, 'Create')

    try {
        Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($SourcePath.Length + 1)
            $zipPath = $relativePath -replace '\\', '/'
            $entry = $zip.CreateEntry($zipPath)
            $entryStream = $entry.Open()
            $fileStream = [System.IO.File]::OpenRead($_.FullName)
            $fileStream.CopyTo($entryStream)
            $fileStream.Close()
            $entryStream.Close()
        }
    } finally {
        $zip.Dispose()
    }
}

# Create component zip with proper folder structure
if (Test-Path "component") {
    Write-Host "Creating component package..." -ForegroundColor Blue

    if (Test-Path "temp_component") { Remove-Item "temp_component" -Recurse -Force }
    New-Item -ItemType Directory -Path "temp_component" -Force | Out-Null

    # Copy manifest to root of component package
    $componentManifest = "component\com_$ProjectName.xml"
    if (Test-Path $componentManifest) {
        Copy-Item $componentManifest -Destination "temp_component\com_$ProjectName.xml" -Force
    }

    # Copy site files (frontend)
    $siteFiles = @("com_$ProjectName.php", "com_$ProjectName", "index.html")
    foreach ($file in $siteFiles) {
        if (Test-Path "component\$file") {
            Copy-Item "component\$file" -Destination "temp_component\$file" -Force
        }
    }

    # Create admin folder and copy admin files
    New-Item -ItemType Directory -Path "temp_component\admin" -Force | Out-Null
    $excludeItems = @("com_$ProjectName.xml") + $siteFiles
    Get-ChildItem "component" -Exclude $excludeItems | ForEach-Object {
        if ($_.PSIsContainer) {
            Copy-Item $_.FullName -Destination "temp_component\admin" -Recurse -Force
        } else {
            Copy-Item $_.FullName -Destination "temp_component\admin" -Force
        }
    }

    New-ZipWithForwardSlashes -SourcePath (Resolve-Path "temp_component").Path -DestinationPath "com_$ProjectName.zip"
    Remove-Item "temp_component" -Recurse -Force
    Write-Host "Component package created" -ForegroundColor Green
}

# Create plugin zip
$pluginPath = "plugins\system\$ProjectName"
if (Test-Path $pluginPath) {
    Write-Host "Creating plugin package..." -ForegroundColor Blue

    # Validate plugin XML before packaging
    $pluginXmlPath = "$pluginPath\$ProjectName.xml"
    if (Test-Path $pluginXmlPath) {
        try {
            [xml]$pluginXml = Get-Content $pluginXmlPath
            Write-Host "Plugin XML is valid" -ForegroundColor Green
        } catch {
            Write-Host "Plugin XML is invalid: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }

    if (Test-Path "temp_plugin") { Remove-Item "temp_plugin" -Recurse -Force }
    New-Item -ItemType Directory -Path "temp_plugin" -Force | Out-Null
    Copy-Item "$pluginPath\$ProjectName.php" -Destination "temp_plugin\$ProjectName.php" -Force
    Copy-Item "$pluginPath\$ProjectName.xml" -Destination "temp_plugin\$ProjectName.xml" -Force
    New-ZipWithForwardSlashes -SourcePath (Resolve-Path "temp_plugin").Path -DestinationPath "plg_$ProjectName.zip"
    Remove-Item "temp_plugin" -Recurse -Force
    Write-Host "Plugin package created" -ForegroundColor Green
}

# Create final package
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$packageName = "pkg_${ProjectName}_Joomla_5_v${version}_${timestamp}.zip"
Write-Host "Creating final package: $packageName" -ForegroundColor Blue

if (Test-Path "temp_package") { Remove-Item "temp_package" -Recurse -Force }
New-Item -ItemType Directory -Path "temp_package" -Force | Out-Null

# Copy package files
$packageFiles = @("pkg_$ProjectName.xml", "script.php", "com_$ProjectName.zip", "plg_$ProjectName.zip", "CHANGELOG.md")
foreach ($file in $packageFiles) {
    if (Test-Path $file) {
        Copy-Item $file -Destination "temp_package" -Force
    }
}

# Copy additional folders
if (Test-Path "language") { Copy-Item "language" -Destination "temp_package" -Recurse -Force }
if (Test-Path "plugins") { Copy-Item "plugins" -Destination "temp_package" -Recurse -Force }

New-ZipWithForwardSlashes -SourcePath (Resolve-Path "temp_package").Path -DestinationPath $packageName
Remove-Item "temp_package" -Recurse -Force

# Clean up intermediate files
Write-Host "Cleaning up intermediate files..." -ForegroundColor Blue
Remove-Item "com_$ProjectName.zip", "plg_$ProjectName.zip" -Force -ErrorAction SilentlyContinue

Write-Host "Package created successfully: $packageName" -ForegroundColor Green
Write-Host "Ready for installation in Joomla!" -ForegroundColor Cyan

# Show file size
if (Test-Path $packageName) {
    $fileSize = [math]::Round((Get-Item $packageName).Length / 1KB, 2)
    Write-Host "Package size: $fileSize KB" -ForegroundColor Yellow
}
