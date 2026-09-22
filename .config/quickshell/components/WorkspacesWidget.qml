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

    // Official Spotify SVG
    property string spotifySvgUri: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.78) translate(-12, -12)'><path fill-rule='evenodd' clip-rule='evenodd' d='M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z' fill='%231ed760'/></g></svg>"

    // Official GitHub Octocat SVG
    property string githubSvgUri: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='%23ffffff'><path fill-rule='evenodd' clip-rule='evenodd' d='M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z'/></svg>"

    // Map of workspace client info: { [wsId]: { count, icon, appClass, title, summary } }
    property var workspaceInfo: ({})

    // Rules to dynamically detect active browser tabs by window title
    property var webTabRules: [
        { keywords: ["leetcode"], icon: "file:///home/ferram/.local/share/icons/leetcode.svg" },
        { keywords: ["youtube", "youtu.be"], icon: "file:///home/ferram/.local/share/icons/youtube.svg" },
        { keywords: ["instagram"], icon: "file:///home/ferram/.local/share/icons/instagram.svg" },
        { keywords: ["whatsapp"], icon: "file:///home/ferram/.local/share/icons/whatsapp.svg" },
        { keywords: ["chatgpt", "openai"], icon: "file:///home/ferram/.local/share/icons/chatgpt.svg" },
        { keywords: ["reddit"], icon: "file:///home/ferram/.local/share/icons/reddit.svg" },
        { keywords: ["github"], icon: root.githubSvgUri },
        { keywords: ["twitch"], icon: "file:///home/ferram/.local/share/icons/twitch.svg" },
        { keywords: ["netflix"], icon: "file:///home/ferram/.local/share/icons/netflix.svg" },
        { keywords: ["notion"], icon: "file:///home/ferram/.local/share/icons/notion.svg" },
        { keywords: ["twitter", "x.com", " x - "], icon: "file:///home/ferram/.local/share/icons/x.svg" },
        { keywords: ["discord"], icon: "file:///home/ferram/.local/share/icons/discord.svg" },
        { keywords: ["telegram", "web.telegram"], icon: "file:///home/ferram/.local/share/icons/telegram.svg" },
        { keywords: ["spotify"], icon: root.spotifySvgUri },
        { keywords: ["claude", "anthropic"], icon: "file:///home/ferram/.local/share/icons/claude.svg" },
        { keywords: ["gemini", "bard.google"], icon: "file:///home/ferram/.local/share/icons/gemini.svg" },
        { keywords: ["gmail", "mail.google"], icon: "file:///home/ferram/.local/share/icons/gmail.svg" },
        { keywords: ["classroom", "google classroom"], icon: "file:///home/ferram/.local/share/icons/classroom.svg" },
        { keywords: ["google docs", "docs.google", "documentos de google", "documento de google"], icon: "file:///home/ferram/.local/share/icons/docs.svg" },
        { keywords: ["google sheets", "sheets.google", "hojas de cálculo de google", "hoja de cálculo de google", "hojas de calculo"], icon: "file:///home/ferram/.local/share/icons/sheets.svg" },
        { keywords: ["google slides", "slides.google", "presentaciones de google", "presentación de google", "presentacion de google"], icon: "file:///home/ferram/.local/share/icons/slides.svg" },
        { keywords: ["google drive", "drive.google", "mi unidad", "my drive"], icon: "file:///home/ferram/.local/share/icons/drive.svg" },
        { keywords: ["google meet", "meet.google", "meet - "], icon: "file:///home/ferram/.local/share/icons/meet.svg" },
        { keywords: ["google calendar", "calendar.google", "calendario de google"], icon: "file:///home/ferram/.local/share/icons/calendar.svg" },
        { keywords: ["google forms", "forms.google", "formularios de google", "formulario de google"], icon: "file:///home/ferram/.local/share/icons/forms.svg" },
        { keywords: ["google keep", "keep.google"], icon: "file:///home/ferram/.local/share/icons/keep.svg" },
        { keywords: ["google search", "búsqueda de google", "busqueda de google", "google"], icon: "file:///home/ferram/.local/share/icons/google.svg" }
    ]

    function resolveWebTabIcon(titleLower) {
        if (!titleLower) return "";
        for (let i = 0; i < root.webTabRules.length; i++) {
            let rule = root.webTabRules[i];
            for (let k = 0; k < rule.keywords.length; k++) {
                if (titleLower.indexOf(rule.keywords[k]) !== -1) {
                    return rule.icon;
                }
            }
        }
        return "";
    }

    function resolveAppIcon(client) {
        if (!client) return "";
        let cls = client.class || client.initialClass || "";
        if (!cls) return "";

        let lower = cls.toLowerCase();
        let titleLower = (client.title || "").toLowerCase();

        // 1. Specific known apps & wrappers (checked FIRST to avoid generic fallback)
        if (lower.indexOf("spotify") !== -1) {
            return root.spotifySvgUri;
        }
        if (lower.indexOf("github") !== -1 || titleLower.indexOf("github") !== -1) {
            return Quickshell.iconPath(cls) || root.githubSvgUri;
        }
        if (lower.startsWith("chrome-")) {
            let pwaIcon = Quickshell.iconPath(cls);
            if (pwaIcon) return pwaIcon;
            let tabIcon = root.resolveWebTabIcon(titleLower);
            if (tabIcon) return tabIcon;
        }

        // 2. Web browser windows: detect active tab by window title!
        if (lower.indexOf("chromium") !== -1 || lower.indexOf("chrome") !== -1 || lower.indexOf("brave") !== -1) {
            let tabIcon = root.resolveWebTabIcon(titleLower);
            if (tabIcon) return tabIcon;
            return "file:///home/ferram/.local/share/icons/chromium.svg";
        }

        // 3. Known desktop applications
        if (lower.indexOf("whatsapp") !== -1 || titleLower.indexOf("whatsapp") !== -1) {
            return "file:///home/ferram/.local/share/icons/whatsapp.svg";
        }
        if (lower.indexOf("instagram") !== -1 || titleLower.indexOf("instagram") !== -1) {
            return "file:///home/ferram/.local/share/icons/instagram.svg";
        }
        if (lower.indexOf("hypr") !== -1 || lower.indexOf("arch") !== -1) {
            return "file:///home/ferram/.local/share/icons/arch.svg";
        }
        if (lower.indexOf("code") !== -1 || lower.indexOf("vscode") !== -1) {
            return Quickshell.iconPath("code") || Quickshell.iconPath("visual-studio-code");
        }
        if (lower.indexOf("kitty") !== -1) {
            return Quickshell.iconPath("kitty");
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

        // 4. Direct match with Quickshell.iconPath
        let icon = Quickshell.iconPath(cls);
        if (icon) return icon;

        icon = Quickshell.iconPath(lower);
        if (icon) return icon;

        return Quickshell.iconPath("application-x-executable") || "file:///home/ferram/.local/share/icons/arch.svg";
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
            width: isFocused ? 36 : (isCurrent ? 32 : 28)
            height: 28
            radius: theme.radiusSmall
            anchors.verticalCenter: parent.verticalCenter

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

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

            scale: wsMouse.pressed ? 0.95 : (wsMouse.containsMouse ? 1.04 : 1.0)
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

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

                scale: wsPill.isFocused ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

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

                scale: wsPill.isFocused ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            }

            // 3. Multi-window Badge (shows client count when more than 1 window is open)
            Rectangle {
                visible: wsPill.clientCount > 1
                scale: wsPill.clientCount > 1 ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

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
