# Convert files from UTF-16 to UTF-8 (no BOM)
# Run from parent repo: .\shared\convert-utf8.ps1 -FilePath "path\to\file.php"

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

# Detect parent repo directory
$submoduleDir = $PSScriptRoot
$parentDir = Split-Path $submoduleDir -Parent
Set-Location $parentDir

if (!(Test-Path $FilePath)) {
    Write-Host "ERROR: File not found: $FilePath" -ForegroundColor Red
    exit 1
}

Write-Host "Converting $FilePath to UTF-8 (no BOM)..." -ForegroundColor Yellow

# Check current encoding
$bytes = [System.IO.File]::ReadAllBytes($FilePath)
$isUtf16 = ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)
$hasUtf8Bom = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

if ($isUtf16) {
    # Read as UTF-16 and convert
    $content = Get-Content -Path $FilePath -Encoding Unicode -Raw
} elseif ($hasUtf8Bom) {
    # Read as UTF-8 (will include BOM)
    $content = Get-Content -Path $FilePath -Encoding UTF8 -Raw
} else {
    Write-Host "File is already UTF-8 without BOM" -ForegroundColor Green
    exit 0
}

# Write back as UTF-8 without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBom)

Write-Host "Conversion complete!" -ForegroundColor Green

# Verify the conversion
$newBytes = [System.IO.File]::ReadAllBytes($FilePath)[0..10]
$hexBytes = ($newBytes | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host "First bytes: $hexBytes" -ForegroundColor Gray

if ($newBytes[0] -eq 0x3C -and $newBytes[1] -eq 0x3F) {
    Write-Host "File is now UTF-8 encoded correctly!" -ForegroundColor Green
} else {
    Write-Host "Warning: File may not start with <?php" -ForegroundColor Yellow
}
