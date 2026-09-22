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

    // Official Arch Linux accurate SVG scaled to match standard icon size
    property string archSvgUri: {
        let col = theme.urlColor(theme.blue);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.74) translate(-11.5, -12)'><path d='M11.39.605C10.376 3.092 9.764 4.72 8.635 7.132c.693.734 1.543 1.589 2.923 2.554-1.484-.61-2.496-1.224-3.252-1.86C6.86 10.842 4.596 15.138 0 23.395c3.612-2.085 6.412-3.37 9.021-3.862a6.61 6.61 0 01-.171-1.547l.003-.115c.058-2.315 1.261-4.095 2.687-3.973 1.426.12 2.534 2.096 2.478 4.409a6.52 6.52 0 01-.146 1.243c2.58.505 5.352 1.787 8.914 3.844-.702-1.293-1.33-2.459-1.929-3.57-.943-.73-1.926-1.682-3.933-2.713 1.38.359 2.367.772 3.137 1.234-6.09-11.334-6.582-12.84-8.67-17.74z' fill='" + col + "'/></g></svg>";
    }

    BarPill {
        id: pill
        iconSource: root.archSvgUri
        text: "Arch"
        accentColor: theme.blue
        active: root.activePopupId === "host"

        onClicked: {
            root.togglePopup("host");
        }
    }

    // Host Info Popover Card
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "host"
        implicitWidth: 210
        implicitHeight: cardLayout.implicitHeight + 24
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.95
            transformOrigin: Item.Top
            transform: Translate {
                y: popup.visible ? 0 : -6
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 10

                Row {
                    spacing: 10
                    Image {
                        source: root.archSvgUri
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        Text {
                            text: "Arch Linux"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        Text {
                            text: "Hyprland Wayland"
                            color: theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }

            }
        }
    }
}
