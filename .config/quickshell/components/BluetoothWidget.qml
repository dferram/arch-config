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
    property string adapterName: "Bluetooth Adapter"

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

    // Sync from native Quickshell.Bluetooth if available
    Connections {
        target: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter : null
        function onEnabledChanged() {
            if (Bluetooth.defaultAdapter) {
                root.isPowered = Bluetooth.defaultAdapter.enabled;
            }
        }
    }

    // Fast robust fallback process to check rfkill and bluetoothctl
    Process {
        id: btProc
        command: ["sh", "-c", "rfkill list bluetooth 2>/dev/null; timeout 1 bluetoothctl show 2>/dev/null | grep 'Powered:'; timeout 1 bluetoothctl devices Connected 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let out = text.trim();
                let rfkillBlocked = out.indexOf("Soft blocked: yes") !== -1 || out.indexOf("Hard blocked: yes") !== -1;
                let poweredYes = out.indexOf("Powered: yes") !== -1;

                if (Bluetooth.defaultAdapter) {
                    root.isPowered = Bluetooth.defaultAdapter.enabled;
                    root.adapterName = Bluetooth.defaultAdapter.name || "Default Controller";
                } else {
                    root.isPowered = !rfkillBlocked && poweredYes;
                }

                // Check connected devices
                let lines = out.split("\n");
                let foundDev = false;
                for (let line of lines) {
                    if (line.startsWith("Device ")) {
                        let parts = line.split(" ");
                        if (parts.length >= 3) {
                            foundDev = true;
                            root.connectedName = parts.slice(2).join(" ");
                            break;
                        }
                    }
                }

                if (!foundDev && Bluetooth.devices) {
                    for (let dev of Bluetooth.devices.values) {
                        if (dev.connected) {
                            foundDev = true;
                            root.connectedName = dev.name || dev.deviceName || "Connected Device";
                            if (dev.batteryAvailable) root.connectedBattery = Math.round(dev.battery);
                            break;
                        }
                    }
                }

                root.isConnected = foundDev;
                if (!foundDev) {
                    root.connectedName = "";
                    root.connectedBattery = -1;
                }
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

    // Toggle process
    Process {
        id: toggleProc
        onExited: btProc.running = true
    }

    // Launch bluetoothctl TUI
    Process {
        id: ctlProc
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

    // Detailed Popover Card
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "bluetooth"
        implicitWidth: 260
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
                    Image {
                        source: root.iconDataUri
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: root.isConnected ? root.connectedName : "Bluetooth"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            width: 180
                        }
                        Text {
                            text: root.isConnected ? "Connected" : (root.isPowered ? "Powered On" : "Disabled")
                            color: theme.blueLight
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }

                // Bluetooth Details Box
                Rectangle {
                    width: parent.width
                    height: detailsCol.implicitHeight + 16
                    color: theme.surface
                    radius: theme.radiusSmall
                    border.color: theme.borderSubtle
                    border.width: 1

                    Column {
                        id: detailsCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Row {
                            width: parent.width
                            Text { text: "Adapter:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 180 }
                            Text {
                                text: root.adapterName
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Connection:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 180 }
                            Text {
                                text: root.isConnected ? root.connectedName : "No device"
                                color: root.isConnected ? theme.blue : theme.textMuted
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            visible: root.connectedBattery > 0
                            width: parent.width
                            Text { text: "Device Battery:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 180 }
                            Text {
                                text: root.connectedBattery + "%"
                                color: theme.blueLight
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // Action Buttons
                Row {
                    width: parent.width
                    spacing: 8

                    // Toggle Power Button
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: theme.radiusSmall
                        color: toggleBtMouse.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: root.isPowered ? theme.blue : theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.isPowered ? "Turn Off" : "Turn On"
                            color: root.isPowered ? theme.text : theme.blue
                            font.pixelSize: 11
                            font.family: theme.fontFamily
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: toggleBtMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.isPowered) {
                                    toggleProc.command = ["sh", "-c", "bluetoothctl power off 2>/dev/null || rfkill block bluetooth"];
                                } else {
                                    toggleProc.command = ["sh", "-c", "rfkill unblock bluetooth; bluetoothctl power on 2>/dev/null"];
                                }
                                toggleProc.running = true;
                            }
                        }
                    }

                    // Open bluetoothctl in kitty
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: theme.radiusSmall
                        color: ctlMouse.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: theme.blueLight
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Pair / Devices..."
                            color: theme.blueLight
                            font.pixelSize: 11
                            font.family: theme.fontFamily
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: ctlMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.togglePopup("");
                                ctlProc.command = ["blueman-manager"];
                                ctlProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
