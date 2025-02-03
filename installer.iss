#define MyAppName "AI小说生成器"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "AI Novel Generator"
#define MyAppExeName "novel_app.exe"
#define MyAppSourceDir "D:\project\cuosor\novel_app\build\windows\x64\runner\Release"

[Setup]
AppId={{NOVEL-APP-GUID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir={#MyAppSourceDir}\..\installer
OutputBaseFilename=AI小说生成器安装程序
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch AI Novel Generator"; Flags: nowait postinstall skipifsilent 