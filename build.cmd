@echo off
setlocal
pushd "%~dp0"
dotnet tool restore ^
  && dotnet pwsh -NoProfile build.ps1 -NoToolRestore
popd & exit /b %ERRORLEVEL%
