import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
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

    // Internal reactive states
    property int fallbackPercent: 100
    property string fallbackStatus: "Discharging"
    property real currentPercent: {
        if (UPower.displayDevice && UPower.displayDevice.ready && UPower.displayDevice.percentage > 0) {
            return Math.round(UPower.displayDevice.percentage * 100);
        }
        return fallbackPercent;
    }

    property bool isCharging: {
        if (UPower.displayDevice && UPower.displayDevice.ready) {
            let s = UPower.displayDevice.state;
            return s === 1 || s === 4 || s === 5 || (!UPower.onBattery && currentPercent < 100);
        }
        return fallbackStatus.toLowerCase().indexOf("charging") !== -1;
    }

    // Instant sysfs read on startup
    Process {
        id: sysfsProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status 2>/dev/null || echo -e '0\\nUnknown'"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let lines = text.trim().split("\n");
                if (lines.length >= 1 && parseInt(lines[0]) > 0) {
                    root.fallbackPercent = parseInt(lines[0]);
                }
                if (lines.length >= 2) {
                    root.fallbackStatus = lines[1].trim();
                }
            }
        }
    }

    // Periodic fallback update
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: sysfsProc.running = true
    }

    // Format time helper (seconds -> "Xh Ym")
    function formatSeconds(secs) {
        if (!secs || secs <= 0 || isNaN(secs)) return "Calculating...";
        let hours = Math.floor(secs / 3600);
        let mins = Math.floor((secs % 3600) / 60);
        if (hours > 0) {
            return hours + "h " + (mins < 10 ? "0" : "") + mins + "m";
        }
        return mins + " mins";
    }

    // State description string
    function getStateText() {
        if (isCharging) {
            if (currentPercent >= 100) return "Fully Charged";
            return "Charging on AC";
        }
        if (UPower.displayDevice && UPower.displayDevice.ready) {
            switch(UPower.displayDevice.state) {
                case 1: return "Charging";
                case 2: return "Discharging";
                case 3: return "Empty";
                case 4: return "Fully Charged";
                case 5: return "Pending Charge";
                case 6: return "Pending Discharge";
                default: return "On Battery";
            }
        }
        return root.fallbackStatus;
    }

    // Dynamic status color (Blue when normal/charging, peach when <= 10%, red when <= 5%)
    property color batteryColor: {
        if (isCharging) return theme.blue;
        if (currentPercent <= 5) return theme.red;
        if (currentPercent <= 10) return theme.peach;
        return theme.blue;
    }

    // Refined horizontal capsule battery icon with sleek proportions and centered nub
    property string iconDataUri: {
        let col = theme.urlColor(root.batteryColor);
        let fillW = Math.max(1.8, Math.min(12.0, (currentPercent / 100.0) * 12.0));
        let nub = "<path d='M19 10.2 h1.2 c0.6 0 1.0 0.4 1.0 1.0 v1.6 c0 0.6 -0.4 1.0 -1.0 1.0 H19' fill='" + col + "'/>";
        if (isCharging) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<rect x='2.5' y='6' width='16' height='12' rx='3.0' stroke='" + col + "' stroke-width='1.8'/>" + nub +
                   "<path d='M11.5 6.8 L7.5 12 h4 L9.5 17.2 L14.5 11.5 h-4 z' fill='" + col + "'/></svg>";
        } else {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<rect x='2.5' y='6' width='16' height='12' rx='3.0' stroke='" + col + "' stroke-width='1.8'/>" + nub +
                   "<rect x='4.5' y='8' width='12' height='8' rx='1.5' fill='" + col + "' fill-opacity='0.16'/>" +
                   "<rect x='4.5' y='8' width='" + fillW + "' height='8' rx='1.5' fill='" + col + "'/></svg>";
        }
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.currentPercent + "%"
        accentColor: root.batteryColor
        active: root.activePopupId === "battery"

        onClicked: {
            root.togglePopup("battery");
        }
    }

    // Detailed Popover Card
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "battery"
        implicitWidth: 260
        implicitHeight: cardLayout.implicitHeight + 28
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
                    spacing: 8
                    Image {
                        source: root.iconDataUri
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: "Battery " + root.currentPercent + "%"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.getStateText()
                            color: !root.isCharging && root.currentPercent <= 10 ? root.batteryColor : theme.blueLight
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                        Text {
                            visible: !root.isCharging && root.currentPercent <= 10
                            text: root.currentPercent <= 5 ? "Batería Crítica: Conectar cargador" : "Batería Baja: Conectar cargador"
                            color: root.batteryColor
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // Progress Bar
                Rectangle {
                    width: parent.width
                    height: 8
                    color: theme.surface
                    radius: 4

                    Rectangle {
                        width: Math.max(4, parent.width * (root.currentPercent / 100.0))
                        height: parent.height
                        radius: 4
                        color: root.batteryColor

                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }
                }

                // Detail entries
                Rectangle {
                    width: parent.width
                    height: detailsCol.implicitHeight + 16
                    color: theme.surface
                    radius: theme.radiusSmall
                    border.color: theme.borderSubtle
                    border.width: 1

                    Column {
                        id: detailsCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Row {
                            width: parent.width
                            Text { text: "Time Remaining:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: {
                                    if (root.isCharging) {
                                        return UPower.displayDevice ? root.formatSeconds(UPower.displayDevice.timeToFull) : "Calculating...";
                                    } else {
                                        return UPower.displayDevice ? root.formatSeconds(UPower.displayDevice.timeToEmpty) : "Calculating...";
                                    }
                                }
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Power Rate:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: (UPower.displayDevice && UPower.displayDevice.changeRate > 0) ? (UPower.displayDevice.changeRate.toFixed(1) + " W") : "Adaptive"
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Health:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: (UPower.displayDevice && UPower.displayDevice.healthSupported) ? (Math.round(UPower.displayDevice.healthPercentage) + "%") : "Normal"
                                color: theme.blueLight
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // Power Profiles quick switch (only if supported)
                Column {
                    width: parent.width
                    spacing: 6
                    visible: PowerProfiles.hasPerformanceProfile

                    Text {
                        text: "Power Profile"
                        color: theme.textSub
                        font.pixelSize: 11
                        font.family: theme.fontFamily
                        font.weight: Font.Medium
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        // Power Saver
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 24
                            radius: 4
                            property bool isCurrent: PowerProfiles.profile === PowerProfile.PowerSaver
                            color: isCurrent ? theme.surfaceActive : (saverMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isCurrent ? theme.green : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Saver"
                                color: parent.isCurrent ? theme.green : theme.text
                                font.pixelSize: 10
                                font.weight: parent.isCurrent ? Font.Bold : Font.Normal
                            }

                            MouseArea {
                                id: saverMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                            }
                        }

                        // Balanced
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 24
                            radius: 4
                            property bool isCurrent: PowerProfiles.profile === PowerProfile.Balanced
                            color: isCurrent ? theme.surfaceActive : (balMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isCurrent ? theme.blue : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Balanced"
                                color: parent.isCurrent ? theme.blue : theme.text
                                font.pixelSize: 10
                                font.weight: parent.isCurrent ? Font.Bold : Font.Normal
                            }

                            MouseArea {
                                id: balMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PowerProfiles.profile = PowerProfile.Balanced
                            }
                        }

                        // Performance
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 24
                            radius: 4
                            property bool isCurrent: PowerProfiles.profile === PowerProfile.Performance
                            color: isCurrent ? theme.surfaceActive : (perfMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isCurrent ? theme.peach : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Perf"
                                color: parent.isCurrent ? theme.peach : theme.text
                                font.pixelSize: 10
                                font.weight: parent.isCurrent ? Font.Bold : Font.Normal
                            }

                            MouseArea {
                                id: perfMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PowerProfiles.profile = PowerProfile.Performance
                            }
                        }
                    }
                }
            }
        }
    }
}
