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

    property int volumeLevel: 100
    property bool isMuted: false
    property var osdService: null

    Connections {
        target: root.osdService
        function onTriggered() {
            if (root.osdService && root.osdService.osdType === "volume") {
                root.volumeLevel = root.osdService.level;
                root.isMuted = root.osdService.isMuted;
            }
        }
    }

    // Auto-dismiss timer: automatically closes popup after 3.5s of inactivity
    Timer {
        id: autoCloseTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (root.activePopupId === "volume") {
                root.togglePopup("");
            }
        }
    }

    onActivePopupIdChanged: {
        if (root.activePopupId === "volume") {
            autoCloseTimer.restart();
        } else {
            autoCloseTimer.stop();
        }
    }

    // Fetch volume info via hypr-volume
    Process {
        id: queryProc
        command: ["/home/ferram/.local/bin/hypr-volume", "get"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                root.isMuted = txt.indexOf("MUTED") !== -1;
                let clean = txt.replace("MUTED", "").replace("%", "").trim();
                let val = parseInt(clean);
                if (!isNaN(val)) root.volumeLevel = Math.max(0, Math.min(100, val));
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!queryProc.running) queryProc.running = true;
        }
    }

    Process {
        id: execProc
        onExited: {
            if (!queryProc.running) queryProc.running = true;
        }
    }

    function setVol(action, arg) {
        autoCloseTimer.restart();
        if (arg !== undefined) {
            execProc.command = ["/home/ferram/.local/bin/hypr-volume", action, String(arg)];
        } else {
            execProc.command = ["/home/ferram/.local/bin/hypr-volume", action];
        }
        execProc.running = true;
    }

    // High quality Lucide Volume SVG Icon (matching Night Mode aesthetic)
    property string iconDataUri: {
        let col = root.isMuted ? "%23ef4444" : "%23ffffff";
        if (root.isMuted) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<line x1='22' y1='9' x2='16' y2='15'/>" +
                   "<line x1='16' y1='9' x2='22' y2='15'/>" +
                   "</svg>";
        } else if (root.volumeLevel === 0) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "</svg>";
        } else if (root.volumeLevel < 50) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<path d='M15.54 8.46a5 5 0 0 1 0 7.07'/>" +
                   "</svg>";
        } else {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<path d='M15.54 8.46a5 5 0 0 1 0 7.07'/>" +
                   "<path d='M19.07 4.93a10 10 0 0 1 0 14.14'/>" +
                   "</svg>";
        }
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.isMuted ? "Muted" : (root.volumeLevel + "%")
        accentColor: root.isMuted ? theme.red : theme.blue
        active: root.activePopupId === "volume"
        customPadding: 8

        onClicked: {
            if (!queryProc.running) queryProc.running = true;
            root.togglePopup("volume");
        }
    }

    // Scroll wheel on pill to adjust volume smoothly
    WheelHandler {
        target: pill
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                root.setVol("up", "5");
            } else if (event.angleDelta.y < 0) {
                root.setVol("down", "5");
            }
        }
    }

    // Popover Window with auto-dismiss and sleek animations
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "volume"
        implicitWidth: 280
        implicitHeight: cardLayout.implicitHeight + 28
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            // Reset auto-dismiss timer on mouse interaction
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: autoCloseTimer.restart()
                onEntered: autoCloseTimer.stop()
                onExited: autoCloseTimer.restart()
            }

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12

                // Header
                Item {
                    width: parent.width
                    height: 32

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: theme.radiusSmall
                            color: root.isMuted ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.15) : Qt.rgba(255, 255, 255, 0.12)
                            border.color: root.isMuted ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.35) : Qt.rgba(255, 255, 255, 0.22)
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: root.iconDataUri
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: "Sound & Volume"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Text {
                                text: root.isMuted ? "Audio Output Muted" : (root.volumeLevel + "% Output Level")
                                color: root.isMuted ? theme.red : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }

                    Item { Layout.fillWidth: true; width: parent.width - 230; height: 1 }

                    // Level Badge
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: badgeTxt.implicitWidth + 14
                        height: 22
                        radius: 11
                        color: root.isMuted ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.18) : Qt.rgba(255, 255, 255, 0.12)
                        border.color: root.isMuted ? theme.red : Qt.rgba(255, 255, 255, 0.25)
                        border.width: 1

                        Text {
                            id: badgeTxt
                            anchors.centerIn: parent
                            text: root.isMuted ? "MUTED" : (root.volumeLevel + "%")
                            color: root.isMuted ? theme.red : theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }

                // Apple Control Center Style Liquid Glass Volume Slider
                Rectangle {
                    id: sliderTrack
                    width: parent.width
                    height: 44
                    radius: 22
                    color: Qt.rgba(255, 255, 255, 0.08)
                    border.color: sliderMouse.containsMouse ? theme.borderGlow : theme.borderSubtle
                    border.width: 1
                    clip: true

                    // Filled Portion (Clean Apple Frosted White Glass)
                    Rectangle {
                        id: sliderFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: root.isMuted ? 0 : Math.max(44, parent.width * (root.volumeLevel / 100.0))
                        radius: 22
                        color: root.isMuted ? theme.surfaceHover : "#ffffff"

                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        // Specular Top Shine
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.5)
                            radius: 22
                        }
                    }

                    // Embedded Speaker Icon (iOS Control Center style - dark on white fill, light on dark)
                    Image {
                        id: sliderIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        source: {
                            if (root.isMuted) {
                                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><path d='M11 5L6 9H2v6h4l5 4V5z' fill='%23ef4444'/><line x1='22' y1='9' x2='16' y2='15' stroke='%23ef4444' stroke-width='2' stroke-linecap='round'/><line x1='16' y1='9' x2='22' y2='15' stroke='%23ef4444' stroke-width='2' stroke-linecap='round'/></svg>";
                            }
                            let col = (root.volumeLevel > 18) ? "%2308080a" : "%23ffffff";
                            if (root.volumeLevel === 0) {
                                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><path d='M11 5L6 9H2v6h4l5 4V5z' fill='" + col + "'/></svg>";
                            } else if (root.volumeLevel < 50) {
                                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><path d='M11 5L6 9H2v6h4l5 4V5z' fill='" + col + "'/><path d='M15.5 8.5a5 5 0 0 1 0 7' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/></svg>";
                            } else {
                                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><path d='M11 5L6 9H2v6h4l5 4V5z' fill='" + col + "'/><path d='M15.5 8.5a5 5 0 0 1 0 7' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/><path d='M19 5a9.5 9.5 0 0 1 0 14' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/></svg>";
                            }
                        }
                    }

                    // Embedded Level Text
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isMuted ? "Muted" : (root.volumeLevel + "%")
                        color: (root.volumeLevel > 75 && !root.isMuted) ? "#08080a" : theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: sliderMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateFromMouse(mouseX) {
                            autoCloseTimer.restart();
                            let ratio = Math.max(0, Math.min(1.0, mouseX / sliderTrack.width));
                            let target = Math.round(ratio * 100);
                            root.volumeLevel = target;
                            if (root.isMuted) root.isMuted = false;
                            root.setVol("set", target);
                        }

                        onPressed: (mouse) => updateFromMouse(mouse.x)
                        onPositionChanged: (mouse) => {
                            if (pressed) updateFromMouse(mouse.x);
                        }
                    }

                    WheelHandler {
                        target: sliderTrack
                        onWheel: (event) => {
                            if (event.angleDelta.y > 0) {
                                root.setVol("up", "5");
                            } else if (event.angleDelta.y < 0) {
                                root.setVol("down", "5");
                            }
                        }
                    }
                }

                // Quick Controls: Mute Toggle + Presets (25%, 50%, 75%, 100%)
                Row {
                    width: parent.width
                    spacing: 6

                    // Mute Button
                    Rectangle {
                        width: 68
                        height: 26
                        radius: 8
                        color: root.isMuted ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.25) : (muteMouse.containsMouse ? theme.surfaceHover : theme.surface)
                        border.color: root.isMuted ? theme.red : (muteMouse.containsMouse ? theme.borderGlow : theme.borderSubtle)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Image {
                                width: 14
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: root.iconDataUri
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: root.isMuted ? "Unmute" : "Mute"
                                color: root.isMuted ? theme.red : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: muteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                autoCloseTimer.restart();
                                root.setVol("mute");
                            }
                        }
                    }

                    // Presets
                    Repeater {
                        model: [25, 50, 75, 100]

                        Rectangle {
                            width: (cardLayout.width - 68 - 24) / 4
                            height: 26
                            radius: 8
                            property bool isNear: !root.isMuted && Math.abs(root.volumeLevel - modelData) <= 12
                            color: isNear ? Qt.rgba(255, 255, 255, 0.22) : (pMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isNear ? "#ffffff" : (pMouse.containsMouse ? theme.borderGlow : theme.borderSubtle)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData + "%"
                                color: parent.isNear ? "#ffffff" : (pMouse.containsMouse ? theme.text : theme.textMuted)
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: parent.isNear ? Font.Bold : Font.Normal
                            }

                            MouseArea {
                                id: pMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    autoCloseTimer.restart();
                                    root.volumeLevel = modelData;
                                    if (root.isMuted) root.isMuted = false;
                                    root.setVol("set", modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
