import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../theme"

// ==============================================================================
// LOCK DOOMSDAY COUNTDOWN CARD — 280x330 Cinematic Obsidian Liquid Glass
// Sits directly next to LockCalendarCard and before LockEventCountdownCard (NSQK).
// Target: "Avengers: Doomsday Premiere" (2026-12-16 at 00:00).
// 5-segment format: MONTHS : DAYS : HOURS : MINUTES : SECONDS
// Organic Green Candlelight back-illumination: gentle flickering & wavering flame.
// ==============================================================================
Item {
    id: root

    Theme { id: theme }

    property var reminders: []
    property color accent: "#10b981" // Refined Doctor Doom Emerald
    property bool active: false
    property bool fullscreen: false
    readonly property real k: fullscreen ? Math.min(Math.max(1.0, width / 500), Math.max(1.0, height / 300)) : 1.0

    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/doomsday.jpg")
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
    property real remainingHours: 720.0

    readonly property real auraIntensity: {
        if (eventPassed) return 1.0;
        let h = remainingHours;
        if (h >= 720) return 0.0;
        if (h >= 168) return 0.55 * (1.0 - (h - 168) / (720 - 168));
        if (h >= 24)  return 0.55 + 0.30 * (1.0 - (h - 24) / (168 - 24));
        return 0.85 + 0.15 * (1.0 - Math.max(0, h) / 24.0);
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + Math.max(0, n);
    }

    function resolveTargetDate() {
        let now = new Date();
        if (root.reminders && Array.isArray(root.reminders)) {
            for (let i = 0; i < root.reminders.length; i++) {
                let r = root.reminders[i];
                let title = (r.title || "").toLowerCase();
                let cat = (r.category || "").toLowerCase();
                if (title.indexOf("doomsday") !== -1 || r.date === "2026-12-16" || cat === "marvel") {
                    if (r.date) {
                        let parts = r.date.split("-");
                        let y = parseInt(parts[0], 10);
                        let m = parseInt(parts[1], 10) - 1;
                        let d = parseInt(parts[2], 10);
                        let hr = 0;
                        let mn = 0;
                        if (r.time) {
                            let tparts = r.time.split(":");
                            hr = parseInt(tparts[0], 10) || 0;
                            mn = parseInt(tparts[1], 10) || 0;
                        }
                        if (r.photo && r.photo.trim()) {
                            root.posterPath = (r.photo.startsWith("http") || r.photo.startsWith("file://")) ? r.photo : ("file://" + r.photo);
                        }
                        let candidate = new Date(y, m, d, hr, mn, 0);
                        if (candidate.getTime() > now.getTime()) {
                            return candidate;
                        }
                    }
                }
            }
        }
        // Fallback default: December 16, 2026 at 00:00 (Midnight Premiere)
        return new Date(2026, 11, 16, 0, 0, 0);
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
            root.remainingHours = 0;
            root.eventPassed = true;
            return;
        }

        root.eventPassed = false;
        root.remainingHours = Math.max(0, (target.getTime() - now.getTime()) / 3600000.0);

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
        let sec = diffSecs % 60;
        let min = Math.floor(diffSecs / 60) % 60;
        let hr = Math.floor(diffSecs / 3600) % 24;
        let dy = Math.floor(diffSecs / 86400);

        root.months = Math.max(0, mDiff);
        root.days = Math.max(0, dy);
        root.hours = Math.max(0, hr);
        root.minutes = Math.max(0, min);
        root.seconds = Math.max(0, sec);
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateCountdown()
    }

    onRemindersChanged: updateCountdown()
    Component.onCompleted: updateCountdown()

    // =========================================================================
    // ORGANIC GREEN CANDLELIGHT BEHIND THE WIDGET
    // Steady, warm ambient glow with delicate candle flame wavering & micro-flicker.
    // Zero harsh pulsing / zero square edges.
    // =========================================================================
    Item {
        anchors.fill: parent
        z: 0

        // 1. Subtle random arcane flicker & behind-border Doom Kirby Krackle
        QtObject {
            id: lockDoomGlowState
            property real alpha: 0.18
            property real rad: 18
            Behavior on alpha { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
            Behavior on rad { NumberAnimation { duration: 260; easing.type: Easing.OutQuad } }
        }

        RectangularGlow {
            anchors.fill: parent
            visible: !root.fullscreen
            glowRadius: lockDoomGlowState.rad
            spread: 0.02
            color: Qt.rgba(16/255, 185/255, 129/255, Math.max(0.08, lockDoomGlowState.alpha))
            cornerRadius: 24
        }

        // Truly random Doctor Doom green fire & fine Kirby Krackle radiating outward from widget center
        Canvas {
            id: lockDoomBehindEdgeCanvas
            visible: !root.fullscreen
            anchors.fill: parent
            anchors.margins: -28
            property var plumes: []
            property var specks: []

            function borderRay(theta, pad, cw, ch) {
                let ca = Math.cos(theta);
                let sa = Math.sin(theta);
                let hw = cw * 0.5;
                let hh = ch * 0.5;
                let cx = pad + hw;
                let cy = pad + hh;
                let tx = Math.abs(ca) > 0.0001 ? hw / Math.abs(ca) : 1e9;
                let ty = Math.abs(sa) > 0.0001 ? hh / Math.abs(sa) : 1e9;
                let dist = Math.min(tx, ty);
                return { x: cx + ca * dist, y: cy + sa * dist, dx: ca, dy: sa };
            }

            function spawnPlume(randomLife) {
                return {
                    theta: Math.random() * Math.PI * 2,
                    life: randomLife ? Math.random() : 0.0,
                    speed: 0.005 + Math.random() * 0.008,
                    rad: 18 + Math.random() * 18,
                    maxOut: 5.0 + Math.random() * 9.0,
                    tangDrift: (Math.random() - 0.5) * 10.0
                };
            }

            function spawnSpeck(randomLife) {
                let palette = ["#ecfccb", "#bef264", "#4ade80", "#22c55e", "#15803d", "#052e16", "#030704"];
                return {
                    theta: Math.random() * Math.PI * 2,
                    life: randomLife ? Math.random() : 0.0,
                    speed: 0.008 + Math.random() * 0.014,
                    maxOut: 7.0 + Math.pow(Math.random(), 1.15) * 13.0,
                    tangDrift: (Math.random() - 0.5) * 8.0,
                    r: 0.7 + Math.pow(Math.random(), 1.6) * 1.4,
                    color: palette[Math.floor(Math.random() * palette.length)]
                };
            }

            Component.onCompleted: {
                let pArr = [];
                for (let i = 0; i < 22; i++) pArr.push(spawnPlume(true));
                plumes = pArr;

                let sArr = [];
                for (let j = 0; j < 115; j++) sArr.push(spawnSpeck(true));
                specks = sArr;
            }

            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                let pad = 28;
                let cw = width - pad * 2;
                let ch = height - pad * 2;
                let intensity = root.eventPassed ? 1.0 : (0.35 + root.auraIntensity * 0.65);

                for (let i = 0; i < plumes.length; i++) {
                    let p = plumes[i];
                    let env = Math.sin(p.life * Math.PI);
                    if (env <= 0.02) continue;

                    let ray = borderRay(p.theta, pad, cw, ch);
                    let easeOut = Math.pow(p.life, 0.75);
                    let out = -3.0 + easeOut * p.maxOut;
                    let gx = ray.x + ray.dx * out - ray.dy * (p.tangDrift * easeOut);
                    let gy = ray.y + ray.dy * out + ray.dx * (p.tangDrift * easeOut);
                    let r = p.rad * (0.78 + 0.32 * env);

                    let g = ctx.createRadialGradient(gx, gy, 1, gx, gy, r);
                    g.addColorStop(0.0, "rgba(236, 252, 203, " + (0.20 * env * intensity).toFixed(3) + ")");
                    g.addColorStop(0.35, "rgba(74, 222, 128, " + (0.18 * env * intensity).toFixed(3) + ")");
                    g.addColorStop(0.70, "rgba(5, 150, 105, " + (0.11 * env * intensity).toFixed(3) + ")");
                    g.addColorStop(1.0, "rgba(2, 44, 34, 0)");
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(gx, gy, r, 0, Math.PI * 2);
                    ctx.fill();
                }

                for (let j = 0; j < specks.length; j++) {
                    let s = specks[j];
                    let env = Math.sin(s.life * Math.PI);
                    if (env <= 0.02) continue;

                    let ray = borderRay(s.theta, pad, cw, ch);
                    let easeOut = Math.pow(s.life, 0.72);
                    let out = -1.5 + easeOut * s.maxOut;
                    let sx = ray.x + ray.dx * out - ray.dy * (s.tangDrift * easeOut);
                    let sy = ray.y + ray.dy * out + ray.dx * (s.tangDrift * easeOut);
                    let sr = s.r * (0.55 + 0.45 * env);

                    if (s.color === "#ecfccb" || s.color === "#bef264") {
                        ctx.globalAlpha = env * 0.55 * intensity;
                        ctx.fillStyle = "#052e16";
                        ctx.beginPath();
                        ctx.arc(sx, sy, sr + 0.55, 0, Math.PI * 2);
                        ctx.fill();
                    }

                    ctx.globalAlpha = env * 0.88 * intensity;
                    ctx.fillStyle = s.color;
                    ctx.beginPath();
                    ctx.arc(sx, sy, sr, 0, Math.PI * 2);
                    ctx.fill();
                }
                ctx.globalAlpha = 1.0;
            }
        }

        Timer {
            interval: 40
            running: !root.fullscreen && root.visible
            repeat: true
            onTriggered: {
                let base = 0.12 + root.auraIntensity * 0.12;
                lockDoomGlowState.alpha = base + (Math.random() - 0.45) * 0.06;
                lockDoomGlowState.rad = 15 + Math.round(root.auraIntensity * 8) + Math.round((Math.random() - 0.5) * 4);

                for (let i = 0; i < lockDoomBehindEdgeCanvas.plumes.length; i++) {
                    let p = lockDoomBehindEdgeCanvas.plumes[i];
                    p.life += p.speed;
                    if (p.life >= 1.0) lockDoomBehindEdgeCanvas.plumes[i] = lockDoomBehindEdgeCanvas.spawnPlume(false);
                }
                for (let j = 0; j < lockDoomBehindEdgeCanvas.specks.length; j++) {
                    let s = lockDoomBehindEdgeCanvas.specks[j];
                    s.life += s.speed;
                    if (s.life >= 1.0) lockDoomBehindEdgeCanvas.specks[j] = lockDoomBehindEdgeCanvas.spawnSpeck(false);
                }
                lockDoomBehindEdgeCanvas.requestPaint();
            }
        }
    }

    // =========================================================================
    // MAIN WIDGET CARD BODY (Clean Obsidian Liquid Glass Container)
    // =========================================================================
    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.fullscreen ? 0 : 16
        color: "#090a0f"
        border.width: root.fullscreen ? 0 : 1
        border.color: Qt.rgba(16/255, 185/255, 129/255, 0.20 + root.auraIntensity * 0.26)
        clip: true
        z: 1

        // Masked Background Poster Image (Subtle Moody Doctor Doom Background)
        Item {
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
                anchors.fill: parent
                source: root.posterPath
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.fullscreen ? 1316 : 480
                smooth: true
                asynchronous: true
                opacity: root.fullscreen ? 0.36 : 0.30

                // Neutral obsidian gradient darkening overlay
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.03, 0.04, 0.76) }
                        GradientStop { position: 0.50; color: Qt.rgba(0.01, 0.02, 0.03, 0.88) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.02, 0.02, 0.96) }
                    }
                }
            }
        }

        // Top Specular Hairline (Subtle Candlelight Sheen)
        Rectangle {
            visible: !root.fullscreen
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            z: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: Qt.rgba(16/255, 185/255, 129/255, 0.22 + root.auraIntensity * 0.22) }
                GradientStop { position: 0.50; color: Qt.rgba(16/255, 185/255, 129/255, 0.36 + root.auraIntensity * 0.30) }
                GradientStop { position: 0.75; color: Qt.rgba(16/255, 185/255, 129/255, 0.22 + root.auraIntensity * 0.22) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ---- HEADER: Marvel Badge & Subtitle ----
        Row {
            id: header
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
                text: "STUDIOS · CINEMA PREMIERE"
                color: Qt.rgba(255, 255, 255, 0.75)
                font.family: theme.fontFamily
                font.pixelSize: root.fullscreen ? 14 : 10
                font.weight: Font.Bold
                font.letterSpacing: root.fullscreen ? 2.0 : 1.2
            }
        }

        // ---- EVENT ARRIVED: MINIMALIST "DOOMSDAY IS HERE" ----
        Text {
            visible: root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.fullscreen ? 0 : 10
            width: parent.width - 28
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.18
            z: 3
            text: "DOOMSDAY\nIS HERE"
            color: "#ffffff"
            font.family: theme.fontFamily
            font.pixelSize: Math.round(23 * root.k)
            font.weight: Font.Black
            font.letterSpacing: 3.0 * root.k
        }

        // ---- MAIN COUNTDOWN (5-SEGMENT CLEAN WHITE REFERENCE STYLE) ----
        Column {
            visible: !root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.fullscreen ? 0 : 14
            spacing: Math.round(16 * root.k)
            z: 3
            width: parent.width - 24

            // Top Banner Title: "DOOMSDAY IS COMING" (Crisp, Clean, Minimalist)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DOOMSDAY IS COMING"
                color: "#ffffff"
                font.family: theme.fontFamily
                font.pixelSize: Math.round(13 * root.k)
                font.weight: Font.Black
                font.letterSpacing: 2.2 * root.k
            }

            // 5-Segment Countdown Row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(3 * root.k)

                // 1. MONTHS
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
                        font.letterSpacing: 0.8 * root.k
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: Math.round(16 * root.k)
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(7 * root.k)
                }

                // 2. DAYS
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
                        font.letterSpacing: 0.8 * root.k
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: Math.round(16 * root.k)
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(7 * root.k)
                }

                // 3. HOURS
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
                        font.letterSpacing: 0.8 * root.k
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: Math.round(16 * root.k)
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(7 * root.k)
                }

                // 4. MINUTES
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
                        text: "MINUTES"
                        font.family: theme.fontFamily
                        font.pixelSize: Math.round(7 * root.k)
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6 * root.k
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: Math.round(16 * root.k)
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(7 * root.k)
                }

                // 5. SECONDS
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
                        text: "SECONDS"
                        font.family: theme.fontFamily
                        font.pixelSize: Math.round(7 * root.k)
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6 * root.k
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }
            }
        }
    }
}
