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
        if (allApps.length === 0 && !scanProc.running) {
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
        if (calcResult !== "") {
            // Copy calculation result to clipboard
            launchProc.command = ["sh", "-c", "echo -n '" + calcResult + "' | wl-copy"];
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

    function filterList(query) {
        let q = query.trim().toLowerCase();
        selectedIndex = 0;

        // Check math
        calcResult = evaluateMath(query);

        if (q === "") {
            filteredApps = [];
            return;
        }

        let matches = [];
        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i];
            let name = (app.name || "").toLowerCase();
            let comment = (app.comment || "").toLowerCase();
            let execCmd = (app.exec || "").toLowerCase();

            let score = -1;
            if (name.startsWith(q)) score = 100 - name.length;
            else if (name.indexOf(q) !== -1) score = 70 - name.indexOf(q);
            else if (execCmd.startsWith(q)) score = 50;
            else if (comment.indexOf(q) !== -1) score = 30;

            if (score > 0) {
                matches.push({ app: app, score: score });
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
        width: 600
        implicitHeight: contentColumn.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.22)

        color: theme.popupBg
        border.color: theme.border
        border.width: 1
        radius: 16
        clip: true

        opacity: launcherWindow.isOpen ? 1.0 : 0.0
        scale: launcherWindow.isOpen ? 1.0 : 0.95
        transform: Translate {
            y: launcherWindow.isOpen ? 0 : -14
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        // Top specular reflection hairline
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: theme.glassHighlight
        }

        Column {
            id: contentColumn
            width: parent.width

            // --- A. Search Input Row ---
            Item {
                width: parent.width
                height: 56

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    // Magnifying glass icon with theme accent
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        font.family: "GeistMono Nerd Font Propo"
                        font.pixelSize: 18
                        color: theme.blueLight
                    }

                    // Search input
                    TextInput {
                        id: searchInput
                        width: parent.width - 90
                        anchors.verticalCenter: parent.verticalCenter
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
                            if (event.key === Qt.Key_Escape) {
                                launcherWindow.close();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                if (launcherWindow.selectedIndex < launcherWindow.filteredApps.length - 1) {
                                    launcherWindow.selectedIndex++;
                                    appListView.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
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

                    // ESC pill indicator or clear button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: escTxt.implicitWidth + 12
                        height: 22
                        radius: 6
                        color: theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Text {
                            id: escTxt
                            anchors.centerIn: parent
                            text: searchInput.text.length > 0 ? "ESC" : "ESC"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (searchInput.text.length > 0) searchInput.text = "";
                                else launcherWindow.close();
                            }
                        }
                    }
                }
            }

            // Divider line
            Rectangle {
                width: parent.width
                height: 1
                color: theme.borderSubtle
                visible: (appListView.height > 0) || (mathCard.visible)
            }

            // --- B. Live Math / Calculation Result Card ---
            Rectangle {
                id: mathCard
                visible: launcherWindow.calcResult !== ""
                width: parent.width
                height: 48
                color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.14)
                border.color: theme.blue
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 14

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰪚"
                        font.family: "GeistMono Nerd Font Propo"
                        font.pixelSize: 18
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
                            text: "Press Enter to copy result"
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

            // --- C. Applications List ---
            ListView {
                id: appListView
                width: parent.width
                height: {
                    if (searchInput.text.trim().length === 0) return 0;
                    if (launcherWindow.filteredApps.length === 0 && launcherWindow.calcResult === "") return 110;
                    return Math.min(360, count * 50);
                }
                visible: height > 0
                clip: true
                model: launcherWindow.filteredApps
                boundsBehavior: Flickable.StopAtBounds

                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                delegate: Rectangle {
                    id: itemDelegate
                    required property var modelData
                    required property int index

                    width: appListView.width
                    height: 50
                    readonly property bool isSelected: index === launcherWindow.selectedIndex

                    color: isSelected ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.16)
                         : itemMouse.containsMouse ? theme.surfaceHover
                         : "transparent"

                    Behavior on color { ColorAnimation { duration: 120 } }

                    // Left selection indicator
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 24
                        radius: 1.5
                        color: theme.blue
                        visible: itemDelegate.isSelected
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        // App Icon Tile
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: 8
                            color: theme.surface
                            border.color: theme.borderSubtle
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
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 64
                            spacing: 1

                            Text {
                                text: modelData.name || ""
                                color: itemDelegate.isSelected ? theme.text : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: itemDelegate.isSelected ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.comment ? modelData.comment : (modelData.exec || "")
                                color: itemDelegate.isSelected ? theme.blueLight : theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
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
                            font.pixelSize: 24
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

            // --- D. Bottom Status Bar ---
            Rectangle {
                width: parent.width
                height: 34
                color: theme.surface
                border.color: theme.borderSubtle
                border.width: 1
                visible: searchInput.text.trim().length > 0 && launcherWindow.filteredApps.length > 0

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: launcherWindow.filteredApps.length + (launcherWindow.filteredApps.length === 1 ? " app" : " apps")
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true; width: parent.width - 200 }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: "↑↓ Navigate"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                        }
                        Text {
                            text: "ESC Close"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    // IPC Endpoint: qs ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { launcherWindow.toggle(); }
        function open(): void { launcherWindow.open(); }
        function close(): void { launcherWindow.close(); }
        function isOpen(): bool { return launcherWindow.isOpen; }
    }
}
