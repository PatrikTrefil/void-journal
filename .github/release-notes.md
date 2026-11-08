## Install

Download the macOS universal ZIP, unzip it, and drag **Void Journal.app** to **Applications**.
Requires macOS 14 or later. The same app runs on Apple silicon and Intel Macs.

For Windows 10 22H2 or Windows 11, download **Windows-x64-Setup.exe** for Intel/AMD PCs
or **Windows-arm64-Setup.exe** for Windows on Arm. Setup installs for your user without
admin rights, adds a Start menu shortcut, and supports uninstalling from Windows Settings.
The optional desktop shortcut is unchecked by default.

For a portable copy, download the matching Windows ZIP, extract it, and open
**VoidJournal.exe**. Both options include the .NET runtime. The app and installer
are unsigned; Windows SmartScreen may warn on first launch.

The Mac build is ad hoc signed and is not notarized by Apple. macOS may block its first launch.
After trying to open it, go to **System Settings > Privacy & Security > Open Anyway**
if you trust this download.

The `.sha256` file lets you verify the download with `shasum -a 256 -c <filename>.zip.sha256`.
