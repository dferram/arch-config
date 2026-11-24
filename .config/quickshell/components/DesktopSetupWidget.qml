import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 448
    implicitHeight: 210

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

    // Keyboard state (read-only reflection from keyboard 0xb6 config block)
    property bool keyboardConnected: false
    property bool ledOn: true
    property string ledMode: "rainbow"
    property string ledColorHex: "#f1f5f9"
    property bool ledMultiColor: true
    property real ledBrightness: 1.0
    property real ledSpeed: 1.0

    function applyStatusJson(txt) {
        let s = (txt || "").trim();
        if (!s || !s.startsWith("{")) return;
        try {
            let d = JSON.parse(s);
            if (d.keyboard) {
                root.keyboardConnected = !!d.keyboard.connected;
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

    function refreshStatus() {
        if (!statusProc.running) statusProc.running = true;
    }

    Component.onCompleted: refreshStatus()

    Timer {
        interval: 1500
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

    // Full-widget 3D Stage (Terport TR69N Keyboard only)
    TerportTR69N3D {
        id: kb3d
        anchors.fill: parent
        anchors.margins: 6
        z: 1
        ledOn: root.keyboardConnected && root.ledOn
        ledMode: root.keyboardConnected ? root.ledMode : "off"
        ledColor: root.ledColorHex
        multiColor: root.ledMultiColor
        ledBrightness: root.ledBrightness
        ledSpeed: root.ledSpeed
        connected: root.keyboardConnected
        isLive: root.isLive
    }
}
