#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef SourceDir
  #error SourceDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef Architecture
  #error Architecture is required
#endif

[Setup]
AppId={{4D72451E-C7B8-4C05-B8E0-EB75372ED219}
AppName=Void Journal
AppVersion={#AppVersion}
AppPublisher=Void Journal
AppPublisherURL=https://github.com/PatrikTrefil/void-journal
AppSupportURL=https://github.com/PatrikTrefil/void-journal/issues
AppUpdatesURL=https://github.com/PatrikTrefil/void-journal/releases
DefaultDirName={localappdata}\Programs\Void Journal
DefaultGroupName=Void Journal
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
MinVersion=10.0.19045
#if Architecture == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible and not arm64
ArchitecturesInstallIn64BitMode=x64compatible
#endif
OutputDir={#OutputDir}
OutputBaseFilename=Void-Journal-v{#AppVersion}-Windows-{#Architecture}-Setup
SetupIconFile=..\VoidJournal\AppIcon.ico
UninstallDisplayIcon={app}\VoidJournal.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Void Journal"; Filename: "{app}\VoidJournal.exe"
Name: "{autodesktop}\Void Journal"; Filename: "{app}\VoidJournal.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\VoidJournal.exe"; Description: "Open Void Journal"; Flags: nowait postinstall skipifsilent
