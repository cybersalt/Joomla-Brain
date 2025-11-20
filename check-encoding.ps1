# Generic encoding checker for Joomla package files
# Run from parent repo: .\shared\check-encoding.ps1

# Detect parent repo directory
$submoduleDir = $PSScriptRoot
$parentDir = Split-Path $submoduleDir -Parent
Set-Location $parentDir

Write-Host "Checking file encodings..." -ForegroundColor Cyan

# Find all PHP files
$phpFiles = Get-ChildItem -Path $parentDir -Filter "*.php" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch 'temp_|\.git|shared' }

foreach ($file in $phpFiles) {
    $relativePath = $file.FullName.Substring($parentDir.Length + 1)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        if ($bytes.Length -lt 2) { continue }

        $hexBytes = ($bytes[0..10] | ForEach-Object { $_.ToString("X2") }) -join " "

        # Check for UTF-16 BOM (FF FE)
        if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            Write-Host "X UTF-16 ENCODING DETECTED: $relativePath" -ForegroundColor Red
            Write-Host "   First bytes: $hexBytes" -ForegroundColor Red
        }
        # Check for UTF-8 BOM (EF BB BF)
        elseif ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            Write-Host "! UTF-8 with BOM: $relativePath" -ForegroundColor Yellow
            Write-Host "   First bytes: $hexBytes" -ForegroundColor Yellow
        }
        # Check for proper PHP start (3C 3F = <?)
        elseif ($bytes[0] -eq 0x3C -and $bytes[1] -eq 0x3F) {
            Write-Host "OK UTF-8 (no BOM): $relativePath" -ForegroundColor Green
        }
        else {
            Write-Host "? UNKNOWN ENCODING: $relativePath" -ForegroundColor Yellow
            Write-Host "   First bytes: $hexBytes" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "! Could not read: $relativePath" -ForegroundColor Yellow
    }
}

Write-Host "`nEncoding check complete." -ForegroundColor Cyan
