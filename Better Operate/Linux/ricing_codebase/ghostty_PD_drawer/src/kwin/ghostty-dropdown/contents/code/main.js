const dropdownAppId = "com.mitchellh.ghostty.dropdown";
const controllerService = "com.mitchellh.ghostty.DropdownController";
const controllerPath = "/com/mitchellh/ghostty/DropdownController";

// Global shortcut keys. KGlobalAccel keeps whatever binding it stores in
// kglobalshortcutsrc: a conflict in another component can clear it, and
// install.sh reclaims the action in that case. Changing a key here needs
// ./install.sh apply, which re-registers the shortcuts.
const toggleShortcut = "Meta+`";
const promoteShortcut = "Meta+F";

let pendingOutputName = "";
let targetOutputName = "";
let managedWindow;
const promotedWindows = [];
let changingGeometry = false;
let handlingHideRequest = false;
let revealSerial = 0;
let dropdownHidden = false;
let returnWindow;
let revealingWindow;
let startingDropdown = false;

function hasDropdownIdentity(window) {
    if (window.deleted) {
        return false;
    }
    return [window.resourceClass, window.resourceName].some((value) => {
        const identity = String(value).toLowerCase();
        return identity === dropdownAppId || identity.startsWith(dropdownAppId + ".");
    });
}

function isPromoted(window) {
    return promotedWindows.includes(window);
}

function isDropdown(window) {
    return hasDropdownIdentity(window) && !isPromoted(window);
}

function findDropdown() {
    if (managedWindow !== undefined && !managedWindow.deleted && workspace.windowList().includes(managedWindow)) {
        return managedWindow;
    }
    return workspace.windowList().find(isDropdown);
}

function focusedOutput() {
    const active = workspace.activeWindow;
    if (active !== null && active !== undefined && !isDropdown(active) && active.output) {
        return active.output;
    }
    return workspace.screenAt(workspace.cursorPos) || workspace.activeScreen;
}

function outputByName(name) {
    return workspace.screens.find((output) => output.name === name);
}

function desiredGeometry(output, desktop) {
    const area = workspace.clientArea(KWin.MaximizeArea, output, desktop);
    const width = Math.round(area.width / 2);
    const height = Math.round(area.height / 3);

    return {
        x: Math.round(area.x + (area.width - width) / 2),
        y: Math.round(area.y),
        width: width,
        height: height
    };
}

function normalGeometry(output, desktop) {
    const area = workspace.clientArea(KWin.MaximizeArea, output, desktop);
    const width = Math.min(1000, Math.round(area.width * 0.9));
    const height = Math.min(800, Math.round(area.height * 0.9));

    return centeredGeometry(area, width, height);
}

function centeredGeometry(area, width, height) {
    const targetWidth = Math.min(width, area.width);
    const targetHeight = Math.min(height, area.height);

    return {
        x: Math.round(area.x + (area.width - targetWidth) / 2),
        y: Math.round(area.y + (area.height - targetHeight) / 2),
        width: targetWidth,
        height: targetHeight
    };
}

function enforceGeometry(window, output, desktop) {
    if (changingGeometry) {
        return;
    }

    const wanted = desiredGeometry(output, desktop);
    if (geometryMatches(window.frameGeometry, wanted)) {
        return;
    }

    changingGeometry = true;
    window.frameGeometry = wanted;
    changingGeometry = false;
}

function geometryMatches(current, wanted) {
    return Math.abs(current.x - wanted.x) <= 1
        && Math.abs(current.y - wanted.y) <= 1
        && Math.abs(current.width - wanted.width) <= 1
        && Math.abs(current.height - wanted.height) <= 1;
}

function finishReveal(window) {
    if (revealingWindow !== window || dropdownHidden || managedWindow !== window) {
        return;
    }
    const target = outputByName(targetOutputName) || window.output || workspace.activeScreen;
    const desktop = workspace.currentDesktopForScreen(target) || workspace.currentDesktop;
    if (!geometryMatches(window.frameGeometry, desiredGeometry(target, desktop))) {
        return;
    }
    revealingWindow = undefined;
    window.opacity = 1;
    workspace.raiseWindow(window);
    workspace.activeWindow = window;
}

