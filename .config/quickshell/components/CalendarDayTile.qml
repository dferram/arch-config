import QtQuick
import "../theme"

// Monochrome mini flip-calendar tile tinted with the active distro accent color.
Item {
    id: tile

    Theme { id: theme }

    property color accentColor: theme.blue
    property bool showTabs: width >= 18

    readonly property real cornerRadius: Math.max(4, Math.round(Math.min(width, height) * 0.25))
    readonly property real headerHeight: Math.max(4, Math.round(height * 0.24))
    readonly property real ringW: Math.max(2, Math.round(width * 0.095))
    readonly property real ringH: Math.max(3, Math.round(height * 0.19))
    readonly property real seamY: Math.round(height * 0.56)
    readonly property real lum: 0.299 * accentColor.r + 0.587 * accentColor.g + 0.114 * accentColor.b
    readonly property color autoTextColor: lum > 0.70 ? "#0a0d14" : "#ffffff"

    // Stacked page bottom shadow lip
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1.5
        anchors.bottomMargin: -1.5
        radius: tile.cornerRadius
        color: Qt.darker(tile.accentColor, 1.70)
    }

    // Main rounded square body
    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: tile.cornerRadius
        clip: true
        color: tile.accentColor
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.20)

        // Darker monochrome top header strip
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: tile.headerHeight
            color: Qt.darker(tile.accentColor, 1.32)

            // Subtle ring sockets underneath binding tabs
            Repeater {
                model: tile.showTabs ? [0.29, 0.71] : []
                delegate: Rectangle {
                    required property real modelData
                    readonly property real d: tile.ringW + 2
                    x: Math.round(cardBody.width * modelData - d / 2)
                    y: Math.max(1, Math.round(tile.headerHeight * 0.30))
                    width: d
                    height: d
                    radius: d / 2
                    color: Qt.rgba(0, 0, 0, 0.22)
                }
            }
        }

        // Subtle center flip-page horizontal seam + edge notches
        Rectangle {
            x: 0
            y: tile.seamY
            width: parent.width
            height: 1
            color: Qt.rgba(0, 0, 0, 0.14)
        }
        Rectangle {
            x: 0.5
            y: tile.seamY - 0.5
            width: 2
            height: 2
            radius: 1
            color: Qt.rgba(0, 0, 0, 0.26)
        }
        Rectangle {
            x: parent.width - 2.5
            y: tile.seamY - 0.5
            width: 2
            height: 2
            radius: 1
            color: Qt.rgba(0, 0, 0, 0.26)
        }

        // Inner bottom sheet rim
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1.5
            color: Qt.rgba(0, 0, 0, 0.18)
        }
    }

    // Two mini top binding tabs
    Repeater {
        model: tile.showTabs ? [0.29, 0.71] : []
        delegate: Rectangle {
            required property real modelData
            x: Math.round(tile.width * modelData - tile.ringW / 2)
            y: -Math.max(1, Math.round(tile.height * 0.055))
            width: tile.ringW
            height: tile.ringH
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.94)
        }
    }
}
