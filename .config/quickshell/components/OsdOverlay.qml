import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: osdWindow

    property var osdService: null

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell"

    anchors {
        top: true
    }
    margins {
        top: 52
    }

    implicitWidth: 284
    implicitHeight: 46
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: isShowing || pillContainer.opacity > 0

    Theme { id: theme }

    property bool isShowing: false
    property string osdType: osdService ? osdService.osdType : "volume"
    property int level: osdService ? osdService.level : 50
    property bool isMuted: osdService ? osdService.isMuted : false
    property bool isBrightness: osdType === "brightness"

    // Lucide SVG vector icons (Pure white for volume, warm amber for brightness, red for mute)
    property string iconDataUri: {
        if (isBrightness) {
            let col = "%23fbbf24";
            if (level < 35) {
                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
                       "<circle cx='12' cy='12' r='4'/>" +
                       "<path d='M12 2v2'/><path d='M12 20v2'/><path d='m4.93 4.93 1.41 1.41'/><path d='m17.66 17.66 1.41 1.41'/><path d='M2 12h2'/><path d='M20 12h2'/><path d='m6.34 17.66-1.41 1.41'/><path d='m19.07 4.93-1.41 1.41'/>" +
                       "</svg>";
            } else {
                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
                       "<circle cx='12' cy='12' r='4'/>" +
                       "<line x1='12' y1='2' x2='12' y2='4'/><line x1='12' y1='20' x2='12' y2='22'/>" +
                       "<line x1='4.93' y1='4.93' x2='6.34' y2='6.34'/><line x1='17.66' y1='17.66' x2='19.07' y2='19.07'/>" +
                       "<line x1='2' y1='12' x2='4' y2='12'/><line x1='20' y1='12' x2='22' y2='12'/>" +
                       "<line x1='4.93' y1='19.07' x2='6.34' y2='17.66'/><line x1='17.66' y1='6.34' x2='19.07' y2='4.93'/>" +
                       "</svg>";
            }
        }

        // Volume Icons (Pure White / Red for mute)
        if (isMuted) {
            let col = "%23ff453a";
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<line x1='22' y1='9' x2='16' y2='15'/>" +
                   "<line x1='16' y1='9' x2='22' y2='15'/>" +
                   "</svg>";
        }

        let col = "%23ffffff";
        if (level === 0) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%2371717a' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "</svg>";
        } else if (level < 35) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<path d='M15.54 8.46a5 5 0 0 1 0 7.07'/>" +
                   "</svg>";
        } else if (level < 70) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<path d='M15.54 8.46a5 5 0 0 1 0 7.07'/>" +
                   "<path d='M19.07 4.93a10 10 0 0 1 0 14.14'/>" +
                   "</svg>";
        } else {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<path d='M15.54 8.46a5 5 0 0 1 0 7.07'/>" +
                   "<path d='M19.07 4.93a10 10 0 0 1 0 14.14'/>" +
                   "</svg>";
        }
    }

    Timer {
        id: hideTimer
        interval: 1350
        repeat: false
        onTriggered: {
            osdWindow.isShowing = false;
        }
    }

    Connections {
        target: osdWindow.osdService
        enabled: !!osdWindow.osdService
        function onTriggered() {
            osdWindow.isShowing = true;
            hideTimer.restart();
        }
    }

    Item {
        id: pillContainer
        anchors.fill: parent

        opacity: osdWindow.isShowing ? 1.0 : 0.0
        scale: osdWindow.isShowing ? 1.0 : 0.92
        y: osdWindow.isShowing ? 0 : -8

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on y {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Soft deep black drop shadow
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: theme.windowRadius + 1
            color: "#000000"
            opacity: 0.65
            z: -1
        }

        // Opaque Pure Obsidian Pill Base (Completely borderless, solid deep black)
        Rectangle {
            id: glassPill
            anchors.fill: parent
            radius: theme.windowRadius
            color: "#0c0e14"
            border.width: 0

            // Interactive dismissal on click
            MouseArea {
                anchors.fill: parent
                onClicked: osdWindow.isShowing = false
            }

            // Pill Content Row
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Icon Container (Neutral Dark Tile, No Colored Border)
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                    radius: 8
                    color: "#181a22"
                    border.color: "#262b3a"
                    border.width: 1

                    Image {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: osdWindow.iconDataUri
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }
                }

                // 10-Segment Chiseled VU Meter (High-Contrast Neutral Dark Slots)
                Row {
                    id: segmentsRow
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3.5

                    Repeater {
                        model: 10

                        Rectangle {
                            id: segTrough
                            width: 13
                            height: 12
                            radius: 3
                            color: "#181b24"
                            border.color: "#262b38"
                            border.width: 1
                            clip: true

                            // Fractional progress for continuous silky smoothness
                            property real sliceProgress: {
                                if (osdWindow.isMuted) return 0.0;
                                let val = osdWindow.level;
                                let segStart = index * 10;
                                if (val <= segStart) return 0.0;
                                if (val >= segStart + 10) return 1.0;
                                return (val - segStart) / 10.0;
                            }

                            // Active Fill
                            Rectangle {
                                id: segFill
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.round(segTrough.sliceProgress * parent.width)
                                radius: 3

                                color: {
                                    if (osdWindow.isMuted) return "#ff453a";
                                    if (osdWindow.isBrightness) {
                                        // Pure Warm Solar Gold
                                        return index < 6 ? "#f59e0b" : "#fbbf24";
                                    } else {
                                        // Pure Deep Crimson & Red (No pink hues)
                                        return index < 6 ? "#dc2626" : "#ef4444";
                                    }
                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                // Specular top shine line
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: 1.2
                                    radius: 3
                                    color: Qt.rgba(255, 255, 255, 0.45)
                                }
                            }
                        }
                    }
                }

                // Percentage Badge / Status Text
                Item {
                    Layout.preferredWidth: 42
                    Layout.fillHeight: true

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: osdWindow.isMuted ? "MUTED" : (osdWindow.level + "%")
                        color: osdWindow.isMuted ? "#ff453a" : (osdWindow.isBrightness ? "#fbbf24" : "#ffffff")
                        font.family: "JetBrainsMono Nerd Font, ZedMono Nerd Font, monospace"
                        font.pixelSize: osdWindow.isMuted ? 10 : 12
                        font.weight: Font.Bold
                        font.letterSpacing: 0.4
                    }
                }
            }
        }
    }
}
