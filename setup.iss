#define MyAppName "AI小说生成器"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "AI Novel"
#define MyAppExeName "novel_app.exe"
#define MyAppSourceDir "build\windows\x64\runner\Release"

[Setup]
AppId={{8C8A91A0-7F4B-4F4D-8B7E-6F0D0E7E8C9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=installer
OutputBaseFilename=AI小说生成器安装程序
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ShowLanguageDialog=no
SetupLogging=yes
UsePreviousLanguage=no

[Languages]
;Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=欢迎安装 AI小说生成器
WelcomeLabel2=这将在您的计算机上安装 AI小说生成器 %1。%n%n建议在继续之前关闭所有其他应用程序。
FinishedLabel=安装已完成。您可以运行 AI小说生成器 了。
SelectDirLabel3=安装程序将安装 AI小说生成器 到下列文件夹。
SelectDirBrowseLabel=点击"下一步"继续。如果要选择其他文件夹，请点击"浏览"。

[CustomMessages]
LaunchProgram=安装完成后运行 AI小说生成器
CreateDesktopIcon=创建桌面快捷方式(&D)
AdditionalIcons=附加快捷方式：

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram}"; Flags: nowait postinstall skipifsilent 