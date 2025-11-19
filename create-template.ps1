# Create template script (shared)
# Joomla 5 Component Manifest Template
# Copy this template for new components and customize as needed

@"
<?xml version='1.0' encoding='utf-8'?>
<extension type="component" version="5.0" method="upgrade">
	<name>COM_YOURCOMPONENT</name>
	<element>com_yourcomponent</element>
	<creationDate>$(Get-Date -Format 'yyyy-MM-dd')</creationDate>
	<author>Your Name</author>
	<authorEmail>you@example.com</authorEmail>
	<authorUrl>https://example.com</authorUrl>
	<copyright>Copyright (C) $(Get-Date -Format 'yyyy') Your Name. All Rights Reserved.</copyright>
	<version>1.0.0</version>
	<license>GNU/GPL</license>
    
	<!-- Site files (frontend) -->
	<files>
		<filename>com_yourcomponent.php</filename>
		<filename>index.html</filename>
	</files>
    
	<!-- Admin files (backend) -->
	<administration>
		<menu>COM_YOURCOMPONENT_MENU</menu>
		<files folder="admin">
			<filename>yourcomponent.php</filename>
			<filename>controller.php</filename>
			<filename>config.xml</filename>
			<filename>access.xml</filename>
			<folder>classes</folder>
			<folder>views</folder>
		</files>
		<languages folder="admin">
			<language tag="en-GB">language/en-GB/en-GB.com_yourcomponent.ini</language>
			<language tag="en-GB">language/en-GB/en-GB.com_yourcomponent.sys.ini</language>
		</languages>
	</administration>
    
	<!-- Media files (CSS/JS/Images) -->
	<media folder="admin/media" destination="com_yourcomponent">
		<folder>com_yourcomponent</folder>
	</media>
    
	<!-- Update server -->
	<updateservers>
		<server type="extension" priority="1" name="YourComponent Update Server">https://example.com/updates/check.php</server>
	</updateservers>
</extension>
"@ | Out-File -FilePath "joomla5-component-template.xml" -Encoding UTF8

Write-Host "Created Joomla 5 component manifest template: joomla5-component-template.xml" -ForegroundColor Green
