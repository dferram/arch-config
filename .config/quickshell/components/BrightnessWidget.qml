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

    property int brightnessLevel: 60
    property bool nightModeActive: false
    property var osdService: null

    Connections {
        target: root.osdService
        function onTriggered() {
            if (root.osdService && root.osdService.osdType === "brightness") {
                root.brightnessLevel = root.osdService.level;
            }
        }
    }

    // Auto-dismiss timer: automatically closes popup after 3.5s of inactivity
    Timer {
        id: autoCloseTimer
        interval: 3500
        repeat: false
        onTriggered: {
            if (root.activePopupId === "brightness") {
                root.togglePopup("");
            }
        }
    }

    onActivePopupIdChanged: {
        if (root.activePopupId === "brightness") {
            autoCloseTimer.restart();
        } else {
            autoCloseTimer.stop();
        }
    }

    // Query brightness
    Process {
        id: queryProc
        command: ["/home/ferram/.local/bin/hypr-brightness", "get"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim().replace("%", "");
                let val = parseInt(txt);
                if (!isNaN(val)) root.brightnessLevel = Math.max(1, Math.min(100, val));
            }
        }
    }

    // Query night mode status
    Process {
        id: queryNightProc
        command: ["/home/ferram/.local/bin/hypr-night-mode", "status"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                root.nightModeActive = text.trim() === "on";
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: {
            if (!queryProc.running) queryProc.running = true;
            if (!queryNightProc.running) queryNightProc.running = true;
        }
    }

    Process {
        id: execProc
        onExited: {
            if (!queryProc.running) queryProc.running = true;
            if (!queryNightProc.running) queryNightProc.running = true;
        }
    }

    function setBright(action, arg) {
        autoCloseTimer.restart();
        if (arg !== undefined) {
            execProc.command = ["/home/ferram/.local/bin/hypr-brightness", action, String(arg)];
        } else {
            execProc.command = ["/home/ferram/.local/bin/hypr-brightness", action];
        }
        execProc.running = true;
    }

    function toggleNight() {
        autoCloseTimer.restart();
        execProc.command = ["/home/ferram/.local/bin/hypr-night-mode", "toggle"];
        execProc.running = true;
    }

    // Lucide Sun SVG icon (matching Night Mode aesthetic)
    property string iconDataUri: {
        let col = root.nightModeActive ? "%23f59e0b" : "%23ffffff";
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
               "<circle cx='12' cy='12' r='4'/>" +
               "<line x1='12' y1='2' x2='12' y2='4'/>" +
               "<line x1='12' y1='20' x2='12' y2='22'/>" +
               "<line x1='4.93' y1='4.93' x2='6.34' y2='6.34'/>" +
               "<line x1='17.66' y1='17.66' x2='19.07' y2='19.07'/>" +
               "<line x1='2' y1='12' x2='4' y2='12'/>" +
               "<line x1='20' y1='12' x2='22' y2='12'/>" +
               "<line x1='4.93' y1='19.07' x2='6.34' y2='17.66'/>" +
               "<line x1='17.66' y1='6.34' x2='19.07' y2='4.93'/>" +
               "</svg>";
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.brightnessLevel + "%"
        accentColor: root.nightModeActive ? "#f59e0b" : theme.blue
        active: root.activePopupId === "brightness"
        customPadding: 8

        onClicked: {
            if (!queryProc.running) queryProc.running = true;
            if (!queryNightProc.running) queryNightProc.running = true;
            root.togglePopup("brightness");
        }
    }

    // Scroll wheel on pill to adjust brightness smoothly
    WheelHandler {
        target: pill
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                root.setBright("up", "5");
            } else if (event.angleDelta.y < 0) {
                root.setBright("down", "5");
            }
        }
    }

    // Popover Window with auto-dismiss and spacious layout
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "brightness"
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
                            color: root.nightModeActive ? Qt.rgba(245/255, 158/255, 11/255, 0.18) : Qt.rgba(255, 255, 255, 0.12)
                            border.color: root.nightModeActive ? Qt.rgba(245/255, 158/255, 11/255, 0.4) : Qt.rgba(255, 255, 255, 0.22)
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
                                text: "Display & Brightness"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Text {
                                text: root.brightnessLevel + "% Backlight" + (root.nightModeActive ? " • Warm Tint" : "")
                                color: root.nightModeActive ? "#f59e0b" : theme.textSub
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
                        color: root.nightModeActive ? Qt.rgba(245/255, 158/255, 11/255, 0.2) : Qt.rgba(255, 255, 255, 0.12)
                        border.color: root.nightModeActive ? "#f59e0b" : Qt.rgba(255, 255, 255, 0.25)
                        border.width: 1

                        Text {
                            id: badgeTxt
                            anchors.centerIn: parent
                            text: root.brightnessLevel + "%"
                            color: root.nightModeActive ? "#f59e0b" : theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }

                // Apple Control Center Style Liquid Glass Brightness Slider
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
                        width: Math.max(44, parent.width * (root.brightnessLevel / 100.0))
                        radius: 22
                        color: root.nightModeActive ? "#f59e0b" : "#ffffff"

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

                    // Embedded Sun Icon (iOS Control Center style - dark on white fill, light on dark)
                    Image {
                        id: sliderIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        source: (root.brightnessLevel > 18)
                            ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%2308080a' stroke-width='2' stroke-linecap='round'><circle cx='12' cy='12' r='4'/><path d='M12 2v2 M12 20v2 M4.93 4.93l1.41 1.41 M17.66 17.66l1.41 1.41 M2 12h2 M20 12h2 M6.34 17.66l-1.41 1.41 M19.07 4.93l-1.41 1.41'/></svg>"
                            : root.iconDataUri
                    }

                    // Embedded Level Text
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.brightnessLevel + "%"
                        color: (root.brightnessLevel > 75) ? "#08080a" : theme.text
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
                            let ratio = Math.max(0.01, Math.min(1.0, mouseX / sliderTrack.width));
                            let target = Math.round(ratio * 100);
                            root.brightnessLevel = target;
                            root.setBright("set", target);
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
                                root.setBright("up", "5");
                            } else if (event.angleDelta.y < 0) {
                                root.setBright("down", "5");
                            }
                        }
                    }
                }

                // Quick Presets (25%, 50%, 75%, 100%)
                Row {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [25, 50, 75, 100]

                        Rectangle {
                            width: (cardLayout.width - 18) / 4
                            height: 26
                            radius: 13
                            property bool isNear: Math.abs(root.brightnessLevel - modelData) <= 12
                            color: isNear
                                ? (root.nightModeActive ? Qt.rgba(245/255, 158/255, 11/255, 0.22) : Qt.rgba(255, 255, 255, 0.22))
                                : (pMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isNear ? (root.nightModeActive ? "#f59e0b" : "#ffffff") : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData + "%"
                                color: parent.isNear ? (root.nightModeActive ? "#f59e0b" : "#ffffff") : theme.textMuted
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
                                    root.brightnessLevel = modelData;
                                    root.setBright("set", modelData);
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.borderSubtle
                }

                // Night Mode / Eye Protection Toggle Card (Spacious, No Overlap)
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: theme.radiusSmall
                    color: root.nightModeActive ? Qt.rgba(245/255, 158/255, 11/255, 0.16) : (nightMouse.containsMouse ? theme.surfaceHover : theme.surface)
                    border.color: root.nightModeActive ? "#f59e0b" : theme.borderSubtle
                    border.width: 1

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        // Left icon badge
                        Rectangle {
                            id: moonBadge
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: 15
                            color: root.nightModeActive ? "#f59e0b" : theme.surfaceActive

                            Image {
                                anchors.centerIn: parent
                                width: 15
                                height: 15
                                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23ffffff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/></svg>"
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        // Middle text column (constrained so it never touches the switch)
                        Column {
                            anchors.left: moonBadge.right
                            anchors.leftMargin: 10
                            anchors.right: toggleSwitch.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "Night Light"
                                color: root.nightModeActive ? "#f59e0b" : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: root.nightModeActive ? "Warm 3500K active" : "Standard color temperature"
                                color: root.nightModeActive ? "#fbbf24" : theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Right toggle switch pill
                        Rectangle {
                            id: toggleSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 20
                            radius: 10
                            color: root.nightModeActive ? "#f59e0b" : theme.surfaceActive
                            border.color: root.nightModeActive ? "#f59e0b" : theme.borderSubtle
                            border.width: 1

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: root.nightModeActive ? theme.bgDark : theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.nightModeActive ? 20 : 3

                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            }
                        }
                    }

                    MouseArea {
                        id: nightMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            autoCloseTimer.restart();
                            root.nightModeActive = !root.nightModeActive;
                            root.toggleNight();
                        }
                    }
                }
            }
        }
    }
}
