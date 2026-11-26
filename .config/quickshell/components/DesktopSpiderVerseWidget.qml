import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root
    Theme { id: theme }

    implicitWidth: 448
    implicitHeight: 207

    function findWrapper() {
        let p = root.parent;
        while (p) {
            if (p.overlay !== undefined && p.startDrag !== undefined) return p;
            if (p.wrapperRef !== undefined) return p.wrapperRef;
            p = p.parent;
        }
        return null;
    }
    readonly property var wrapper: findWrapper()
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/spiderverse-bg.jpg")
    property string posterPath: defaultPosterPath

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
    property real s1Dx: -16
    property real s2Dx: 22
    property real s3Dx: -14
    property real s4Dx: 18

    property var reminders: []

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

    Process {
        command: [Quickshell.env("HOME") + "/.local/bin/hypr-reminders", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let list = JSON.parse(txt);
                    if (Array.isArray(list)) {
                        root.reminders = list;
                        root.updateCountdown();
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: root.isLive
        repeat: true
        onTriggered: root.updateCountdown()
    }

    // Spider-Verse Dimensional Glitch Driver (snappy on/off comic-frame stutter)
    function randomizeSliceOffsets() {
        root.glitchX = (Math.random() > 0.5 ? 1 : -1) * (4.0 + Math.random() * 5.0);
        root.glitchY = (Math.random() - 0.5) * 3.0;
        root.s1Dx = (Math.random() > 0.5 ? 1 : -1) * (10 + Math.random() * 18);
        root.s2Dx = (Math.random() > 0.5 ? 1 : -1) * (14 + Math.random() * 22);
        root.s3Dx = (Math.random() > 0.5 ? 1 : -1) * (12 + Math.random() * 18);
        root.s4Dx = (Math.random() > 0.5 ? 1 : -1) * (8 + Math.random() * 16);
    }

    Timer {
        interval: 230
        running: root.isLive && root.visible
        repeat: true
        onTriggered: {
            if (!root.glitchActive && Math.random() > 0.72) {
                root.glitchStep = 3 + Math.floor(Math.random() * 3);
                root.altGlitchPalette = Math.random() > 0.55; // Type A: Cyan/Magenta, Type B: Yellow/Purple
                root.glitchActive = true;
                root.randomizeSliceOffsets();
                spiderGlitchCanvas.requestPaint();
                glitchFrameTimer.restart();
            }
        }
    }

    Timer {
        id: glitchFrameTimer
        interval: 52
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
                    root.randomizeSliceOffsets();
                    spiderGlitchCanvas.requestPaint();
                }
                glitchFrameTimer.restart();
            } else {
                root.glitchActive = false;
                root.glitchX = 0;
                root.glitchY = 0;
            }
        }
    }

    Component.onCompleted: updateCountdown()

    // Multiverse dual-chromatic ambient glow
    Item {
        anchors.fill: parent
        z: 0

        RectangularGlow {
            width: parent.width * 0.55
            height: parent.height * 0.72
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            glowRadius: 24
            spread: 0.04
            color: Qt.rgba(255/255, 45/255, 85/255, 0.24)
            cornerRadius: 24
        }

        RectangularGlow {
            width: parent.width * 0.55
            height: parent.height * 0.72
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glowRadius: 24
            spread: 0.04
            color: Qt.rgba(0/255, 229/255, 255/255, 0.22)
            cornerRadius: 24
        }
    }

    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: 20
        color: "#090812"
        border.color: "#05070d"
        border.width: 2.5
        clip: true
        z: 1

        Item {
            id: posterContainer
            anchors.fill: parent
            layer.enabled: true
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
                anchors.topMargin: 10
                anchors.bottomMargin: -10
                source: root.posterPath
                fillMode: Image.PreserveAspectCrop
                verticalAlignment: Image.AlignVCenter
                asynchronous: true
                opacity: 0.68

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.01, 0.05, 0.40) }
                        GradientStop { position: 0.50; color: Qt.rgba(0.01, 0.01, 0.03, 0.48) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.01, 0.03, 0.72) }
                    }
                }
            }

            // Torn horizontal slices of the real Spider-Man logo during glitch
            Repeater {
                model: root.glitchActive ? 4 : 0
                delegate: Item {
                    required property int index
                    readonly property real sliceH: posterContainer.height / 4.0
                    readonly property real dx: index === 0 ? root.s1Dx : (index === 1 ? root.s2Dx : (index === 2 ? root.s3Dx : root.s4Dx))
                    x: 0
                    y: index * sliceH
                    width: posterContainer.width
                    height: sliceH
                    clip: true

                    Image {
                        x: dx
                        y: -index * sliceH + 10
                        width: posterContainer.width
                        height: posterContainer.height
                        source: root.posterPath
                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignVCenter
                        opacity: 0.75
                    }
                }
            }
        }

        // Crisp Spider-Verse Glitch Tear Lines, Halftone Flash Strips & Comic Sparks
        Canvas {
            id: spiderGlitchCanvas
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
                // Razor-thin horizontal comic/dimensional tear lines
                let lines = 5 + Math.floor(Math.random() * 5);
                for (let i = 0; i < lines; i++) {
                    let ly = 14 + Math.random() * (height - 28);
                    let lx = Math.random() * (width * 0.35);
                    let lw = width * (0.25 + Math.random() * 0.65);
                    ctx.globalAlpha = 0.85;
                    ctx.fillStyle = palette[Math.floor(Math.random() * palette.length)];
                    ctx.fillRect(lx, ly, lw, 1.8);
                }
                // Comic halftone glitch strip
                let hy = 24 + Math.random() * (height - 56);
                let hh = 10 + Math.random() * 14;
                let hx = Math.random() * (width * 0.3);
                let hw = width * 0.55;
                ctx.fillStyle = root.altGlitchPalette
                    ? (Math.random() > 0.5 ? "rgba(250, 204, 21, 0.25)" : "rgba(168, 85, 247, 0.28)")
                    : (Math.random() > 0.5 ? "rgba(0, 229, 255, 0.25)" : "rgba(255, 45, 85, 0.25)");
                ctx.fillRect(hx, hy, hw, hh);
                ctx.fillStyle = root.altGlitchPalette
                    ? (Math.random() > 0.5 ? "#facc15" : "#a855f7")
                    : (Math.random() > 0.5 ? "#00e5ff" : "#ff2d55");
                for (let dx = hx + 4; dx < hx + hw - 4; dx += 6) {
                    for (let dy = hy + 2; dy < hy + hh - 2; dy += 5) {
                        ctx.beginPath();
                        ctx.arc(dx, dy, 1.1, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
                // Tiny crisp pixel-shard offsets
                let shards = 7 + Math.floor(Math.random() * 5);
                for (let s = 0; s < shards; s++) {
                    let sx = 16 + Math.random() * (width - 32);
                    let sy = 16 + Math.random() * (height - 32);
                    ctx.globalAlpha = 0.9;
                    ctx.fillStyle = palette[Math.floor(Math.random() * palette.length)];
                    ctx.fillRect(sx, sy, 3 + Math.random() * 11, 2 + Math.random() * 4);
                }
                ctx.globalAlpha = 1.0;
            }
        }

        // Full-widget Comic-Book Ben-Day Halftone Pattern + Comic Panel Inset Frame
        Canvas {
            anchors.fill: parent
            z: 2
            opacity: 0.42
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // Full-card staggered Ben-Day halftone grid across the ENTIRE widget
                let step = 8;
                for (let row = 0, y = 4; y < height - 4; y += step, row++) {
                    let xOff = (row % 2 === 0) ? 4 : 8;
                    for (let x = xOff; x < width - 4; x += step) {
                        let u = x / width;
                        let v = y / height;
                        // Blend magenta (left) -> subtle violet/indigo (center) -> cyan (right)
                        let distCenter = Math.hypot((u - 0.5) * 1.1, (v - 0.5) * 1.4);
                        let r = 0.75 + Math.min(1.0, distCenter) * 1.15;
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

                // Comic speed-lines around the perimeter reaching inward
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

        // Crisp inner comic-panel ink border
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 16
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.22)
            z: 2
        }

        // Top chromatic hairline
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 2
            z: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: "#ff2d55" }
                GradientStop { position: 0.7; color: "#00e5ff" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Header (Marvel logo matching Doomsday)
        Row {
            x: 16; y: 14
            width: parent.width - 32
            spacing: 8
            z: 3

            Image {
                source: "file://" + Quickshell.shellPath("icons/marvel.svg")
                width: 38
                height: 15
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                smooth: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "SPIDER-VERSE · JUNE 18, 2027"
                color: Qt.rgba(255, 255, 255, 0.78)
                font.family: theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
        }



        // Active Countdown
        Column {
            visible: !root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 14
            spacing: 12
            z: 3
            width: parent.width - 24
            transform: Translate {
                x: root.glitchActive ? root.glitchX * 0.65 : 0
                y: root.glitchActive ? root.glitchY * 0.5 : 0
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: titleMain.implicitWidth
                height: titleMain.implicitHeight

                Text {
                    x: root.glitchActive ? root.glitchX : 1.5
                    text: "BEYOND THE SPIDER-VERSE"
                    color: root.altGlitchPalette ? "#facc15" : "#00e5ff"
                    opacity: root.glitchActive ? 0.85 : 0.45
                    font.family: theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Black
                    font.italic: true
                    font.letterSpacing: 2.0
                }

                Text {
                    x: root.glitchActive ? -root.glitchX : -1.5
                    text: "BEYOND THE SPIDER-VERSE"
                    color: root.altGlitchPalette ? "#a855f7" : "#ff2d55"
                    opacity: root.glitchActive ? 0.85 : 0.45
                    font.family: theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Black
                    font.italic: true
                    font.letterSpacing: 2.0
                }

                Text {
                    id: titleMain
                    text: "BEYOND THE SPIDER-VERSE"
                    color: "#ffffff"
                    font.family: theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Black
                    font.italic: true
                    font.letterSpacing: 2.0
                    style: Text.Outline
                    styleColor: "#05070d"
                }
            }

            // Chromatic duplicate rows behind the countdown numbers during glitch (Cyan/Magenta or Yellow/Purple)
            Row {
                visible: root.glitchActive
                y: mainDigitsRow.y - 1.5
                x: mainDigitsRow.x - Math.abs(root.glitchX) * 1.35
                opacity: 0.72
                spacing: root.width > 400 ? 14 : 10

                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#a855f7" : "#ff2d55" } Text { text: "MONTHS"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#a855f7" : "#ff2d55" } Text { text: "DAYS"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#a855f7" : "#ff2d55" } Text { text: "HOURS"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#a855f7" : "#ff2d55" } Text { text: "MIN"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#a855f7" : "#ff2d55" } Text { text: "SEC"; font.pixelSize: 9; opacity: 0 } }
            }

            Row {
                visible: root.glitchActive
                y: mainDigitsRow.y + 1.5
                x: mainDigitsRow.x + Math.abs(root.glitchX) * 1.35
                opacity: 0.72
                spacing: root.width > 400 ? 14 : 10

                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#facc15" : "#00e5ff" } Text { text: "MONTHS"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#facc15" : "#00e5ff" } Text { text: "DAYS"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#facc15" : "#00e5ff" } Text { text: "HOURS"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#facc15" : "#00e5ff" } Text { text: "MIN"; font.pixelSize: 9; opacity: 0 } }
                Text { text: ":"; font.pixelSize: root.width > 400 ? 24 : 20; opacity: 0 }
                Column { spacing: 2; FallingDigits { anchors.horizontalCenter: parent.horizontalCenter; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Bold; textColor: root.altGlitchPalette ? "#facc15" : "#00e5ff" } Text { text: "SEC"; font.pixelSize: 9; opacity: 0 } }
            }

            Row {
                id: mainDigitsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.width > 400 ? 14 : 10

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: svMon.implicitWidth; height: svMon.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: svMon; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MONTHS"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#ffffff"; opacity: 0.85; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: svDay.implicitWidth; height: svDay.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: svDay; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "DAYS"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#ffffff"; opacity: 0.85; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: svHr.implicitWidth; height: svHr.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: svHr; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "HOURS"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#ffffff"; opacity: 0.85; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: svMin.implicitWidth; height: svMin.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: svMin; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MIN"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#ffffff"; opacity: 0.85; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: svSec.implicitWidth; height: svSec.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: svSec; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "SEC"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#ffffff"; opacity: 0.85; style: Text.Outline; styleColor: "#05070d" }
                }
            }
        }

        // Event Arrived State
        Item {
            visible: root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 10
            width: parent.width - 32
            height: arrivedMain.implicitHeight
            z: 3

            Text {
                anchors.centerIn: parent
                x: root.glitchActive ? root.glitchX : 2
                text: "BEYOND IS HERE"
                color: "#00e5ff"
                opacity: 0.75
                font.family: theme.fontFamily
                font.pixelSize: root.width > 400 ? 24 : 19
                font.weight: Font.Black
                font.letterSpacing: 3.2
            }

            Text {
                anchors.centerIn: parent
                x: root.glitchActive ? -root.glitchX : -2
                text: "BEYOND IS HERE"
                color: "#ff2d55"
                opacity: 0.75
                font.family: theme.fontFamily
                font.pixelSize: root.width > 400 ? 24 : 19
                font.weight: Font.Black
                font.letterSpacing: 3.2
            }

            Text {
                id: arrivedMain
                anchors.centerIn: parent
                text: "BEYOND IS HERE"
                color: "#ffffff"
                font.family: theme.fontFamily
                font.pixelSize: root.width > 400 ? 24 : 19
                font.weight: Font.Black
                font.letterSpacing: 3.2
            }
        }

        // Drag Handler
        MouseArea {
            id: dragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            z: 10
            property real startScreenX: 0
            property real startScreenY: 0
            property bool isDragging: false

            onPressed: (mouse) => {
                if (mouse.button !== Qt.LeftButton) return;
                let w = root.wrapper || root.findWrapper();
                let target = (w && w.parent) ? w.parent : null;
                if (target) {
                    let pt = dragArea.mapToItem(target, mouse.x, mouse.y);
                    startScreenX = pt.x;
                    startScreenY = pt.y;
                } else {
                    startScreenX = mouse.x;
                    startScreenY = mouse.y;
                }
                isDragging = false;
            }
            onPositionChanged: (mouse) => {
                if (!dragArea.pressed) return;
                let w = root.wrapper || root.findWrapper();
                let target = (w && w.parent) ? w.parent : null;
                let dx, dy;
                if (target) {
                    let pt = dragArea.mapToItem(target, mouse.x, mouse.y);
                    dx = pt.x - startScreenX;
                    dy = pt.y - startScreenY;
                } else {
                    dx = mouse.x - startScreenX;
                    dy = mouse.y - startScreenY;
                }
                if (!isDragging && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                    isDragging = true;
                    if (w && w.startDrag) w.startDrag(mouse.x, mouse.y);
                }
                if (isDragging && w && w.updateDrag) w.updateDrag(dx, dy);
            }
            onReleased: {
                let w = root.wrapper || root.findWrapper();
                if (isDragging && w && w.endDrag) w.endDrag();
                isDragging = false;
            }
            onCanceled: {
                let w = root.wrapper || root.findWrapper();
                if (isDragging && w && w.endDrag) w.endDrag();
                isDragging = false;
            }
        }
    }
}
