; Catalogador EsSalud - InnoSetup Installer Script
; Windows Desktop Application Installer
; Version 1.0.0

#define MyAppName "Catalogador EsSalud"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "EsSalud"
#define MyAppURL "https://github.com/martinosorio302/catalogador"
#define MyAppExeName "CatalogadorEsSalud.exe"
#define MyAppService "CatalogadorAPI"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\LICENSE
InfoBeforeFile=installer_readme.txt
OutputDir=output
OutputBaseFilename=CatalogadorEsSalud_Setup_{#MyAppVersion}
SetupIconFile=icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startmenuicon"; Description: "Crear acceso directo en el Menú Inicio"; GroupDescription: "{cm:AdditionalIcons}"
Name: "installservice"; Description: "Instalar servicio de backend (requerido)"; GroupDescription: "Servicios:"; Flags: checkedonce

[Files]
; WPF Application
Source: "..\Catalogador.App\bin\Release\net8.0-windows\*"; DestDir: "{app}\Application"; Flags: ignoreversion recursesubdirs createallsubdirs
; Python Backend
Source: "..\api\*"; DestDir: "{app}\Backend\api"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\engine\*"; DestDir: "{app}\Backend\engine"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\requirements.txt"; DestDir: "{app}\Backend"; Flags: ignoreversion
Source: "..\setup.py"; DestDir: "{app}\Backend"; Flags: ignoreversion
; Service Management Scripts
Source: "..\tools\install_windows_service.ps1"; DestDir: "{app}\Tools"; Flags: ignoreversion
Source: "..\tools\uninstall_service.ps1"; DestDir: "{app}\Tools"; Flags: ignoreversion
Source: "..\tools\start_service.ps1"; DestDir: "{app}\Tools"; Flags: ignoreversion
Source: "..\tools\stop_service.ps1"; DestDir: "{app}\Tools"; Flags: ignoreversion
Source: "..\tools\nssm.exe"; DestDir: "{app}\Tools"; Flags: ignoreversion
; Data Files
Source: "..\data\essalud_pcd_anexo02.full.json"; DestDir: "{app}\Data"; Flags: ignoreversion
; Documentation
Source: "..\README_NEW.md"; DestDir: "{app}"; DestName: "README.md"; Flags: ignoreversion isreadme
Source: "..\IMPLEMENTATION_SUMMARY.md"; DestDir: "{app}\Docs"; Flags: ignoreversion
; Icon
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\Application\{#MyAppExeName}"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\Application\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\Application\{#MyAppExeName}"; Tasks: startmenuicon

[Run]
; Install Python dependencies and service (if selected)
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Tools\install_windows_service.ps1"" -PythonPath ""C:\Python312\python.exe"" -InstallPath ""{app}\Backend"" -ServiceName ""{#MyAppService}"" -Port 8000"; StatusMsg: "Instalando servicio de backend..."; Flags: runhidden waituntilterminated; Tasks: installservice; Check: IsAdminLoggedOn
; Launch application after installation
Filename: "{app}\Application\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop and remove service on uninstall
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Tools\stop_service.ps1"" -ServiceName ""{#MyAppService}"""; Flags: runhidden waituntilterminated; RunOnceId: "StopService"
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Tools\uninstall_service.ps1"" -ServiceName ""{#MyAppService}"""; Flags: runhidden waituntilterminated; RunOnceId: "UninstallService"

[UninstallDelete]
Type: filesandordirs; Name: "{app}\Backend\venv"
Type: filesandordirs; Name: "{app}\logs"
Type: files; Name: "{localappdata}\CatalogadorEsSalud\logs\*"

[Code]
// Check if .NET 8 Runtime is installed
function IsDotNetInstalled: Boolean;
var
  ResultCode: Integer;
begin
  // Check for .NET 8 Desktop Runtime
  Result := RegKeyExists(HKLM, 'SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost\8.0') or
            RegKeyExists(HKLM, 'SOFTWARE\dotnet\Setup\InstalledVersions\x86\sharedhost\8.0');
  
  if not Result then
  begin
    MsgBox('Se requiere .NET 8 Desktop Runtime para ejecutar esta aplicación.' + #13#10 + 
           'Por favor, descárguelo de https://dotnet.microsoft.com/download/dotnet/8.0', 
           mbError, MB_OK);
  end;
end;

// Check if Python 3.11+ is installed
function IsPythonInstalled: Boolean;
var
  ResultCode: Integer;
  PythonVersion: String;
begin
  Result := Exec('python', '--version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  
  if not Result or (ResultCode <> 0) then
  begin
    MsgBox('Se requiere Python 3.11 o superior para el backend.' + #13#10 + 
           'Por favor, descárguelo de https://www.python.org/downloads/', 
           mbError, MB_OK);
    Result := False;
  end;
end;

function InitializeSetup: Boolean;
begin
  Result := True;
  
  // Check prerequisites
  if not IsDotNetInstalled then
    Result := False;
    
  if not IsPythonInstalled then
    Result := False;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Create logs directory
    if not DirExists(ExpandConstant('{app}\logs')) then
      CreateDir(ExpandConstant('{app}\logs'));
  end;
end;
