param(
    [Parameter(Mandatory = $true)][string]$Tag,
    [ValidateSet('win-x64', 'win-arm64')][string]$Runtime = 'win-x64',
    [switch]$Installer
)
$ErrorActionPreference = 'Stop'
if ($Tag -notmatch '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
    throw 'Expected a release tag such as v1.0.0'
}
$platformRoot = Split-Path $PSScriptRoot -Parent
$output = Join-Path $platformRoot "build/$Tag/$Runtime"
$archive = Join-Path $platformRoot "build/Void-Journal-$Tag-Windows-$($Runtime.Substring(4)).zip"
# Include the runtime so users do not need a separate .NET installation.
dotnet publish (Join-Path $platformRoot 'VoidJournal/VoidJournal.csproj') `
    --configuration Release --runtime $Runtime --self-contained true -m:1 -p:BuildInParallel=false `
    -p:Version=$($Tag.Substring(1)) -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false `
    --output $output
if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed' }
Copy-Item -LiteralPath (Join-Path $platformRoot 'INSTALL.txt') -Destination $output
Compress-Archive -Path (Join-Path $output '*') -DestinationPath $archive -Force
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path $archive -Leaf)" | Set-Content -LiteralPath "$archive.sha256" -Encoding ascii
Write-Output "Packaged $archive"
if ($Installer) {
    $compiler = & (Join-Path $PSScriptRoot 'get-inno-setup.ps1')
    & $compiler "/DAppVersion=$($Tag.Substring(1))" "/DArchitecture=$($Runtime.Substring(4))" `
        "/DSourceDir=$output" "/DOutputDir=$(Join-Path $platformRoot 'build')" `
        (Join-Path $platformRoot 'installer/VoidJournal.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Windows installer compilation failed' }
    $setup = Join-Path $platformRoot "build/Void-Journal-$Tag-Windows-$($Runtime.Substring(4))-Setup.exe"
    $setupHash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
    "$setupHash  $(Split-Path $setup -Leaf)" | Set-Content -LiteralPath "$setup.sha256" -Encoding ascii
    Write-Output "Packaged $setup"
}
