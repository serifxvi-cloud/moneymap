@echo off
setlocal
cd /d "%~dp0"
echo.
echo  MoneyMap - No npm / no Node.js required
echo  ---------------------------------------
echo  This launcher uses Windows PowerShell, which is built into Windows.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0MoneyMap-Server.ps1"
echo.
echo MoneyMap has stopped. Press any key to close this window.
pause >nul
