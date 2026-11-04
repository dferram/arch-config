import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 165
    implicitHeight: 165
    width: implicitWidth
    height: implicitHeight

    radius: 20
    // Apple Sonoma Translucent Obsidian Glass
    color: Qt.rgba(0.06, 0.06, 0.09, 0.55)
    border.color: Qt.rgba(255, 255, 255, 0.10)
    border.width: 1
    clip: true

    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    SystemClock {
        id: sysClock
        precision: root.isLive ? SystemClock.Seconds : SystemClock.Hours
    }

    property date now: sysClock.date
    property int hours: now.getHours() % 12
    property int minutes: now.getMinutes()
    property int seconds: now.getSeconds()

    // Smooth clock hands rotation
    property real secondAngle: seconds * 6
    property real minuteAngle: minutes * 6 + seconds * 0.1
    property real hourAngle: (hours * 30) + (minutes * 0.5)

    // Clock Face Dial (Apple Sonoma Classic Ceramic Dial)
    Rectangle {
        id: dial
        anchors.centerIn: parent
        width: 138
        height: 138
        radius: width / 2
        color: "#f8f9fc"
        border.color: "#e2e8f0"
        border.width: 1

        // Subtle dial inner shadow / specular sheen
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: "#0a000000"
            border.width: 2
        }

        // Hour Tick Marks & Numerals
        Repeater {
            model: 12
            delegate: Item {
                id: tickItem
                required property int index
                anchors.centerIn: dial
                width: dial.width
                height: dial.height
                rotation: index * 30

                // Hour number
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 5
                    rotation: -parent.rotation
                    text: (index === 0 ? 12 : index).toString()
                    color: "#1c1c1e"
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                // Minute subticks
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: 1
                        height: 3
                        color: "#94a3b8"
                        x: dial.width / 2 - 0.5
                        y: 3
                        transformOrigin: Item.Bottom
                        rotation: (index + 1) * 6
                    }
                }
            }
        }

        // Dial label
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 27
            text: "LOCAL TIME"
            color: "#64748b"
            font.family: theme.fontFamily
            font.pixelSize: 8
            font.weight: Font.Bold
            font.letterSpacing: 0.6
        }

        // Hour Hand
        Rectangle {
            id: hourHand
            width: 3.5
            height: 34
            radius: 2
            color: "#1c1c1e"
            x: dial.width / 2 - width / 2
            y: dial.height / 2 - height + 4
            transformOrigin: Item.Bottom
            rotation: root.hourAngle

            Behavior on rotation {
                RotationAnimation {
                    duration: 200
                    direction: RotationAnimation.Shortest
                }
            }
        }

        // Minute Hand
        Rectangle {
            id: minHand
            width: 2.5
            height: 48
            radius: 1.5
            color: "#1c1c1e"
            x: dial.width / 2 - width / 2
            y: dial.height / 2 - height + 4
            transformOrigin: Item.Bottom
            rotation: root.minuteAngle

            Behavior on rotation {
                RotationAnimation {
                    duration: 150
                    direction: RotationAnimation.Shortest
                }
            }
        }

        // Second Hand (Apple Orange Sweeping Accent)
        Item {
            id: secHandContainer
            anchors.fill: parent
            rotation: root.secondAngle

            Behavior on rotation {
                RotationAnimation {
                    duration: 150
                    direction: RotationAnimation.Shortest
                }
            }

            // Pointer
            Rectangle {
                width: 1.5
                height: 55
                radius: 0.75
                color: "#ff9500" // Apple Orange
                anchors.horizontalCenter: parent.horizontalCenter
                y: dial.height / 2 - height + 10
            }

            // Counterweight tail
            Rectangle {
                width: 2
                height: 12
                radius: 1
                color: "#ff9500"
                anchors.horizontalCenter: parent.horizontalCenter
                y: dial.height / 2
            }

            // Center Pinion Cap
            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: "#ff9500"
                anchors.centerIn: parent
                border.color: "#ffffff"
                border.width: 1
            }
        }

        // Center black pivot pin
        Rectangle {
            width: 2
            height: 2
            radius: 1
            color: "#1c1c1e"
            anchors.centerIn: parent
        }
    }
}
