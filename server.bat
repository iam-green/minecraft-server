@echo off
PowerShell.exe -ExecutionPolicy RemoteSigned -File .\server.ps1 %*
pause