import QtQuick
import QtQuick.Controls
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

    // Internal state
    property bool isPowered: false
    property bool isConnected: false
    property string connectedName: ""
    property int connectedBattery: -1
    property var pairedDevices: []
    property var nearbyDevices: []
    property bool hasScanned: false
    readonly property var visibleDevices: pairedDevices.concat(nearbyDevices.filter(d => !pairedDevices.some(p => p.mac === d.mac)))
    property string actionError: ""
    property string pendingAction: ""
    readonly property bool busy: actionProc.running || toggleProc.running || ctlProc.running || scanProc.running
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
                    root.pairedDevices = (data.devices || []).sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name));
                    root.connectedBattery = -1;
                    if (data.connected_name) {
                        for (let d of root.pairedDevices) {
                            if (d.connected && d.name === root.connectedName && d.battery >= 0) {
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
        onExited: (exitCode) => {
            if (exitCode !== 0) root.actionError = "Could not complete the action. Please try again.";
            btProc.running = true;
        }
    }

    // Device connect/disconnect process
    Process {
        id: actionProc
        onExited: (exitCode) => {
            if (exitCode !== 0) root.actionError = "Could not " + root.pendingAction + ". Check the device and try again.";
            root.isConnecting = false;
            root.connectingMac = "";
            btProc.running = true;
        }
    }

    Process {
        id: scanProc
        command: ["/home/ferram/.local/bin/hypr-bluetooth", "scan-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.nearbyDevices = JSON.parse(text);
                    root.hasScanned = true;
                } catch (e) {
                    root.actionError = "Could not search for devices. Please try again.";
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.actionError = "Could not search for devices. Please try again.";
            btProc.running = true;
        }
    }

    // External Rofi / Menu process
    Process {
        id: ctlProc
        onExited: (exitCode) => {
            if (exitCode !== 0) root.actionError = "Could not complete the action. Please try again.";
            btProc.running = true;
        }
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.pillText
        subText: root.isConnected && root.connectedBattery >= 0 ? (root.connectedBattery + "%") : ""
        accentColor: theme.blue
        active: root.activePopupId === "bluetooth"

        onClicked: {
            root.togglePopup("bluetooth");
        }
    }

    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8
        visible: root.activePopupId === "bluetooth"
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

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 11

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
                        width: parent.width - 36
                        spacing: 1
                        Text {
                            text: "Bluetooth"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: toggleProc.running ? "Updating Bluetooth…"
                                : !root.isPowered ? "Turn on to connect your devices"
                                : root.isConnected ? root.pairedDevices.filter(d => d.connected).length + " connected · Ready to pair"
                                : "Not connected · Ready to pair"
                            color: root.isConnected ? theme.blueLight : theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: theme.borderSubtle }

                Row {
                    visible: root.isPowered
                    width: parent.width
                    Text {
                        width: parent.width - 30
                        text: root.hasScanned ? "Paired & Nearby Devices" : "Paired Devices"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: 30
                        text: root.visibleDevices.length
                        horizontalAlignment: Text.AlignRight
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                ScrollView {
                    visible: root.isPowered && root.visibleDevices.length > 0
                    width: parent.width
                    height: Math.min(deviceList.implicitHeight, 264)
                    contentWidth: availableWidth
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Column {
                        id: deviceList
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: root.visibleDevices
                            delegate: Rectangle {
                                id: deviceRow
                                required property var modelData
                                readonly property bool pending: root.isConnecting && root.connectingMac === modelData.mac
                                width: deviceList.width
                                height: 48
                                radius: 6
                                color: modelData.connected ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.12) : "transparent"
                                border.color: modelData.connected ? theme.blueDeep : "transparent"
                                border.width: 1
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: deviceRow.modelData.type === "audio" ? "󰋋" : "󰂯"
                                    font.family: "GeistMono Nerd Font Propo"
                                    font.pixelSize: 16
                                    color: deviceRow.modelData.connected ? theme.blueLight : theme.textMuted
                                }
                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 34
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 126
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: deviceRow.modelData.name
                                        elide: Text.ElideRight
                                        color: deviceRow.modelData.connected ? theme.blueLight : theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        width: parent.width
                                        text: deviceRow.pending ? (root.pendingAction === "pair" ? "Pairing…" : root.pendingAction === "connect" ? "Connecting…" : "Disconnecting…")
                                            : deviceRow.modelData.connected ? "Connected" + (deviceRow.modelData.battery >= 0 ? " · " + deviceRow.modelData.battery + "%" : "") : deviceRow.modelData.discovered ? "Available to pair" : "Not connected"
                                        elide: Text.ElideRight
                                        color: theme.textMuted
                                        font.family: theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                }
                                BluetoothActionButton {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 80
                                    text: deviceRow.pending ? "Please wait…" : deviceRow.modelData.discovered ? "Pair" : deviceRow.modelData.connected ? "Disconnect" : "Connect"
                                    accent: deviceRow.modelData.connected
                                    enabled: !root.busy
                                    Accessible.name: text + " " + deviceRow.modelData.name
                                    onClicked: {
                                        root.actionError = "";
                                        root.pendingAction = deviceRow.modelData.discovered ? "pair" : deviceRow.modelData.connected ? "disconnect" : "connect";
                                        root.isConnecting = true;
                                        root.connectingMac = deviceRow.modelData.mac;
                                        actionProc.command = ["/home/ferram/.local/bin/hypr-bluetooth", root.pendingAction, deviceRow.modelData.mac, deviceRow.modelData.name];
                                        actionProc.running = true;
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !root.isPowered || root.visibleDevices.length === 0
                    width: parent.width
                    height: emptyText.implicitHeight + 24
                    radius: theme.radiusSmall
                    color: theme.surface
                    Text {
                        id: emptyText
                        anchors.centerIn: parent
                        width: parent.width - 24
                        text: !root.isPowered ? "Bluetooth is off. Turn it on to reconnect or pair a device." : "No paired devices yet. Put your device in pairing mode, then choose Pair New Device."
                        wrapMode: Text.WordWrap
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Text {
                    visible: root.actionError !== ""
                    width: parent.width
                    text: root.actionError
                    wrapMode: Text.WordWrap
                    color: theme.red
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                }

                Text {
                    visible: root.isPowered && (scanProc.running || root.hasScanned)
                    width: parent.width
                    text: scanProc.running ? "Searching for nearby devices…"
                        : root.nearbyDevices.filter(d => !root.pairedDevices.some(p => p.mac === d.mac)).length > 0
                        ? "Choose Pair next to a nearby device."
                        : "No new devices found. Enable pairing mode and scan again."
                    wrapMode: Text.WordWrap
                    color: theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                }

                BluetoothActionButton {
                    visible: root.isPowered
                    width: parent.width
                    text: scanProc.running ? "Searching…" : root.hasScanned ? "Scan Again" : "＋  Pair New Device"
                    enabled: !root.busy
                    onClicked: {
                        root.actionError = "";
                        root.nearbyDevices = [];
                        root.hasScanned = false;
                        scanProc.running = true;
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8
                    BluetoothActionButton {
                        width: (parent.width - 8) / 2
                        text: toggleProc.running ? "Please wait…" : root.isPowered ? "Turn Bluetooth Off" : "Turn Bluetooth On"
                        enabled: !root.busy
                        onClicked: {
                            root.actionError = "";
                            toggleProc.command = ["/home/ferram/.local/bin/hypr-bluetooth", "toggle"];
                            toggleProc.running = true;
                        }
                    }
                    BluetoothActionButton {
                        width: (parent.width - 8) / 2
                        text: "Manage Bluetooth"
                        accent: true
                        enabled: !root.busy
                        onClicked: {
                            root.actionError = "";
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
