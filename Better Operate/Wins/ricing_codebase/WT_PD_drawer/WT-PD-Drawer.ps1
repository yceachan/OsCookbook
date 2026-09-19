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
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace WtPd
{
    public static class Native
    {
        public const uint DetachMessage = 0x8001;
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        private delegate IntPtr LowLevelKeyboardProc(int code, IntPtr wParam, IntPtr lParam);
        private static readonly LowLevelKeyboardProc KeyboardCallback = KeyboardHookCallback;
        private static IntPtr keyboardHook = IntPtr.Zero;
        private static IntPtr drawerWindow = IntPtr.Zero;
        private static uint messageThreadId;
        private static uint detachVirtualKey = 0x46;
        private static bool suppressDetachKey;
        private static bool detachPending;
        private static bool detachKeyDown;
        private static bool leftControlDown;
        private static bool rightControlDown;
        private static bool leftShiftDown;
        private static bool rightShiftDown;

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
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int maxCount);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int hookId, LowLevelKeyboardProc callback, IntPtr module, uint threadId);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnhookWindowsHookEx(IntPtr hook);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int virtualKey);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool PostThreadMessage(uint threadId, uint message, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr GetModuleHandle(string moduleName);

        [DllImport("kernel32.dll")]
        public static extern uint GetCurrentThreadId();

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

        [StructLayout(LayoutKind.Sequential)]
        private struct KeyboardData
        {
            public uint VirtualKey;
            public uint ScanCode;
            public uint Flags;
            public uint Time;
            public UIntPtr ExtraInfo;
        }

        public static void SetDrawerWindow(IntPtr window)
        {
            drawerWindow = window;
        }

        public static bool InstallDetachHook(uint targetThreadId, uint virtualKey)
        {
            if (keyboardHook != IntPtr.Zero)
            {
                return true;
            }
            messageThreadId = targetThreadId;
            detachVirtualKey = virtualKey;
            using (Process process = Process.GetCurrentProcess())
            using (ProcessModule module = process.MainModule)
            {
                keyboardHook = SetWindowsHookEx(13, KeyboardCallback, GetModuleHandle(module.ModuleName), 0);
            }
            return keyboardHook != IntPtr.Zero;
        }

        public static void UninstallDetachHook()
        {
            if (keyboardHook != IntPtr.Zero)
            {
                UnhookWindowsHookEx(keyboardHook);
                keyboardHook = IntPtr.Zero;
            }
        }

        public static void SendControlShiftKey(uint virtualKey)
        {
            const uint KeyUp = 0x0002;
            keybd_event(0x11, 0, 0, UIntPtr.Zero);
            keybd_event(0x10, 0, 0, UIntPtr.Zero);
            keybd_event((byte)virtualKey, 0, 0, UIntPtr.Zero);
            keybd_event((byte)virtualKey, 0, KeyUp, UIntPtr.Zero);
            keybd_event(0x10, 0, KeyUp, UIntPtr.Zero);
            keybd_event(0x11, 0, KeyUp, UIntPtr.Zero);
        }

        private static IntPtr KeyboardHookCallback(int code, IntPtr wParam, IntPtr lParam)
        {
            if (code >= 0)
            {
                uint message = (uint)wParam.ToInt64();
                bool keyDown = message == 0x0100 || message == 0x0104;
                bool keyUp = message == 0x0101 || message == 0x0105;
                KeyboardData data = (KeyboardData)Marshal.PtrToStructure(lParam, typeof(KeyboardData));
                uint key = data.VirtualKey;

                if (key == 0xA2)
                {
                    if (keyDown) leftControlDown = true;
                    if (keyUp) leftControlDown = false;
                }
                else if (key == 0xA3)
                {
                    if (keyDown) rightControlDown = true;
                    if (keyUp) rightControlDown = false;
                }
                else if (key == 0xA0)
                {
                    if (keyDown) leftShiftDown = true;
                    if (keyUp) leftShiftDown = false;
                }
                else if (key == 0xA1)
                {
                    if (keyDown) rightShiftDown = true;
                    if (keyUp) rightShiftDown = false;
                }

                bool controlDown = leftControlDown || rightControlDown ||
                    (GetAsyncKeyState(0x11) & 0x8000) != 0;
                bool shiftDown = leftShiftDown || rightShiftDown ||
                    (GetAsyncKeyState(0x10) & 0x8000) != 0;

                if (key == detachVirtualKey)
                {
                    if (keyDown && controlDown && shiftDown &&
                        drawerWindow != IntPtr.Zero && GetForegroundWindow() == drawerWindow)
                    {
                        leftControlDown = leftControlDown || (GetAsyncKeyState(0xA2) & 0x8000) != 0;
                        rightControlDown = rightControlDown || (GetAsyncKeyState(0xA3) & 0x8000) != 0;
                        leftShiftDown = leftShiftDown || (GetAsyncKeyState(0xA0) & 0x8000) != 0;
                        rightShiftDown = rightShiftDown || (GetAsyncKeyState(0xA1) & 0x8000) != 0;
                        suppressDetachKey = true;
                        detachPending = true;
                        detachKeyDown = true;
                        return new IntPtr(1);
                    }
                    if (keyUp && suppressDetachKey)
                    {
                        suppressDetachKey = false;
                        detachKeyDown = false;
                        TryPostDetach();
                        return new IntPtr(1);
                    }
                }

                if ((key == 0xA2 || key == 0xA3 || key == 0xA0 || key == 0xA1) && keyUp)
                {
                    TryPostDetach();
                }
            }
            return CallNextHookEx(keyboardHook, code, wParam, lParam);
        }

        private static void TryPostDetach()
        {
            if (detachPending && !detachKeyDown &&
                !leftControlDown && !rightControlDown &&
                !leftShiftDown && !rightShiftDown)
            {
                detachPending = false;
                PostThreadMessage(messageThreadId, DetachMessage, IntPtr.Zero, IntPtr.Zero);
            }
        }

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
$script:ManagedWindowName = $null
$script:ManagedWindowTitle = $null

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
    $titleMarker = if ([string]::IsNullOrWhiteSpace($script:ManagedWindowTitle)) {
        [string]$config.windowTitle
    }
    else {
        $script:ManagedWindowTitle
    }
    $script:CachedWindow = [WtPd.Native]::FindWindowByTitleMarker($titleMarker)
    if ($script:CachedWindow -ne [IntPtr]::Zero) {
        [WtPd.Native]::SetDrawerWindow($script:CachedWindow)
    }
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

    $instanceId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $script:ManagedWindowName = '{0}-{1}' -f [string]$config.windowName, $instanceId
    $script:ManagedWindowTitle = '{0}-{1}' -f [string]$config.windowTitle, $instanceId
    $script:CachedWindow = [IntPtr]::Zero

    $arguments = New-Object Collections.Generic.List[string]
    $arguments.Add('-w')
    $arguments.Add((Quote-DrawerArgument $script:ManagedWindowName))
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
    $arguments.Add((Quote-DrawerArgument $script:ManagedWindowTitle))
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

function Invoke-DrawerDetach {
    $window = Get-DrawerWindow
    if ($window -eq [IntPtr]::Zero -or [WtPd.Native]::GetForegroundWindow() -ne $window) {
        return
    }

    Write-DrawerLog 'Detaching the active drawer tab into a normal Terminal window.'
    Start-Sleep -Milliseconds 75
    [WtPd.Native]::SendControlShiftKey([uint32]$config.detachActionVirtualKey)
    $script:CachedWindow = [IntPtr]::Zero
    $script:ManagedWindowName = $null
    $script:ManagedWindowTitle = $null
    [WtPd.Native]::SetDrawerWindow([IntPtr]::Zero)
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

    if ([WtPd.Native]::InstallDetachHook(
        [WtPd.Native]::GetCurrentThreadId(),
        [uint32]$config.detachHotkeyVirtualKey)) {
        Write-DrawerLog 'Enabled Ctrl+Shift+F detach while the managed drawer is foreground.'
        $existingDrawer = Get-DrawerWindow
        if ($existingDrawer -ne [IntPtr]::Zero) {
            Write-DrawerLog 'Adopted an existing managed drawer window.'
        }
    }
    else {
        Write-DrawerLog 'Could not install the Ctrl+Shift+F detach hook.'
    }

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
        elseif ($message.Message -eq [WtPd.Native]::DetachMessage) {
            try {
                Invoke-DrawerDetach
            }
            catch {
                Write-DrawerLog ("Detach failed: {0}" -f $_.Exception.Message)
            }
        }
    }
}
finally {
    [WtPd.Native]::UninstallDetachHook()
    [WtPd.Native]::SetDrawerWindow([IntPtr]::Zero)
    [WtPd.Native]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId) | Out-Null
    if (Test-Path -LiteralPath $pidPath) {
        Remove-Item -LiteralPath $pidPath -Force
    }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
