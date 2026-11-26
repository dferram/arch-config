import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 216
    implicitHeight: 208

    radius: 20
    color: theme.widgetGlass
    border.color: theme.borderSubtle
    border.width: 1
    clip: true

    function findWrapper() {
        let p = root.parent;
        while (p) {
            if (p.overlay !== undefined && p.startDrag !== undefined) return p;
            if (p.wrapperRef !== undefined) return p.wrapperRef;
            p = p.parent;
        }
        return null;
    }
    readonly property var wrapper: findWrapper()
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    property var portsList: []
    property var containersList: []
    property bool dockerRunning: false

    function iconForKey(key, isDocker) {
        if (key === "docker") return "file://" + Quickshell.shellPath("icons/docker.svg");
        if (key === "postgresql") return "file://" + Quickshell.shellPath("icons/postgresql.svg");
        if (key === "node") return "file://" + Quickshell.shellPath("icons/node.svg");
        if (key === "ollama") return "file://" + Quickshell.shellPath("icons/ollama.svg");
        if (key === "vite") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23a78bfa' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'><path d='M13 2 3 14h9l-1 8 10-12h-9l1-8z' fill='%23facc15' fill-opacity='0.22'/></svg>";
        }
        if (key === "python") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2338bdf8' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M12 3c-3.5 0-4 1.5-4 3.5V9h5v1H6.5C4.5 10 3 11.5 3 14s1.5 4 3.5 4H8v-2.5c0-1.5 1-2.5 2.5-2.5h4c1.5 0 2.5-1 2.5-2.5V6.5C17 4.5 15.5 3 12 3z'/><circle cx='10.5' cy='6' r='0.8' fill='%23facc15' stroke='none'/><path d='M16 10v2.5c0 1.5-1 2.5-2.5 2.5h-4c-1.5 0-2.5 1-2.5 2.5v2c0 1.8 1.5 3 4.5 3s4.5-1.2 4.5-3.2V18h-4v-1h5.5c2 0 3.5-1.5 3.5-4s-1.5-4-3.5-4z' stroke='%23facc15'/></svg>";
        }
        if (key === "pgadmin") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2360a5fa' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><ellipse cx='12' cy='5' rx='8' ry='3'/><path d='M4 5v6c0 1.66 3.58 3 8 3s8-1.34 8-3V5'/><path d='M4 11v6c0 1.66 3.58 3 8 3'/><circle cx='17.5' cy='17.5' r='2.5' stroke='%23facc15'/><path d='m21 21-1.5-1.5' stroke='%23facc15'/></svg>";
        }
        if (key === "sitl") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2334d399' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='6' cy='6' r='2.5'/><circle cx='18' cy='6' r='2.5'/><circle cx='6' cy='18' r='2.5'/><circle cx='18' cy='18' r='2.5'/><path d='M8 8l8 8M16 8l-8 8'/><rect x='10' y='10' width='4' height='4' rx='1' fill='%2334d399'/></svg>";
        }
        if (key === "redis") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23f87171' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='m12 2 9 4.5-9 4.5-9-4.5Z'/><path d='m3 12 9 4.5 9-4.5'/><path d='m3 17.5 9 4.5 9-4.5'/></svg>";
        }
        if (key === "mongodb") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2334d399' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M12 22v-4'/><path d='M12 2C9 6 7 9.5 7 13a5 5 0 0 0 10 0c0-3.5-2-7-5-11Z' fill='%2334d399' fill-opacity='0.2'/></svg>";
        }
        if (key === "mysql") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2338bdf8' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><ellipse cx='12' cy='5' rx='8' ry='3'/><path d='M4 5v14c0 1.66 3.58 3 8 3s8-1.34 8-3V5'/><path d='M4 12c0 1.66 3.58 3 8 3s8-1.34 8-3'/></svg>";
        }
        if (key === "web") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2330d158' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='9'/><path d='M3 12h18'/><path d='M12 3a14 14 0 0 1 0 18 14 14 0 0 1 0-18Z'/></svg>";
        }
        if (isDocker) return "file://" + Quickshell.shellPath("icons/docker.svg");
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2394a3b8' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><rect x='3' y='4' width='18' height='6' rx='2'/><rect x='3' y='14' width='18' height='6' rx='2'/><circle cx='7' cy='7' r='1' fill='%2330d158' stroke='none'/><circle cx='7' cy='17' r='1' fill='%2330d158' stroke='none'/></svg>";
    }

    readonly property var combinedItems: {
        let arr = [];
        for (let i = 0; i < containersList.length; i++) {
            arr.push({
                "kind": "docker",
                "title": containersList[i].name,
                "subtitle": containersList[i].image,
                "badge": "UP",
                "url": "",
                "isHttp": false,
                "icon": containersList[i].icon || "docker"
            });
        }
        for (let j = 0; j < portsList.length; j++) {
            arr.push({
                "kind": "port",
                "title": ":" + portsList[j].port,
                "subtitle": portsList[j].process,
                "badge": portsList[j].isHttp ? "OPEN" : "TCP",
                "url": portsList[j].url,
                "isHttp": portsList[j].isHttp,
                "icon": portsList[j].icon || "port"
            });
        }
        return arr;
    }

    Process {
        id: devProc
        command: ["python3", Quickshell.shellPath("scripts/dev-env-status.py"), "ports"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    root.portsList = Array.isArray(d.ports) ? d.ports : [];
                    root.containersList = Array.isArray(d.containers) ? d.containers : [];
                    root.dockerRunning = !!d.dockerRunning;
                } catch(e) {}
            }
        }
    }

    function refreshNow() {
        if (!devProc.running) devProc.running = true;
    }

    Component.onCompleted: refreshNow()

    Timer {
        interval: 10000
        repeat: true
        running: root.isLive
        onTriggered: root.refreshNow()
    }

    // Drag, right-click menu, and click-to-refresh MouseArea
    MouseArea {
        id: bgMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (root.wrapper) root.wrapper.menuOpen = !root.wrapper.menuOpen;
                return;
            }
            if (mouse.button !== Qt.LeftButton) return;
            if (root.wrapper && root.wrapper.menuOpen) root.wrapper.menuOpen = false;
            let canvasPt = mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
            startScreenX = canvasPt.x;
            startScreenY = canvasPt.y;
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!bgMouseArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                if (isDragging) {
                    isDragging = false;
                    if (root.wrapper) root.wrapper.endDrag();
                }
                return;
            }
            let canvasPt = mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
            let dx = canvasPt.x - startScreenX;
            let dy = canvasPt.y - startScreenY;
            if (!isDragging && Math.hypot(dx, dy) > 4) {
                isDragging = true;
                if (root.wrapper) root.wrapper.startDrag(mouse.x, mouse.y);
            }
            if (isDragging && root.wrapper) root.wrapper.updateDrag(dx, dy);
        }

        onReleased: {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
        }

        onCanceled: {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
        }

        onClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton || isDragging) return;
            root.refreshNow();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 13
        anchors.bottomMargin: 12
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 6

            Text {
                text: "󰒍"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: root.combinedItems.length > 0 ? "#30d158" : theme.textMuted
            }

            Text {
                Layout.fillWidth: true
                text: "Dev Ports"
                color: theme.text
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Rectangle {
                visible: root.dockerRunning
                Layout.preferredHeight: 18
                Layout.preferredWidth: dockTxt.implicitWidth + 10
                radius: 6
                color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.16)
                border.width: 1
                border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.35)

                Text {
                    id: dockTxt
                    anchors.centerIn: parent
                    text: "Docker"
                    color: theme.blueLight
                    font.family: theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }
            }
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.combinedItems.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰒍"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: Qt.rgba(1, 1, 1, 0.22)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No local servers"
                    color: theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.dockerRunning ? "Docker online • 0 ports" : "Ports 3000-9999 & Docker"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                }
            }
        }

        // Active Ports & Containers List
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.combinedItems.length > 0
            model: root.combinedItems
            spacing: 5
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: itemRow
                required property var modelData
                width: ListView.view.width
                height: 36
                radius: 9
                color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.045)
                border.width: 1
                border.color: rowMa.containsMouse ? Qt.rgba(48/255, 209/255, 88/255, 0.40) : Qt.rgba(1, 1, 1, 0.07)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 6

                    Image {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        sourceSize: Qt.size(32, 32)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: root.iconForKey(itemRow.modelData.icon, itemRow.modelData.kind === "docker")
                    }

                    Text {
                        text: itemRow.modelData.title
                        color: theme.text
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: itemRow.modelData.subtitle
                        elide: Text.ElideRight
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                    }

                    Text {
                        text: itemRow.modelData.badge
                        color: itemRow.modelData.isHttp ? "#30d158" : theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: itemRow.modelData.isHttp ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (itemRow.modelData.isHttp && itemRow.modelData.url) {
                            Quickshell.execDetached(["xdg-open", itemRow.modelData.url]);
                        }
                    }
                }
            }
        }
    }
}
