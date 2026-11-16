Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PubspecVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $match = [regex]::Match(
        $Content,
        '(?m)^\s*version:\s*(?<name>\d+(?:\.\d+){2})\+(?<code>\d+)\s*$'
    )
    if (!$match.Success) {
        throw "$Source must define a semantic version and Android versionCode"
    }

    return [pscustomobject]@{
        Name = $match.Groups['name'].Value
        Code = [long]$match.Groups['code'].Value
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
$version = Get-PubspecVersion -Content $pubspec -Source 'pubspec.yaml'

$baselinePath = Join-Path $PSScriptRoot 'release_baseline.json'
$baseline = Get-Content -Raw -Encoding UTF8 $baselinePath | ConvertFrom-Json
$deliveredVersionCode = [long]$baseline.lastDelivered.versionCode
if ($version.Code -lt $deliveredVersionCode) {
    throw "versionCode $($version.Code) is below the delivered baseline $deliveredVersionCode"
}

$commitObject = (& git -C $repoRoot cat-file -p HEAD 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the current Git commit object: $commitObject"
}
$commitHeaderMatch = [regex]::Match(
    $commitObject,
    '\A(?<headers>.*?)(?:\r?\n){2}',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (!$commitHeaderMatch.Success) {
    throw 'The current Git commit object has no valid header section'
}
$parentHashes = @(
    foreach ($parentMatch in [regex]::Matches(
        $commitHeaderMatch.Groups['headers'].Value,
        '(?m)^parent (?<hash>[0-9a-fA-F]{40,64})\r?$'
    )) {
        $parentMatch.Groups['hash'].Value
    }
)
foreach ($parentHash in $parentHashes) {
    $parentPubspecPath = (& git -C $repoRoot ls-tree --name-only $parentHash -- pubspec.yaml 2>&1 |
            Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect parent commit $parentHash for pubspec.yaml: $parentPubspecPath"
    }
    if (!$parentPubspecPath) {
        continue
    }

    $parentPubspec = (& git -C $repoRoot show "${parentHash}:pubspec.yaml" 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read pubspec.yaml from parent commit ${parentHash}: $parentPubspec"
    }
    $parentVersion = Get-PubspecVersion -Content $parentPubspec -Source "pubspec.yaml at parent $parentHash"
    if ($version.Code -lt $parentVersion.Code) {
        throw "versionCode $($version.Code) is below parent $parentHash versionCode $($parentVersion.Code)"
    }
}

$versionName = $version.Name
$versionCode = $version.Code.ToString()
$commitHash = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to resolve the current Git commit'
}
$buildTime = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

@{
    'pili.name' = $versionName
    'pili.code' = $versionCode
    'pili.hash' = $commitHash
    'pili.time' = $buildTime
} | ConvertTo-Json -Compress | Set-Content -Encoding UTF8 (Join-Path $repoRoot 'pili_release.json')

if ($env:GITHUB_ENV) {
    Add-Content -Path $env:GITHUB_ENV -Value "version=$versionName+$versionCode"
}
