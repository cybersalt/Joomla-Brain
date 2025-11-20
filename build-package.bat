
@echo off
REM Shared build script for Joomla packages. Context-aware for parent repo.
REM Usage: Run from parent repo root.
REM See PACKAGE-BUILD-NOTES.md for details.

REM Detect parent repo directory
setlocal
set "SUBMODULE_DIR=%~dp0"
set "PARENT_DIR=%SUBMODULE_DIR:~0,-7%"
cd /d "%PARENT_DIR%"

REM Call the PowerShell build script which has proper folder structure handling
powershell -ExecutionPolicy Bypass -File "%SUBMODULE_DIR%build-package.ps1"

endlocal
