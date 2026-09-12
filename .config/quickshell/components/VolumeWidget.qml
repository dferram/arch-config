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

    // High quality dynamic Volume SVG Icon
    property string iconDataUri: {
        let col = root.isMuted ? "%23ef4444" : "%2338bdf8";
        if (root.isMuted) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M11 5L6 9H2v6h4l5 4V5z' fill='" + col + "'/>" +
                   "<line x1='22' y1='9' x2='16' y2='15' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/>" +
                   "<line x1='16' y1='9' x2='22' y2='15' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/>" +
                   "</svg>";
        } else if (root.volumeLevel === 0) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M11 5L6 9H2v6h4l5 4V5z' fill='" + col + "'/>" +
                   "</svg>";
        } else if (root.volumeLevel < 50) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M11 5L6 9H2v6h4l5 4V5z' fill='" + col + "'/>" +
                   "<path d='M15.5 8.5a5 5 0 0 1 0 7' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/>" +
                   "</svg>";
        } else {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M11 5L6 9H2v6h4l5 4V5z' fill='" + col + "'/>" +
                   "<path d='M15.5 8.5a5 5 0 0 1 0 7' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/>" +
                   "<path d='M19 5a9.5 9.5 0 0 1 0 14' stroke='" + col + "' stroke-width='2' stroke-linecap='round'/>" +
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
                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        radius: theme.radiusSmall
                        color: root.isMuted ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.15) : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.15)
                        border.color: root.isMuted ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.3) : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.3)
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
                        spacing: 2

                        Text {
                            text: "Volume Output"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            text: root.isMuted ? "Audio Muted" : (root.volumeLevel + "% Level")
                            color: root.isMuted ? theme.red : theme.blueLight
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // Sleek Interactive Volume Slider
                Rectangle {
                    id: sliderTrack
                    width: parent.width
                    height: 18
                    radius: 9
                    color: Qt.rgba(14/255, 20/255, 32/255, 0.95)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    Rectangle {
                        id: sliderFill
                        width: Math.max(8, Math.min(parent.width, parent.width * (root.isMuted ? 0 : (root.volumeLevel / 100.0))))
                        height: parent.height
                        radius: 9
                        color: root.isMuted ? theme.textMuted : theme.blue

                        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                        // Glowing knob indicator at slider head
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            radius: 6
                            color: "#ffffff"
                            visible: !root.isMuted && root.volumeLevel > 3
                        }
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
                }

                // Quick buttons: Mute Toggle + Step buttons
                Row {
                    width: parent.width
                    spacing: 6

                    // Mute Button
                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 28
                        radius: theme.radiusSmall
                        color: root.isMuted ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.25) : (muteMouse.containsMouse ? theme.surfaceHover : theme.surface)
                        border.color: root.isMuted ? theme.red : theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: root.isMuted ? "Unmute" : "Mute"
                            color: root.isMuted ? theme.red : theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
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

                    // -5% Button
                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 28
                        radius: theme.radiusSmall
                        color: minusMouse.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "-5%"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: minusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                autoCloseTimer.restart();
                                root.setVol("down", "5");
                            }
                        }
                    }

                    // +5% Button
                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 28
                        radius: theme.radiusSmall
                        color: plusMouse.containsMouse ? theme.surfaceHover : theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+5%"
                            color: theme.blue
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: plusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                autoCloseTimer.restart();
                                root.setVol("up", "5");
                            }
                        }
                    }
                }
            }
        }
    }
}
