import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
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
    property bool isConnected: false
    property string currentSsid: "Disconnected"
    property int signalPercent: 0
    property string currentIp: "No IP"
    property string deviceInterface: "wlan0"
    property string securityType: ""
    property bool wifiRadioOn: true

    // Clean, perfectly centered Wi-Fi SVG Icon
    property string iconDataUri: {
        let col = theme.urlColor(theme.blue);
        if (!wifiRadioOn || !isConnected) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M1.5 8.5a15 15 0 0 1 21 0' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-opacity='0.25'/>" +
                   "<path d='M5 12a10 10 0 0 1 14 0' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-opacity='0.25'/>" +
                   "<path d='M8.5 15.5a5 5 0 0 1 7 0' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-opacity='0.25'/>" +
                   "<line x1='2' y1='2' x2='22' y2='22' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/>" +
                   "</svg>";
        }

        let outerOp = root.signalPercent >= 70 ? "1" : "0.25";
        let midOp = root.signalPercent >= 35 ? "1" : "0.25";
        let dotOp = "1";

        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
               "<path d='M1.5 8.5a15 15 0 0 1 21 0' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-opacity='" + outerOp + "'/>" +
               "<path d='M5 12a10 10 0 0 1 14 0' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-opacity='" + midOp + "'/>" +
               "<path d='M8.5 15.5a5 5 0 0 1 7 0' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-opacity='" + dotOp + "'/>" +
               "<circle cx='12' cy='19.5' r='1.3' fill='" + col + "' fill-opacity='" + dotOp + "'/>" +
               "</svg>";
    }

    // Process to scan nmcli wifi status
    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY,DEVICE dev wifi 2>/dev/null; nmcli radio wifi 2>/dev/null; ip -4 -o addr show scope global | awk '{print $2 \":\" $4}'"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let lines = text.trim().split("\n");
                let foundActive = false;
                let radioStatus = true;
                let ipMap = {};

                for (let line of lines) {
                    line = line.trim();
                    if (!line) continue;

                    if (line === "enabled" || line === "disabled") {
                        radioStatus = (line === "enabled");
                        continue;
                    }

                    if (line.indexOf(":") !== -1) {
                        let parts = line.split(":");
                        if (parts[0] === "yes" && !foundActive) {
                            foundActive = true;
                            root.currentSsid = parts[1] || "Hidden Network";
                            root.signalPercent = parseInt(parts[2]) || 50;
                            root.securityType = parts[3] || "";
                            root.deviceInterface = parts[4] || root.deviceInterface;
                        } else if (parts.length === 2 && parts[1].indexOf("/") !== -1) {
                            ipMap[parts[0]] = parts[1].split("/")[0];
                        }
                    }
                }

                root.wifiRadioOn = radioStatus;
                root.isConnected = foundActive;
                if (!foundActive) {
                    root.currentSsid = radioStatus ? "Disconnected" : "Wi-Fi Off";
                    root.signalPercent = 0;
                }

                if (root.deviceInterface && ipMap[root.deviceInterface]) {
                    root.currentIp = ipMap[root.deviceInterface];
                } else if (Object.keys(ipMap).length > 0) {
                    root.currentIp = Object.values(ipMap)[0];
                } else {
                    root.currentIp = "No IP assigned";
                }
            }
        }
    }

    // Refresh every 6 seconds
    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: wifiProc.running = true
    }

    // Background toggle process
    Process {
        id: toggleProc
        onExited: wifiProc.running = true
    }

    // Launch nmtui in terminal
    Process {
        id: nmtuiProc
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.currentSsid
        subText: root.isConnected && root.signalPercent > 0 ? (root.signalPercent + "%") : ""
        accentColor: theme.blue
        active: root.activePopupId === "wifi"

        onClicked: {
            root.togglePopup("wifi");
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

        visible: root.activePopupId === "wifi"
        implicitWidth: 270
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
                            text: root.isConnected ? root.currentSsid : "Wi-Fi Network"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            width: 180
                        }
                        Text {
                            text: root.isConnected ? ("Connected (" + root.signalPercent + "%)") : (root.wifiRadioOn ? "Not connected" : "Radio Disabled")
                            color: theme.blueLight
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }

                // Signal Bar if connected
                Rectangle {
                    visible: root.isConnected
                    width: parent.width
                    height: 6
                    color: theme.surface
                    radius: 3

                    Rectangle {
                        width: Math.max(4, parent.width * (root.signalPercent / 100.0))
                        height: parent.height
                        radius: 3
                        color: theme.blue
                        Behavior on width { NumberAnimation { duration: 250 } }
                    }
                }

                // Network Details Box
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
                            Text { text: "IP Address:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.currentIp
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Interface:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.deviceInterface
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Security:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.securityType !== "" ? root.securityType : "None"
                                color: theme.text
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

                    // Toggle Radio Button
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: theme.radiusSmall
                        color: toggleMouse.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: root.wifiRadioOn ? theme.blue : theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.wifiRadioOn ? "Turn Wi-Fi Off" : "Turn Wi-Fi On"
                            color: root.wifiRadioOn ? theme.text : theme.blue
                            font.pixelSize: 11
                            font.family: theme.fontFamily
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: toggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                toggleProc.command = ["nmcli", "radio", "wifi", root.wifiRadioOn ? "off" : "on"];
                                toggleProc.running = true;
                            }
                        }
                    }

                    // Open nmtui Manager Button
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: theme.radiusSmall
                        color: manageMouse.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: theme.blueDeep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Manage Wi-Fi"
                            color: theme.blueLight
                            font.pixelSize: 11
                            font.family: theme.fontFamily
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: manageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.togglePopup("");
                                nmtuiProc.command = ["kitty", "--class", "wifi-manager", "--title", "Network Connections", "-e", "nmtui"];
                                nmtuiProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
