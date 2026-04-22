@echo off
cd /d "%~dp0..\.."

:: Check if server already running
netstat -ano | findstr ":3456" >nul 2>&1
if %errorlevel%==0 (
  start "" "http://localhost:3456"
  exit /b
)

:: Start server in background (no visible window)
start /b node launcher\win\server.mjs

:: Poll until server is ready
:wait
timeout /t 1 >nul
curl -s http://localhost:3456/health >nul 2>&1
if %errorlevel% neq 0 goto wait

:: Open browser
start "" "http://localhost:3456"
