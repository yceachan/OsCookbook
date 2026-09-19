[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Profile = '',
    [string]$StartingDirectory = [Environment]::GetFolderPath('UserProfile'),
    [ValidateRange(20, 400)][int]$Columns = 90,
    [ValidateRange(5, 200)][int]$Rows = 15,
    [int]$X = 373,
    [int]$Y = 0,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'WT_PD_drawer'),
    [switch]$KeepLegacyGlobalWindowSettings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false)))
}

function Stop-InstalledDrawer {
    param([string]$Root)
    $pidFile = Join-Path $Root 'drawer.pid'
    if (-not (Test-Path -LiteralPath $pidFile)) {
        return
    }
    $drawerPid = 0
    if (-not [int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$drawerPid)) {
        return
    }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$drawerPid" -ErrorAction SilentlyContinue
    if ($process -and $process.CommandLine -like '*WT-PD-Drawer.ps1*') {
        Stop-Process -Id $drawerPid -Force
    }
}

function Find-TerminalSettings {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    return $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $StartingDirectory)) {
    throw "Starting directory does not exist: $StartingDirectory"
}

$runtimeSource = Join-Path $PSScriptRoot 'WT-PD-Drawer.ps1'
if (-not (Test-Path -LiteralPath $runtimeSource)) {
    throw "Runtime source not found: $runtimeSource"
}

$terminalSettingsPath = Find-TerminalSettings
if (-not $terminalSettingsPath) {
    throw 'Windows Terminal settings.json was not found.'
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$terminalBackup = "$terminalSettingsPath.backup-WT_PD_drawer-$timestamp"

if ($PSCmdlet.ShouldProcess($InstallRoot, 'Install WT_PD_drawer')) {
    Stop-InstalledDrawer -Root $InstallRoot
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    Copy-Item -LiteralPath $runtimeSource -Destination (Join-Path $InstallRoot 'WT-PD-Drawer.ps1') -Force

    $config = [ordered]@{
        terminalExecutable = '%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe'
        windowName = 'dropdown-terminal'
        windowTitle = '__WT_PD_DRAWER__'
        profile = $Profile
        startingDirectory = $StartingDirectory
        columns = $Columns
        rows = $Rows
        x = $X
        y = $Y
        focusMode = $true
        hotkeyModifiers = 16392
        hotkeyVirtualKey = 192
    }
    Write-Utf8NoBom -Path (Join-Path $InstallRoot 'config.json') -Content ($config | ConvertTo-Json)

    Copy-Item -LiteralPath $terminalSettingsPath -Destination $terminalBackup
    try {
        $settings = Get-Content -LiteralPath $terminalSettingsPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Terminal settings are not strict JSON. A backup was created at $terminalBackup, but no settings were changed. Remove comments/trailing commas or edit the file manually."
    }

    if ($settings.PSObject.Properties['actions']) {
        $settings.actions = @($settings.actions | Where-Object {
            $_.id -ne 'User.DropdownTerminal' -and
            -not ($_.command -and $_.command.action -eq 'globalSummon' -and $_.command.name -eq 'dropdown-terminal')
        })
    }
    if ($settings.PSObject.Properties['keybindings']) {
        $settings.keybindings = @($settings.keybindings | Where-Object {
            $keys = @($_.keys)
            $_.id -ne 'User.DropdownTerminal' -and -not ($keys -contains 'win+`')
        })
    }
    if (-not $KeepLegacyGlobalWindowSettings) {
        foreach ($property in 'initialCols', 'initialRows', 'initialPosition') {
            $settings.PSObject.Properties.Remove($property)
        }
        $settings | Add-Member NoteProperty launchMode 'default' -Force
    }
    $settings | Add-Member NoteProperty windowingBehavior 'useNew' -Force
    $settings | Add-Member NoteProperty startOnUserLogin $false -Force
    Write-Utf8NoBom -Path $terminalSettingsPath -Content ($settings | ConvertTo-Json -Depth 100)

    $legacyExe = Join-Path $env:LOCALAPPDATA 'DropdownTerminal\DropdownTerminalHotkey.exe'
    Get-Process -Name DropdownTerminalHotkey -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Path -eq $legacyExe) {
            Stop-Process -Id $_.Id -Force
        }
    }
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'DropdownTerminalHotkey' -ErrorAction SilentlyContinue
    $legacyRoot = Join-Path $env:LOCALAPPDATA 'DropdownTerminal'
    if (Test-Path -LiteralPath $legacyRoot) {
        $resolvedLegacy = (Resolve-Path -LiteralPath $legacyRoot).Path
        $resolvedLocal = (Resolve-Path -LiteralPath $env:LOCALAPPDATA).Path
        if (-not $resolvedLegacy.StartsWith($resolvedLocal, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to move legacy directory outside LOCALAPPDATA: $resolvedLegacy"
        }
        Move-Item -LiteralPath $resolvedLegacy -Destination "$resolvedLegacy.backup-$timestamp"
    }

    $state = [ordered]@{
        installedAt = (Get-Date).ToString('o')
        terminalSettingsPath = $terminalSettingsPath
        terminalSettingsBackup = $terminalBackup
    }
    Write-Utf8NoBom -Path (Join-Path $InstallRoot 'install-state.json') -Content ($state | ConvertTo-Json)

    $runtime = Join-Path $InstallRoot 'WT-PD-Drawer.ps1'
    $startupCommand = 'powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $runtime
    New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WT_PD_drawer' -PropertyType String -Value $startupCommand -Force | Out-Null
    Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $runtime) -WindowStyle Hidden
    Start-Sleep -Milliseconds 800

    Write-Host 'WT_PD_drawer installed.' -ForegroundColor Green
    Write-Host "Runtime: $runtime"
    Write-Host "Config:  $(Join-Path $InstallRoot 'config.json')"
    Write-Host "Log:     $(Join-Path $InstallRoot 'drawer.log')"
    Write-Host "Backup:  $terminalBackup"
    Write-Host 'Press Win+` to show or hide the drawer terminal.'
}
