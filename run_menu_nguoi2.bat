@echo off
chcp 65001 >nul
title DEMO DE TAI 13: CSDL QUAN HE SAN SANG CAO (HA) & SAO LUU PHUC HOI PITR - NGUOI 2
cd /d "%~dp0"

set "BASH_PATH="
if exist "C:\Program Files\Git\bin\bash.exe" set "BASH_PATH=C:\Program Files\Git\bin\bash.exe"
if not defined BASH_PATH if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "BASH_PATH=C:\Program Files (x86)\Git\bin\bash.exe"
if not defined BASH_PATH (
  for /f "tokens=*" %%i in ('where bash.exe 2^>nul') do (
    if not defined BASH_PATH set "BASH_PATH=%%i"
  )
)

if not defined BASH_PATH (
  echo [LOI] Khong tim thay Git Bash!
  echo Vui long cai dat Git for Windows hoac chay menu.sh trong Git Bash.
  pause
  exit /b 1
)

"%BASH_PATH%" -l -c "cd '%cd:\=/%' && bash menu_nguoi2.sh"
pause
