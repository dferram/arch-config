import QtQuick
import Quickshell
import "../theme"

Rectangle {
    id: root
    property var agents: []
    property bool available: false
    property color accent: "#42a0bf"
    // Use the exact asset paths used by WorkspacesWidget.
    function iconFor(agent) {
        if (agent.name === "Devin") return "file:///usr/share/pixmaps/devin-desktop.png";
        if (agent.icon) return "file://" + Quickshell.env("HOME") + "/.local/share/icons/" + agent.icon;
        return "";
    }
    Theme { id: theme }
    radius: 16
    color: theme.popupBg
    border.width: 1
    border.color: theme.border

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 18
        spacing: 5
        Text {
            text: "AI agents"
            color: theme.text
            font.family: theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            text: root.agents.length ? "Local sessions & services" : "Terminal & editor activity"
            color: theme.textDim
            font.family: theme.fontFamily
            font.pixelSize: 11
        }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 20
        visible: root.agents.length === 0
        text: root.available ? "No agents detected" : "Status unavailable"
        color: theme.textMuted
        font.family: theme.fontFamily
        font.pixelSize: 13
    }

    ListView {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 8
        clip: true
        model: root.agents
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: 72
            radius: 10
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.07)
            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Item {
                    width: 30
                    height: parent.height
                    Item {
                        anchors.centerIn: parent
                        width: 28; height: 28
                        Image {
                            id: agentIcon
                            objectName: "agentIcon"
                            anchors.centerIn: parent
                            width: 24; height: 24
                            source: root.iconFor(modelData)
                            sourceSize: Qt.size(64, 64)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: agentIcon.source.toString() === "" || agentIcon.status === Image.Error
                            text: "AI"
                            color: root.accent
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                        // Same >_ terminal sub-badge as the workspace icons.
                        Rectangle {
                            objectName: "terminalBadge"
                            visible: modelData.source === "Terminal" || modelData.source === "Editor terminal"
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: 10; height: 8
                            radius: 2
                            color: "#0a0c14"
                            border.color: theme.blueLight
                            border.width: 1
                            z: 3
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
                }
                Column {
                    width: parent.width - 40
                    spacing: 3
                    Text {
                        width: parent.width
                        text: modelData.name + (modelData.count > 1 ? " ×" + modelData.count : "")
                        elide: Text.ElideRight
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: modelData.source
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        text: modelData.state
                        color: root.accent
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
