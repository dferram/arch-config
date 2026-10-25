import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 216
    implicitHeight: 207

    radius: 20
    // Obsidian Translucent Glass
    color: Qt.rgba(0.06, 0.06, 0.09, 0.55)
    border.color: Qt.rgba(255, 255, 255, 0.10)
    border.width: 1
    clip: true

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null

    property int cpuPct: 0
    property int ramPct: 0
    property real ramUsed: 0.0
    property real ramTotal: 16.0
    property int tempC: 0
    property int fanRpm: 0
    property real freqGhz: 0.0
    property bool thermaldActive: false
    property string cpuName: "Ultra 5"
    property string cpuFull: "Ultra 5 125H"

    // Real-time telemetry history buffer (20 data points)
    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    readonly property color accentColor: {
        if (root.cpuPct > 80 || root.tempC > 85) return theme.red;
        if (root.cpuPct > 55 || root.tempC > 72) return theme.peach;
        return (theme.blueLight != "" ? theme.blueLight : theme.cyan);
    }

    Process {
        id: resProc
        command: ["/home/ferram/.local/bin/hypr-resources"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.cpuPct = d.cpu || 0;
                    root.ramPct = d.ram_pct || 0;
                    root.ramUsed = d.ram_used || 0;
                    root.ramTotal = d.ram_total || 16.0;
                    root.tempC = d.temp || 0;
                    if (d.fan !== undefined) root.fanRpm = d.fan;
                    if (d.freq !== undefined) root.freqGhz = d.freq;
                    if (d.thermald !== undefined) root.thermaldActive = d.thermald;
                    if (d.cpu_name) root.cpuName = d.cpu_name;
                    if (d.cpu_full) root.cpuFull = d.cpu_full;

                    // Push to history buffer
                    let hist = root.cpuHistory.slice(1);
                    hist.push(root.cpuPct);
                    root.cpuHistory = hist;
                    chartCanvas.requestPaint();
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: {
            if (!resProc.running) resProc.running = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 7

        // 1. Header: Title & Thermald Protected Badge
        Item {
            width: parent.width
            height: 20

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    text: "󰍛"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: root.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Telemetry"
                    color: theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Thermald Status Badge
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: thermaldRow.implicitWidth + 10
                radius: 9
                color: root.thermaldActive ? Qt.rgba(0.18, 0.8, 0.44, 0.12) : Qt.rgba(1, 1, 1, 0.08)
                border.color: root.thermaldActive ? Qt.rgba(0.18, 0.8, 0.44, 0.35) : Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Row {
                    id: thermaldRow
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: root.thermaldActive ? "#30d158" : theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.thermaldActive ? "thermald" : "passive"
                        color: root.thermaldActive ? "#30d158" : theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 2. Real-time Telemetry Graph (Sparkline Chart)
        Rectangle {
            width: parent.width
            height: 48
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.28)
            border.color: Qt.rgba(255, 255, 255, 0.06)
            border.width: 1
            clip: true

            Canvas {
                id: chartCanvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var w = width;
                    var h = height;
                    if (w <= 0 || h <= 0) return;

                    var hist = root.cpuHistory;
                    var n = hist.length;
                    if (n < 2) return;

                    var step = w / (n - 1);
                    var pts = [];
                    for (var i = 0; i < n; i++) {
                        var val = Math.max(0, Math.min(100, hist[i]));
                        var y = h - (val / 100.0) * (h - 10) - 5;
                        pts.push({ x: i * step, y: y });
                    }

                    // Draw area curve
                    ctx.beginPath();
                    ctx.moveTo(pts[0].x, pts[0].y);
                    for (var j = 1; j < n; j++) {
                        var cx = (pts[j - 1].x + pts[j].x) / 2;
                        ctx.bezierCurveTo(cx, pts[j - 1].y, cx, pts[j].y, pts[j].x, pts[j].y);
                    }

                    // Stroke line
                    ctx.lineWidth = 1.6;
                    ctx.strokeStyle = root.accentColor;
                    ctx.stroke();

                    // Fill gradient area below line
                    ctx.lineTo(w, h);
                    ctx.lineTo(0, h);
                    ctx.closePath();
                    var grad = ctx.createLinearGradient(0, 0, 0, h);
                    grad.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.28));
                    grad.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.01));
                    ctx.fillStyle = grad;
                    ctx.fill();
                }
            }

            // Real-time overlay values (Live CPU % + Current Freq)
            Row {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 5
                spacing: 4

                Text {
                    text: root.cpuPct + "%"
                    color: root.accentColor
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                Text {
                    text: "LOAD"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // 3. Sensor Badges Row: Temperature, Clock Frequency & Fan RPM
        Row {
            width: parent.width
            spacing: 4

            // Temperature Chip
            Rectangle {
                width: (parent.width - 8) / 3
                height: 22
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: root.tempC > 85 ? Qt.rgba(1, 0.27, 0.23, 0.35) : Qt.rgba(255, 255, 255, 0.07)
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        text: "󰔏"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: root.tempC > 80 ? theme.red : (root.tempC > 65 ? theme.peach : theme.green)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: (root.tempC > 0 ? root.tempC : "--") + "°C"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Frequency Chip
            Rectangle {
                width: (parent.width - 8) / 3
                height: 22
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.07)
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        text: "󰓅"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: theme.blueLight != "" ? theme.blueLight : theme.cyan
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: (root.freqGhz > 0 ? root.freqGhz.toFixed(1) : "--") + "G"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Fan Speed Chip
            Rectangle {
                width: (parent.width - 8) / 3
                height: 22
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.07)
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        text: "󰈐"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: root.fanRpm > 4500 ? theme.peach : theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.fanRpm > 0 ? (root.fanRpm > 1000 ? (root.fanRpm / 1000).toFixed(1) + "k" : root.fanRpm) : "0"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 4. RAM Section Bar
        Column {
            width: parent.width
            spacing: 3

            Row {
                width: parent.width
                Text {
                    text: "RAM"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
                Item { Layout.fillWidth: true; width: parent.width - 120; height: 1 }
                Text {
                    text: root.ramUsed.toFixed(1) + " / " + root.ramTotal.toFixed(0) + " GB (" + root.ramPct + "%)"
                    color: root.ramPct > 85 ? theme.red : theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Medium
                }
            }

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    height: parent.height
                    width: Math.max(6, parent.width * (Math.min(100, Math.max(0, root.ramPct)) / 100.0))
                    radius: 3
                    color: root.ramPct > 85 ? theme.red : "#30d158"
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }
        }

        // 5. Bottom Footer: Processor Tag + Intel Adaptive
        Rectangle {
            width: parent.width
            height: 20
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(255, 255, 255, 0.06)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "󰌢"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Intel " + root.cpuFull
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
