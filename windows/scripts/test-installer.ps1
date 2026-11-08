param([Parameter(Mandatory = $true)][string]$InstallerPath)
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "VoidJournal-install-test-$([guid]::NewGuid().ToString('N'))"
$setup = Start-Process -FilePath (Resolve-Path -LiteralPath $InstallerPath).Path -WindowStyle Hidden -Wait -PassThru `
    -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOICONS', "/DIR=`"$testRoot`"")
if ($setup.ExitCode -ne 0 -or !(Test-Path -LiteralPath (Join-Path $testRoot 'VoidJournal.exe'))) {
    throw "Installer smoke test failed (exit $($setup.ExitCode))"
}
$uninstall = Start-Process -FilePath (Join-Path $testRoot 'unins000.exe') -WindowStyle Hidden -Wait -PassThru `
    -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
if ($uninstall.ExitCode -ne 0) { throw "Uninstaller failed (exit $($uninstall.ExitCode))" }
$deadline = [DateTime]::UtcNow.AddSeconds(20)
while ((Test-Path -LiteralPath (Join-Path $testRoot 'VoidJournal.exe')) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 100
}
if (Test-Path -LiteralPath (Join-Path $testRoot 'VoidJournal.exe')) { throw 'Uninstaller left the application installed' }
Write-Output 'Installer and uninstaller smoke tests passed.'
