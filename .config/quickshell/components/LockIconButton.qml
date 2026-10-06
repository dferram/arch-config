import QtQuick
import "../theme"

// Circular icon button used by the lock screen (media controls, power actions)
Item {
    id: root
    Theme { id: theme }

    property real size: 36
    property string icon: ""
    property string iconFont: "GeistMono Nerd Font Propo"
    property real iconSize: size * 0.46
    property bool filled: false
    property color fillColor: theme.blue
    property bool bordered: false
    property color glassColor: "transparent"
    property string tooltip: ""
    signal clicked()

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.filled ? root.fillColor
               : mouse.containsMouse ? theme.surfaceHover
               : root.glassColor
        border.width: root.bordered && !root.filled ? 1 : 0
        border.color: theme.border
        scale: mouse.pressed ? 0.90 : (mouse.containsMouse ? 1.06 : 1.0)
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: root.iconFont
            font.pixelSize: root.iconSize
            color: root.filled ? "#0b0b0e" : (mouse.containsMouse ? theme.text : theme.textSub)
        }
    }

    // Tooltip above the button
    Rectangle {
        visible: root.tooltip !== "" && (mouse.containsMouse || root.filled)
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: tip.implicitWidth + 16
        height: 24
        radius: 8
        color: "#f20f0f14"
        border.width: 1
        border.color: theme.border
        Text {
            id: tip
            anchors.centerIn: parent
            text: root.tooltip
            color: theme.textSub
            font.family: theme.fontFamily
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
