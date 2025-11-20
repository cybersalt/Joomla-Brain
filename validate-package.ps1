# Generic Joomla 5 Package Validation Script
# Run this before building to catch common issues
# Run from parent repo: .\shared\validate-package.ps1

param(
    [string]$ProjectName = ""
)

# Detect parent repo directory
$submoduleDir = $PSScriptRoot
$parentDir = Split-Path $submoduleDir -Parent
Set-Location $parentDir

Write-Host "Validating Joomla 5 Package Structure..." -ForegroundColor Cyan

# Auto-detect project name from package manifest
if (-not $ProjectName) {
    $pkgManifest = Get-ChildItem -Path $parentDir -Filter "pkg_*.xml" | Select-Object -First 1
    if ($pkgManifest) {
        $ProjectName = $pkgManifest.BaseName -replace '^pkg_', ''
    } else {
        Write-Host "ERROR: No pkg_*.xml found. Please specify -ProjectName parameter." -ForegroundColor Red
        exit 1
    }
}

$errors = @()
$warnings = @()

# Check 1: Package Manifest Schema Version
$pkgManifestPath = "pkg_$ProjectName.xml"
if (Test-Path $pkgManifestPath) {
    $content = Get-Content $pkgManifestPath -Raw
    if ($content -match 'version="3\.0"') {
        $errors += "Package manifest uses version='3.0' - should be '5.0' for Joomla 5"
    }
    if ($content -match 'targetplatformversion=') {
        $errors += "Package manifest has deprecated 'targetplatformversion' attribute"
    }
    if ($content -match '<files>\s*</files>') {
        $errors += "Package manifest has empty <files> section - this can cause uninstall issues"
    }
    # Check for script.php reference
    if ($content -match '<scriptfile>script\.php</scriptfile>') {
        if (!(Test-Path "script.php")) {
            $errors += "Package manifest references script.php but file is missing"
        }
    }
} else {
    $errors += "Package manifest not found: $pkgManifestPath"
}

# Check 2: Component Manifest
$componentManifestPath = "component\com_$ProjectName.xml"
if (Test-Path $componentManifestPath) {
    $content = Get-Content $componentManifestPath -Raw
    if ($content -match 'version="3\.0"') {
        $errors += "Component manifest uses version='3.0' - should be '5.0' for Joomla 5"
    }
    if ($content -notmatch '<element>') {
        $warnings += "Component manifest missing <element> tag - recommended for Joomla 5"
    }

    # Check media folder paths
    if ($content -match '<media folder="media"') {
        $warnings += "Component manifest references 'media' folder - verify this matches ZIP structure"
    }
}

# Check 3: Required Component Files
if (Test-Path "component") {
    $requiredSiteFiles = @("com_$ProjectName.php", "index.html")
    foreach ($file in $requiredSiteFiles) {
        if (!(Test-Path "component\$file")) {
            $errors += "Missing required site file: component\$file"
        }
    }
}

# Check 4: Plugin Manifest
$pluginManifestPath = "plugins\system\$ProjectName\$ProjectName.xml"
if (Test-Path $pluginManifestPath) {
    try {
        [xml]$pluginXml = Get-Content $pluginManifestPath
    } catch {
        $errors += "Plugin manifest XML is invalid: $($_.Exception.Message)"
    }
}

# Check 5: File Encoding (BOM check)
$phpFiles = Get-ChildItem -Path $parentDir -Filter "*.php" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch 'temp_|\.git' }
foreach ($file in $phpFiles) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        if ($bytes.Length -ge 3) {
            if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                $relativePath = $file.FullName.Substring($parentDir.Length + 1)
                $errors += "File $relativePath has UTF-8 BOM - remove it to prevent output issues"
            }
            if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
                $relativePath = $file.FullName.Substring($parentDir.Length + 1)
                $errors += "File $relativePath is UTF-16 encoded - convert to UTF-8"
            }
        }
    } catch {
        # Skip files that can't be read
    }
}

# Display Results
if ($errors.Count -gt 0) {
    Write-Host "`nERRORS FOUND:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  X $error" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "`nWARNINGS:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  ! $warning" -ForegroundColor Yellow
    }
}

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "`nPackage structure looks good!" -ForegroundColor Green
} elseif ($errors.Count -eq 0) {
    Write-Host "`nNo critical errors found (warnings can usually be ignored)" -ForegroundColor Green
} else {
    Write-Host "`nFix errors before building package" -ForegroundColor Red
    exit 1
}
