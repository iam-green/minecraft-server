@echo off
if not exist "server.ps1" (
  powershell Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Past2l/minecraft-server/main/server.ps1" -OutFile "server.ps1"
)
PowerShell.exe -ExecutionPolicy RemoteSigned -File .\server.ps1 %*
pause