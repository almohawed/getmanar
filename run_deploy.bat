@echo off
powershell -ExecutionPolicy Bypass -File deploy_v2.ps1
if %errorlevel% neq 0 echo Error in powershell script
