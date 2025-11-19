# StageIt Shared Package Builder Script
# This script automatically creates the complete StageIt installation package in the parent repo directory

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir = (Get-Item $scriptDir).Parent.FullName
Set-Location $repoDir

Write-Host "Building StageIt Package in repo: $repoDir" -ForegroundColor Green

# Run validation first
Write-Host "Running pre-build validation..." -ForegroundColor Blue
if (Test-Path "$repoDir\validate-package.ps1") {
	& "$repoDir\validate-package.ps1"
	if ($LASTEXITCODE -eq 1) {
		Write-Host "Build cancelled due to validation errors" -ForegroundColor Red
		exit 1
	}
}

# Auto-detect StageIt and Joomla version from pkg_stageit.xml
$pkgXml = [xml](Get-Content "$repoDir\pkg_stageit.xml")
$version = $pkgXml.SelectSingleNode("//extension/version").InnerText.Trim()
$joomlaVersion = $pkgXml.extension.targetplatform.version.Trim()
Write-Host "Detected StageIt version: $version" -ForegroundColor Yellow
Write-Host "Detected Joomla target version: $joomlaVersion" -ForegroundColor Yellow

# Clean up old build files
Write-Host "Cleaning old build files..." -ForegroundColor Blue
Remove-Item "$repoDir\com_stageit.zip", "$repoDir\plg_stageit.zip" -ErrorAction SilentlyContinue
Remove-Item "$repoDir\pkg_stageit_Joomla_5_v*.zip", "$repoDir\pkg_stageit_Joomla_6_v*.zip" -ErrorAction SilentlyContinue

# Create component zip with proper folder structure and forward slashes
Write-Host "Creating component package..." -ForegroundColor Blue

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

if (Test-Path "$repoDir\temp_component") { Remove-Item "$repoDir\temp_component" -Recurse -Force }
New-Item -ItemType Directory -Path "$repoDir\temp_component" -Force | Out-Null
Copy-Item "$repoDir\component\com_stageit.xml" -Destination "$repoDir\temp_component\com_stageit.xml" -Force
$siteFiles = @("com_stageit.php", "com_stageit", "index.html")
foreach ($file in $siteFiles) {
	if (Test-Path "$repoDir\component\$file") {
		Copy-Item "$repoDir\component\$file" -Destination "$repoDir\temp_component\$file" -Force
	}
}
New-Item -ItemType Directory -Path "$repoDir\temp_component\admin" -Force | Out-Null
$excludeItems = @("com_stageit.xml") + $siteFiles
Get-ChildItem "$repoDir\component" -Exclude $excludeItems | ForEach-Object {
	if ($_.PSIsContainer) {
		Copy-Item $_.FullName -Destination "$repoDir\temp_component\admin" -Recurse -Force
	} else {
		Copy-Item $_.FullName -Destination "$repoDir\temp_component\admin" -Force
	}
}
New-ZipWithForwardSlashes -SourcePath (Resolve-Path "$repoDir\temp_component").Path -DestinationPath "$repoDir\com_stageit.zip"
Remove-Item "$repoDir\temp_component" -Recurse -Force

Write-Host "Creating plugin package..." -ForegroundColor Blue
try {
	[xml]$pluginXml = Get-Content "$repoDir\plugins\system\stageit\stageit.xml"
	Write-Host "✅ Plugin XML is valid" -ForegroundColor Green
} catch {
	Write-Host "❌ Plugin XML is invalid: $($_.Exception.Message)" -ForegroundColor Red
	exit 1
}
if (Test-Path "$repoDir\temp_plugin") { Remove-Item "$repoDir\temp_plugin" -Recurse -Force }
New-Item -ItemType Directory -Path "$repoDir\temp_plugin" -Force | Out-Null
Copy-Item "$repoDir\plugins\system\stageit\stageit.php" -Destination "$repoDir\temp_plugin\stageit.php" -Force
Copy-Item "$repoDir\plugins\system\stageit\stageit.xml" -Destination "$repoDir\temp_plugin\stageit.xml" -Force
New-ZipWithForwardSlashes -SourcePath (Resolve-Path "$repoDir\temp_plugin").Path -DestinationPath "$repoDir\plg_stageit.zip"
Remove-Item "$repoDir\temp_plugin" -Recurse -Force

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
if ($joomlaVersion -like "6*") {
	$packageName = "$repoDir\pkg_stageit_Joomla_6_v${version}_${timestamp}.zip"
} else {
	$packageName = "$repoDir\pkg_stageit_Joomla_5_v${version}_${timestamp}.zip"
}
Write-Host "Creating final package: $packageName" -ForegroundColor Blue
if (Test-Path "$repoDir\temp_package") { Remove-Item "$repoDir\temp_package" -Recurse -Force }
New-Item -ItemType Directory -Path "$repoDir\temp_package" -Force | Out-Null
Copy-Item "$repoDir\pkg_stageit.xml", "$repoDir\script.php", "$repoDir\com_stageit.zip", "$repoDir\plg_stageit.zip", "$repoDir\CHANGELOG.md" -Destination "$repoDir\temp_package" -Force
Copy-Item "$repoDir\language", "$repoDir\plugins" -Destination "$repoDir\temp_package" -Recurse -Force
New-ZipWithForwardSlashes -SourcePath (Resolve-Path "$repoDir\temp_package").Path -DestinationPath $packageName
Remove-Item "$repoDir\temp_package" -Recurse -Force
Remove-Item "$repoDir\com_stageit.zip", "$repoDir\plg_stageit.zip" -Force
Write-Host "Package created successfully: $packageName" -ForegroundColor Green
Write-Host "Ready for installation in Joomla!" -ForegroundColor Cyan
if (Test-Path $packageName) {
	$fileSize = [math]::Round((Get-Item $packageName).Length / 1KB, 2)
	Write-Host "Package size: $fileSize KB" -ForegroundColor Yellow
}
