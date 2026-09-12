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

    // Sculpted solid power button icon
    property string iconDataUri: {
        let col = theme.urlColor(theme.blue);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(1.15) translate(-8, -8)'><path d='m 8 0 c -0.550781 0 -1 0.449219 -1 1 v 5 c 0 0.550781 0.449219 1 1 1 s 1 -0.449219 1 -1 v -5 c 0 -0.550781 -0.449219 -1 -1 -1 z m -3.136719 1.816406 c -0.128906 0.015625 -0.253906 0.058594 -0.367187 0.125 c -2.734375 1.582032 -4.074219 4.816406 -3.257813 7.871094 c 0.820313 3.050781 3.59375 5.183594 6.75 5.1875 c 3.160157 0.003906 5.941407 -2.121094 6.765625 -5.167969 c 0.828125 -3.050781 -0.5 -6.289062 -3.230468 -7.878906 c -0.476563 -0.28125 -1.089844 -0.121094 -1.367188 0.359375 c -0.132812 0.226562 -0.171875 0.5 -0.105469 0.757812 c 0.070313 0.257813 0.234375 0.476563 0.464844 0.609376 c 1.957031 1.140624 2.902344 3.441406 2.3125 5.628906 c -0.59375 2.183594 -2.570313 3.695312 -4.832031 3.691406 c -2.265625 -0.003906 -4.238282 -1.519531 -4.824219 -3.707031 s 0.363281 -4.488281 2.324219 -5.621094 c 0.476562 -0.277344 0.640625 -0.886719 0.363281 -1.363281 c -0.132813 -0.230469 -0.347656 -0.398438 -0.605469 -0.464844 c -0.125 -0.035156 -0.257812 -0.042969 -0.390625 -0.027344 z' fill='" + col + "'/></g></svg>";
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
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' width='16' height='16' fill='none'><path d='m 8 1 c -2.199219 0 -4 1.800781 -4 4 v 2 c -1.109375 0 -2 0.890625 -2 2 v 5 c 0 0.554688 0.445312 1 1 1 h 10 c 0.554688 0 1 -0.445312 1 -1 v -5 c 0 -1.109375 -0.890625 -2 -2 -2 v -2 c 0 -2.199219 -1.800781 -4 -4 -4 z m 0 2 c 1.125 0 2 0.875 2 2 v 2 h -4 v -2 c 0 -1.125 0.875 -2 2 -2 z' fill='" + theme.urlColor(theme.blue) + "'/></svg>"
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
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' width='16' height='16' fill='none'><path d='m 8 3 c -2.761719 0 -5 2.238281 -5 5 s 2.238281 5 5 5 c 2.199219 0 4.066406 -1.421875 4.738281 -3.394531 c -0.527343 0.25 -1.117187 0.394531 -1.738281 0.394531 c -2.210938 0 -4 -1.789062 -4 -4 c 0 -1.1875 0.519531 -2.253906 1.34375 -2.988281 c -0.113281 -0.007813 -0.230469 -0.011719 -0.34375 -0.011719 z' fill='" + theme.urlColor(theme.blue) + "'/></svg>"
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
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' width='16' height='16' fill='none'><path d='m 8 0 c -0.550781 0 -1 0.449219 -1 1 v 5 c 0 0.550781 0.449219 1 1 1 s 1 -0.449219 1 -1 v -5 c 0 -0.550781 -0.449219 -1 -1 -1 z m -7 1 l 2.050781 2.050781 c -2.117187 2.117188 -2.652343 5.355469 -1.332031 8.039063 c 1.324219 2.683594 4.214844 4.238281 7.179688 3.851562 c 2.96875 -0.386718 5.367187 -2.625 5.960937 -5.554687 c 0.59375 -2.933594 -0.75 -5.929688 -3.335937 -7.433594 c -0.476563 -0.28125 -1.089844 -0.117187 -1.367188 0.359375 s -0.117188 1.089844 0.359375 1.367188 c 1.851563 1.078124 2.808594 3.207031 2.382813 5.3125 c -0.421876 2.101562 -2.128907 3.691406 -4.253907 3.96875 c -2.128906 0.273437 -4.183593 -0.828126 -5.128906 -2.753907 s -0.566406 -4.226562 0.949219 -5.742187 l 1.535156 1.535156 v -4.003906 c 0 -0.519532 -0.449219 -0.996094 -1 -0.996094 z' fill='" + theme.urlColor(theme.blue) + "'/></svg>"
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
                            width: 14
                            height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' width='16' height='16' fill='none'><path d='m 8 0 c -0.550781 0 -1 0.449219 -1 1 v 5 c 0 0.550781 0.449219 1 1 1 s 1 -0.449219 1 -1 v -5 c 0 -0.550781 -0.449219 -1 -1 -1 z m -3.136719 1.816406 c -0.128906 0.015625 -0.253906 0.058594 -0.367187 0.125 c -2.734375 1.582032 -4.074219 4.816406 -3.257813 7.871094 c 0.820313 3.050781 3.59375 5.183594 6.75 5.1875 c 3.160157 0.003906 5.941407 -2.121094 6.765625 -5.167969 c 0.828125 -3.050781 -0.5 -6.289062 -3.230468 -7.878906 c -0.476563 -0.28125 -1.089844 -0.121094 -1.367188 0.359375 c -0.132812 0.226562 -0.171875 0.5 -0.105469 0.757812 c 0.070313 0.257813 0.234375 0.476563 0.464844 0.609376 c 1.957031 1.140624 2.902344 3.441406 2.3125 5.628906 c -0.59375 2.183594 -2.570313 3.695312 -4.832031 3.691406 c -2.265625 -0.003906 -4.238282 -1.519531 -4.824219 -3.707031 s 0.363281 -4.488281 2.324219 -5.621094 c 0.476562 -0.277344 0.640625 -0.886719 0.363281 -1.363281 c -0.132813 -0.230469 -0.347656 -0.398438 -0.605469 -0.464844 c -0.125 -0.035156 -0.257812 -0.042969 -0.390625 -0.027344 z' fill='" + theme.urlColor(theme.blue) + "'/></svg>"
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
