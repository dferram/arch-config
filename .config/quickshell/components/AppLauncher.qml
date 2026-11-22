import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"

// ==============================================================================
// APP LAUNCHER (Spotlight / Raycast Style Liquid Obsidian Glass)
// Replaces hyprlauncher with a modern, fluid, beautifully integrated launcher.
// IPC:  qs ipc call launcher toggle
//       qs ipc call launcher open
//       qs ipc call launcher close
// ==============================================================================
PanelWindow {
    id: launcherWindow

    Theme { id: theme }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: isOpen || card.opacity > 0.01

    // State
    property bool isOpen: false
    property var allApps: []
    property var filteredApps: []
    property int selectedIndex: 0
    property string calcResult: ""

    function open() {
        isOpen = true;
        searchInput.text = "";
        selectedIndex = 0;
        filterList("");
        if (!scanProc.running) {
            scanProc.running = true;
        }
        openTimer.restart();
    }

    function close() {
        isOpen = false;
        searchInput.text = "";
        calcResult = "";
    }

    function toggle() {
        if (isOpen) close();
        else open();
    }

    Timer {
        id: openTimer
        interval: 30
        onTriggered: searchInput.forceActiveFocus()
    }

    // Process to scan installed desktop apps
    Process {
        id: scanProc
        command: ["python3", Quickshell.shellPath("scripts/app-launcher-scanner.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let res = JSON.parse(text);
                    launcherWindow.allApps = Array.isArray(res) ? res : [];
                    launcherWindow.filterList(searchInput.text);
                } catch (e) {
                    console.warn("Error parsing launcher apps:", e);
                }
            }
        }
    }

    // Process to launch application
    Process {
        id: launchProc
    }

    function launchSelected() {
        if (launchProc.running) {
            launchProc.running = false;
        }

        if (calcResult !== "") {
            // Copy calculation result to clipboard without shell interpolation
            launchProc.command = ["wl-copy", calcResult];
            launchProc.running = true;
            close();
            return;
        }

        if (filteredApps.length === 0 || selectedIndex < 0 || selectedIndex >= filteredApps.length) return;
        let item = filteredApps[selectedIndex];
        launchProc.command = [
            "python3",
            Quickshell.shellPath("scripts/app-launcher-scanner.py"),
            "launch",
            item.id || "",
            item.exec || "",
            item.terminal ? "true" : "false"
        ];
        launchProc.running = true;
        close();
    }

    // Simple, safe math expression evaluator
    function evaluateMath(expr) {
        let clean = expr.trim();
        // Check if expression looks like math: e.g. "12 + 5", "100 * 1.16", "2^8", "sqrt(144)"
        if (!/^[0-9\.\s\+\-\*\/\%\(\)\^]+$/.test(clean) && !/^sqrt\([0-9\.]+\)$/i.test(clean)) {
            return "";
        }
        // Must contain at least one operator
        if (!/[\+\-\*\/\%\^]|sqrt/i.test(clean)) {
            return "";
        }
        try {
            let sanitized = clean.replace(/\^/g, "**");
            sanitized = sanitized.replace(/sqrt\(([0-9\.]+)\)/gi, "Math.sqrt($1)");
            // Evaluate safely using Function
            let val = Function('"use strict"; return (' + sanitized + ')')();
            if (typeof val === "number" && !isNaN(val) && isFinite(val)) {
                // Round nicely if floating point
                if (Math.abs(val - Math.round(val)) < 0.000001) return String(Math.round(val));
                return String(parseFloat(val.toFixed(4)));
            }
        } catch (e) {}
        return "";
    }

    function fuzzyScore(text, query) {
        if (!text || !query) return -1;
        let ti = 0;
        let qi = 0;
        let consecutive = 0;
        let bonus = 0;
        while (ti < text.length && qi < query.length) {
            if (text[ti] === query[qi]) {
                consecutive++;
                bonus += consecutive * 2;
                if (ti === 0 || text[ti - 1] === " " || text[ti - 1] === "-") bonus += 4;
                qi++;
            } else {
                consecutive = 0;
            }
            ti++;
        }
        return qi === query.length ? Math.max(10, 35 + bonus - Math.floor(text.length * 0.25)) : -1;
    }

    function filterList(query) {
        let q = query.trim().toLowerCase();
        selectedIndex = 0;

        // Check math
        calcResult = evaluateMath(query);

        if (q === "") {
            let recent = [];
            for (let i = 0; i < allApps.length; i++) {
                if ((allApps[i].lastUsed || 0) > 0) {
                    recent.push(allApps[i]);
                }
            }
            recent.sort((a, b) => (b.lastUsed || 0) - (a.lastUsed || 0));
            filteredApps = recent.slice(0, 6);
            return;
        }

        let tokens = q.split(/\s+/).filter(t => t.length > 0);
        let matches = [];
        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i];
            let name = (app.name || "").toLowerCase();
            let comment = (app.comment || "").toLowerCase();
            let keywords = (app.keywords || "").toLowerCase();
            let execCmd = (app.exec || "").toLowerCase();
            let haystack = name + " " + keywords + " " + comment + " " + execCmd;
            let frecency = app.frecency || 0;

            let score = -1;
            if (name.startsWith(q)) {
                score = 120 - name.length;
            } else if (name.indexOf(q) !== -1) {
                score = 85 - name.indexOf(q);
            } else if (keywords.indexOf(q) !== -1) {
                score = 65;
            } else if (execCmd.startsWith(q) || execCmd.indexOf(q) !== -1) {
                score = 55;
            } else if (comment.indexOf(q) !== -1) {
                score = 40;
            } else if (tokens.length > 1 && tokens.every(t => haystack.indexOf(t) !== -1)) {
                score = 50;
            } else {
                score = fuzzyScore(name, q);
            }

            if (score > 0) {
                matches.push({ app: app, score: score + frecency });
            }
        }

        matches.sort((a, b) => b.score - a.score);
        let result = [];
        for (let i = 0; i < Math.min(12, matches.length); i++) {
            result.push(matches[i].app);
        }
        filteredApps = result;
    }

    // Icon resolver
    function resolveIcon(raw) {
        if (!raw) return "file:///home/ferram/.local/share/icons/arch.svg";
        let lower = raw.toLowerCase();

        // Custom high quality icons in ~/.local/share/icons
        if (lower.indexOf("spotify") !== -1) return "file:///home/ferram/.local/share/icons/spotify.svg";
        if (lower.indexOf("chrome") !== -1 || lower.indexOf("chromium") !== -1) return "file:///home/ferram/.local/share/icons/chromium.svg";
        if (lower.indexOf("discord") !== -1 || lower.indexOf("vesktop") !== -1) return "file:///home/ferram/.local/share/icons/discord.svg";
        if (lower.indexOf("kitty") !== -1) return "file:///home/ferram/.local/share/icons/kitty.svg";
        if (lower.indexOf("arch") !== -1) return "file:///home/ferram/.local/share/icons/arch.svg";
        if (lower.indexOf("whatsapp") !== -1) return "file:///home/ferram/.local/share/icons/whatsapp.svg";
        if (lower.indexOf("instagram") !== -1) return "file:///home/ferram/.local/share/icons/instagram.svg";
        if (lower.indexOf("antigravity") !== -1) return "file:///home/ferram/.local/share/icons/antigravity.png";
        if (lower.indexOf("stremio") !== -1) return "file:///home/ferram/.local/share/icons/stremio.svg";

        if (raw.startsWith("/") || raw.startsWith("file://")) return raw;

        // Quickshell icon lookup
        let qPath = Quickshell.iconPath(raw, true);
        if (qPath) return qPath;

        return "file:///home/ferram/.local/share/icons/arch.svg";
    }

    // 1. Fullscreen Backdrop (Click outside to close)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: launcherWindow.isOpen ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: launcherWindow.close()
        }
    }

    // 2. Central Spotlight Card
    Rectangle {
        id: card
        width: 580
        implicitHeight: contentColumn.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.22)

        color: Qt.rgba(14 / 255, 16 / 255, 24 / 255, 0.90)
        border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.42)
        border.width: 1
        radius: 14
        clip: true

        opacity: launcherWindow.isOpen ? 1.0 : 0.0
        scale: launcherWindow.isOpen ? 1.0 : 0.96
        transform: Translate {
            y: launcherWindow.isOpen ? 0 : -10
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Column {
            id: contentColumn
            width: parent.width

            // --- A. Search Input Row ---
            Item {
                width: parent.width
                height: 54

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    // Magnifying glass icon (dynamic wallpaper accent)
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "󰍉"
                        font.family: "GeistMono Nerd Font Propo"
                        font.pixelSize: 17
                        color: searchInput.text.length > 0 ? theme.blueLight : theme.blue
                    }

                    // Search input
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        clip: true
                        selectByMouse: true
                        selectionColor: theme.blueDeep

                        Text {
                            anchors.fill: parent
                            visible: searchInput.text.length === 0
                            text: "Search apps or calculate…"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 15
                        }

                        onTextChanged: {
                            launcherWindow.filterList(text);
                        }

                        Keys.onPressed: event => {
                            let moveDown = (event.key === Qt.Key_Down) ||
                                           (event.key === Qt.Key_Tab) ||
                                           ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_J || event.key === Qt.Key_N));
                            let moveUp = (event.key === Qt.Key_Up) ||
                                         (event.key === Qt.Key_Backtab) ||
                                         ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_K || event.key === Qt.Key_P));

                            if (event.key === Qt.Key_Escape) {
                                launcherWindow.close();
                                event.accepted = true;
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U) {
                                searchInput.text = "";
                                event.accepted = true;
                            } else if (moveDown) {
                                if (launcherWindow.selectedIndex < launcherWindow.filteredApps.length - 1) {
                                    launcherWindow.selectedIndex++;
                                    appListView.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (moveUp) {
                                if (launcherWindow.selectedIndex > 0) {
                                    launcherWindow.selectedIndex--;
                                    appListView.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                launcherWindow.launchSelected();
                                event.accepted = true;
                            }
                        }
                    }
                }
            }

            // Divider line
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: (appListView.height > 0) || (mathCard.visible)
            }

            // --- B. Live Math / Calculation Result Card ---
            Item {
                id: mathCard
                visible: launcherWindow.calcResult !== ""
                width: parent.width
                height: 58

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 10
                    color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.16)
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.48)
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰪚"
                            font.family: "GeistMono Nerd Font Propo"
                            font.pixelSize: 17
                            color: theme.blueLight
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                text: "= " + launcherWindow.calcResult
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }
                            Text {
                                text: "Copy result"
                                color: theme.blueLight
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: launcherWindow.launchSelected()
                    }
                }
            }

            // --- C. Applications List ---
            ListView {
                id: appListView
                width: parent.width
                topMargin: 6
                bottomMargin: 6
                height: {
                    if (searchInput.text.trim().length === 0) {
                        return launcherWindow.filteredApps.length > 0 ? Math.min(312, count * 50 + 12) : 0;
                    }
                    if (launcherWindow.filteredApps.length === 0 && launcherWindow.calcResult === "") return 108;
                    return Math.min(362, count * 50 + 12);
                }
                visible: height > 0
                clip: true
                model: launcherWindow.filteredApps
                boundsBehavior: Flickable.StopAtBounds

                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                delegate: Item {
                    id: itemDelegate
                    required property var modelData
                    required property int index

                    width: appListView.width
                    height: 50
                    readonly property bool isSelected: index === launcherWindow.selectedIndex

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: 10

                        color: itemDelegate.isSelected ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.20)
                             : itemMouse.containsMouse ? theme.surfaceHover
                             : "transparent"
                        border.color: itemDelegate.isSelected ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.55) : "transparent"
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 12

                            // Clean Icon Container
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 8
                                color: itemDelegate.isSelected
                                    ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.20)
                                    : Qt.rgba(1, 1, 1, 0.06)
                                border.color: itemDelegate.isSelected
                                    ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.45)
                                    : "transparent"
                                border.width: 1

                                Image {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: launcherWindow.resolveIcon(modelData.icon)
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 40
                                    sourceSize.height: 40
                                    mipmap: true
                                }
                            }

                            // App Text (Name + Comment/Exec)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name || ""
                                    color: itemDelegate.isSelected ? theme.text : theme.textSub
                                    font.family: theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: itemDelegate.isSelected ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.comment ? modelData.comment : (modelData.exec || "")
                                    color: itemDelegate.isSelected ? theme.blueLight : theme.textDim
                                    font.family: theme.fontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: launcherWindow.selectedIndex = index
                        onClicked: {
                            launcherWindow.selectedIndex = index;
                            launcherWindow.launchSelected();
                        }
                    }
                }

                // Empty state
                Item {
                    anchors.fill: parent
                    visible: searchInput.text.trim().length > 0 && launcherWindow.filteredApps.length === 0 && launcherWindow.calcResult === ""

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰍉"
                            font.family: "GeistMono Nerd Font Propo"
                            font.pixelSize: 22
                            color: theme.textDim
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No applications found"
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                        }
                    }
                }
            }

            // --- D. Minimal Footer ---
            Rectangle {
                width: parent.width
                height: 28
                color: Qt.rgba(1, 1, 1, 0.03)
                visible: launcherWindow.filteredApps.length > 0

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.07)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    text: searchInput.text.trim().length === 0
                        ? (launcherWindow.filteredApps.length + " recent")
                        : (launcherWindow.filteredApps.length + (launcherWindow.filteredApps.length === 1 ? " app" : " apps"))
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }

    // IPC Endpoint: qs ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle() { launcherWindow.toggle(); }
        function open() { launcherWindow.open(); }
        function close() { launcherWindow.close(); }
        function isOpen(): bool { return launcherWindow.isOpen; }
    }
}
