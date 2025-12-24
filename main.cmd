@echo off
title Patch_logs
setlocal

set "TB1=%~dp0table1_history/main_1_history.ps1"
set "TB3=%~dp0table3_Group_patch_computer\main_3_group_patch_computer.ps1"
start "" C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TB1%"
start "" C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TB3%"
timeout /t 5 /nobreak >nul
endlocal