function prepareDropdown(window, output) {
    if (!output) {
        output = workspace.activeScreen;
    }

    const desktop = workspace.currentDesktopForScreen(output) || workspace.currentDesktop;
    targetOutputName = output.name;

    workspace.sendClientToScreen(window, output);
    window.fullScreen = false;
    window.noBorder = true;
    window.skipTaskbar = true;
    window.skipPager = true;
    window.skipSwitcher = true;
    window.keepAbove = true;
    window.desktops = [desktop];
    window.activities = [workspace.currentActivity];
    enforceGeometry(window, output, desktop);
}

function revealDropdown(window, output) {
    const serial = ++revealSerial;

    dropdownHidden = false;
    revealingWindow = undefined;
    window.opacity = 0;
    window.minimized = false;
    prepareDropdown(window, output);
    if (serial !== revealSerial || dropdownHidden || managedWindow !== window) {
        return;
    }
    const target = outputByName(targetOutputName) || window.output || workspace.activeScreen;
    const desktop = workspace.currentDesktopForScreen(target) || workspace.currentDesktop;
    enforceGeometry(window, target, desktop);
    // Wayland resizing is asynchronous. Reveal after the client acknowledges
    // the requested geometry, including when its GTK process is already warm.
    revealingWindow = window;
    finishReveal(window);
}

function hideDropdown(window) {
    ++revealSerial;
    revealingWindow = undefined;
    dropdownHidden = true;
    window.opacity = 0;
    window.keepAbove = false;

    const current = window.frameGeometry;
    changingGeometry = true;
    window.frameGeometry = {
        x: -10000 - current.width,
        y: -10000 - current.height,
        width: current.width,
        height: current.height
    };
    changingGeometry = false;

    if (returnWindow && workspace.windowList().includes(returnWindow)) {
        workspace.activeWindow = returnWindow;
    }
}

function startDropdown(output) {
    if (startingDropdown) {
        return;
    }
    startingDropdown = true;
    pendingOutputName = output.name;
    callDBus(
        controllerService,
        controllerPath,
        controllerService,
        "Start",
        () => { startingDropdown = false; }
    );
}

function promoteDropdown(window, width, height) {
    if (window === undefined || isPromoted(window)) {
        return;
    }

    ++revealSerial;
    revealingWindow = undefined;
    // Promote on the screen the drawer was last shown on, so promoting a hidden
    // drawer does not drag it onto whatever output currently has focus.
    const output = outputByName(targetOutputName) || window.output || workspace.activeScreen;
    const desktop = workspace.currentDesktopForScreen(output) || workspace.currentDesktop;
    promotedWindows.push(window);
    if (managedWindow === window) {
        managedWindow = undefined;
    }
    dropdownHidden = false;
    targetOutputName = "";

    window.opacity = 1;
    window.fullScreen = false;
    window.setMaximize(false, false);
    window.noBorder = false;
    window.skipTaskbar = false;
    window.skipPager = false;
    window.skipSwitcher = false;
    window.keepAbove = false;
    window.minimized = false;

    workspace.sendClientToScreen(window, output);
    window.desktops = [desktop];
    window.activities = [workspace.currentActivity];
    // The controller derives the size from the main terminal configuration
    // (window-width/window-height); 0 means it could not and we keep our own.
    const area = workspace.clientArea(KWin.MaximizeArea, output, desktop);
    const target = width > 0 && height > 0
        ? centeredGeometry(area, width, height)
        : normalGeometry(output, desktop);
    changingGeometry = true;
    window.frameGeometry = target;
    changingGeometry = false;

    workspace.raiseWindow(window);
    workspace.activeWindow = window;
}

function toggleDropdown() {
    const window = findDropdown();

    if (window !== undefined) {
        if (!dropdownHidden) {
            hideDropdown(window);
            return;
        }

        const active = workspace.activeWindow;
        if (active && !isDropdown(active)) {
            returnWindow = active;
        }
        revealDropdown(window, focusedOutput());
        return;
    }

    const active = workspace.activeWindow;
    if (active && !isDropdown(active)) {
        returnWindow = active;
    }
    const output = focusedOutput();
    startDropdown(output);
}

