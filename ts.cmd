@echo off
title Patch_logs
setlocal
REM --- ใช้ path ตามตำแหน่งไฟล์ .bat ---
REM --- เปิด 2 โปรเซสแยกหน้าต่าง ---
start "table1_history"   powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0table1_history\main_1_history.ps1"
echo.
timeout /t 5 /nobreak >nul
endlocal