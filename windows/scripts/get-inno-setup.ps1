$ErrorActionPreference = 'Stop'
$toolRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'build/tools/inno-6.7.4'
$compiler = Join-Path $toolRoot 'ISCC.exe'
if (Test-Path -LiteralPath $compiler) { return $compiler }
$download = Join-Path (Split-Path $toolRoot -Parent) 'innosetup-6.7.4.exe'
New-Item -ItemType Directory -Force (Split-Path $download -Parent) | Out-Null
# SHA-256 from the official immutable GitHub release asset.
$expected = 'a549929319f9120716677c685535ca4671e4b937b5fdc87e2585f32d8eb30e8c'
if (!(Test-Path -LiteralPath $download) -or (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    try {
        Invoke-WebRequest -Uri 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_4/innosetup-6.7.4.exe' `
            -OutFile $download -MaximumRetryCount 2 -RetryIntervalSec 2
    }
    catch {
        # The API reaches the identical immutable asset when the regular CDN route is unavailable.
        Invoke-WebRequest -Uri 'https://api.github.com/repos/jrsoftware/issrc/releases/assets/686086859' `
            -Headers @{ Accept = 'application/octet-stream' } -OutFile $download
    }
}
if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Inno Setup download failed SHA-256 verification'
}
# Install the compiler only into ignored build output, without shortcuts or file associations.
$process = Start-Process -FilePath $download -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER',
    "/DIR=`"$toolRoot`"", '/NOICONS', '/TASKS='
)
if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $compiler)) { throw 'Could not prepare Inno Setup compiler' }
return $compiler
