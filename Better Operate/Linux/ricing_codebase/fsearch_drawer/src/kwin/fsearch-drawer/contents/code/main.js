const appId = "io.github.cboxdoerfer.fsearch";
const toggleShortcut = "Ctrl+Shift+W";
let managedWindow;
let returnWindow;
let lastOutputName = "";
let targetOutputName = "";
let starting = false;
let revealing = false;
let changingGeometry = false;

function isFSearch(window) {
    return window && !window.deleted
        && String(window.resourceClass).toLowerCase() === appId
        && window.normalWindow && !window.transient;
}

function rememberFocus() {
    const active = workspace.activeWindow;
    if (active && active.normalWindow && !isFSearch(active)
        && (!active.transientFor || !isFSearch(active.transientFor))) {
        returnWindow = active;
        lastOutputName = active.output.name;
    }
}

function outputByName(name) {
    return workspace.screens.find(output => output.name === name);
}

function focusedOutput() {
    const active = workspace.activeWindow;
    if (active && active.normalWindow && !isFSearch(active) && active.output) {
        return active.output;
    }
    return outputByName(lastOutputName)
        || workspace.screenAt(workspace.cursorPos) || workspace.activeScreen;
}

function desiredGeometry(output) {
    const desktop = workspace.currentDesktopForScreen(output) || workspace.currentDesktop;
    const area = workspace.clientArea(KWin.MaximizeArea, output, desktop);
    const screen = output.geometry;
    // On this Wayland desktop QScreen::availableGeometry (used by KRunner)
    // is the full logical output geometry, unlike KWin's panel-reserved area.
    // Verified against KRunner on both outputs, including fractional scaling.
    const y = Math.round(screen.y + Math.floor(screen.height / 3));
    let bottom = area.y + area.height;
    workspace.windowList().forEach(window => {
        const frame = window.frameGeometry;
        if (window.dock && window.output === output
            && frame.width > frame.height && frame.y > screen.y + screen.height / 2) {
            bottom = Math.min(bottom, frame.y);
        }
    });
    const width = Math.round(screen.width / 2);
    return {
        x: Math.round(screen.x + (screen.width - width) / 2),
        y: y,
        width: width,
        height: Math.round(bottom - y)
    };
}

function geometryMatches(current, wanted) {
    return ["x", "y", "width", "height"].every(key => Math.abs(current[key] - wanted[key]) <= 1);
}

function enforceGeometry(window) {
    if (changingGeometry || window.minimized) {
        return;
    }
    const output = outputByName(targetOutputName) || window.output;
    const wanted = desiredGeometry(output);
    if (!geometryMatches(window.frameGeometry, wanted)) {
        changingGeometry = true;
        window.frameGeometry = wanted;
        changingGeometry = false;
    }
    if (revealing && geometryMatches(window.frameGeometry, wanted)) {
        revealing = false;
        window.opacity = 1;
        workspace.raiseWindow(window);
        workspace.activeWindow = window;
    }
}

function showWindow(window, output) {
    rememberFocus();
    targetOutputName = output.name;
    revealing = true;
    window.opacity = 0;
    changingGeometry = true;
    window.minimized = false;
    window.fullScreen = false;
    window.setMaximize(false, false);
    workspace.sendClientToScreen(window, output);
    window.desktops = [workspace.currentDesktopForScreen(output) || workspace.currentDesktop];
    window.activities = [workspace.currentActivity];
    window.keepAbove = true;
    changingGeometry = false;
    enforceGeometry(window);
}

function hideWindow(window) {
    revealing = false;
    window.opacity = 1;
    window.keepAbove = false;
    window.minimized = true;
    if (returnWindow && !returnWindow.deleted && workspace.windowList().includes(returnWindow)) {
        workspace.activeWindow = returnWindow;
    }
}

function showFSearch() {
    const output = focusedOutput();
    if (managedWindow && !managedWindow.deleted) {
        showWindow(managedWindow, output);
        return;
    }
    if (starting) {
        return;
    }
    rememberFocus();
    targetOutputName = output.name;
    starting = true;
    callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager", "StartUnit", "fsearch-drawer.service", "replace");
}

function toggleFSearch() {
    if (managedWindow && !managedWindow.deleted && !managedWindow.minimized
        && workspace.activeWindow === managedWindow) {
        hideWindow(managedWindow);
    } else {
        showFSearch();
    }
}

function manageWindow(window, existing) {
    if (!isFSearch(window)) {
        return;
    }
    managedWindow = window;
    window.noBorder = true;
    window.skipTaskbar = false;
    targetOutputName = starting ? targetOutputName : window.output.name;
    window.frameGeometryChanged.connect(() => enforceGeometry(window));
    window.minimizedChanged.connect(() => {
        if (changingGeometry) {
            return;
        }
        if (window.minimized) {
            revealing = false;
            window.opacity = 1;
            window.keepAbove = false;
        } else {
            // Restoring through Plasma's existing task button bypasses Exec.
            // Capture the external focus before FSearch receives activation.
            showWindow(window, focusedOutput());
        }
    });
    window.closed.connect(() => {
        if (managedWindow === window) {
            managedWindow = undefined;
            revealing = false;
            starting = false;
        }
    });
    if (starting) {
        starting = false;
        showWindow(window, outputByName(targetOutputName) || focusedOutput());
    } else if (!existing) {
        hideWindow(window);
    } else if (!window.minimized) {
        enforceGeometry(window);
    }
}

rememberFocus();
workspace.windowList().forEach(window => manageWindow(window, true));
workspace.windowAdded.connect(window => manageWindow(window, false));
workspace.windowActivated.connect(window => {
    if (isFSearch(window) && !revealing && !changingGeometry) {
        showWindow(window, focusedOutput());
    } else {
        rememberFocus();
    }
});
workspace.screensChanged.connect(() => {
    if (managedWindow && !managedWindow.deleted && !managedWindow.minimized) {
        showWindow(managedWindow, outputByName(targetOutputName) || focusedOutput());
    }
});
registerShortcut("Toggle FSearch Drawer", "Show or hide FSearch", toggleShortcut, toggleFSearch);
registerShortcut("Show FSearch Drawer", "Show FSearch on the focused screen", "", showFSearch);
