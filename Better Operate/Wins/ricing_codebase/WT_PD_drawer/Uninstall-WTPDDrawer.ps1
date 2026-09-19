[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'WT_PD_drawer'),
    [switch]$KeepTerminalSettings
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InstallRoot)) {
    Write-Host 'WT_PD_drawer is not installed.'
    return
}

$resolvedInstall = (Resolve-Path -LiteralPath $InstallRoot).Path
$resolvedLocal = (Resolve-Path -LiteralPath $env:LOCALAPPDATA).Path
if (-not $resolvedInstall.StartsWith($resolvedLocal, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove an install directory outside LOCALAPPDATA: $resolvedInstall"
}

if ($PSCmdlet.ShouldProcess($resolvedInstall, 'Uninstall WT_PD_drawer and remove its local runtime files')) {
    $pidFile = Join-Path $resolvedInstall 'drawer.pid'
    if (Test-Path -LiteralPath $pidFile) {
        $drawerPid = 0
        if ([int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$drawerPid)) {
            $process = Get-CimInstance Win32_Process -Filter "ProcessId=$drawerPid" -ErrorAction SilentlyContinue
            if ($process -and $process.CommandLine -like '*WT-PD-Drawer.ps1*') {
                Stop-Process -Id $drawerPid -Force
            }
        }
    }

    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WT_PD_drawer' -ErrorAction SilentlyContinue

    $statePath = Join-Path $resolvedInstall 'install-state.json'
    if (-not $KeepTerminalSettings -and (Test-Path -LiteralPath $statePath)) {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if ((Test-Path -LiteralPath $state.terminalSettingsPath) -and
            (Test-Path -LiteralPath $state.terminalSettingsBackup)) {
            Copy-Item -LiteralPath $state.terminalSettingsBackup -Destination $state.terminalSettingsPath -Force
            Write-Host "Restored Terminal settings from $($state.terminalSettingsBackup)"
        }
    }

    Remove-Item -LiteralPath $resolvedInstall -Recurse -Force
    Write-Host 'WT_PD_drawer uninstalled.' -ForegroundColor Green
}
