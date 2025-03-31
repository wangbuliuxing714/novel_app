#define MyAppName "DaiZong Novel"
#define MyAppVersion "4.0.0"
#define MyAppPublisher "DaiZong Tech"
#define MyAppURL "https://www.example.com/"
#define MyAppExeName "novel_app.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{EFAD5F82-1234-4ABC-95D6-58A123456789}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputBaseFilename=DaiZongNovelSetup
OutputDir=D:\project\cuosor\novel_app\novel_app-1\installers
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
SetupIconFile=D:\project\cuosor\novel_app\novel_app-1\windows\runner\resources\app_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main executable file
Source: "D:\project\cuosor\novel_app\novel_app-1\build\windows\x64\runner\Release\novel_app.exe"; DestDir: "{app}"; Flags: ignoreversion

; DLL files
Source: "D:\project\cuosor\novel_app\novel_app-1\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\project\cuosor\novel_app\novel_app-1\build\windows\x64\runner\Release\just_audio_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\project\cuosor\novel_app\novel_app-1\build\windows\x64\runner\Release\permission_handler_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\project\cuosor\novel_app\novel_app-1\build\windows\x64\runner\Release\share_plus_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "D:\project\cuosor\novel_app\novel_app-1\build\windows\x64\runner\Release\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data directory
Source: "D:\project\cuosor\novel_app\novel_app-1\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Dirs]
Name: "{app}\data\flutter_assets"; Permissions: users-modify
Name: "{app}\data\database"; Permissions: users-modify 