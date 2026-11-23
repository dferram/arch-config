import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 448
    implicitHeight: 430

    radius: 20
    color: theme.widgetGlass
    border.color: hoverArea.containsMouse ? theme.border : theme.borderSubtle
    border.width: 1
    clip: true

    Behavior on border.color { ColorAnimation { duration: 180 } }

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

    // Peripherals state
    property bool monitorConnected: false
    property string monitorName: "Monitor"
    property string monitorDetail: "Offline"

    property bool mouseConnected: false
    property string mouseName: "Mouse"
    property string mouseTransport: ""

    property bool keyboardConnected: false
    property string keyboardName: "Terport TR69N"
    property string keyboardTransport: ""

    property bool baseOn: false
    property bool uhubctlConfigured: false
    readonly property bool baseConnectable: uhubctlConfigured || monitorConnected || mouseConnected || keyboardConnected
    readonly property bool effectiveBaseOn: baseOn && baseConnectable

    // 3D Keyboard LED replica state
    property bool ledOn: true
    property string ledMode: "rainbow"
    property string ledColorHex: "#bf4148"
    property bool ledMultiColor: true
    property real ledBrightness: 0.90
    property real ledSpeed: 1.0

    property bool modeMenuOpen: false
    property bool colorMenuOpen: false
    property string selectedDevice: "keyboard" // "keyboard" | "monitor" | "mouse" | "base"
    readonly property string effectiveMonitorStyle: monitorName.toLowerCase().indexOf("samsung") !== -1 ? "samsung" : "mark"

    readonly property var ledModes: [
        { "id": "rainbow",         "label": "Spectrum Wave" },
        { "id": "horizontal_wave", "label": "Horizontal Flow" },
        { "id": "vertical_wave",   "label": "Vertical Cascade" },
        { "id": "breathing",       "label": "Breathing" },
        { "id": "color_cycle",     "label": "Neon Cycle" },
        { "id": "static",          "label": "Static Solid" },
        { "id": "gradient",        "label": "Dual Glow" },
        { "id": "ripple",          "label": "Ripple Ring" },
        { "id": "sine_wave",       "label": "Aurora Sine" },
        { "id": "marquee",         "label": "Marquee Snake" },
        { "id": "raindrop",        "label": "Raindrop" },
        { "id": "starlight",       "label": "Starlight" },
        { "id": "center_split",    "label": "Center Split" },
        { "id": "collision",       "label": "Laser Clash" },
        { "id": "radar",           "label": "Radar Sweep" },
        { "id": "reactive_typing", "label": "Reactive Burst" },
        { "id": "crosshair",       "label": "Crosshair Scan" },
        { "id": "wasd_gaming",     "label": "Gaming Zone" },
        { "id": "off",             "label": "Lights Off" }
    ]

    readonly property var colorPalette: [
        { "id": "multi",  "label": "Full RGB",  "hex": "multi" },
        { "id": "accent", "label": "Theme",     "hex": theme.blue.toString() },
        { "id": "red",    "label": "Red",       "hex": "#ff2d3b" },
        { "id": "orange", "label": "Orange",    "hex": "#ff7b00" },
        { "id": "yellow", "label": "Yellow",    "hex": "#ffd60a" },
        { "id": "green",  "label": "Green",     "hex": "#30d158" },
        { "id": "cyan",   "label": "Cyan",      "hex": "#06b6d4" },
        { "id": "blue",   "label": "Blue",      "hex": "#0a84ff" },
        { "id": "purple", "label": "Purple",    "hex": "#a855f7" },
        { "id": "pink",   "label": "Magenta",   "hex": "#ff2d87" },
        { "id": "white",  "label": "Ice White", "hex": "#f1f5f9" }
    ]

    function currentModeLabel() {
        if (!root.ledOn || root.ledMode === "off") return "Lights Off";
        for (let i = 0; i < ledModes.length; i++) {
            if (ledModes[i].id === root.ledMode) return ledModes[i].label;
        }
        return "Spectrum Wave";
    }

    function currentColorLabel() {
        if (root.ledMultiColor) return "Full RGB";
        for (let i = 0; i < colorPalette.length; i++) {
            if (colorPalette[i].hex.toLowerCase() === root.ledColorHex.toLowerCase()) return colorPalette[i].label;
        }
        return "Custom";
    }

    function applyStatusJson(txt) {
        let s = (txt || "").trim();
        if (!s || !s.startsWith("{")) return;
        try {
            let d = JSON.parse(s);
            if (d.monitor) {
                root.monitorConnected = !!d.monitor.connected;
                root.monitorName = d.monitor.name || "Monitor";
                root.monitorDetail = d.monitor.detail || (root.monitorConnected ? "Connected" : "Offline");
            }
            if (d.mouse) {
                root.mouseConnected = !!d.mouse.connected;
                root.mouseName = d.mouse.name || "Mouse";
                root.mouseTransport = d.mouse.transport || "";
            }
            if (d.keyboard) {
                root.keyboardConnected = !!d.keyboard.connected;
                root.keyboardName = d.keyboard.name || "Terport TR69N";
                root.keyboardTransport = d.keyboard.transport || "";
            }
            if (d.base) {
                root.baseOn = !!d.base.on;
                root.uhubctlConfigured = !!d.base.uhubctlConfigured;
            }
            if (d.replica) {
                root.ledOn = (d.replica.ledOn !== undefined) ? !!d.replica.ledOn : true;
                if (d.replica.mode) root.ledMode = d.replica.mode;
                if (d.replica.color) root.ledColorHex = d.replica.color;
                if (d.replica.multiColor !== undefined) root.ledMultiColor = !!d.replica.multiColor;
                if (d.replica.brightness !== undefined) root.ledBrightness = d.replica.brightness;
                if (d.replica.speed !== undefined) root.ledSpeed = d.replica.speed;
            }
        } catch (e) {}
    }

    Process {
        id: statusProc
        command: ["python3", Quickshell.shellPath("scripts/peripherals-status.py"), "status"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatusJson(text)
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: root.applyStatusJson(text)
        }
    }

    function refreshStatus() {
        if (!statusProc.running) statusProc.running = true;
    }

    function toggleBase() {
        if (!root.baseConnectable) return;
        root.baseOn = !root.baseOn;
        actionProc.running = false;
        actionProc.command = ["python3", Quickshell.shellPath("scripts/peripherals-status.py"), "toggle-base"];
        actionProc.running = true;
    }

    function saveReplica(mode, colorHex, multiFlag, brightness, speed, ledOnFlag) {
        if (!root.keyboardConnected) return;
        if (mode !== undefined) root.ledMode = mode;
        if (colorHex !== undefined) root.ledColorHex = colorHex;
        if (multiFlag !== undefined) root.ledMultiColor = multiFlag;
        if (brightness !== undefined) root.ledBrightness = brightness;
        if (speed !== undefined) root.ledSpeed = speed;
        if (ledOnFlag !== undefined) root.ledOn = ledOnFlag;

        actionProc.running = false;
        actionProc.command = [
            "python3", Quickshell.shellPath("scripts/peripherals-status.py"), "set-replica",
            "--mode", root.ledMode,
            "--color", root.ledColorHex,
            "--multi-color", root.ledMultiColor ? "true" : "false",
            "--brightness", String(root.ledBrightness),
            "--speed", String(root.ledSpeed),
            "--led-on", root.ledOn ? "true" : "false"
        ];
        actionProc.running = true;
    }

    function cycleBrightness() {
        let nextB = 1.0;
        if (root.ledBrightness >= 0.92) nextB = 0.45;
        else if (root.ledBrightness >= 0.65) nextB = 1.0;
        else nextB = 0.75;
        saveReplica(undefined, undefined, undefined, nextB, undefined, true);
    }

    function cycleSpeed() {
        let nextS = 1.0;
        if (root.ledSpeed >= 1.8) nextS = 0.6;
        else if (root.ledSpeed >= 1.3) nextS = 2.0;
        else if (root.ledSpeed >= 0.85) nextS = 1.4;
        else nextS = 1.0;
        saveReplica(undefined, undefined, undefined, undefined, nextS, undefined);
    }

    Component.onCompleted: refreshStatus()

    Timer {
        interval: 3500
        repeat: true
        running: root.isLive
        onTriggered: root.refreshStatus()
    }

    onIsLiveChanged: {
        if (isLive) refreshStatus();
    }

    // Background drag & right-click menu MouseArea
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 0

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.modeMenuOpen = false;
                root.colorMenuOpen = false;
                if (root.wrapper) root.wrapper.menuOpen = !root.wrapper.menuOpen;
                return;
            }
            if (mouse.button !== Qt.LeftButton) return;
            root.modeMenuOpen = false;
            root.colorMenuOpen = false;
            if (root.wrapper && root.wrapper.menuOpen) root.wrapper.menuOpen = false;
            let canvasPt = mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
            startScreenX = canvasPt.x;
            startScreenY = canvasPt.y;
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!hoverArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
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
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        z: 1

        // 1. Peripheral Cards (Monitor, Mouse, Base, TR69N) - Clean headerless top row
        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            // Card 1: Monitor
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 12
                clip: true
                readonly property bool isSel: root.selectedDevice === "monitor"
                color: root.monitorConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.10) : Qt.rgba(0.05, 0.055, 0.08, 0.58)
                border.color: isSel ? theme.blueLight : (root.monitorConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.36) : Qt.rgba(255, 255, 255, 0.08))
                border.width: isSel ? 1.5 : 1

                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 10; anchors.rightMargin: 10; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(255, 255, 255, 0.14) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            width: 22; height: 22; radius: 7
                            color: root.monitorConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.18) : Qt.rgba(255, 255, 255, 0.05)
                            border.color: root.monitorConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.36) : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "󰍹"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: root.monitorConnected ? theme.green : theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            height: 15
                            width: monPillTxt.implicitWidth + 8
                            radius: 7.5
                            color: root.monitorConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.22) : Qt.rgba(255, 255, 255, 0.05)
                            Text {
                                id: monPillTxt
                                anchors.centerIn: parent
                                text: root.monitorConnected ? "ON" : "OFF"
                                color: root.monitorConnected ? theme.green : theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 7
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            width: parent.width
                            text: root.monitorConnected ? root.monitorName : "Monitor"
                            color: root.monitorConnected ? theme.text : theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.monitorConnected ? root.monitorDetail : "Offline"
                            color: root.monitorConnected ? theme.textMuted : theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.modeMenuOpen = false;
                        root.colorMenuOpen = false;
                        root.selectedDevice = "monitor";
                    }
                }
            }

            // Card 2: Mouse
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 12
                clip: true
                readonly property bool isSel: root.selectedDevice === "mouse"
                color: root.mouseConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.10) : Qt.rgba(0.05, 0.055, 0.08, 0.58)
                border.color: isSel ? theme.blueLight : (root.mouseConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.36) : Qt.rgba(255, 255, 255, 0.08))
                border.width: isSel ? 1.5 : 1

                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 10; anchors.rightMargin: 10; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(255, 255, 255, 0.14) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            width: 22; height: 22; radius: 7
                            color: root.mouseConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.18) : Qt.rgba(255, 255, 255, 0.05)
                            border.color: root.mouseConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.36) : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "󰍽"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: root.mouseConnected ? theme.green : theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            height: 15
                            width: mousePillTxt.implicitWidth + 8
                            radius: 7.5
                            color: root.mouseConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.22) : Qt.rgba(255, 255, 255, 0.05)
                            Text {
                                id: mousePillTxt
                                anchors.centerIn: parent
                                text: root.mouseConnected ? root.mouseTransport : "OFF"
                                color: root.mouseConnected ? theme.green : theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 7
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            width: parent.width
                            text: root.mouseConnected ? root.mouseName : "Mouse"
                            color: root.mouseConnected ? theme.text : theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.mouseConnected ? "Connected" : "Offline"
                            color: root.mouseConnected ? theme.textMuted : theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.modeMenuOpen = false;
                        root.colorMenuOpen = false;
                        root.selectedDevice = "mouse";
                    }
                }
            }

            // Card 3: Cooling Base (Interactive Power Switch only when desk setup / uhubctl active)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 12
                clip: true
                readonly property bool isSel: root.selectedDevice === "base"
                color: root.effectiveBaseOn
                    ? Qt.rgba(0.02, 0.71, 0.83, 0.15)
                    : (baseMa.containsMouse ? Qt.rgba(0.08, 0.09, 0.13, 0.75) : Qt.rgba(0.05, 0.055, 0.08, 0.58))
                border.color: isSel
                    ? theme.blueLight
                    : (root.effectiveBaseOn
                        ? Qt.rgba(0.13, 0.83, 0.93, 0.58)
                        : (baseMa.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)))
                border.width: isSel ? 1.5 : 1
                scale: baseMa.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 110 } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 10; anchors.rightMargin: 10; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(255, 255, 255, 0.14) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            width: 22; height: 22; radius: 7
                            color: root.effectiveBaseOn ? Qt.rgba(0.02, 0.71, 0.83, 0.24) : Qt.rgba(255, 255, 255, 0.05)
                            border.color: root.effectiveBaseOn ? Qt.rgba(0.13, 0.83, 0.93, 0.48) : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "󰈐"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: root.effectiveBaseOn ? "#22d3ee" : theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 24; height: 13; radius: 6.5
                            opacity: root.baseConnectable ? 1.0 : 0.40
                            color: root.effectiveBaseOn ? "#06b6d4" : Qt.rgba(255, 255, 255, 0.14)
                            Rectangle {
                                x: root.effectiveBaseOn ? 13 : 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9; height: 9; radius: 4.5
                                color: "#ffffff"
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            width: parent.width
                            text: "Base"
                            color: root.effectiveBaseOn ? theme.text : theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: !root.baseConnectable ? "Offline" : (root.effectiveBaseOn ? "Cooling ON" : "Standby")
                            color: root.effectiveBaseOn ? "#67e8f9" : theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: baseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.modeMenuOpen = false;
                        root.colorMenuOpen = false;
                        root.selectedDevice = "base";
                    }
                }

                // Dedicated tap area on the switch pill to toggle power directly (only when connectable)
                MouseArea {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: 40
                    height: 30
                    enabled: root.baseConnectable
                    cursorShape: root.baseConnectable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    z: 2
                    onClicked: {
                        root.selectedDevice = "base";
                        root.toggleBase();
                    }
                }
            }

            // Card 4: Keyboard (Terport TR69N)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 12
                clip: true
                readonly property bool isSel: root.selectedDevice === "keyboard"
                color: root.keyboardConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.10) : Qt.rgba(0.05, 0.055, 0.08, 0.58)
                border.color: isSel ? theme.blueLight : (root.keyboardConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.36) : Qt.rgba(255, 255, 255, 0.08))
                border.width: isSel ? 1.5 : 1

                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 10; anchors.rightMargin: 10; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(255, 255, 255, 0.14) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            width: 22; height: 22; radius: 7
                            color: root.keyboardConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.18) : Qt.rgba(255, 255, 255, 0.05)
                            border.color: root.keyboardConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.36) : Qt.rgba(255, 255, 255, 0.08)
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "󰌌"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: root.keyboardConnected ? theme.green : theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            height: 15
                            width: kbPillTxt.implicitWidth + 8
                            radius: 7.5
                            color: root.keyboardConnected ? Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.22) : Qt.rgba(255, 255, 255, 0.05)
                            Text {
                                id: kbPillTxt
                                anchors.centerIn: parent
                                text: root.keyboardConnected ? root.keyboardTransport : "USB"
                                color: root.keyboardConnected ? theme.green : theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 7
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            width: parent.width
                            text: "TR69N"
                            color: root.keyboardConnected ? theme.text : theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.keyboardConnected ? "Connected" : "Unplugged"
                            color: root.keyboardConnected ? theme.textMuted : theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.modeMenuOpen = false;
                        root.colorMenuOpen = false;
                        root.selectedDevice = "keyboard";
                    }
                }
            }
        }

        // 3. Clean Interactive 3D Stage (Keyboard, Monitor, Mouse, or Cooling Base)
        Rectangle {
            id: stage3d
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: Qt.rgba(0.025, 0.030, 0.048, 0.72)
            border.color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 1
            clip: true

            TerportTR69N3D {
                id: kb3d
                anchors.fill: parent
                activeDevice: root.selectedDevice
                monitorConnected: root.monitorConnected
                monitorStyle: root.effectiveMonitorStyle
                mouseConnected: root.mouseConnected
                baseOn: root.effectiveBaseOn
                ledOn: root.keyboardConnected && root.ledOn
                ledMode: root.keyboardConnected ? root.ledMode : "off"
                ledColor: root.ledColorHex
                multiColor: root.ledMultiColor
                ledBrightness: root.ledBrightness
                ledSpeed: root.ledSpeed
                connected: root.keyboardConnected
                isLive: root.isLive
            }

            // Minimal reset view icon button (top-right, subtle)
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                width: 24
                height: 24
                radius: 8
                color: resetViewMa.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(0, 0, 0, 0.42)
                border.color: Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰑓"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: resetViewMa.containsMouse ? "#ffffff" : theme.textDim
                }

                MouseArea {
                    id: resetViewMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: kb3d.resetCamera()
                }
            }
        }

        // 2. LED Controls Bar (only shown when TR69N is selected AND physically connected)
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.selectedDevice === "keyboard" && root.keyboardConnected

            // Mode Dropdown Trigger
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 9
                color: root.modeMenuOpen ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.24) : (modeTrigMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.color: root.modeMenuOpen ? theme.blueLight : Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "󰚀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: theme.blueLight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.currentModeLabel()
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        text: root.modeMenuOpen ? "󰅃" : "󰅀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: theme.textDim
                    }
                }

                MouseArea {
                    id: modeTrigMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.colorMenuOpen = false;
                        root.modeMenuOpen = !root.modeMenuOpen;
                    }
                }
            }

            // Color Dropdown Trigger
            Rectangle {
                Layout.preferredWidth: 108
                Layout.preferredHeight: 28
                radius: 9
                color: root.colorMenuOpen ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.24) : (colTrigMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                border.color: root.colorMenuOpen ? theme.blueLight : Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Rectangle {
                        width: 11; height: 11; radius: 5.5
                        color: root.ledMultiColor ? "transparent" : root.ledColorHex
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.45)

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: root.ledMultiColor
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#ff2d3b" }
                                GradientStop { position: 0.33; color: "#ffd60a" }
                                GradientStop { position: 0.66; color: "#06b6d4" }
                                GradientStop { position: 1.0; color: "#a855f7" }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.currentColorLabel()
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.colorMenuOpen ? "󰅃" : "󰅀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: theme.textDim
                    }
                }

                MouseArea {
                    id: colTrigMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.modeMenuOpen = false;
                        root.colorMenuOpen = !root.colorMenuOpen;
                    }
                }
            }

            // Speed Pill
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: spdRow.implicitWidth + 14
                radius: 9
                color: spdMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Row {
                    id: spdRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󱐋"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.ledSpeed.toFixed(1).replace(".0", "") + "x"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: spdMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleSpeed()
                }
            }

            // Brightness Pill
            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: brtRow.implicitWidth + 14
                radius: 9
                color: brtMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Row {
                    id: brtRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰃟"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: (root.ledOn && root.ledMode !== "off") ? "#ffffff" : theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Math.round(root.ledBrightness * 100) + "%"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: brtMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleBrightness()
                }
            }
        }
    }

    // =========================================================================
    // LED MODE DROPDOWN POPOVER (19 Terport TR69N Effects)
    // =========================================================================
    Rectangle {
        id: modeDropdown
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 48
        height: Math.min(246, modeGrid.implicitHeight + 20)
        radius: 14
        color: Qt.rgba(0.055, 0.06, 0.095, 0.96)
        border.color: theme.borderGlow
        border.width: 1
        z: 30
        clip: true
        visible: opacity > 0.01
        opacity: (root.modeMenuOpen && root.keyboardConnected && root.selectedDevice === "keyboard") ? 1.0 : 0.0
        scale: root.modeMenuOpen ? 1.0 : 0.96
        transformOrigin: Item.Bottom
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 10
            contentWidth: width
            contentHeight: modeGrid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Grid {
                id: modeGrid
                width: parent.width
                columns: 2
                spacing: 5

                Repeater {
                    model: root.ledModes
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isSel: root.ledMode === modelData.id && (root.ledOn || modelData.id === "off")
                        width: (modeGrid.width - 5) / 2
                        height: 26
                        radius: 8
                        color: isSel
                            ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.30)
                            : (mItemMa.containsMouse ? Qt.rgba(255, 255, 255, 0.09) : Qt.rgba(255, 255, 255, 0.03))
                        border.color: isSel ? theme.blueLight : Qt.rgba(255, 255, 255, 0.06)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 8
                            spacing: 6

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: isSel ? theme.blueLight : Qt.rgba(255, 255, 255, 0.22)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: isSel ? "#ffffff" : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: isSel ? Font.Bold : Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: mItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.modeMenuOpen = false;
                                root.saveReplica(modelData.id, undefined, undefined, undefined, undefined, modelData.id !== "off");
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // COLOR PALETTE DROPDOWN POPOVER (Full RGB + 10 Single Colors)
    // =========================================================================
    Rectangle {
        id: colorDropdown
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 14
        anchors.bottomMargin: 48
        width: 224
        height: colorGrid.implicitHeight + 20
        radius: 14
        color: Qt.rgba(0.055, 0.06, 0.095, 0.96)
        border.color: theme.borderGlow
        border.width: 1
        z: 30
        clip: true
        visible: opacity > 0.01
        opacity: (root.colorMenuOpen && root.keyboardConnected && root.selectedDevice === "keyboard") ? 1.0 : 0.0
        scale: root.colorMenuOpen ? 1.0 : 0.96
        transformOrigin: Item.BottomRight
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
        }

        Grid {
            id: colorGrid
            anchors.fill: parent
            anchors.margins: 10
            columns: 2
            spacing: 5

            Repeater {
                model: root.colorPalette
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isMultiOpt: modelData.hex === "multi"
                    readonly property bool isSel: isMultiOpt
                        ? root.ledMultiColor
                        : (!root.ledMultiColor && root.ledColorHex.toLowerCase() === modelData.hex.toLowerCase())
                    width: (colorGrid.width - 5) / 2
                    height: 26
                    radius: 8
                    color: isSel
                        ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28)
                        : (cItemMa.containsMouse ? Qt.rgba(255, 255, 255, 0.09) : Qt.rgba(255, 255, 255, 0.03))
                    border.color: isSel ? theme.blueLight : Qt.rgba(255, 255, 255, 0.06)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Rectangle {
                            width: 11; height: 11; radius: 5.5
                            color: isMultiOpt ? "transparent" : modelData.hex
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.38)

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: isMultiOpt
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#ff2d3b" }
                                    GradientStop { position: 0.33; color: "#ffd60a" }
                                    GradientStop { position: 0.66; color: "#06b6d4" }
                                    GradientStop { position: 1.0; color: "#a855f7" }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: isSel ? "#ffffff" : theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: isSel ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: cItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.colorMenuOpen = false;
                            let nextMode = (root.ledMode === "off" || !root.ledOn) ? "static" : root.ledMode;
                            if (isMultiOpt) {
                                root.saveReplica(nextMode, undefined, true, undefined, undefined, true);
                            } else {
                                if (nextMode === "rainbow" || nextMode === "horizontal_wave" || nextMode === "vertical_wave" || nextMode === "color_cycle") {
                                    nextMode = "static";
                                }
                                root.saveReplica(nextMode, modelData.hex, false, undefined, undefined, true);
                            }
                        }
                    }
                }
            }
        }
    }
}
