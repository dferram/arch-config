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

    // Internal state from wifi-details.py
    property bool isConnected: false
    property bool wifiRadioOn: true
    property string currentSsid: "Disconnected"
    property string bssid: ""
    property string channel: ""
    property string frequency: ""
    property string band: ""
    property string linkRate: ""
    property int signalPercent: 0
    property string currentIp: "No IP"
    property string gatewayIp: ""
    property string dnsServer: ""
    property string deviceInterface: "wlp0s20f3"
    property string securityType: "None"
    property var nearbyNetworks: []
    property bool isCopied: false
    property bool isScanning: false

    // Lucide Wi-Fi vector icon
    property string iconDataUri: {
        let col = theme.urlColor(root.isConnected ? theme.blue : theme.textMuted);
        if (!wifiRadioOn || !isConnected) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<line x1='2' y1='2' x2='22' y2='22'/>" +
                   "<path d='M12 20h.01'/>" +
                   "<path d='M8.5 16.4a5 5 0 0 1 7 0'/>" +
                   "<path d='M4.9 12.8a10 10 0 0 1 3.2 -2.1'/>" +
                   "<path d='M14.5 11.5a10 10 0 0 1 4.6 1.3'/>" +
                   "<path d='M1.5 8.5a15 15 0 0 1 4.2 -2.6'/>" +
                   "<path d='M10.7 5a15 15 0 0 1 11.8 3.5'/>" +
                   "</svg>";
        }

        let outerOp = root.signalPercent >= 70 ? "1" : "0.25";
        let midOp = root.signalPercent >= 35 ? "1" : "0.25";
        let dotOp = "1";

        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
               "<path d='M1.5 8.5a15 15 0 0 1 21 0' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round' stroke-opacity='" + outerOp + "'/>" +
               "<path d='M5 12.5a10 10 0 0 1 14 0' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round' stroke-opacity='" + midOp + "'/>" +
               "<path d='M8.5 16.5a5 5 0 0 1 7 0' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round' stroke-opacity='" + dotOp + "'/>" +
               "<circle cx='12' cy='20' r='1.3' fill='" + col + "' fill-opacity='" + dotOp + "'/>" +
               "</svg>";
    }

    // Process to scan wifi telemetry via python script
    Process {
        id: wifiProc
        command: ["python3", Quickshell.shellPath("scripts/wifi-details.py")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.isScanning = false;
                try {
                    let d = JSON.parse(text);
                    root.isConnected = d.connected || false;
                    root.wifiRadioOn = d.radioOn !== undefined ? d.radioOn : true;
                    root.currentSsid = d.ssid || "Disconnected";
                    root.bssid = d.bssid || "";
                    root.channel = d.channel || "";
                    root.frequency = d.freq || "";
                    root.band = d.band || "";
                    root.linkRate = d.rate || "";
                    root.signalPercent = d.signal || 0;
                    root.currentIp = d.ip || "No IP";
                    root.gatewayIp = d.gateway || "";
                    root.dnsServer = d.dns || "";
                    root.deviceInterface = d.device || "wlp0s20f3";
                    root.securityType = d.security || "None";
                    root.nearbyNetworks = d.nearby || [];
                } catch (e) {
                    console.warn("Error parsing wifi-details:", e);
                }
            }
        }
    }

    // Refresh every 5 seconds
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!wifiProc.running) wifiProc.running = true;
        }
    }

    // Action commands
    Process {
        id: actionProc
        onExited: {
            rescanTimer.restart();
        }
    }

    Timer {
        id: rescanTimer
        interval: 1200
        onTriggered: if (!wifiProc.running) wifiProc.running = true
    }

    Timer {
        id: copyFeedbackTimer
        interval: 1600
        onTriggered: root.isCopied = false
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.currentSsid
        subText: root.isConnected && root.signalPercent > 0 ? (root.signalPercent + "%" + (root.band === "5 GHz" ? " 5G" : "")) : ""
        accentColor: theme.blue
        active: root.activePopupId === "wifi"

        onClicked: {
            root.togglePopup("wifi");
            if (!wifiProc.running) wifiProc.running = true;
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
        implicitWidth: 320
        implicitHeight: cardLayout.implicitHeight + 36
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 8
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.95
            transformOrigin: Item.Top
            transform: Translate {
                y: popup.visible ? 0 : -6
                Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 11

                // 1. Header with SSID, Status, and Rescan button
                Row {
                    width: parent.width
                    spacing: 10

                    Image {
                        source: root.iconDataUri
                        width: 26
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - 70
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Row {
                            spacing: 6
                            Text {
                                text: root.isConnected ? root.currentSsid : "Wi-Fi Network"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            Rectangle {
                                visible: root.isConnected && root.band !== ""
                                width: bandTxt.implicitWidth + 8
                                height: 16
                                radius: 4
                                color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.20)
                                border.color: theme.blue
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    id: bandTxt
                                    anchors.centerIn: parent
                                    text: root.band
                                    color: theme.blueLight
                                    font.family: theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        Text {
                            text: root.isConnected
                                  ? ("Connected  ·  " + root.signalPercent + "%" + (root.linkRate !== "" ? "  ·  " + root.linkRate : ""))
                                  : (root.wifiRadioOn ? "Not connected" : "Radio Disabled")
                            color: root.isConnected ? theme.blueLight : theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // Rescan icon button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: 13
                        color: rescanMa.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            font.family: "GeistMono Nerd Font Propo"
                            font.pixelSize: 13
                            color: root.isScanning ? theme.blue : theme.textMuted
                            rotation: root.isScanning ? 360 : 0
                            Behavior on rotation { NumberAnimation { duration: 600 } }
                        }

                        MouseArea {
                            id: rescanMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isScanning = true;
                                actionProc.command = ["nmcli", "dev", "wifi", "rescan"];
                                actionProc.running = true;
                            }
                        }
                    }
                }

                // 2. Signal Strength Progress Bar
                Rectangle {
                    visible: root.isConnected
                    width: parent.width
                    height: 5
                    color: theme.surface
                    radius: 2.5

                    Rectangle {
                        width: Math.max(4, parent.width * (root.signalPercent / 100.0))
                        height: parent.height
                        radius: 2.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: theme.blueDeep }
                            GradientStop { position: 1.0; color: theme.blue }
                        }
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }

                // 3. Technical Network Telemetry Box
                Rectangle {
                    visible: root.isConnected
                    width: parent.width
                    height: detailsCol.implicitHeight + 16
                    color: theme.surface
                    radius: theme.radiusSmall
                    border.color: theme.borderSubtle
                    border.width: 1

                    Column {
                        id: detailsCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        // IP Address with Quick Copy button
                        Row {
                            width: parent.width
                            Text { text: "IPv4:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Rectangle {
                                width: ipRow.implicitWidth + 8
                                height: 18
                                radius: 4
                                color: copyMa.containsMouse ? theme.surfaceHover : "transparent"
                                Row {
                                    id: ipRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: root.isCopied ? "Copied!" : root.currentIp
                                        color: root.isCopied ? theme.green : theme.text
                                        font.pixelSize: 11
                                        font.family: theme.fontFamily
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        visible: !root.isCopied
                                        text: "󰅍"
                                        font.family: "GeistMono Nerd Font Propo"
                                        font.pixelSize: 10
                                        color: theme.textDim
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: copyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.currentIp && root.currentIp !== "No IP") {
                                            actionProc.command = ["sh", "-c", "echo -n '" + root.currentIp + "' | wl-copy"];
                                            actionProc.running = true;
                                            root.isCopied = true;
                                            copyFeedbackTimer.restart();
                                        }
                                    }
                                }
                            }
                        }

                        // Gateway
                        Row {
                            visible: root.gatewayIp !== ""
                            width: parent.width
                            Text { text: "Gateway:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.gatewayIp
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        // Frequency & Channel
                        Row {
                            visible: root.channel !== ""
                            width: parent.width
                            Text { text: "Channel / Freq:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: "Ch " + root.channel + (root.frequency !== "" ? " (" + root.frequency + ")" : "")
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        // Security & Interface
                        Row {
                            width: parent.width
                            Text { text: "Security:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.securityType + " (" + root.deviceInterface + ")"
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // 4. Nearby Available Networks List
                Column {
                    visible: root.wifiRadioOn && root.nearbyNetworks.length > 0
                    width: parent.width
                    spacing: 6

                    Text {
                        text: "Nearby Networks"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: root.nearbyNetworks
                        delegate: Rectangle {
                            id: netRow
                            width: parent.width
                            height: 28
                            radius: 6
                            color: netMa.containsMouse ? theme.surfaceHover : (modelData.active ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.12) : "transparent")
                            border.color: modelData.active ? theme.blueDeep : "transparent"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.signal >= 65 ? "󰤨" : modelData.signal >= 40 ? "󰤥" : "󰤢"
                                    font.family: "GeistMono Nerd Font Propo"
                                    font.pixelSize: 12
                                    color: modelData.active ? theme.blue : theme.textMuted
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 150
                                    text: modelData.ssid
                                    elide: Text.ElideRight
                                    color: modelData.active ? theme.blueLight : theme.text
                                    font.family: theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                }

                                Item { Layout.fillWidth: true; width: netRow.width - 240 }

                                // 5G / 2.4G badge
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.band
                                    color: theme.textDim
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.signal + "%"
                                    color: theme.textMuted
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                id: netMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!modelData.active) {
                                        actionProc.command = ["nmcli", "dev", "wifi", "connect", modelData.ssid];
                                        actionProc.running = true;
                                    }
                                }
                            }
                        }
                    }
                }

                // 5. Action Buttons (Toggle Radio, Disconnect, Manage)
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
                                actionProc.command = ["nmcli", "radio", "wifi", root.wifiRadioOn ? "off" : "on"];
                                actionProc.running = true;
                            }
                        }
                    }

                    // Manage (nmtui) Button
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
                                actionProc.command = ["kitty", "--class", "wifi-manager", "--title", "Network Connections", "-e", "nmtui"];
                                actionProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
