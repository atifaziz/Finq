#!/usr/bin/env sh
set -e
cd "$(dirname "$0")"
dotnet tool restore
dotnet pwsh -NoProfile build.ps1 -Test -NoToolRestore
