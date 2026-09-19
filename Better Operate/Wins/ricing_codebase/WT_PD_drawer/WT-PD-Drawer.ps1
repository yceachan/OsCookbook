[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$ToggleOnce
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'config.json'
}

$nativeSource = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace WtPd
{
    public static class Native
    {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MSG
        {
            public IntPtr HWnd;
            public uint Message;
            public IntPtr WParam;
            public IntPtr LParam;
            public uint Time;
            public POINT Point;
        }

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint virtualKey);

        [DllImport("user32.dll")]
        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        [DllImport("user32.dll")]
        public static extern int GetMessage(out MSG message, IntPtr hWnd, uint min, uint max);

        [DllImport("user32.dll")]
        public static extern bool IsWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool IsIconic(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindowAsync(IntPtr hWnd, int command);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

        public static IntPtr FindWindowByTitleMarker(string marker)
        {
            IntPtr result = IntPtr.Zero;
            EnumWindows(delegate(IntPtr window, IntPtr parameter)
            {
                var title = new StringBuilder(512);
                GetWindowText(window, title, title.Capacity);
                if (title.ToString().IndexOf(marker, StringComparison.Ordinal) >= 0)
                {
                    result = window;
                    return false;
                }
                return true;
            }, IntPtr.Zero);
            return result;
        }
    }
}
'@

if (-not ('WtPd.Native' -as [type])) {
    Add-Type -TypeDefinition $nativeSource -Language CSharp
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$installRoot = Split-Path -Parent $ConfigPath
$logPath = Join-Path $installRoot 'drawer.log'
$pidPath = Join-Path $installRoot 'drawer.pid'
$script:CachedWindow = [IntPtr]::Zero

function Write-DrawerLog {
    param([string]$Message)
    $line = '{0} {1}' -f (Get-Date -Format 's'), $Message
    [IO.File]::AppendAllText($logPath, $line + [Environment]::NewLine)
}

function Expand-DrawerPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Quote-DrawerArgument {
    param([string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Get-DrawerWindow {
    if ($script:CachedWindow -ne [IntPtr]::Zero -and [WtPd.Native]::IsWindow($script:CachedWindow)) {
        return $script:CachedWindow
    }
    $script:CachedWindow = [WtPd.Native]::FindWindowByTitleMarker([string]$config.windowTitle)
    return $script:CachedWindow
}

function Start-DrawerWindow {
    $terminal = Expand-DrawerPath ([string]$config.terminalExecutable)
    if (-not (Test-Path -LiteralPath $terminal)) {
        $terminalCommand = Get-Command wt.exe -ErrorAction SilentlyContinue
        if (-not $terminalCommand) {
            throw 'wt.exe was not found. Install Windows Terminal or update terminalExecutable in config.json.'
        }
        $terminal = $terminalCommand.Source
    }

    $startingDirectory = Expand-DrawerPath ([string]$config.startingDirectory)
    if ([string]::IsNullOrWhiteSpace($startingDirectory) -or -not (Test-Path -LiteralPath $startingDirectory)) {
        $startingDirectory = [Environment]::GetFolderPath('UserProfile')
    }

    $arguments = New-Object Collections.Generic.List[string]
    $arguments.Add('-w')
    $arguments.Add((Quote-DrawerArgument ([string]$config.windowName)))
    $arguments.Add('--size')
    $arguments.Add(('{0},{1}' -f [int]$config.columns, [int]$config.rows))
    $arguments.Add('--pos')
    $arguments.Add(('{0},{1}' -f [int]$config.x, [int]$config.y))
    if ([bool]$config.focusMode) {
        $arguments.Add('--focus')
    }
    $arguments.Add('new-tab')
    if (-not [string]::IsNullOrWhiteSpace([string]$config.profile)) {
        $arguments.Add('-p')
        $arguments.Add((Quote-DrawerArgument ([string]$config.profile)))
    }
    $arguments.Add('-d')
    $arguments.Add((Quote-DrawerArgument $startingDirectory))
    $arguments.Add('--title')
    $arguments.Add((Quote-DrawerArgument ([string]$config.windowTitle)))
    $arguments.Add('--suppressApplicationTitle')

    $argumentLine = $arguments -join ' '
    Write-DrawerLog ("Launching: {0} {1}" -f $terminal, $argumentLine)
    Start-Process -FilePath $terminal -ArgumentList $argumentLine -WorkingDirectory $startingDirectory

    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        Start-Sleep -Milliseconds 100
        $window = Get-DrawerWindow
        if ($window -ne [IntPtr]::Zero) {
            [WtPd.Native]::ShowWindowAsync($window, 5) | Out-Null
            [WtPd.Native]::SetForegroundWindow($window) | Out-Null
            return
        }
    }
    Write-DrawerLog 'Windows Terminal started, but the drawer window was not found within 10 seconds.'
}

function Invoke-DrawerToggle {
    $window = Get-DrawerWindow
    if ($window -eq [IntPtr]::Zero) {
        Start-DrawerWindow
        return
    }

    if ([WtPd.Native]::IsWindowVisible($window) -and -not [WtPd.Native]::IsIconic($window)) {
        [WtPd.Native]::ShowWindowAsync($window, 0) | Out-Null
    }
    else {
        $showCommand = if ([WtPd.Native]::IsIconic($window)) { 9 } else { 5 }
        [WtPd.Native]::ShowWindowAsync($window, $showCommand) | Out-Null
        [WtPd.Native]::SetForegroundWindow($window) | Out-Null
    }
}

if ($ToggleOnce) {
    Invoke-DrawerToggle
    return
}

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, 'Local\WT_PD_drawer', [ref]$createdNew)
if (-not $createdNew) {
    $mutex.Dispose()
    return
}

$hotkeyId = 0x4454
try {
    [IO.File]::WriteAllText($pidPath, [string]$PID)
    $loggedConflict = $false
    while (-not [WtPd.Native]::RegisterHotKey(
        [IntPtr]::Zero,
        $hotkeyId,
        [uint32]$config.hotkeyModifiers,
        [uint32]$config.hotkeyVirtualKey)) {
        if (-not $loggedConflict) {
            Write-DrawerLog 'Win+` is owned by another process; retrying every 5 seconds.'
            $loggedConflict = $true
        }
        Start-Sleep -Seconds 5
    }
    Write-DrawerLog 'Registered Win+`.'

    $message = New-Object WtPd.Native+MSG
    while ([WtPd.Native]::GetMessage([ref]$message, [IntPtr]::Zero, 0, 0) -gt 0) {
        if ($message.Message -eq 0x0312 -and $message.WParam.ToInt32() -eq $hotkeyId) {
            try {
                Invoke-DrawerToggle
            }
            catch {
                Write-DrawerLog ("Toggle failed: {0}" -f $_.Exception.Message)
            }
        }
    }
}
finally {
    [WtPd.Native]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId) | Out-Null
    if (Test-Path -LiteralPath $pidPath) {
        Remove-Item -LiteralPath $pidPath -Force
    }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
