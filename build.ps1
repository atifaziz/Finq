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
    [switch]$NoValidation,
    [Parameter(ParameterSetName = 'Release', Mandatory = $true, Position = 0)]
    [switch]$Release,
    [Parameter(ParameterSetName = 'Release', Mandatory = $true, Position = 1)]
    [string]$CommitId,
    [Parameter(ParameterSetName = 'Release')]
    [string]$Label,
    [Parameter(ParameterSetName = 'Release')]
    [string]$Tag,
    [Parameter(ParameterSetName = 'Release')]
    [string]$DestinationPath = '.'
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

    [string[]]$argv = if ($versionSuffix) { @('--version-suffix', $versionSuffix) }

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

function Release
{
    [version]$ghVersion = `
        gh --version |
        # Example version string: gh version 2.50.0 (2024-05-29)
        ? { $_ -match '(?<=gh +version +)[0-9]+(\.[0-9]+){2}\b' } |
        % { $Matches[0] }
    if (!$?) {
        throw "GitHub CLI not found or is incompatible."
    }

    if ($ghVersion.Major -ne 2) {
        throw "Unsupported GitHub CLI version: $ghVersion"
    }

    $run = `
        gh run list -c $commitId -s completed -w build --json 'databaseId,number,displayTitle,conclusion' |
        Select-Object -First 1 |
        ConvertFrom-Json
    if (!$?) {
        throw "Listing GitHub workflow runs failed (exit code = $LASTEXITCODE)."
    }

    if ($run.conclusion -ne 'success') {
        throw "Latest run (#$($run.number)) for commit $commitId did not succeed."
    }

    $runId = $run.databaseId
    Write-Verbose "Downloading artifacts from run #$($runId)"

    $runPath = Join-Path .temp gh runs $runId
    gh run download -D $runPath -n nuget $runId
    if (!$?) {
        throw "Downloading artifacts (for $($runId)) failed (exit code = $LASTEXITCODE)."
    }

    [array]$runNupkgs = Get-ChildItem (Join-Path $runPath *.nupkg)

    if ($runNupkgs.Count -ne 1) {
        throw "Expected a single nupkg file but found $($runNupkgs.Count)."
    }

    $nupkgPath = $runNupkgs[0]

    [string[]]$argv = if ($label) { @('--label', $label) }

    $argv += $nupkgPath
    dotnet nupkgwrench release @argv
    if (!$?) {
        throw "Releasing package failed (exit code = $LASTEXITCODE)."
    }

    [string]$nupkgPath = `
        Get-ChildItem (Join-Path $runPath *.nupkg) |
        Select-Object -ExpandProperty FullName

    [xml]$nuspec = dotnet nupkgwrench nuspec show $nupkgPath
    if (!$?) {
        throw "Querying package metadata failed (exit code = $LASTEXITCODE)."
    }

    $repoUrl = [uri]$nuspec.package.metadata.repository.url

    if (!$package.metadata.releaseNotes)
    {
        if (!$tag)
        {
            $pkgVersion = dotnet nupkgwrench version $nupkgPath
            if (!$?) {
                throw "Querying package version failed (exit code = $LASTEXITCODE)."
            }

            $tag = "v$pkgVersion"
            Write-Warning "No tag specified. Assuming: $tag"
        }

        if ($repoUrl.Host -eq 'github.com')
        {
            dotnet nupkgwrench nuspec edit `
                --property ReleaseNotes --value "https://github.com/atifaziz/Finq/releases/$tag" `
                $nupkgPath
            if (!$?) {
                throw "Editing package failed (exit code = $LASTEXITCODE)."
            }
        }
        else
        {
            Write-Warning "Release notes not set. Unsupported repository URL: $repoUrl"
        }
    }
    elseif ($tag)
    {
        Write-Warning "Release notes already set! Ignoring tag: $tag"
    }

    Move-Item $nupkgPath $destinationPath

    dotnet nupkgwrench nuspec show (Join-Path $destinationPath (Split-Path $nupkgPath -Leaf))
    if (!$?) {
        throw "Showing package failed (exit code = $LASTEXITCODE)."
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
