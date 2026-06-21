@echo off
setlocal

rem This script now lives at the repo root, so REPO_ROOT is its own folder.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%.") do set "REPO_ROOT=%%~fI"

set "PORT="
for /f %%P in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0); $listener.Start(); $port=$listener.LocalEndpoint.Port; $listener.Stop(); $port"') do set "PORT=%%P"
if not defined PORT set "PORT=8767"

set "PAGE=/docs/%%E7%%BE%%8E%%E6%%9C%%AF%%E7%%B4%%A0%%E6%%9D%%90%%E5%%88%%B6%%E4%%BD%%9C%%E6%%8E%%A2%%E7%%B4%%A2/%%E4%%B8%%89%%E7%%AE%%A1%%E7%%BA%%BF%%E5%%AE%%8C%%E6%%95%%B4%%E6%%B5%%81%%E7%%A8%%8B%%E5%%9B%%BE.html"
set "URL=http://127.0.0.1:%PORT%%PAGE%"

echo Repo root: %REPO_ROOT%
echo URL: %URL%
echo.
echo Starting local web server. Close the server window to stop it.

start "InkMon art pipeline web server" /D "%REPO_ROOT%" cmd /k "python -m http.server %PORT% --bind 127.0.0.1"
timeout /t 1 /nobreak >nul
start "" "%URL%"

endlocal
