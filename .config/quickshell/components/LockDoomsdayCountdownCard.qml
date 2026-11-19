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

        // 1. Steady Diffuse Backlight Glow (Warm Wall Reflection)
        RectangularGlow {
            anchors.fill: parent
            visible: !root.fullscreen
            glowRadius: 26
            spread: 0.08
            color: Qt.rgba(16/255, 185/255, 129/255, ambientFlicker.val)
            cornerRadius: 24

            QtObject {
                id: ambientFlicker
                property real val: 0.18
                // Subtle candlelight ambient shimmer (tight range: 0.16 to 0.21, no throbbing)
                SequentialAnimation on val {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { to: 0.20; duration: 280; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.17; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.21; duration: 310; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.18; duration: 490; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.19; duration: 250; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.16; duration: 380; easing.type: Easing.InOutSine }
                }
            }
        }

        // 2. The Green Candle Flame (Soft blurred oval that wavers gently like a live flame)
        Rectangle {
            id: candleFlame
            width: root.fullscreen ? Math.round(root.width * 0.70) : 240
            height: root.fullscreen ? Math.round(root.height * 0.78) : 270
            radius: Math.round(width / 2)
            color: "#059669"
            layer.enabled: true
            layer.effect: FastBlur { radius: root.fullscreen ? 96 : 64 }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -10

            // Gentle organic horizontal flame waver (subtle draft)
            SequentialAnimation on anchors.horizontalCenterOffset {
                loops: Animation.Infinite
                running: true
                NumberAnimation { to: 4; duration: 450; easing.type: Easing.InOutSine }
                NumberAnimation { to: -3; duration: 580; easing.type: Easing.InOutSine }
                NumberAnimation { to: 2; duration: 360; easing.type: Easing.InOutSine }
                NumberAnimation { to: -5; duration: 620; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 410; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 530; easing.type: Easing.InOutSine }
            }

            // Gentle organic vertical flame waver (slight rising motion)
            SequentialAnimation on anchors.verticalCenterOffset {
                loops: Animation.Infinite
                running: true
                NumberAnimation { to: -14; duration: 480; easing.type: Easing.InOutSine }
                NumberAnimation { to: -8; duration: 560; easing.type: Easing.InOutSine }
                NumberAnimation { to: -13; duration: 390; easing.type: Easing.InOutSine }
                NumberAnimation { to: -9; duration: 610; easing.type: Easing.InOutSine }
                NumberAnimation { to: -11; duration: 430; easing.type: Easing.InOutSine }
            }

            // Delicate candle flame luminescence (flickers slightly between 0.22 and 0.28, never turns off)
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: true
                NumberAnimation { to: 0.27; duration: 220; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.23; duration: 340; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.28; duration: 190; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.22; duration: 380; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.26; duration: 260; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.24; duration: 310; easing.type: Easing.InOutSine }
            }

            // Minimal organic stretch/flicker
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: true
                NumberAnimation { to: 1.02; duration: 380; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.98; duration: 440; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.03; duration: 310; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.99; duration: 490; easing.type: Easing.InOutQuad }
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
        color: Qt.rgba(0.04, 0.04, 0.06, root.fullscreen ? 1.0 : 0.90)
        border.width: root.fullscreen ? 0 : 1
        border.color: Qt.rgba(16/255, 185/255, 129/255, 0.24)
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
                GradientStop { position: 0.25; color: Qt.rgba(16, 185, 129, 0.25) }
                GradientStop { position: 0.50; color: Qt.rgba(16, 185, 129, 0.40) }
                GradientStop { position: 0.75; color: Qt.rgba(16, 185, 129, 0.25) }
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

        // ---- MAIN COUNTDOWN (5-SEGMENT CLEAN WHITE REFERENCE STYLE) ----
        Column {
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
