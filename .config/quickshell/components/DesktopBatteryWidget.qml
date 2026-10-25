import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
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

    // Battery telemetry
    property int fallbackPercent: 100
    property string fallbackStatus: "Discharging"
    property real powerNow: 0.0

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

    // Dynamic color matching Apple battery levels and wallpaper accents
    property color gaugeColor: {
        if (isCharging) return theme.green != "" ? theme.green : "#30d158";
        if (currentPercent <= 10) return theme.red != "" ? theme.red : "#ff453a";
        if (currentPercent <= 20) return theme.yellow != "" ? theme.yellow : "#ffd60a";
        return theme.green != "" ? theme.green : "#30d158";
    }

    // Telemetry process from quickshell battery-details.py
    Process {
        id: sysfsProc
        command: ["python3", Quickshell.shellPath("scripts/battery-details.py")]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.capacity !== undefined && d.capacity > 0) root.fallbackPercent = d.capacity;
                    if (d.status) root.fallbackStatus = d.status;
                    if (d.power_now_w !== undefined) root.powerNow = d.power_now_w;
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: sysfsProc.running = true
    }

    Column {
        anchors.centerIn: parent
        spacing: 8
        anchors.verticalCenterOffset: -4

        // Circular Apple Ring Gauge
        Item {
            id: ringContainer
            width: 90
            height: 90
            anchors.horizontalCenter: parent.horizontalCenter

            Canvas {
                id: gaugeCanvas
                anchors.fill: parent
                antialiasing: true

                property real animPercent: root.currentPercent

                Behavior on animPercent {
                    NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                }

                onAnimPercentChanged: requestPaint()

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.reset();

                    let centerX = width / 2;
                    let centerY = height / 2;
                    let radius = (width - 12) / 2;
                    let lineWidth = 9;

                    // Background Track
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
                    ctx.lineWidth = lineWidth;
                    ctx.lineCap = "round";
                    ctx.stroke();

                    // Progress Arc
                    let startAngle = -0.5 * Math.PI;
                    let pct = Math.max(0, Math.min(100, animPercent)) / 100.0;
                    let endAngle = startAngle + (pct * 2 * Math.PI);

                    if (pct > 0.005) {
                        ctx.beginPath();
                        ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                        ctx.strokeStyle = root.gaugeColor.toString();
                        ctx.lineWidth = lineWidth;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }
            }

            // Center Content: Laptop Icon + Percentage
            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isCharging ? "󱐋" : "󰌢"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.isCharging ? 20 : 18
                    color: root.isCharging ? (theme.yellow != "" ? theme.yellow : "#ffd60a") : theme.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.currentPercent + "%"
                    font.family: theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: theme.text
                }
            }
        }

        // Status Label (Apple Sonoma Style in English)
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MateBook 14"
                color: theme.textSub
                font.family: theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.isCharging ? "Charging" : (root.currentPercent >= 100 ? "Fully Charged" : "On Battery")
                color: theme.textDim
                font.family: theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Medium
            }
        }
    }
}
