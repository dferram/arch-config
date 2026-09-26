import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
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

    // Internal state
    property bool isPowered: false
    property bool isConnected: false
    property string connectedName: ""
    property int connectedBattery: -1
    property var pairedDevices: []
    property bool isConnecting: false
    property string connectingMac: ""

    // Text to show on the pill
    property string pillText: {
        if (isConnected && connectedName !== "") return connectedName;
        if (isPowered) return "On";
        return "Off";
    }

    // Lucide Bluetooth vector icon (matching Night Mode aesthetic)
    property string iconDataUri: {
        let col = theme.urlColor(root.isPowered ? theme.blue : theme.textMuted);
        let op = !isPowered ? "0.35" : "1.0";
        let dot = isConnected ? "<circle cx='18.5' cy='12' r='1.5' fill='" + col + "' stroke='none'/>" : "";
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
               "<path d='M6.5 6.5 L17.5 17.5 L12 23 L12 1 L17.5 6.5 L6.5 17.5' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round' stroke-opacity='" + op + "'/>" +
               dot + "</svg>";
    }

    // Fast robust status fetcher from hypr-bluetooth
    Process {
        id: btProc
        command: ["/home/ferram/.local/bin/hypr-bluetooth", "status-json"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let out = text.trim();
                if (!out) return;
                try {
                    let data = JSON.parse(out);
                    root.isPowered = !!data.powered;
                    root.isConnected = !!data.connected;
                    root.connectedName = data.connected_name || "";
                    root.pairedDevices = data.devices || [];
                    if (data.connected_name) {
                        for (let d of data.devices) {
                            if (d.connected && d.battery > 0) {
                                root.connectedBattery = d.battery;
                                break;
                            }
                        }
                    } else {
                        root.connectedBattery = -1;
                    }
                } catch(e) {}
            }
        }
    }

    // Refresh every 8 seconds
    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    onActivePopupIdChanged: {
        if (activePopupId === "bluetooth") {
            btProc.running = true;
        }
    }

    // Toggle process
    Process {
        id: toggleProc
        onExited: btProc.running = true
    }

    // Device connect/disconnect process
    Process {
        id: actionProc
        onExited: {
            root.isConnecting = false;
            root.connectingMac = "";
            btProc.running = true;
        }
    }

    // External Rofi / Menu process
    Process {
        id: ctlProc
        onExited: btProc.running = true
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.pillText
        subText: root.connectedBattery > 0 ? (root.connectedBattery + "%") : ""
        accentColor: theme.blue
        active: root.activePopupId === "bluetooth"

        onClicked: {
            root.togglePopup("bluetooth");
        }
    }

    // Detailed Popover Card with In-Card Paired Devices
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "bluetooth"
        implicitWidth: 290
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
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12

                // Header: Status + Toggle Switch
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Image {
                            source: root.iconDataUri
                            width: 22
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: "Bluetooth"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.isConnected ? root.connectedName : (root.isPowered ? "Powered On" : "Disabled")
                                color: root.isConnected ? theme.blue : theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                width: 140
                            }
                        }
                    }

                    // Power Toggle Pill
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 58
                        height: 24
                        radius: 12
                        color: root.isPowered ? Qt.rgba(59/255, 130/255, 246/255, 0.22) : Qt.rgba(255, 255, 255, 0.08)
                        border.color: root.isPowered ? theme.blue : Qt.rgba(255, 255, 255, 0.15)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.isPowered ? "ON" : "OFF"
                            color: root.isPowered ? theme.blueLight : theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                toggleProc.command = ["/home/ferram/.local/bin/hypr-bluetooth", "toggle"];
                                toggleProc.running = true;
                            }
                        }
                    }
                }

                // Section Label
                Text {
                    text: "PAIRED DEVICES"
                    color: theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    visible: root.isPowered
                }

                // In-Card Paired Devices List
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.isPowered

                    Repeater {
                        model: root.pairedDevices

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 44
                            radius: theme.radiusSmall
                            color: devMa.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : theme.surface
                            border.color: modelData.connected ? Qt.rgba(59/255, 130/255, 246/255, 0.40) : theme.borderSubtle
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                width: parent.width - 96

                                Text {
                                    text: modelData.type === "audio" ? "󰋋" : "󰂯"
                                    font.family: theme.fontFamily
                                    font.pixelSize: 15
                                    color: modelData.connected ? theme.blueLight : theme.textMuted
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 24

                                    Text {
                                        text: modelData.name
                                        color: theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: {
                                            if (root.isConnecting && root.connectingMac === modelData.mac) return "Connecting…";
                                            if (modelData.connected) {
                                                return modelData.battery > 0 ? ("Connected • " + modelData.battery + "%") : "Connected";
                                            }
                                            return "Saved";
                                        }
                                        color: modelData.connected ? theme.blueLight : theme.textMuted
                                        font.family: theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            // Connect / Disconnect Action Button
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 72
                                height: 26
                                radius: 13
                                color: {
                                    if (modelData.connected) {
                                        return btnMa.containsMouse ? Qt.rgba(239/255, 68/255, 68/255, 0.25) : Qt.rgba(255, 255, 255, 0.06);
                                    }
                                    return btnMa.containsMouse ? Qt.lighter(theme.blue, 1.15) : theme.blue;
                                }
                                border.color: modelData.connected ? (btnMa.containsMouse ? "#ef4444" : Qt.rgba(255, 255, 255, 0.12)) : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (root.isConnecting && root.connectingMac === modelData.mac) return "…";
                                        return modelData.connected ? "Disconnect" : "Connect";
                                    }
                                    color: modelData.connected ? (btnMa.containsMouse ? "#ef4444" : theme.textSub) : "#ffffff"
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: btnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.isConnecting = true;
                                        root.connectingMac = modelData.mac;
                                        if (modelData.connected) {
                                            actionProc.command = ["/home/ferram/.local/bin/hypr-bluetooth", "disconnect", modelData.mac, modelData.name];
                                        } else {
                                            actionProc.command = ["/home/ferram/.local/bin/hypr-bluetooth", "connect", modelData.mac, modelData.name];
                                        }
                                        actionProc.running = true;
                                    }
                                }
                            }

                            MouseArea {
                                id: devMa
                                anchors.fill: parent
                                z: -1
                                hoverEnabled: true
                            }
                        }
                    }

                    // Empty state
                    Rectangle {
                        visible: root.pairedDevices.length === 0
                        width: parent.width
                        height: 38
                        radius: theme.radiusSmall
                        color: theme.surface
                        Text {
                            anchors.centerIn: parent
                            text: "No paired devices found"
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // Action Buttons (Scan + Sleek Rofi Menu)
                Row {
                    width: parent.width
                    spacing: 8
                    visible: root.isPowered

                    // Scan Nearby Button
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: theme.radiusSmall
                        color: scanMa.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰍉"
                                color: theme.textSub
                                font.pixelSize: 13
                                font.family: theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Scan Nearby"
                                color: theme.textSub
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: scanMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.togglePopup("");
                                ctlProc.command = ["/home/ferram/.local/bin/hypr-bluetooth", "scan"];
                                ctlProc.running = true;
                            }
                        }
                    }

                    // Full Bluetooth Menu Button
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: theme.radiusSmall
                        color: menuMa.containsMouse ? Qt.rgba(59/255, 130/255, 246/255, 0.20) : theme.surface
                        border.color: theme.blue
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰂯"
                                color: theme.blueLight
                                font.pixelSize: 13
                                font.family: theme.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Bluetooth Menu"
                                color: theme.blueLight
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: menuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.togglePopup("");
                                ctlProc.command = ["/home/ferram/.local/bin/hypr-bluetooth", "menu"];
                                ctlProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
