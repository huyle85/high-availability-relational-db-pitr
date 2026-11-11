@echo off
chcp 65001 >nul
title DEMO HE THONG CSDL HA & PITR - BANG DIEU KHIEN
cls

cd /d "%~dp0"

echo Dang khoi dong Bang Dieu Khien Demo...

:: Tim duong dan Git Bash
set "GIT_BASH="
if exist "C:\Program Files\Git\bin\bash.exe" set "GIT_BASH=C:\Program Files\Git\bin\bash.exe"
if not defined GIT_BASH if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "GIT_BASH=C:\Program Files (x86)\Git\bin\bash.exe"
if not defined GIT_BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "GIT_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"

if defined GIT_BASH (
    "%GIT_BASH%" --login -i -c "./menu.sh"
) else (
    bash ./menu.sh
)

pause
