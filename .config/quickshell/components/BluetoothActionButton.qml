import QtQuick
import QtQuick.Controls
import "../theme"

Button {
    id: control
    Theme { id: theme }
    property bool accent: false
    implicitHeight: 28
    hoverEnabled: true
    font.family: theme.fontFamily
    font.pixelSize: 11
    font.weight: Font.Medium
    opacity: enabled ? 1 : 0.45
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.accent ? theme.blueLight : theme.textSub
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: theme.radiusSmall
        color: control.down ? theme.surfaceActive : control.hovered ? theme.surfaceHover : theme.surface
        border.width: 1
        border.color: control.activeFocus ? theme.text : control.accent ? theme.blueDeep : theme.borderSubtle
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}

