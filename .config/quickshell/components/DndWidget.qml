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

    property bool isDndOn: false

    // Process to query Do Not Disturb status
    Process {
        id: statusProc
        command: ["/home/ferram/.local/bin/hypr-dnd", "status"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let lines = text.trim().split("\n");
                if (lines.length > 0) {
                    let last = lines[lines.length - 1].trim();
                    root.isDndOn = (last === "on");
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!statusProc.running) statusProc.running = true;
        }
    }

    Process {
        id: toggleProc
        command: ["/home/ferram/.local/bin/hypr-dnd", "toggle"]
        onExited: {
            if (!statusProc.running) statusProc.running = true;
        }
    }

    function toggle() {
        root.isDndOn = !root.isDndOn;
        if (!toggleProc.running) toggleProc.running = true;
    }

    // High quality crisp SVG bell icons (matching other bar widgets)
    property string iconDataUri: {
        if (root.isDndOn) {
            let col = theme.urlColor(theme.purple);
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M13.73 21a2 2 0 0 1-3.46 0'/>" +
                   "<path d='M18.63 13A17.89 17.89 0 0 1 18 8'/>" +
                   "<path d='M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h14'/>" +
                   "<path d='M18 8a6 6 0 0 0-9.33-5'/>" +
                   "<line x1='1' y1='1' x2='23' y2='23'/>" +
                   "</svg>";
        } else {
            let col = theme.urlColor(theme.textMuted);
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9'/>" +
                   "<path d='M13.73 21a2 2 0 0 1-3.46 0'/>" +
                   "</svg>";
        }
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.isDndOn ? "DND" : ""
        accentColor: root.isDndOn ? theme.purple : theme.textMuted
        active: root.isDndOn || root.activePopupId === "dnd"
        customPadding: root.isDndOn ? 10 : 8
        tooltipText: root.isDndOn ? "Do Not Disturb (Active: System & Antigravity only)" : "Do Not Disturb (Inactive)"

        onClicked: {
            root.toggle();
        }

        onRightClicked: {
            root.togglePopup("dnd");
        }
    }

    // Popover Window with Details & Rules
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "dnd"
        implicitWidth: 300
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
                Behavior on y { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            }

            Behavior on opacity { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }

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
                        width: 34
                        height: 34
                        radius: theme.radiusSmall
                        color: root.isDndOn ? Qt.rgba(theme.purple.r, theme.purple.g, theme.purple.b, 0.18) : theme.surface
                        border.color: root.isDndOn ? theme.purple : theme.borderSubtle
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
                            text: "Do Not Disturb"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: root.isDndOn ? "Focus mode enabled" : "Normal notifications"
                            color: root.isDndOn ? theme.purple : theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // Quick Toggle Button
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: theme.radiusSmall
                    color: root.isDndOn ? Qt.rgba(theme.purple.r, theme.purple.g, theme.purple.b, 0.22) : theme.surface
                    border.color: root.isDndOn ? theme.purple : theme.borderSubtle
                    border.width: 1

                    scale: toggleMouse.pressed ? 0.97 : (toggleMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        Text {
                            text: root.isDndOn ? "Disable Do Not Disturb" : "Enable Do Not Disturb"
                            color: root.isDndOn ? theme.text : theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 36
                            height: 20
                            radius: 10
                            color: root.isDndOn ? theme.purple : "#27272a"

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.isDndOn ? parent.width - width - 2 : 2
                                Behavior on x { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                            }
                        }
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.toggle();
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.borderSubtle
                }

                // Rules Breakdown Section
                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: "ACTIVE RULES IN DO NOT DISTURB"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                    }

                    // Rule: Allowed
                    Row {
                        spacing: 8
                        width: parent.width

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.2)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: theme.green
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            text: "System (battery, hardware, safety)"
                            color: theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 8
                        width: parent.width

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.2)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: theme.blue
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Antigravity IDE (agents and tasks)"
                            color: theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Rule: Blocked
                    Row {
                        spacing: 8
                        width: parent.width

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.2)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: theme.red
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Social media (WhatsApp, Instagram, Discord...)"
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 8
                        width: parent.width

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.2)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: theme.red
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            text: "Other apps (browsers, downloads, spotify)"
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
