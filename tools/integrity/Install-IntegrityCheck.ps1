<#
.SYNOPSIS
    Copies the integrity check PHP classes into an extension under its own
    namespace, and adds the CS_INTEGRITY_* strings to its language files.

.DESCRIPTION
    Each extension gets its own copy (in its own namespace) so two Cybersalt
    extensions on one site never fight over one class. Re-run it after the
    Brain copy changes; it overwrites the extension's copy.

.PARAMETER Destination
    Folder to put the PHP files in, e.g. packages\com_example\admin\src\Integrity.

.PARAMETER Namespace
    PHP namespace that folder maps to, e.g. Cybersalt\Component\Example\Administrator\Integrity.

.PARAMETER WithField
    Also copy IntegrityField.php (for a settings page). Point the fieldset's
    addfieldprefix at the same namespace.

.PARAMETER LanguageIni
    The extension's en-GB .ini file(s) to receive the CS_INTEGRITY_* strings.
    Keys already present are left alone.

.EXAMPLE
    & "$brain\tools\integrity\Install-IntegrityCheck.ps1" `
        -Destination packages\com_example\admin\src\Integrity `
        -Namespace 'Cybersalt\Component\Example\Administrator\Integrity' `
        -LanguageIni packages\com_example\admin\language\en-GB\com_example.ini
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,
    [Parameter(Mandatory = $true)]
    [string]$Namespace,
    [switch]$WithField,
    [string[]]$LanguageIni = @()
)

$ErrorActionPreference = 'Stop'

if ($Namespace -notmatch '^[A-Za-z_][A-Za-z0-9_]*(\\[A-Za-z_][A-Za-z0-9_]*)*$') {
    throw "Not a PHP namespace: $Namespace"
}

$here  = $PSScriptRoot
$utf8  = New-Object System.Text.UTF8Encoding($false)
$files = @('IntegrityCheck.php')
if ($WithField) { $files += 'IntegrityField.php' }

$Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

foreach ($name in $files) {
    $text = [IO.File]::ReadAllText((Join-Path $here "php\$name"), $utf8)
    $text = $text.Replace('__INTEGRITY_NAMESPACE__', $Namespace)
    [IO.File]::WriteAllText((Join-Path $Destination $name), $text, $utf8)
    Write-Host "  $name -> $Destination" -ForegroundColor Gray
}

$strings = [IO.File]::ReadAllLines((Join-Path $here 'integrity.en-GB.ini'), $utf8) |
    Where-Object { $_ -match '^CS_INTEGRITY_[A-Z_]+=' }

foreach ($ini in $LanguageIni) {
    $existing = [IO.File]::ReadAllText((Resolve-Path $ini).Path, $utf8)
    $missing  = @($strings | Where-Object {
        $key = $_.Split('=')[0]
        $existing -notmatch "(?m)^$key="
    })

    if ($missing.Count -eq 0) {
        Write-Host "  $ini already has the strings" -ForegroundColor Gray
        continue
    }

    $nl    = if ($existing.Contains("`r`n")) { "`r`n" } else { "`n" }
    $block = "$nl; Shipped-file integrity check (Joomla-Brain tools/integrity)$nl" + ($missing -join $nl) + $nl
    [IO.File]::WriteAllText((Resolve-Path $ini).Path, $existing.TrimEnd("`r", "`n") + $nl + $block, $utf8)
    Write-Host "  added $($missing.Count) strings to $ini" -ForegroundColor Gray
}
