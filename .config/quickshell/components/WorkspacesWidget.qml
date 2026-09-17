import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Row {
    id: root

    Theme { id: theme }

    spacing: 5
    height: 28

    // Target screen passed from shell.qml
    property var targetScreen: null

    // Monitor name (e.g. "eDP-1" or "HDMI-A-1")
    property string screenName: {
        if (targetScreen && targetScreen.name) return targetScreen.name;
        return "";
    }

    // Determine if this screen is the primary laptop display
    property bool isPrimaryScreen: {
        if (screenName !== "") {
            return screenName.indexOf("eDP") !== -1;
        }
        return true;
    }

    // Model of workspaces: 1-5 for primary screen, 6-10 for secondary / external screen
    property var workspacesModel: isPrimaryScreen ? [1, 2, 3, 4, 5] : [6, 7, 8, 9, 10]

    // Query Hyprland monitor for this screen
    property var hyprMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    property var monitorActiveWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
    property bool isMonitorFocused: hyprMonitor ? hyprMonitor.focused : false

    // Active workspace ID on this monitor
    property int activeWorkspaceId: {
        if (monitorActiveWorkspace && monitorActiveWorkspace.id !== undefined && monitorActiveWorkspace.id > 0) {
            return monitorActiveWorkspace.id;
        }
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id !== undefined) {
            let fid = Hyprland.focusedWorkspace.id;
            if (root.workspacesModel.indexOf(fid) !== -1) {
                return fid;
            }
        }
        return isPrimaryScreen ? 1 : 6;
    }

    // Map of workspace client info: { [wsId]: { count, icon, appClass, title, summary } }
    property var workspaceInfo: ({})

    function resolveAppIcon(client) {
        if (!client) return "";
        let cls = client.class || client.initialClass || "";
        if (!cls) return "";

        // 1. Direct match with Quickshell.iconPath
        let icon = Quickshell.iconPath(cls);
        if (icon) return icon;

        let lower = cls.toLowerCase();
        icon = Quickshell.iconPath(lower);
        if (icon) return icon;

        // 2. Specific known classes & wrappers
        if (lower.startsWith("chrome-") || lower.indexOf("chromium") !== -1) {
            return Quickshell.iconPath("chromium") || Quickshell.iconPath("google-chrome");
        }
        if (lower.indexOf("code") !== -1 || lower.indexOf("vscode") !== -1) {
            return Quickshell.iconPath("code") || Quickshell.iconPath("visual-studio-code");
        }
        if (lower.indexOf("kitty") !== -1) {
            return Quickshell.iconPath("kitty");
        }
        if (lower.indexOf("spotify") !== -1) {
            return Quickshell.iconPath("spotify-launcher") || Quickshell.iconPath("spotify");
        }
        if (lower.indexOf("dolphin") !== -1) {
            return Quickshell.iconPath("org.kde.dolphin") || Quickshell.iconPath("system-file-manager");
        }
        if (lower.indexOf("antigravity") !== -1) {
            return Quickshell.iconPath("antigravity-ide") || Quickshell.iconPath("antigravity");
        }
        if (lower.indexOf("devin") !== -1) {
            return Quickshell.iconPath("devin-desktop");
        }
        if (lower.indexOf("terminal") !== -1 || lower.indexOf("alacritty") !== -1 || lower.indexOf("wezterm") !== -1 || lower.indexOf("foot") !== -1) {
            return Quickshell.iconPath("utilities-terminal");
        }
        if (lower.indexOf("thunar") !== -1 || lower.indexOf("nautilus") !== -1 || lower.indexOf("file") !== -1) {
            return Quickshell.iconPath("system-file-manager");
        }
        if (lower.indexOf("easyeffects") !== -1) {
            return Quickshell.iconPath("com.github.wwmm.easyeffects");
        }
        if (lower.indexOf("pavucontrol") !== -1) {
            return Quickshell.iconPath("multimedia-volume-control");
        }

        return Quickshell.iconPath("application-x-executable") || "";
    }

    function updateClientsData(clientsList) {
        if (!clientsList || !Array.isArray(clientsList)) return;

        let map = {};
        for (let i = 0; i < clientsList.length; i++) {
            let c = clientsList[i];
            let wsId = (c.workspace && c.workspace.id !== undefined) ? c.workspace.id : null;
            if (wsId === null || wsId === undefined || wsId <= 0) continue;

            let sz = c.size || [0, 0];
            let area = (sz[0] || 0) * (sz[1] || 0);

            if (!map[wsId]) {
                map[wsId] = {
                    count: 0,
                    largestArea: -1,
                    largestClient: null,
                    titles: []
                };
            }

            map[wsId].count += 1;
            if (c.title) map[wsId].titles.push(c.title);

            // Keep the client occupying the most screen space
            if (area > map[wsId].largestArea) {
                map[wsId].largestArea = area;
                map[wsId].largestClient = c;
            }
        }

        let newInfo = {};
        for (let wsKey in map) {
            let item = map[wsKey];
            let client = item.largestClient;
            let icon = resolveAppIcon(client);
            newInfo[wsKey] = {
                count: item.count,
                icon: icon,
                appClass: client ? (client.class || client.initialClass || "") : "",
                title: client ? (client.title || "") : "",
                summary: item.titles.join(", ")
            };
        }
        root.workspaceInfo = newInfo;
    }

    function refreshClients() {
        if (!clientsProc.running) {
            clientsProc.running = true;
        }
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let data = JSON.parse(txt);
                    root.updateClientsData(data);
                } catch(e) {
                    // Ignore transient parsing issues
                }
            }
        }
    }

    // React in real time to Hyprland window and workspace events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            let name = event.name;
            if (name === "openwindow" || name === "closewindow" || name === "movewindow" ||
                name === "movewindowv2" || name === "changefloatingmode" || name === "fullscreen" ||
                name === "activewindow" || name === "activewindowv2" || name === "workspace" ||
                name === "focusedmon") {
                root.refreshClients();
            }
        }
    }

    // Periodic safety check
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.refreshClients()
    }

    Repeater {
        model: root.workspacesModel

        Rectangle {
            id: wsPill
            width: 28
            height: 28
            radius: theme.radiusSmall
            anchors.verticalCenter: parent.verticalCenter

            property int wsId: modelData
            property bool isCurrent: root.activeWorkspaceId === wsId
            property bool isFocused: isCurrent && (root.isMonitorFocused || (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId))

            property var wsData: root.workspaceInfo[wsId] || null
            property bool hasClients: wsData !== null && wsData.count > 0
            property string iconSource: hasClients ? (wsData.icon || "") : ""
            property int clientCount: hasClients ? wsData.count : 0
            property bool imageError: false

            color: {
                if (isFocused) return theme.blue;
                if (isCurrent) return Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.35);
                if (wsMouse.containsMouse) return Qt.rgba(255, 255, 255, 0.14);
                return Qt.rgba(255, 255, 255, 0.06);
            }

            border.color: {
                if (isFocused) return theme.blueLight;
                if (isCurrent) return theme.blue;
                if (wsMouse.containsMouse) return Qt.rgba(255, 255, 255, 0.24);
                return Qt.rgba(255, 255, 255, 0.10);
            }
            border.width: 1

            Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }
            Behavior on border.color { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }

            scale: wsMouse.pressed ? 0.96 : (wsMouse.containsMouse ? 1.03 : 1.0)
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }

            // 1. App Icon (shown when there are clients and icon loaded successfully)
            Image {
                id: appIconImg
                anchors.centerIn: parent
                width: 17
                height: 17
                source: wsPill.iconSource
                sourceSize: Qt.size(24, 24)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: wsPill.hasClients && wsPill.iconSource !== "" && !wsPill.imageError

                onStatusChanged: {
                    if (status === Image.Error) {
                        wsPill.imageError = true;
                    } else if (status === Image.Ready) {
                        wsPill.imageError = false;
                    }
                }
            }

            // 2. Workspace Number (shown when no clients open or icon not found)
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: wsPill.wsId
                visible: !appIconImg.visible
                color: {
                    if (wsPill.isFocused) return "#ffffff";
                    if (wsPill.isCurrent) return theme.blueLight;
                    if (wsMouse.containsMouse) return theme.text;
                    return theme.textMuted;
                }
                font.family: theme.fontFamily
                font.pixelSize: 11
                font.weight: wsPill.isCurrent ? Font.Bold : Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            // 3. Multi-window Badge (shows client count when more than 1 window is open)
            Rectangle {
                visible: wsPill.clientCount > 1
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.rightMargin: 1
                width: 10
                height: 10
                radius: 5
                color: wsPill.isFocused ? "#ffffff" : theme.blue
                border.color: theme.bgDark
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: wsPill.clientCount
                    color: wsPill.isFocused ? theme.bgDark : "#ffffff"
                    font.family: theme.fontFamily
                    font.pixelSize: 7
                    font.weight: Font.Bold
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.ArrowCursor
            }
        }
    }
}
