const dropdownAppId = "com.mitchellh.ghostty.dropdown";
const dropdownUnit = "ghostty-dropdown.service";
const controllerService = "com.mitchellh.ghostty.DropdownController";
const controllerPath = "/com/mitchellh/ghostty/DropdownController";

let pendingOutputName = "";
let targetOutputName = "";
let managedWindow;
let changingGeometry = false;
let handlingHideRequest = false;
let revealSerial = 0;
let dropdownHidden = false;
let returnWindow;

function isDropdown(window) {
    return String(window.resourceClass).toLowerCase() === dropdownAppId
        || String(window.resourceName).toLowerCase() === dropdownAppId;
}

function findDropdown() {
    return workspace.windowList().find(isDropdown);
}

function focusedOutput() {
    const active = workspace.activeWindow;
    if (active !== null && active !== undefined && !isDropdown(active) && active.output) {
        return active.output;
    }
    return workspace.activeScreen;
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

function enforceGeometry(window, output, desktop) {
    if (changingGeometry) {
        return;
    }

    const wanted = desiredGeometry(output, desktop);
    const current = window.frameGeometry;
    if (Math.abs(current.x - wanted.x) <= 1
            && Math.abs(current.y - wanted.y) <= 1
            && Math.abs(current.width - wanted.width) <= 1
            && Math.abs(current.height - wanted.height) <= 1) {
        return;
    }

    changingGeometry = true;
    window.frameGeometry = wanted;
    changingGeometry = false;
}

function prepareDropdown(window, output) {
    if (!output) {
        output = workspace.activeScreen;
    }

    const desktop = workspace.currentDesktopForScreen(output) || workspace.currentDesktop;
    targetOutputName = output.name;

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
    window.opacity = 0;
    prepareDropdown(window, output);

    callDBus(
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "GetUnit",
        dropdownUnit,
        () => {
            if (serial !== revealSerial || dropdownHidden || managedWindow !== window) {
                return;
            }
            const target = outputByName(targetOutputName) || window.output || workspace.activeScreen;
            const desktop = workspace.currentDesktopForScreen(target) || workspace.currentDesktop;
            enforceGeometry(window, target, desktop);
            window.minimized = false;
            window.opacity = 1;
            workspace.raiseWindow(window);
            workspace.activeWindow = window;
        }
    );
}

function hideDropdown(window) {
    ++revealSerial;
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
    const desktop = workspace.currentDesktopForScreen(output) || workspace.currentDesktop;
    const geometry = desiredGeometry(output, desktop);
    callDBus(
        controllerService,
        controllerPath,
        controllerService,
        "Start",
        geometry.x,
        geometry.y,
        geometry.width,
        geometry.height
    );
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
    pendingOutputName = output ? output.name : "";
    startDropdown(output);
}

function promoteDropdownSession() {
    const window = findDropdown();
    if (window !== undefined && !dropdownHidden) {
        hideDropdown(window);
    }

    callDBus(
        controllerService,
        controllerPath,
        controllerService,
        "Promote"
    );
}

function configureNewWindow(window) {
    if (!isDropdown(window)) {
        return;
    }

    const output = outputByName(pendingOutputName) || focusedOutput();
    pendingOutputName = "";
    if (managedWindow !== window) {
        managedWindow = window;
        window.frameGeometryChanged.connect(() => {
            if (dropdownHidden) {
                return;
            }
            const target = outputByName(targetOutputName) || window.output || workspace.activeScreen;
            const desktop = workspace.currentDesktopForScreen(target) || workspace.currentDesktop;
            enforceGeometry(window, target, desktop);
        });
        window.maximizedChanged.connect(() => {
            if (dropdownHidden || handlingHideRequest || managedWindow !== window) {
                return;
            }

            handlingHideRequest = true;
            window.setMaximize(false, false);
            handlingHideRequest = false;
            hideDropdown(window);
        });
        window.closed.connect(() => {
            if (managedWindow === window) {
                managedWindow = undefined;
                dropdownHidden = false;
            }
        });
    }
    dropdownHidden = false;
    prepareDropdown(window, output);
    window.minimized = false;
    window.opacity = 1;
    workspace.raiseWindow(window);
    workspace.activeWindow = window;
}

registerShortcut(
    "Toggle Ghostty Dropdown",
    "Show or hide the Ghostty drop-down terminal",
    "Meta+`",
    toggleDropdown
);

registerShortcut(
    "Promote Ghostty Dropdown Session",
    "Move the drawer tmux session to a normal Ghostty window",
    "Meta+F",
    promoteDropdownSession
);

workspace.windowList().forEach(configureNewWindow);
workspace.windowAdded.connect(configureNewWindow);
