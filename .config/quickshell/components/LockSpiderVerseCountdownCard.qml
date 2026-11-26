import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../theme"

// ==============================================================================
// LOCK SPIDER-VERSE COUNTDOWN CARD — 280x330 Multiverse Chromatic Glass
// Target: "Spider-Man: Beyond the Spider-Verse" (2027-06-18 at 00:00)
// ==============================================================================
Item {
    id: root
    Theme { id: theme }

    property var reminders: []
    property color accent: "#ff2d55"
    property bool active: false
    property bool fullscreen: false
    readonly property real k: fullscreen ? Math.min(Math.max(1.0, width / 500), Math.max(1.0, height / 300)) : 1.0

    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/spiderverse-bg.jpg")
    property string posterPath: defaultPosterPath

    implicitWidth: 280
    implicitHeight: 330
    width: 280
    height: 330

    property int months: 0
    property int days: 0
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool eventPassed: false
    property bool lockPreviewState: false
    property bool glitchActive: false
    property bool altGlitchPalette: false
    property real glitchX: 0
    property real glitchY: 0
    property int glitchStep: 0

    function pad2(n) {
        return (n < 10 ? "0" : "") + Math.max(0, n);
    }

    function resolveTargetDate() {
        let now = new Date();
        if (root.reminders && Array.isArray(root.reminders)) {
            for (let i = 0; i < root.reminders.length; i++) {
                let r = root.reminders[i];
                let title = (r.title || "").toLowerCase();
                if (title.indexOf("spider-verse") !== -1 || title.indexOf("spiderverse") !== -1 || title.indexOf("beyond") !== -1 || r.date === "2027-06-18") {
                    if (r.date) {
                        let parts = r.date.split("-");
                        let y = parseInt(parts[0], 10);
                        let m = parseInt(parts[1], 10) - 1;
                        let d = parseInt(parts[2], 10);
                        let hr = 0, mn = 0;
                        if (r.time) {
                            let tparts = r.time.split(":");
                            hr = parseInt(tparts[0], 10) || 0;
                            mn = parseInt(tparts[1], 10) || 0;
                        }
                        let candidate = new Date(y, m, d, hr, mn, 0);
                        if (candidate.getTime() > now.getTime()) return candidate;
                    }
                }
            }
        }
        return new Date(2027, 5, 18, 0, 0, 0);
    }

    function updateCountdown() {
        if (root.lockPreviewState) return;
        let target = resolveTargetDate();
        let now = new Date();

        if (target.getTime() <= now.getTime()) {
            root.months = 0;
            root.days = 0;
            root.hours = 0;
            root.minutes = 0;
            root.seconds = 0;
            root.eventPassed = true;
            return;
        }

        root.eventPassed = false;
        let yDiff = target.getFullYear() - now.getFullYear();
        let mDiff = target.getMonth() - now.getMonth() + yDiff * 12;

        let anchor = new Date(now.getTime());
        anchor.setFullYear(now.getFullYear() + Math.floor((now.getMonth() + mDiff) / 12));
        anchor.setMonth(((now.getMonth() + mDiff) % 12 + 12) % 12);

        if (anchor.getTime() > target.getTime()) {
            mDiff--;
            anchor = new Date(now.getTime());
            let targetMonthIndex = now.getMonth() + mDiff;
            anchor.setFullYear(now.getFullYear() + Math.floor(targetMonthIndex / 12));
            anchor.setMonth(((targetMonthIndex % 12) + 12) % 12);
        }

        let diffSecs = Math.floor((target.getTime() - anchor.getTime()) / 1000);
        root.months = Math.max(0, mDiff);
        root.days = Math.max(0, Math.floor(diffSecs / 86400));
        root.hours = Math.max(0, Math.floor(diffSecs / 3600) % 24);
        root.minutes = Math.max(0, Math.floor(diffSecs / 60) % 60);
        root.seconds = Math.max(0, diffSecs % 60);
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateCountdown()
    }

    Timer {
        interval: 260
        running: root.active && root.visible
        repeat: true
        onTriggered: {
            if (!root.glitchActive && Math.random() > 0.78) {
                root.glitchStep = 3 + Math.floor(Math.random() * 2);
                root.altGlitchPalette = Math.random() > 0.55;
                root.glitchActive = true;
                root.glitchX = (Math.random() > 0.5 ? 1 : -1) * (4.0 + Math.random() * 5.0);
                root.glitchY = (Math.random() - 0.5) * 3.0;
                lockSpiderGlitchCanvas.requestPaint();
                lockGlitchFrameTimer.restart();
            }
        }
    }

    Timer {
        id: lockGlitchFrameTimer
        interval: 48
        repeat: false
        onTriggered: {
            root.glitchStep--;
            if (root.glitchStep > 0) {
                if (root.glitchStep % 2 === 0) {
                    root.glitchActive = false;
                    root.glitchX = 0;
                    root.glitchY = 0;
                } else {
                    root.glitchActive = true;
                    root.glitchX = (Math.random() > 0.5 ? 1 : -1) * (3.5 + Math.random() * 6.0);
                    root.glitchY = (Math.random() - 0.5) * 3.5;
                    lockSpiderGlitchCanvas.requestPaint();
                }
                lockGlitchFrameTimer.restart();
            } else {
                root.glitchActive = false;
                root.glitchX = 0;
                root.glitchY = 0;
            }
        }
    }

    onRemindersChanged: updateCountdown()
    Component.onCompleted: updateCountdown()

    Item {
        anchors.fill: parent
        z: 0
        visible: !root.fullscreen

        RectangularGlow {
            width: parent.width * 0.65
            height: parent.height * 0.65
            anchors.left: parent.left
            anchors.top: parent.top
            glowRadius: 24
            spread: 0.04
            color: Qt.rgba(255/255, 45/255, 85/255, 0.22)
            cornerRadius: 24
        }

        RectangularGlow {
            width: parent.width * 0.65
            height: parent.height * 0.65
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            glowRadius: 24
            spread: 0.04
            color: Qt.rgba(0/255, 229/255, 255/255, 0.20)
            cornerRadius: 24
        }
    }

    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.fullscreen ? 0 : 16
        color: "#090812"
        border.width: root.fullscreen ? 0 : 2.5
        border.color: "#05070d"
        clip: true
        z: 1

        Item {
            id: lockPosterContainer
            anchors.fill: parent
            layer.enabled: !root.fullscreen
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: cardBody.width
                    height: cardBody.height
                    radius: cardBody.radius
                }
            }

            Image {
                visible: !root.glitchActive
                anchors.fill: parent
                anchors.topMargin: 8
                anchors.bottomMargin: -8
                source: root.posterPath
                fillMode: Image.PreserveAspectCrop
                verticalAlignment: Image.AlignVCenter
                asynchronous: true
                opacity: root.fullscreen ? 0.58 : 0.54

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.01, 0.05, 0.45) }
                        GradientStop { position: 0.50; color: Qt.rgba(0.01, 0.01, 0.03, 0.55) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.01, 0.03, 0.80) }
                    }
                }
            }

            Repeater {
                model: root.glitchActive ? 4 : 0
                delegate: Item {
                    required property int index
                    readonly property real sliceH: lockPosterContainer.height / 4.0
                    readonly property real dx: (index % 2 === 0 ? -1 : 1) * (10 + Math.abs(root.glitchX) * 2.0)
                    x: 0
                    y: index * sliceH
                    width: lockPosterContainer.width
                    height: sliceH
                    clip: true

                    Image {
                        x: dx
                        y: -index * sliceH + 8
                        width: lockPosterContainer.width
                        height: lockPosterContainer.height
                        source: root.posterPath
                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignVCenter
                        opacity: 0.65
                    }
                }
            }
        }

        Canvas {
            id: lockSpiderGlitchCanvas
            anchors.fill: parent
            z: 6
            visible: root.glitchActive
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!root.glitchActive) return;

                let palette = root.altGlitchPalette
                    ? ["#facc15", "#a855f7", "#fde047", "#ffffff"]
                    : ["#00e5ff", "#ff2d55", "#facc15", "#ffffff"];
                let lines = 4 + Math.floor(Math.random() * 4);
                for (let i = 0; i < lines; i++) {
                    let ly = 16 + Math.random() * (height - 32);
                    let lx = Math.random() * (width * 0.45);
                    let lw = width * (0.20 + Math.random() * 0.55);
                    ctx.globalAlpha = 0.75;
                    ctx.fillStyle = palette[Math.floor(Math.random() * palette.length)];
                    ctx.fillRect(lx, ly, lw, 1.5);
                }
                let shards = 5 + Math.floor(Math.random() * 5);
                for (let s = 0; s < shards; s++) {
                    let sx = 20 + Math.random() * (width - 40);
                    let sy = 20 + Math.random() * (height - 40);
                    ctx.globalAlpha = 0.85;
                    ctx.fillStyle = palette[Math.floor(Math.random() * palette.length)];
                    ctx.fillRect(sx, sy, 3 + Math.random() * 9, 2 + Math.random() * 3);
                }
                ctx.globalAlpha = 1.0;
            }
        }

        // Full-widget Comic-Book Ben-Day Halftone Pattern + Comic Panel Inset Frame
        Canvas {
            anchors.fill: parent
            z: 2
            opacity: 0.40
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                let step = 8;
                for (let row = 0, y = 4; y < height - 4; y += step, row++) {
                    let xOff = (row % 2 === 0) ? 4 : 8;
                    for (let x = xOff; x < width - 4; x += step) {
                        let u = x / width;
                        let v = y / height;
                        let distCenter = Math.hypot((u - 0.5) * 1.1, (v - 0.5) * 1.1);
                        let r = 0.75 + Math.min(1.0, distCenter) * 1.10;
                        if (u < 0.38) {
                            ctx.fillStyle = "rgba(255, 45, 85, " + (0.28 + (0.38 - u) * 0.65).toFixed(2) + ")";
                        } else if (u > 0.62) {
                            ctx.fillStyle = "rgba(0, 229, 255, " + (0.28 + (u - 0.62) * 0.65).toFixed(2) + ")";
                        } else {
                            ctx.fillStyle = "rgba(168, 85, 247, 0.24)";
                        }
                        ctx.beginPath();
                        ctx.arc(x, y, r, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                ctx.strokeStyle = "rgba(255, 255, 255, 0.16)";
                ctx.lineWidth = 1.0;
                for (let a = 0; a < 24; a++) {
                    let ang = (a / 24.0) * Math.PI * 2;
                    let cx = width * 0.5;
                    let cy = height * 0.5;
                    let r1 = Math.min(width, height) * 0.38;
                    let r2 = Math.max(width, height) * 0.70;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(ang) * r1, cy + Math.sin(ang) * r1);
                    ctx.lineTo(cx + Math.cos(ang) * r2, cy + Math.sin(ang) * r2);
                    ctx.stroke();
                }
            }
        }

        Rectangle {
            visible: !root.fullscreen
            anchors.fill: parent
            anchors.margins: 4
            radius: 12
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.22)
            z: 2
        }

        Row {
            x: root.fullscreen ? 36 : 16
            y: root.fullscreen ? 28 : 14
            width: parent.width - (root.fullscreen ? 72 : 32)
            spacing: root.fullscreen ? 14 : 8
            z: 3

            Image {
                source: "file://" + Quickshell.shellPath("icons/marvel.svg")
                width: root.fullscreen ? 64 : 38
                height: root.fullscreen ? 25 : 15
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                smooth: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "SPIDER-VERSE · JUNE 18, 2027"
                color: Qt.rgba(255, 255, 255, 0.78)
                font.family: theme.fontFamily
                font.pixelSize: root.fullscreen ? 14 : 9
                font.weight: Font.Bold
                font.letterSpacing: 1.1
            }
        }



        Column {
            visible: !root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.fullscreen ? 0 : 14
            spacing: Math.round(16 * root.k)
            z: 3
            width: parent.width - 24
            transform: Translate {
                x: root.glitchActive ? root.glitchX * 0.65 : 0
                y: root.glitchActive ? root.glitchY * 0.5 : 0
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "BEYOND THE\nSPIDER-VERSE"
                color: "#ffffff"
                font.family: theme.fontFamily
                font.pixelSize: Math.round(13 * root.k)
                font.weight: Font.Black
                font.italic: true
                font.letterSpacing: 2.0 * root.k
                style: Text.Outline
                styleColor: "#05070d"
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(3 * root.k)

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    FallingDigits {
                        anchors.horizontalCenter: parent.horizontalCenter
                        value: root.pad2(root.months)
                        fontFamily: theme.fontFamily
                        pixelSize: Math.round(22 * root.k)
                        fontWeight: Font.Bold
                        textColor: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MONTHS"
                        font.family: theme.fontFamily
                        font.pixelSize: Math.round(8 * root.k)
                        font.weight: Font.Bold
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Bold; color: "#ffffff"; opacity: 0.65; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    FallingDigits {
                        anchors.horizontalCenter: parent.horizontalCenter
                        value: root.pad2(root.days)
                        fontFamily: theme.fontFamily
                        pixelSize: Math.round(22 * root.k)
                        fontWeight: Font.Bold
                        textColor: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "DAYS"
                        font.family: theme.fontFamily
                        font.pixelSize: Math.round(8 * root.k)
                        font.weight: Font.Bold
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Bold; color: "#ffffff"; opacity: 0.65; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    FallingDigits {
                        anchors.horizontalCenter: parent.horizontalCenter
                        value: root.pad2(root.hours)
                        fontFamily: theme.fontFamily
                        pixelSize: Math.round(22 * root.k)
                        fontWeight: Font.Bold
                        textColor: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "HOURS"
                        font.family: theme.fontFamily
                        font.pixelSize: Math.round(8 * root.k)
                        font.weight: Font.Bold
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Bold; color: "#ffffff"; opacity: 0.65; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    FallingDigits {
                        anchors.horizontalCenter: parent.horizontalCenter
                        value: root.pad2(root.minutes)
                        fontFamily: theme.fontFamily
                        pixelSize: Math.round(22 * root.k)
                        fontWeight: Font.Bold
                        textColor: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MIN"
                        font.family: theme.fontFamily
                        font.pixelSize: Math.round(8 * root.k)
                        font.weight: Font.Bold
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Bold; color: "#ffffff"; opacity: 0.65; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    FallingDigits {
                        anchors.horizontalCenter: parent.horizontalCenter
                        value: root.pad2(root.seconds)
                        fontFamily: theme.fontFamily
                        pixelSize: Math.round(22 * root.k)
                        fontWeight: Font.Bold
                        textColor: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "SEC"
                        font.family: theme.fontFamily
                        font.pixelSize: Math.round(8 * root.k)
                        font.weight: Font.Bold
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }
            }
        }

        Text {
            visible: root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.fullscreen ? 0 : 10
            width: parent.width - 28
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            z: 3
            text: "BEYOND\nIS HERE"
            color: "#ffffff"
            font.family: theme.fontFamily
            font.pixelSize: Math.round(23 * root.k)
            font.weight: Font.Black
            font.letterSpacing: 3.0 * root.k
        }
    }
}
