# Build simple script (shared)
# Simple StageIt Package Builder - Uses built-in compression
Write-Host "Building StageIt Package (Simple)..." -ForegroundColor Green

$version = "6.0.0"
$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$packageName = "pkg_stageit_SIMPLE_v${version}_${timestamp}.zip"

# Clean up
Remove-Item "com_stageit_simple.zip", "plg_stageit_simple.zip" -ErrorAction SilentlyContinue
Remove-Item "pkg_stageit_SIMPLE_v*.zip" -ErrorAction SilentlyContinue

# Create component zip with proper Joomla structure
Write-Host "Creating component package..." -ForegroundColor Blue
if (Test-Path "temp_comp") { Remove-Item "temp_comp" -Recurse -Force }
New-Item -ItemType Directory -Path "temp_comp" -Force | Out-Null

# Copy manifest to root of component package
Copy-Item "component\com_stageit.xml" -Destination "temp_comp\com_stageit.xml" -Force

# Copy site files (frontend) to root
$siteFiles = @("com_stageit.php", "com_stageit", "index.html")
foreach ($file in $siteFiles) {
	if (Test-Path "component\$file") {
		Copy-Item "component\$file" -Destination "temp_comp\$file" -Recurse -Force
	}
}

# Create admin folder and copy admin files (excluding manifest and site files)
New-Item -ItemType Directory -Path "temp_comp\admin" -Force | Out-Null
$excludeItems = @("com_stageit.xml") + $siteFiles
Get-ChildItem "component" -Exclude $excludeItems | ForEach-Object {
	if ($_.PSIsContainer) {
		Copy-Item $_.FullName -Destination "temp_comp\admin" -Recurse -Force
	} else {
		Copy-Item $_.FullName -Destination "temp_comp\admin" -Force
	}
}

Compress-Archive -Path "temp_comp\*" -DestinationPath "com_stageit_simple.zip" -Force
Remove-Item "temp_comp" -Recurse -Force

# Create plugin zip
Write-Host "Creating plugin package..." -ForegroundColor Blue
if (Test-Path "temp_plugin") { Remove-Item "temp_plugin" -Recurse -Force }
New-Item -ItemType Directory -Path "temp_plugin" -Force | Out-Null
Copy-Item "plugins\system\stageit\stageit.php" -Destination "temp_plugin\stageit.php" -Force
Copy-Item "plugins\system\stageit\stageit.xml" -Destination "temp_plugin\stageit.xml" -Force
Compress-Archive -Path "temp_plugin\*" -DestinationPath "plg_stageit_simple.zip" -Force
Remove-Item "temp_plugin" -Recurse -Force

# Create final package
Write-Host "Creating final package: $packageName" -ForegroundColor Blue
if (Test-Path "temp_pkg") { Remove-Item "temp_pkg" -Recurse -Force }
New-Item -ItemType Directory -Path "temp_pkg" -Force | Out-Null
Copy-Item "pkg_stageit.xml", "script.php", "com_stageit_simple.zip", "plg_stageit_simple.zip", "CHANGELOG.md" -Destination "temp_pkg" -Force
Copy-Item "language" -Destination "temp_pkg" -Recurse -Force

# Rename zips in package to standard names
Rename-Item "temp_pkg\com_stageit_simple.zip" "com_stageit.zip"
Rename-Item "temp_pkg\plg_stageit_simple.zip" "plg_stageit.zip"
