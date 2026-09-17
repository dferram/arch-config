import QtQuick
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

    // Lucide Power icon (matching Night Mode aesthetic)
    property string iconDataUri: {
        let col = theme.urlColor(theme.blue);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
               "<path d='M18.36 6.64a9 9 0 1 1-12.73 0'/>" +
               "<line x1='12' y1='2' x2='12' y2='12'/>" +
               "</svg>";
    }

    Process { id: actionProc }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: ""
        customPadding: 8
        accentColor: theme.blue
        active: root.activePopupId === "power"

        onClicked: {
            root.togglePopup("power");
        }
    }

    // Power Popover Card
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "power"
        implicitWidth: 170
        implicitHeight: cardLayout.implicitHeight + 20
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
                anchors.margins: 10
                spacing: 6

                // Lock Screen
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: theme.radiusSmall
                    color: lockMouse.containsMouse ? theme.surfaceHover : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Image {
                            width: 15
                            height: 15
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(theme.blue) + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><rect x='3' y='11' width='18' height='11' rx='2' ry='2'/><path d='M7 11V7a5 5 0 0 1 10 0v4'/></svg>"
                            fillMode: Image.PreserveAspectFit
                        }
                        Text { text: "Lock Screen"; color: theme.text; font.pixelSize: 11; font.family: theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: lockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.togglePopup("");
                            actionProc.command = ["sh", "-c", "hyprlock || swaylock || true"];
                            actionProc.running = true;
                        }
                    }
                }

                // Suspend
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: theme.radiusSmall
                    color: suspMouse.containsMouse ? theme.surfaceHover : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Image {
                            width: 15
                            height: 15
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(theme.blue) + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z'/></svg>"
                            fillMode: Image.PreserveAspectFit
                        }
                        Text { text: "Suspend"; color: theme.text; font.pixelSize: 11; font.family: theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: suspMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.togglePopup("");
                            actionProc.command = ["systemctl", "suspend"];
                            actionProc.running = true;
                        }
                    }
                }

                // Reboot
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: theme.radiusSmall
                    color: rebootMouse.containsMouse ? theme.surfaceHover : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Image {
                            width: 15
                            height: 15
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(theme.blue) + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><polyline points='23 4 23 10 17 10'/><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/></svg>"
                            fillMode: Image.PreserveAspectFit
                        }
                        Text { text: "Restart"; color: theme.text; font.pixelSize: 11; font.family: theme.fontFamily; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: rebootMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.togglePopup("");
                            actionProc.command = ["systemctl", "reboot"];
                            actionProc.running = true;
                        }
                    }
                }

                // Shutdown
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: theme.radiusSmall
                    color: shutMouse.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.2) : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Image {
                            width: 15
                            height: 15
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(theme.blue) + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><path d='M18.36 6.64a9 9 0 1 1-12.73 0'/><line x1='12' y1='2' x2='12' y2='12'/></svg>"
                            fillMode: Image.PreserveAspectFit
                        }
                        Text { text: "Shutdown"; color: theme.text; font.pixelSize: 11; font.family: theme.fontFamily; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: shutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.togglePopup("");
                            actionProc.command = ["systemctl", "poweroff"];
                            actionProc.running = true;
                        }
                    }
                }
            }
        }
    }
}
