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

    // Reactive storage data
    property var partitionsList: []
    property real totalDiskGb: 0.0
    property real rootUsedGb: 0.0
    property real rootTotalGb: 0.0
    property real rootFreeGb: 0.0
    property int rootPct: 0

    // Fetch disk storage details
    Process {
        id: diskProc
        command: ["/home/ferram/Personal/dotfiles/.config/quickshell/scripts/disk-partitions.py"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.total_disk_gb !== undefined) root.totalDiskGb = d.total_disk_gb;
                    if (d.root) {
                        root.rootUsedGb = d.root.used_gb || 0;
                        root.rootTotalGb = d.root.total_gb || 0;
                        root.rootFreeGb = d.root.free_gb || 0;
                        root.rootPct = d.root.pct || 0;
                    }
                    if (d.partitions) {
                        root.partitionsList = d.partitions;
                    }
                } catch(e) {}
            }
        }
    }

    // Refresh every 10 seconds
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!diskProc.running) diskProc.running = true;
        }
    }

    property color statusColor: {
        if (root.rootPct > 85) return theme.red;
        if (root.rootPct > 70) return theme.peach;
        return theme.blue;
    }

    // Lucide Hard Drive SVG Icon
    property string iconDataUri: {
        let col = theme.urlColor(root.statusColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
               "<line x1='22' y1='12' x2='2' y2='12'/>" +
               "<path d='M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z'/>" +
               "<line x1='6' y1='16' x2='6.01' y2='16'/>" +
               "<line x1='10' y1='16' x2='10.01' y2='16'/>" +
               "</svg>";
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: ""
        accentColor: root.statusColor
        active: root.activePopupId === "storage"
        customPadding: 8

        onClicked: root.togglePopup("storage")
    }

    Process { id: dolphinProc }

    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "storage"
        implicitWidth: 320
        implicitHeight: cardLayout.implicitHeight + 38
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.95
            transformOrigin: Item.Top
            transform: Translate {
                y: popup.visible ? 0 : -6
                Behavior on y { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            }

            Behavior on opacity { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }

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
                        color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.15)
                        border.color: theme.blue
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
                            text: "Storage & Partitions"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Text {
                            text: (root.totalDiskGb > 0 ? (root.totalDiskGb + " GB SSD Total • ") : "") + (root.partitionsList.length + " partitions")
                            color: theme.textSub
                            font.pixelSize: 10
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: theme.borderSubtle }

                // Partitions List
                Column {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: root.partitionsList

                        delegate: Column {
                            required property var modelData
                            width: parent.width
                            spacing: 4

                            // Labels row
                            Item {
                                width: parent.width
                                height: 16

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        text: modelData.label
                                        color: theme.text
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }

                                    // Filesystem tag
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 14
                                        width: fsText.implicitWidth + 8
                                        radius: 3
                                        color: theme.surface
                                        border.color: theme.borderSubtle
                                        border.width: 1

                                        Text {
                                            id: fsText
                                            anchors.centerIn: parent
                                            text: modelData.fstype
                                            color: theme.textDim
                                            font.pixelSize: 9
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (modelData.is_mounted) {
                                            return modelData.free_gb + " GB free (" + modelData.pct + "%)";
                                        } else {
                                            return modelData.total_gb + " GB (Not mounted)";
                                        }
                                    }
                                    color: {
                                        if (!modelData.is_mounted) return theme.textDim;
                                        if (modelData.pct > 85) return theme.red;
                                        if (modelData.pct > 70) return theme.peach;
                                        return theme.blueLight;
                                    }
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                            }

                            // Progress Bar for mounted partitions
                            Rectangle {
                                width: parent.width
                                height: 6
                                radius: 3
                                color: theme.surface
                                visible: modelData.is_mounted

                                Rectangle {
                                    width: Math.max(3, parent.width * (Math.min(100, modelData.pct) / 100))
                                    height: parent.height
                                    radius: 3
                                    color: {
                                        if (modelData.pct > 85) return theme.red;
                                        if (modelData.pct > 70) return theme.peach;
                                        return theme.blue;
                                    }
                                    Behavior on width { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                                }
                            }

                            // Subtitle showing mount point and used/total
                            Text {
                                visible: modelData.is_mounted
                                text: modelData.used_gb + " / " + modelData.total_gb + " GB • " + modelData.mount
                                color: theme.textDim
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                                width: parent.width
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: theme.borderSubtle }

                // Open Dolphin Button
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: theme.radiusSmall
                    color: dolphinMa.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : theme.surface
                    border.color: dolphinMa.containsMouse ? theme.blue : theme.borderSubtle
                    border.width: 1

                    scale: dolphinMa.pressed ? 0.95 : (dolphinMa.containsMouse ? 1.025 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "Open File Manager (Dolphin)"
                            color: theme.blueLight
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: dolphinMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            dolphinProc.command = ["dolphin"];
                            dolphinProc.running = true;
                            root.togglePopup("");
                        }
                    }
                }
            }
        }
    }
}
