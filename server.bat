@echo off
if not exist "server.ps1" (
  powershell curl.exe -sfSLo .\server.ps1 "https://raw.githubusercontent.com/iam-green/minecraft-server/main/server.ps1"
)
attrib +h .\server.ps1
PowerShell.exe -ExecutionPolicy RemoteSigned -File .\server.ps1 %*
