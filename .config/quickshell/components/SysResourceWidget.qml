import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    Theme { id: theme }

    required property var parentWindow
    property string activePopupId: ""
    signal togglePopup(string id)

    implicitHeight: pill.implicitHeight
    implicitWidth: pill.implicitWidth

    property int cpuPct: 0
    property int ramPct: 0
    property real ramUsed: 0.0
    property real ramTotal: 0.0
    property int tempC: 0

    // Fetch resources
    Process {
        id: resProc
        command: ["/home/ferram/.local/bin/hypr-resources"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.cpuPct = d.cpu || 0;
                    root.ramPct = d.ram_pct || 0;
                    root.ramUsed = d.ram_used || 0;
                    root.ramTotal = d.ram_total || 0;
                    root.tempC = d.temp || 0;
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: {
            if (!resProc.running) resProc.running = true;
        }
    }

    property color statusColor: {
        if (root.cpuPct > 80 || root.ramPct > 85) return theme.red;
        if (root.cpuPct > 55 || root.ramPct > 70) return theme.yellow;
        return theme.cyan;
    }

    // CPU icon data URI
    property string iconDataUri: {
        let col = theme.urlColor(root.statusColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
               "<rect x='5' y='5' width='14' height='14' rx='2' stroke='" + col + "' stroke-width='2'/>" +
               "<rect x='9' y='9' width='6' height='6' fill='" + col + "'/>" +
               "<path d='M9 2v3m6-3v3M9 19v3m6-3v3M2 9h3m-3 6h3M19 9h3m-3 6h3' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/>" +
               "</svg>";
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.cpuPct + "%"
        subText: root.ramUsed > 0 ? root.ramUsed + "G" : ""
        accentColor: root.statusColor
        active: root.activePopupId === "resources"
        customPadding: 8

        onClicked: root.togglePopup("resources")
    }

    Process { id: btopProc }

    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "resources"
        implicitWidth: 280
        implicitHeight: cardLayout.implicitHeight + 28
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12

                // Header
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: Qt.rgba(theme.cyan.r, theme.cyan.g, theme.cyan.b, 0.15)
                        border.color: theme.cyan
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: root.iconDataUri
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "System Monitor"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Text {
                            text: root.tempC > 0 ? "Core Temp: " + root.tempC + "°C" : "Hardware Status"
                            color: theme.textSub
                            font.pixelSize: 10
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: theme.borderSubtle }

                // CPU Section
                Column {
                    width: parent.width
                    spacing: 4

                    Row {
                        width: parent.width
                        Text { text: "CPU Usage"; color: theme.textSub; font.pixelSize: 11; font.weight: Font.Medium }
                        Item { Layout.fillWidth: true; width: 1; height: 1 }
                        Text { text: root.cpuPct + "%"; color: root.statusColor; font.pixelSize: 11; font.weight: Font.Bold }
                    }

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: theme.surface
                        Rectangle {
                            width: Math.max(4, parent.width * (root.cpuPct / 100))
                            height: parent.height
                            radius: 3
                            color: root.statusColor
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }
                }

                // RAM Section
                Column {
                    width: parent.width
                    spacing: 4

                    Row {
                        width: parent.width
                        Text { text: "Memory (RAM)"; color: theme.textSub; font.pixelSize: 11; font.weight: Font.Medium }
                        Item { Layout.fillWidth: true; width: 1; height: 1 }
                        Text { text: root.ramUsed + " / " + root.ramTotal + " GB (" + root.ramPct + "%)"; color: theme.blueLight; font.pixelSize: 11; font.weight: Font.Bold }
                    }

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: theme.surface
                        Rectangle {
                            width: Math.max(4, parent.width * (root.ramPct / 100))
                            height: parent.height
                            radius: 3
                            color: root.ramPct > 80 ? theme.red : theme.blue
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }
                }

                // Open Task Manager (btop) button
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: theme.radiusSmall
                    color: btopMa.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : theme.surface
                    border.color: btopMa.containsMouse ? theme.blue : theme.borderSubtle
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "⚡ Open btop Monitor"
                            color: theme.blueLight
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: btopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            btopProc.command = ["kitty", "--title", "btop", "btop"];
                            btopProc.running = true;
                            root.togglePopup("");
                        }
                    }
                }
            }
        }
    }
}
