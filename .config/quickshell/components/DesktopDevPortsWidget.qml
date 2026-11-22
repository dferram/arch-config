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

    readonly property var combinedItems: {
        let arr = [];
        for (let i = 0; i < containersList.length; i++) {
            arr.push({
                "kind": "docker",
                "title": containersList[i].name,
                "subtitle": containersList[i].image,
                "badge": "UP",
                "url": "",
                "isHttp": false
            });
        }
        for (let j = 0; j < portsList.length; j++) {
            arr.push({
                "kind": "port",
                "title": ":" + portsList[j].port,
                "subtitle": portsList[j].process,
                "badge": portsList[j].isHttp ? "OPEN" : "TCP",
                "url": portsList[j].url,
                "isHttp": portsList[j].isHttp
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
        interval: 4000
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

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: itemRow.modelData.kind === "docker" ? theme.blueLight : "#30d158"
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
