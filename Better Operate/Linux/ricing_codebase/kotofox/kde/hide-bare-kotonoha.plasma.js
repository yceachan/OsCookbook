panels().forEach(function (panel) {
    panel.widgets().forEach(function (widget) {
        widget.currentConfigGroup = ["General"];
        if (widget.type === "org.kde.plasma.systemtray") {
            var disabled = widget.readConfig("disabledStatusNotifiers", []);
            if (disabled.indexOf("kotonoha") < 0) {
                disabled.push("kotonoha");
            }
            widget.writeConfig("disabledStatusNotifiers", disabled);
            var shown = widget.readConfig("shownItems", []).filter(function (id) {
                return id !== "kotonoha";
            });
            widget.writeConfig("shownItems", shown);
        }
        if (widget.type === "org.kde.plasma.icontasks" || widget.type === "org.kde.plasma.taskmanager") {
            var launchers = widget.readConfig("launchers", []);
            var cleaned = launchers.filter(function (id) {
                return id !== "applications:kotonoha.desktop";
            });
            if (cleaned.length !== launchers.length) {
                widget.writeConfig("launchers", cleaned);
            }
        }
    });
});
