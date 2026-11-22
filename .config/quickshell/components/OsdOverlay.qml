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

    readonly property bool isBrightness: osdType === "brightness"
    readonly property bool isMic: osdType === "mic"
    readonly property bool isNight: osdType === "nightmode"
    readonly property bool isCaps: osdType === "capslock"
    readonly property bool isToggle: isMic || isNight || isCaps
    readonly property bool isToggleActive: isToggle && !isMuted

    implicitWidth: isToggle ? 252 : 304
    implicitHeight: isToggle ? 52 : 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: isShowing || pillContainer.opacity > 0

    Theme { id: theme }

    property bool isShowing: false
    property string osdType: osdService ? osdService.osdType : "volume"
    property int level: osdService ? osdService.level : 50
    property bool isMuted: osdService ? osdService.isMuted : false
    property string customText: osdService ? osdService.customText : ""

    readonly property color accentColor: {
        if (isBrightness) return theme.peach;
        if (isMic) return isMuted ? theme.red : theme.blue;
        if (isNight) return isMuted ? theme.textDim : theme.peach;
        if (isCaps) return isMuted ? theme.textDim : theme.red;
        if (isMuted) return theme.red;
        if (level > 100) return theme.peach;
        return theme.blue;
    }

    readonly property color accentHighlight: {
        if (isBrightness) return theme.yellow;
        if (isMic) return isMuted ? "#ff6961" : theme.blueLight;
        if (isNight) return isMuted ? theme.textMuted : theme.yellow;
        if (isCaps) return isMuted ? theme.textMuted : "#ff6961";
        if (isMuted) return "#ff6961";
        if (level > 100) return theme.yellow;
        return theme.blueLight;
    }

    readonly property string hudTitle: {
        if (isBrightness) return "Brightness";
        if (isMic) return "Microphone";
        if (isNight) return "Night Mode";
        if (isCaps) return "Caps Lock";
        return isMuted ? "Volume Muted" : "Volume";
    }

    readonly property string toggleSubtitle: {
        if (isMic) return isMuted ? "Input muted" : "Input active";
        if (isNight) return isMuted ? "Warm display off" : "Warm display on";
        if (isCaps) return isMuted ? "Standard case" : "Uppercase lock";
        return "";
    }

    readonly property string statusText: {
        if (customText && customText.length > 0) return customText;
        if (isMuted) return "MUTED";
        return level + "%";
    }

    // Lucide SVG vector icons (Volume, Brightness, Mic, Night Light, Caps Lock)
    property string iconDataUri: {
        if (isBrightness) {
            let col = theme.urlColor(theme.yellow);
            if (level < 35) {
                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                       "<circle cx='12' cy='12' r='4'/>" +
                       "<path d='M12 2v2'/><path d='M12 20v2'/><path d='m4.93 4.93 1.41 1.41'/><path d='m17.66 17.66 1.41 1.41'/><path d='M2 12h2'/><path d='M20 12h2'/><path d='m6.34 17.66-1.41 1.41'/><path d='m19.07 4.93-1.41 1.41'/>" +
                       "</svg>";
            }
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<circle cx='12' cy='12' r='4'/>" +
                   "<line x1='12' y1='2' x2='12' y2='4'/><line x1='12' y1='20' x2='12' y2='22'/>" +
                   "<line x1='4.93' y1='4.93' x2='6.34' y2='6.34'/><line x1='17.66' y1='17.66' x2='19.07' y2='19.07'/>" +
                   "<line x1='2' y1='12' x2='4' y2='12'/><line x1='20' y1='12' x2='22' y2='12'/>" +
                   "<line x1='4.93' y1='19.07' x2='6.34' y2='17.66'/><line x1='17.66' y1='6.34' x2='19.07' y2='4.93'/>" +
                   "</svg>";
        }

        if (isMic) {
            if (isMuted) {
                let col = theme.urlColor(theme.red);
                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                       "<line x1='2' y1='2' x2='22' y2='22'/>" +
                       "<path d='M18.89 13.23A7.12 7.12 0 0 0 19 12v-2'/>" +
                       "<path d='M5 10v2a7 7 0 0 0 12 5'/>" +
                       "<path d='M15 9.34V5a3 3 0 0 0-5.68-1.33'/>" +
                       "<path d='M9 9v3a3 3 0 0 0 5.12 2.12'/>" +
                       "<line x1='12' y1='19' x2='12' y2='22'/>" +
                       "</svg>";
            }
            let col = theme.urlColor(theme.blueLight);
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z'/>" +
                   "<path d='M19 10v2a7 7 0 0 1-14 0v-2'/>" +
                   "<line x1='12' y1='19' x2='12' y2='22'/>" +
                   "</svg>";
        }

        if (isNight) {
            let col = theme.urlColor(isMuted ? theme.textMuted : theme.peach);
            let fillCol = isMuted ? "none" : theme.urlColor(theme.peach);
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='" + fillCol + "' fill-opacity='" + (isMuted ? "0" : "0.25") + "' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z'/>" +
                   "</svg>";
        }

        if (isCaps) {
            let col = theme.urlColor(isMuted ? theme.textMuted : theme.red);
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polyline points='7 11 12 6 17 11'/>" +
                   "<line x1='12' y1='18' x2='12' y2='6'/>" +
                   "</svg>";
        }

        // Volume Icons
        if (isMuted) {
            let col = theme.urlColor(theme.red);
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<line x1='22' y1='9' x2='16' y2='15'/>" +
                   "<line x1='16' y1='9' x2='22' y2='15'/>" +
                   "</svg>";
        }

        let col = theme.urlColor(theme.text);
        if (level === 0) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(theme.textMuted) + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "</svg>";
        } else if (level < 35) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
                   "<path d='M15.54 8.46a5 5 0 0 1 0 7.07'/>" +
                   "</svg>";
        }
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'>" +
               "<polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/>" +
               "<path d='M15.54 8.46a5 5 0 0 1 0 7.07'/>" +
               "<path d='M19.07 4.93a10 10 0 0 1 0 14.14'/>" +
               "</svg>";
    }

    Timer {
        id: hideTimer
        interval: 1500
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
        scale: osdWindow.isShowing ? 1.0 : 0.94
        y: osdWindow.isShowing ? 0 : -10

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        // Soft ambient drop shadow beneath the floating capsule
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: -2
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            radius: glassPill.radius + 1
            color: "#000000"
            opacity: 0.36
            z: -2
        }

        // Smoked Obsidian Liquid Glass Capsule
        Rectangle {
            id: glassPill
            anchors.fill: parent
            radius: height / 2
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            clip: true

            // Signature 3-stop Liquid Glass specular surface sheen
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.11) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.015) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04) }
                }
            }

            // Subtle ambient tint radiating from the icon side
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(osdWindow.accentColor.r, osdWindow.accentColor.g, osdWindow.accentColor.b, osdWindow.isToggle && !osdWindow.isToggleActive ? 0.04 : 0.14)
                    }
                    GradientStop { position: 0.45; color: Qt.rgba(osdWindow.accentColor.r, osdWindow.accentColor.g, osdWindow.accentColor.b, 0.02) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Crisp top specular hairline reflection
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: glassPill.radius * 0.75
                anchors.rightMargin: glassPill.radius * 0.75
                height: 1
                color: Qt.rgba(1, 1, 1, 0.22)
            }

            // Interactive dismissal on click
            MouseArea {
                anchors.fill: parent
                onClicked: osdWindow.isShowing = false
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 14
                spacing: 11

                // Liquid Glass circular icon well
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignVCenter
                    radius: 17
                    color: Qt.rgba(osdWindow.accentColor.r, osdWindow.accentColor.g, osdWindow.accentColor.b, (osdWindow.isToggle && !osdWindow.isToggleActive) ? 0.08 : 0.18)
                    border.color: Qt.rgba(osdWindow.accentColor.r, osdWindow.accentColor.g, osdWindow.accentColor.b, (osdWindow.isToggle && !osdWindow.isToggleActive) ? 0.18 : 0.42)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    // Subtle inner gloss inside icon well
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                            GradientStop { position: 0.6; color: "transparent" }
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                        source: osdWindow.iconDataUri
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }
                }

                // Mode A: Continuous Liquid Glass Slider (Volume & Brightness)
                ColumnLayout {
                    visible: !osdWindow.isToggle
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: osdWindow.hudTitle
                            color: osdWindow.isMuted ? theme.red : theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: osdWindow.isMuted ? "MUTED" : (osdWindow.level + "%")
                            color: {
                                if (osdWindow.isMuted) return theme.red;
                                if (osdWindow.isBrightness) return theme.yellow;
                                if (osdWindow.level > 100) return theme.peach;
                                return theme.text;
                            }
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    // Smooth frosted track with glowing gradient fill
                    Rectangle {
                        id: sliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 7
                        radius: 3.5
                        color: Qt.rgba(1, 1, 1, 0.10)
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1
                        clip: true

                        Rectangle {
                            id: sliderFill
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: osdWindow.isMuted ? 0 : Math.round(Math.max(0, Math.min(1, osdWindow.level / 100.0)) * parent.width)
                            radius: parent.radius

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: osdWindow.accentColor }
                                GradientStop { position: 1.0; color: osdWindow.accentHighlight }
                            }

                            Behavior on width {
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }

                            // Top liquid specular highlight along the active bar
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: 1
                                height: 1.5
                                radius: 1
                                color: Qt.rgba(1, 1, 1, 0.45)
                            }
                        }
                    }
                }

                // Mode B: Toggle State Capsule (Night Mode, Microphone, Caps Lock)
                RowLayout {
                    visible: osdWindow.isToggle
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: osdWindow.hudTitle
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: osdWindow.toggleSubtitle
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Frosted Status Capsule Badge (ON / OFF / ACTIVE / MUTED)
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: badgeRow.implicitWidth + 16
                        implicitHeight: 24
                        radius: 12
                        color: {
                            if (osdWindow.isToggleActive) {
                                return Qt.rgba(osdWindow.accentColor.r, osdWindow.accentColor.g, osdWindow.accentColor.b, 0.20);
                            }
                            if (osdWindow.isMic && osdWindow.isMuted) {
                                return Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.18);
                            }
                            return theme.surface;
                        }
                        border.color: {
                            if (osdWindow.isToggleActive) {
                                return Qt.rgba(osdWindow.accentColor.r, osdWindow.accentColor.g, osdWindow.accentColor.b, 0.48);
                            }
                            if (osdWindow.isMic && osdWindow.isMuted) {
                                return Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.42);
                            }
                            return theme.borderSubtle;
                        }
                        border.width: 1

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: {
                                    if (osdWindow.isToggleActive) return osdWindow.accentHighlight;
                                    if (osdWindow.isMic && osdWindow.isMuted) return theme.red;
                                    return theme.textDim;
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: osdWindow.statusText
                                color: {
                                    if (osdWindow.isToggleActive) return osdWindow.accentHighlight;
                                    if (osdWindow.isMic && osdWindow.isMuted) return theme.red;
                                    return theme.textMuted;
                                }
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.4
                            }
                        }
                    }
                }
            }
        }
    }
}
