@echo off
title WorkLife App Launcher
cd /d "%~dp0"

set "AUTOIT3="

rem 1) Detect AutoIt3 install dir from registry (no hardcoded drive path)
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\AutoIt v3\AutoIt" /v InstallDir 2^>nul') do set "AUTOIT3=%%b\AutoIt3.exe"
if not exist "%AUTOIT3%" for /f "skip=2 tokens=2*" %%a in ('reg query "HKCU\SOFTWARE\AutoIt v3\AutoIt" /v InstallDir 2^>nul') do set "AUTOIT3=%%b\AutoIt3.exe"

rem 2) Fall back to PATH
if not exist "%AUTOIT3%" set "AUTOIT3=AutoIt3.exe"
if not exist "%AUTOIT3%" set "AUTOIT3="

if "%AUTOIT3%"=="" (
    echo [ERROR] AutoIt3.exe not found.
    echo Please install AutoIt3 or add it to PATH, then run this launcher again.
    pause
    exit /b 1
)

echo Launching WorkLife App ...
"%AUTOIT3%" "%~dp0WorkLifeApp.au3"
echo.
echo App exited. Press any key to close this window.
pause
