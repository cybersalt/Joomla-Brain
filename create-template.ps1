# Joomla 5 Component Manifest Template Generator
# Run from parent repo: .\shared\create-template.ps1

param(
    [string]$ComponentName = "yourcomponent",
    [string]$AuthorName = "Your Name",
    [string]$AuthorEmail = "you@example.com",
    [string]$AuthorUrl = "https://example.com"
)

# Detect parent repo directory
$submoduleDir = $PSScriptRoot
$parentDir = Split-Path $submoduleDir -Parent
Set-Location $parentDir

$template = @"
<?xml version="1.0" encoding="utf-8"?>
<extension type="component" version="5.0" method="upgrade">
    <name>COM_$($ComponentName.ToUpper())</name>
    <element>com_$ComponentName</element>
    <creationDate>$(Get-Date -Format 'yyyy-MM-dd')</creationDate>
    <author>$AuthorName</author>
    <authorEmail>$AuthorEmail</authorEmail>
    <authorUrl>$AuthorUrl</authorUrl>
    <copyright>Copyright (C) $(Get-Date -Format 'yyyy') $AuthorName. All Rights Reserved.</copyright>
    <version>1.0.0</version>
    <license>GNU/GPL</license>

    <!-- Site files (frontend) -->
    <files>
        <filename>com_$ComponentName.php</filename>
        <filename>index.html</filename>
    </files>

    <!-- Admin files (backend) -->
    <administration>
        <menu>COM_$($ComponentName.ToUpper())_MENU</menu>
        <files folder="admin">
            <filename>$ComponentName.php</filename>
            <filename>controller.php</filename>
            <filename>config.xml</filename>
            <filename>access.xml</filename>
            <folder>classes</folder>
            <folder>views</folder>
        </files>
        <languages folder="admin">
            <language tag="en-GB">language/en-GB/en-GB.com_$ComponentName.ini</language>
            <language tag="en-GB">language/en-GB/en-GB.com_$ComponentName.sys.ini</language>
        </languages>
    </administration>

    <!-- Media files (CSS/JS/Images) -->
    <media folder="admin/media" destination="com_$ComponentName">
        <folder>com_$ComponentName</folder>
    </media>

    <!-- Update server -->
    <updateservers>
        <server type="extension" priority="1" name="$ComponentName Update Server">https://example.com/updates/check.php</server>
    </updateservers>
</extension>
"@

$outputFile = "joomla5-component-template.xml"
$template | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Created Joomla 5 component manifest template: $outputFile" -ForegroundColor Green
Write-Host "Customize the template and rename to com_$ComponentName.xml" -ForegroundColor Cyan
