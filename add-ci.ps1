# Add the Brain's CI template to an extension repo
# Run from the extension repo: .\.joomla-brain\add-ci.ps1 (or wherever the Brain submodule is)
#
# Copies templates/.github/workflows/ci.yml and templates/tests/check.php into
# the repo. A file that is already there is never overwritten: compare it with
# the template by hand.

param(
    # The extension repo. Defaults to the folder the Brain submodule sits in.
    [string]$RepoDir = (Split-Path $PSScriptRoot -Parent)
)

$templates = Join-Path $PSScriptRoot "templates"
$copies = @(
    @{ From = ".github\workflows\ci.yml"; To = ".github\workflows\ci.yml" },
    @{ From = "tests\check.php";          To = "tests\check.php" }
)

Write-Host "Adding the CI template to $RepoDir" -ForegroundColor Green

foreach ($c in $copies) {
    $from = Join-Path $templates $c.From
    $to   = Join-Path $RepoDir $c.To
    if (Test-Path $to) {
        Write-Host "  kept     $($c.To) (already there; compare with templates\$($c.From))" -ForegroundColor Yellow
        continue
    }
    New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
    Copy-Item $from $to
    Write-Host "  added    $($c.To)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Next:" -ForegroundColor Green
Write-Host "  1. ci.yml: set the PHP versions in the matrix (manifest floor to newest supported)."
Write-Host "  2. tests/check.php: set `$sameVersion and `$skipLanguageFiles if the repo needs them."
Write-Host "  3. Run php tests/check.php and fix what it reports, then commit both files."
