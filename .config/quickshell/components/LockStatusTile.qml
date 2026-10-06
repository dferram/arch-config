import QtQuick
import "../theme"

// Compact glass status tile for the lock screen (weather, battery, bluetooth)
Rectangle {
    id: root
    Theme { id: theme }

    property color glass: "#d90f0f14"
    property color accent: theme.blue
    property string iconFont: "GeistMono Nerd Font Propo"
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property real progress: -1   // 0..1 shows a thin bar, -1 hides it

    radius: theme.radiusLarge
    color: glass
    border.width: 1
    border.color: theme.border

    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: 10
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
        border.width: 1
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.30)
        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: 18
            color: Qt.lighter(root.accent, 1.2)
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: theme.text
            font.family: theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.subtitle
            color: theme.textMuted
            font.family: theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Rectangle {
            visible: root.progress >= 0
            width: parent.width
            height: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.08)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.progress))
                height: parent.height
                radius: 1.5
                color: root.accent
            }
        }
    }
}
