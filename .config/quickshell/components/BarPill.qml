import QtQuick
import "../theme"

Rectangle {
    id: root

    Theme { id: theme }

    property string iconSource: ""
    property color iconColor: theme.text
    property string text: ""
    property string subText: ""
    property bool active: false
    property color accentColor: theme.blue
    property string badgeText: ""
    property color badgeColor: theme.blue
    property bool showText: true
    property int customPadding: 10
    property string tooltipText: ""

    signal clicked()
    signal rightClicked()

    implicitHeight: 28
    implicitWidth: {
        let w = contentRow.implicitWidth + (customPadding * 2);
        return Math.max(28, w);
    }
    radius: theme.radiusSmall

    color: {
        if (root.active) return Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22);
        if (mouseArea.containsMouse) return Qt.rgba(255, 255, 255, 0.14);
        return Qt.rgba(255, 255, 255, 0.06);
    }

    border.color: {
        if (root.active) return root.accentColor;
        if (mouseArea.containsMouse) return Qt.rgba(255, 255, 255, 0.24);
        return Qt.rgba(255, 255, 255, 0.10);
    }
    border.width: 1

    Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }
    Behavior on border.color { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }

    scale: mouseArea.pressed ? 0.97 : (mouseArea.containsMouse ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        height: parent.height
        spacing: 6

        // Dedicated fixed 16x16 icon container for perfect vertical alignment
        Item {
            visible: root.iconSource !== ""
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }

        // Badge (e.g. charging lightning bolt)
        Text {
            visible: root.badgeText !== ""
            text: root.badgeText
            color: root.badgeColor
            font.pixelSize: 11
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1.5
        }

        // Main Text
        Text {
            id: label
            visible: root.showText && root.text !== ""
            text: root.text
            color: root.active ? root.accentColor : theme.text
            font.family: theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1.5

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        // Subtext (if any)
        Text {
            visible: root.showText && root.subText !== ""
            text: root.subText
            color: root.active ? theme.blueLight : theme.textSub
            font.family: theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1.5
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.clicked();
            } else if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            }
        }
    }
}
