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

    property var agents: []
    property bool available: false

    readonly property int totalCount: {
        let sum = 0;
        for (let i = 0; i < agents.length; i++) {
            sum += (agents[i].count || 1);
        }
        return sum;
    }

    readonly property bool hasAttention: {
        for (let i = 0; i < agents.length; i++) {
            let st = (agents[i].state || "").toLowerCase();
            if (st.indexOf("wait") !== -1 || st.indexOf("approv") !== -1 || st.indexOf("input") !== -1) {
                return true;
            }
        }
        return false;
    }

    function iconFor(agent) {
        if (!agent) return "";
        if (agent.name === "Devin") return "file:///usr/share/pixmaps/devin-desktop.png";
        if (agent.icon) return "file://" + Quickshell.env("HOME") + "/.local/share/icons/" + agent.icon;
        return "";
    }

    function stateColor(stateStr) {
        let st = (stateStr || "").toLowerCase();
        if (st.indexOf("wait") !== -1 || st.indexOf("approv") !== -1 || st.indexOf("input") !== -1) {
            return "#ff9f0a";
        }
        if (st.indexOf("work") !== -1 || st.indexOf("run") !== -1 || st.indexOf("exec") !== -1 || st.indexOf("think") !== -1) {
            return "#30d158";
        }
        if (st.indexOf("open") !== -1 || st.indexOf("idle") !== -1 || st.indexOf("ready") !== -1) {
            return theme.blueLight;
        }
        return theme.textDim;
    }

    Process {
        id: agentProc
        command: ["python3", Quickshell.shellPath("scripts/agent-status.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    root.available = !!d.available;
                    root.agents = Array.isArray(d.agents) ? d.agents : [];
                } catch(e) {}
            }
        }
    }

    function refreshNow() {
        if (!agentProc.running) {
            agentProc.running = true;
        }
    }

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
                text: "󰚩"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: root.agents.length > 0 ? theme.blueLight : theme.textMuted
            }

            Text {
                Layout.fillWidth: true
                text: "Agents"
                color: theme.text
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        // Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.agents.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰚩"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: Qt.rgba(1, 1, 1, 0.22)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.available ? "No active agents" : "Agent status idle"
                    color: theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "CLI & IDE sessions"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                }
            }
        }

        // Active Agents List
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.agents.length > 0
            model: root.agents
            spacing: 5
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 44
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.045)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)

                readonly property color stColor: root.stateColor(modelData.state)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 7

                    // Icon + optional terminal badge
                    Item {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24

                        Image {
                            id: agImg
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: root.iconFor(modelData)
                            sourceSize: Qt.size(48, 48)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: agImg.source.toString() === "" || agImg.status === Image.Error
                            text: "AI"
                            color: theme.blueLight
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }

                        Rectangle {
                            visible: modelData.source === "Terminal" || modelData.source === "Editor terminal"
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: 10
                            height: 8
                            radius: 2
                            color: "#0a0c14"
                            border.color: theme.blueLight
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: ">_"
                                color: theme.blueLight
                                font.family: "monospace"
                                font.pixelSize: 6
                                font.weight: Font.Bold
                            }
                        }
                    }

                    // Name & source
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name + (modelData.count > 1 ? (" ×" + modelData.count) : "")
                            elide: Text.ElideRight
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.source || "Session"
                            elide: Text.ElideRight
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                        }
                    }

                    // State tag
                    Rectangle {
                        Layout.preferredHeight: 17
                        Layout.preferredWidth: Math.min(72, stateTxt.implicitWidth + 10)
                        radius: 6
                        color: Qt.rgba(stColor.r, stColor.g, stColor.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(stColor.r, stColor.g, stColor.b, 0.30)

                        Text {
                            id: stateTxt
                            anchors.centerIn: parent
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.state || "Active"
                            elide: Text.ElideRight
                            color: stColor
                            font.family: theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }
}
