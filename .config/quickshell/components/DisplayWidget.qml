import QtQuick
import QtQuick.Layouts
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

    // Display state
    property bool hasExternal: false
    property string primaryName: "eDP-1"
    property string externalName: "HDMI-A-1"
    property string externalDesc: "External Monitor"
    property string currentPosition: "right"
    property string positionLabel: "Right"

    // Modern monitor SVG icon
    property string iconDataUri: {
        let col = theme.urlColor(root.hasExternal ? theme.blue : theme.textMuted);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
               "<rect x='3' y='3.5' width='18' height='13' rx='2' stroke='" + col + "' stroke-width='1.8'/>" +
               "<path d='M9 19.5 h6 M12 16.5 v3' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round'/>" +
               (root.hasExternal ? "<circle cx='18' cy='6.5' r='1.8' fill='" + theme.urlColor(theme.green) + "'/>" : "") +
               "</svg>";
    }

    // Process to query monitor status
    Process {
        id: statusProc
        command: ["/home/ferram/.local/bin/hypr-display-manager", "--status"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let trimmed = text.trim();
                if (!trimmed) return;
                try {
                    let data = JSON.parse(trimmed);
                    root.hasExternal = !!data.connected;
                    if (data.primary) {
                        root.primaryName = data.primary.name || "eDP-1";
                    }
                    if (data.external) {
                        root.externalName = data.external.name || "HDMI-A-1";
                        root.externalDesc = data.external.model || data.external.name || "External Monitor";
                    }
                    root.currentPosition = data.position || "right";
                    root.positionLabel = data.position_label || "Right";
                } catch (e) {
                    console.log("Error parsing monitor status: " + e);
                }
            }
        }
    }

    // Process to apply layout
    Process {
        id: applyProc
    }

    function applyPosition(pos) {
        root.currentPosition = pos;
        let labels = {
            "left": "Left",
            "right": "Right",
            "top": "Above",
            "bottom": "Below",
            "mirror": "Mirror"
        };
        root.positionLabel = labels[pos] || pos;
        applyProc.command = ["/home/ferram/.local/bin/hypr-display-manager", "--set", pos];
        applyProc.running = true;
    }

    // Refresh status every 5 seconds
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!statusProc.running) {
                statusProc.running = true;
            }
        }
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: ""
        customPadding: 8
        accentColor: root.hasExternal ? theme.blue : theme.textMuted
        active: root.activePopupId === "display"

        onClicked: {
            if (!statusProc.running) statusProc.running = true;
            root.togglePopup("display");
        }
    }

    // Popover Window
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "display"
        implicitWidth: 280
        implicitHeight: cardLayout.implicitHeight + 24
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
                anchors.margins: 14
                spacing: 12

                // Header
                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        radius: theme.radiusSmall
                        color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.15)
                        border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.3)
                        border.width: 1

                        Image {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            source: root.iconDataUri
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Display Layout"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Text {
                            text: root.hasExternal ? root.externalDesc + " (" + root.externalName + ")" : "No external display"
                            color: root.hasExternal ? theme.blueLight : theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.borderSubtle
                }

                // If External monitor is connected
                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.hasExternal

                    Text {
                        text: "EXTERNAL DISPLAY POSITION"
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                    }

                    // 2x2 Grid for directional positions
                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 8

                        // Left Button
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 38
                            radius: theme.radiusSmall
                            color: root.currentPosition === "left" ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : (mouseLeft.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: root.currentPosition === "left" ? theme.blue : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Left"
                                color: root.currentPosition === "left" ? theme.blue : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: root.currentPosition === "left" ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: mouseLeft
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyPosition("left")
                            }
                        }

                        // Right Button
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 38
                            radius: theme.radiusSmall
                            color: root.currentPosition === "right" ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : (mouseRight.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: root.currentPosition === "right" ? theme.blue : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Right"
                                color: root.currentPosition === "right" ? theme.blue : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: root.currentPosition === "right" ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: mouseRight
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyPosition("right")
                            }
                        }

                        // Top / Above Button
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 38
                            radius: theme.radiusSmall
                            color: root.currentPosition === "top" ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : (mouseTop.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: root.currentPosition === "top" ? theme.blue : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Above"
                                color: root.currentPosition === "top" ? theme.blue : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: root.currentPosition === "top" ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: mouseTop
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyPosition("top")
                            }
                        }

                        // Bottom / Below Button
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 38
                            radius: theme.radiusSmall
                            color: root.currentPosition === "bottom" ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : (mouseBottom.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: root.currentPosition === "bottom" ? theme.blue : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Below"
                                color: root.currentPosition === "bottom" ? theme.blue : theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: root.currentPosition === "bottom" ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: mouseBottom
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyPosition("bottom")
                            }
                        }
                    }

                    // Mirror Button (Full Width)
                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: theme.radiusSmall
                        color: root.currentPosition === "mirror" ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : (mouseMirror.containsMouse ? theme.surfaceHover : theme.surface)
                        border.color: root.currentPosition === "mirror" ? theme.blue : theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Mirror Display"
                            color: root.currentPosition === "mirror" ? theme.blue : theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.weight: root.currentPosition === "mirror" ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: mouseMirror
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.applyPosition("mirror")
                        }
                    }
                }

                // When no external screen is connected
                Column {
                    width: parent.width
                    spacing: 6
                    visible: !root.hasExternal

                    Rectangle {
                        width: parent.width
                        height: 60
                        radius: theme.radiusSmall
                        color: theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "Primary display only (" + root.primaryName + ")"
                                color: theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: "Connect an HDMI or DisplayPort monitor"
                                color: theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // Footer with Advanced GUI launcher
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: theme.radiusSmall
                    color: mouseAdv.containsMouse ? theme.surfaceHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Advanced display settings..."
                        color: theme.blueLight
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: mouseAdv
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.togglePopup("");
                            applyProc.command = ["/home/ferram/.local/bin/hypr-display-manager", "--gui"];
                            applyProc.running = true;
                        }
                    }
                }
            }
        }
    }
}
