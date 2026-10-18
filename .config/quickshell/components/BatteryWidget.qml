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
    property int cycleCount: 0
    property real energyNow: 0.0
    property real energyFull: 0.0
    property real energyDesign: 0.0
    property real voltageNow: 0.0
    property real powerNow: 0.0
    property real healthPct: 0.0
    property string tech: "Li-ion"
    property string modelName: ""
    property string manufacturer: ""
    property string thresholds: ""
    property string calcTimeStr: ""
    property bool showPercentageInBar: false
    property string currentProfile: "balanced"

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

    // Comprehensive battery telemetry read
    Process {
        id: sysfsProc
        command: ["/home/ferram/Personal/dotfiles/.config/quickshell/scripts/battery-details.py"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.capacity !== undefined && d.capacity > 0) root.fallbackPercent = d.capacity;
                    if (d.status) root.fallbackStatus = d.status;
                    if (d.cycle_count !== undefined) root.cycleCount = d.cycle_count;
                    if (d.energy_now_wh !== undefined) root.energyNow = d.energy_now_wh;
                    if (d.energy_full_wh !== undefined) root.energyFull = d.energy_full_wh;
                    if (d.energy_design_wh !== undefined) root.energyDesign = d.energy_design_wh;
                    if (d.power_now_w !== undefined) root.powerNow = d.power_now_w;
                    if (d.voltage_now_v !== undefined) root.voltageNow = d.voltage_now_v;
                    if (d.health_pct !== undefined) root.healthPct = d.health_pct;
                    if (d.technology) root.tech = d.technology;
                    if (d.model) root.modelName = d.model;
                    if (d.manufacturer) root.manufacturer = d.manufacturer;
                    if (d.thresholds) root.thresholds = d.thresholds;
                    if (d.time_str) root.calcTimeStr = d.time_str;
                    if (d.power_profile) root.currentProfile = d.power_profile;
                } catch(e) {}
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

    Process {
        id: setProfileProc
        function setProfile(name) {
            root.currentProfile = name;
            command = ["powerprofilesctl", "set", name];
            running = true;
        }
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

    // Dynamic status color: reflects active power profile (Saver: green, Balanced: blue, Performance: peach)
    property color batteryColor: {
        if (currentPercent <= 5 && !isCharging) return theme.red;
        if (currentPercent <= 10 && !isCharging) return theme.peach;
        if (root.currentProfile === "power-saver") return theme.green;
        if (root.currentProfile === "performance") return theme.peach;
        return theme.blue;
    }

    // Lucide horizontal battery icon (matching Night Mode aesthetic)
    property string iconDataUri: {
        let col = theme.urlColor(root.batteryColor);
        let fillW = Math.max(1.8, Math.min(12.0, (currentPercent / 100.0) * 12.0));
        let nub = "<path d='M19 10.2 h1.2 c0.6 0 1.0 0.4 1.0 1.0 v1.6 c0 0.6 -0.4 1.0 -1.0 1.0 H19' fill='" + col + "'/>";
        if (isCharging) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<rect x='2.5' y='6.5' width='16' height='11' rx='2.5' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/>" + nub +
                   "<path d='M11.5 7 L8 12 h3.5 L9.5 17 L14 11.5 h-3 z' fill='" + col + "'/></svg>";
        } else {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<rect x='2.5' y='6.5' width='16' height='11' rx='2.5' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/>" + nub +
                   "<rect x='4.5' y='8.5' width='12' height='7' rx='1.2' fill='" + col + "' fill-opacity='0.16'/>" +
                   "<rect x='4.5' y='8.5' width='" + fillW + "' height='7' rx='1.2' fill='" + col + "'/></svg>";
        }
    }

    BarPill {
        id: pill
        iconSource: root.iconDataUri
        text: root.currentPercent + "%"
        showText: root.showPercentageInBar || root.activePopupId === "battery"
        accentColor: root.batteryColor
        active: root.activePopupId === "battery"
        pulsingIcon: root.isCharging

        onClicked: {
            root.togglePopup("battery");
        }
        onRightClicked: {
            root.showPercentageInBar = !root.showPercentageInBar;
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
        implicitWidth: 290
        implicitHeight: cardLayout.implicitHeight + 38
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.95
            transformOrigin: Item.Top
            transform: Translate {
                y: popup.visible ? 0 : -6
                Behavior on y { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            }

            Behavior on opacity { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }

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
                            text: root.currentPercent <= 5 ? "Critical Battery: Connect charger" : "Low Battery: Connect charger"
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

                        Behavior on width { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
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

                        // Time Remaining
                        Row {
                            width: parent.width
                            Text { text: "Time Remaining:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: {
                                    if (root.calcTimeStr !== "") return root.calcTimeStr;
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

                        // Power Rate
                        Row {
                            width: parent.width
                            Text { text: "Power Rate:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.powerNow > 0 ? (root.powerNow + " W") : ((UPower.displayDevice && UPower.displayDevice.changeRate > 0) ? (UPower.displayDevice.changeRate.toFixed(1) + " W") : "Adaptive")
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        // Health & Capacity
                        Row {
                            width: parent.width
                            Text { text: "Health & Capacity:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.healthPct > 0 ? (root.healthPct + "% (" + root.energyFull + " / " + root.energyDesign + " Wh)") : ((UPower.displayDevice && UPower.displayDevice.healthSupported) ? (Math.round(UPower.displayDevice.healthPercentage) + "%") : "Normal")
                                color: theme.blueLight
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        // Charge Cycles
                        Row {
                            width: parent.width
                            visible: root.cycleCount > 0
                            Text { text: "Charge Cycles:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.cycleCount + " cycles"
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        // Voltage
                        Row {
                            width: parent.width
                            visible: root.voltageNow > 0
                            Text { text: "Voltage:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.voltageNow + " V"
                                color: theme.text
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        // Thresholds
                        Row {
                            width: parent.width
                            visible: root.thresholds !== ""
                            Text { text: "Charge Thresholds:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: root.thresholds + " (Protected)"
                                color: theme.green
                                font.pixelSize: 11
                                font.family: theme.fontFamily
                                font.weight: Font.Medium
                            }
                        }

                        // Hardware / Model
                        Row {
                            width: parent.width
                            visible: root.modelName !== ""
                            Text { text: "Hardware:"; color: theme.textSub; font.pixelSize: 11; font.family: theme.fontFamily }
                            Item { Layout.fillWidth: true; width: parent.width - 200 }
                            Text {
                                text: (root.manufacturer !== "" ? (root.manufacturer + " ") : "") + root.modelName + " (" + root.tech + ")"
                                color: theme.textDim
                                font.pixelSize: 10
                                font.family: theme.fontFamily
                                font.weight: Font.Normal
                                elide: Text.ElideLeft
                            }
                        }
                    }
                }

                // Power Profiles quick switch
                Column {
                    width: parent.width
                    spacing: 6
                    visible: true

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
                            property bool isCurrent: root.currentProfile === "power-saver"
                            color: isCurrent ? theme.surfaceActive : (saverMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isCurrent ? theme.green : theme.borderSubtle
                            border.width: 1

                            scale: saverMouse.pressed ? 0.97 : (saverMouse.containsMouse ? 1.015 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                            Behavior on color { ColorAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                            Behavior on border.color { ColorAnimation { duration: 750; easing.type: Easing.InOutQuart } }

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
                                onClicked: {
                                    setProfileProc.setProfile("power-saver");
                                }
                            }
                        }

                        // Balanced
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 24
                            radius: 4
                            property bool isCurrent: root.currentProfile === "balanced"
                            color: isCurrent ? theme.surfaceActive : (balMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isCurrent ? theme.blue : theme.borderSubtle
                            border.width: 1

                            scale: balMouse.pressed ? 0.97 : (balMouse.containsMouse ? 1.015 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                            Behavior on color { ColorAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                            Behavior on border.color { ColorAnimation { duration: 750; easing.type: Easing.InOutQuart } }

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
                                onClicked: {
                                    setProfileProc.setProfile("balanced");
                                }
                            }
                        }

                        // Performance
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 24
                            radius: 4
                            property bool isCurrent: root.currentProfile === "performance"
                            color: isCurrent ? theme.surfaceActive : (perfMouse.containsMouse ? theme.surfaceHover : theme.surface)
                            border.color: isCurrent ? theme.peach : theme.borderSubtle
                            border.width: 1

                            scale: perfMouse.pressed ? 0.97 : (perfMouse.containsMouse ? 1.015 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                            Behavior on color { ColorAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                            Behavior on border.color { ColorAnimation { duration: 750; easing.type: Easing.InOutQuart } }

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
                                onClicked: {
                                    setProfileProc.setProfile("performance");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