function promoteActiveDropdown() {
    // The drawer is promoted whether or not it currently holds the keyboard
    // focus (a fullscreen game keeps focus, and a drawer hidden with Esc has no
    // focus at all); there is only ever one drawer to promote.
    const window = managedWindow;
    if (window === undefined || isPromoted(window)) {
        return;
    }
    const geometry = window.frameGeometry;
    callDBus(
        controllerService,
        controllerPath,
        controllerService,
        "Promote",
        // D-Bus takes int32 here: frameGeometry is fractional on fractional
        // display scales, and KWin drops such a call without any error.
        Math.round(geometry.width),
        Math.round(geometry.height),
        (width, height) => promoteDropdown(window, width, height)
    );
}

function hideActiveDropdown() {
    const window = managedWindow;
    if (window === undefined || dropdownHidden || isPromoted(window)) {
        return;
    }
    hideDropdown(window);
}

function configureNewWindow(window, reveal) {
    if (!isDropdown(window)) {
        return;
    }

    const output = outputByName(pendingOutputName) || focusedOutput();
    pendingOutputName = "";
    if (managedWindow !== window) {
        let hideOnMaximize = false;
        managedWindow = window;
        window.frameGeometryChanged.connect(() => {
            if (dropdownHidden || managedWindow !== window || isPromoted(window)) {
                return;
            }
            const target = outputByName(targetOutputName) || window.output || workspace.activeScreen;
            const desktop = workspace.currentDesktopForScreen(target) || workspace.currentDesktop;
            enforceGeometry(window, target, desktop);
            finishReveal(window);
        });
        window.maximizedAboutToChange.connect((mode) => {
            hideOnMaximize = mode !== 0;
        });
        window.maximizedChanged.connect(() => {
            if (dropdownHidden || handlingHideRequest || managedWindow !== window) {
                return;
            }
            if (!hideOnMaximize) {
                return;
            }

            hideOnMaximize = false;
            handlingHideRequest = true;
            window.setMaximize(false, false);
            handlingHideRequest = false;
            hideDropdown(window);
        });
        window.closed.connect(() => {
            if (managedWindow === window) {
                managedWindow = undefined;
                dropdownHidden = false;
                revealingWindow = undefined;
            }
        });
    }

    if (!reveal) {
        // Adopted while the script was (re)loaded: keep the window exactly as
        // the user left it, including a drawer that is currently hidden.
        dropdownHidden = window.opacity === 0;
        return;
    }

    revealDropdown(window, output);
}

function manageNewWindow(window) {
    if (!hasDropdownIdentity(window)) {
        return;
    }
    window.opacity = 0;
    callDBus(
        controllerService,
        controllerPath,
        controllerService,
        "Register",
        window.pid,
        (current) => {
            if (window.deleted) {
                return;
            }
            if (current) {
                startingDropdown = false;
                configureNewWindow(window, true);
            } else {
                // A new normal window belonging to an already promoted process.
                promotedWindows.push(window);
                window.opacity = 1;
            }
        }
    );
}

function classifyExistingWindow(window) {
    if (!hasDropdownIdentity(window)) {
        return;
    }
    callDBus(
        controllerService,
        controllerPath,
        controllerService,
        "IsCurrent",
        window.pid,
        (current) => {
            if (current) {
                configureNewWindow(window, false);
            } else if (!isPromoted(window)) {
                promotedWindows.push(window);
            }
        }
    );
}

registerShortcut(
    "Toggle Ghostty Dropdown",
    "Show or hide the Ghostty drop-down terminal",
    toggleShortcut,
    toggleDropdown
);

registerShortcut(
    "Promote Ghostty Dropdown Session",
    "Turn the drawer into a normal Ghostty window",
    promoteShortcut,
    promoteActiveDropdown
);

// Key-less: the drawer shell hides the window through its controller, which
// keeps "hide" distinct from the toggle shortcut (that one can start a drawer).
registerShortcut(
    "Hide Ghostty Dropdown",
    "Hide the Ghostty drop-down terminal without touching its terminal session",
    "",
    hideActiveDropdown
);

workspace.windowList().forEach(classifyExistingWindow);
workspace.windowAdded.connect(manageNewWindow);
