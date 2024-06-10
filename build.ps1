#Requires -PSEdition Core

[CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'Build')]
param(
    [Parameter(ParameterSetName = 'Build')]
    [Parameter(ParameterSetName = 'Test')]
    [string[]]$Configuration = @('Debug', 'Release'),
    [switch]$NoToolRestore,
    [Parameter(ParameterSetName = 'Test', Mandatory = $true)]
    [switch]$Test,
    [Parameter(ParameterSetName = 'Pack', Mandatory = $true)]
    [switch]$Pack,
    [Parameter(ParameterSetName = 'Pack')]
    [string]$VersionSuffix,
    [Parameter(ParameterSetName = 'Pack')]
    [switch]$CI,
    [Parameter(ParameterSetName = 'Pack')]
    [switch]$NoValidation
)

$ErrorActionPreference = 'Stop'

function Invoke-Build
{
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Configuration
    )

    dotnet restore
    if (!$?) {
        throw "Restore failed (exit code = $LASTEXITCODE)."
    }

    $configuration |
    % {
        Write-Verbose "Building configuration: $_"
        dotnet build --no-restore -c $_
        if (!$?) {
            throw "Build failed (exit code = $LASTEXITCODE)."
        }
    }
}

function Build
{
    Invoke-Build $configuration
}

function Test
{
    Build

    $Configuration |
    % {
        Write-Verbose "Testing configuration: $_"
        dotnet test --no-build -c $_ --settings tests/.runsettings
        if (!$?) {
            throw "Testing failed (exit code = $LASTEXITCODE)."
        }
    }

    $testResultsPath = Join-Path tests TestResults

    Write-Verbose "Generating coverage report."
    dotnet reportgenerator -reporttypes:TextSummary `
        "-reports:$(Join-Path $testResultsPath '*' 'coverage.cobertura.xml')" `
        "-targetdir:${testResultsPath}"
    if (!$?) {
        throw "Coverage report generation failed (exit code = $LASTEXITCODE)."
    }

    Get-Content (Join-Path $testResultsPath 'Summary.txt')
}

function Pack
{
    Invoke-Build 'Release'

    if (!$versionSuffix -and ($ci -or $env:CI -eq 'true'))
    {
        [datetimeoffset]$commitTime = git show -q --pretty=%cI
        $versionSuffix = "ci-$($commitTime.ToUniversalTime().ToString('yyyyMMdd''t''HHmm'))"
    }

    [string[]]$argv = @()
    if ($versionSuffix)
    {
        $argv += '--version-suffix'
        $argv += $VersionSuffix
    }

    dotnet pack --no-build @argv

    if (!$?) {
        throw "Packing failed (exit code = $LASTEXITCODE)."
    }

    if (-not $noValidation)
    {
        $info = `
            dotnet msbuild src -getProperty:VersionPrefix -getProperty:PackageId |
            ConvertFrom-Json

        if (!$?) {
            throw "Build query failed (exit code = $LASTEXITCODE)."
        }

        $versionPrefix = $info.Properties.VersionPrefix
        $packageId = $info.Properties.PackageId
        $packageVersion = if ($versionSuffix) { "$versionPrefix-$versionSuffix" } else { $versionPrefix }
        $nupkgPath = Join-Path dist "$packageId.$packageVersion.nupkg"

        dotnet meziantou.validate-nuget-package $nupkgPath `
            --excluded-rules XmlDocumentationMustBePresent `
            --excluded-rules IconMustBeSet

        if (!$?) {
            throw "Package validation failed (exit code = $LASTEXITCODE)."
        }
    }
}

if (-not $noToolRestore)
{
    dotnet tool restore
    if (!$?) {
        throw "Restoring tools failed (exit code = $LASTEXITCODE)."
    }
}

Push-Location $PSScriptRoot

try
{
    if (-not $noToolRestore)
    {
        dotnet tool restore
        if (!$?) {
            throw "Restoring tools failed (exit code = $LASTEXITCODE)."
        }
    }

    & $PSCmdlet.ParameterSetName
}
finally
{
    Pop-Location
}
