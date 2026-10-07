// The manager supplies terminalPid and terminalAppId before loading this script.
function presentPlayer(window) {
    if (window.pid !== terminalPid || String(window.resourceClass) !== terminalAppId) {
        return;
    }
    window.minimized = false;
    workspace.raiseWindow(window);
    workspace.activeWindow = window;
    callDBus("org.kotofox.Terminal", "/Terminal", "org.kotofox.Terminal", "Focused", String(terminalPid));
}

workspace.windowAdded.connect(presentPlayer);
workspace.windowList().forEach(presentPlayer);
