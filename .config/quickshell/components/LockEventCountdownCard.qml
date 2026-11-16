import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../theme"

// ==============================================================================
// LOCK EVENT COUNTDOWN CARD — 280x330 Apple Obsidian Liquid Glass
// Sits directly next to LockDoomsdayCountdownCard in the lock screen control panel.
// Target: "NSQK presenta Mosca" (2027-02-27 at 20:00).
// 5-segment liquid glass pill boxes: MONTHS : DAYS : HOURS : MIN : SEC
// ==============================================================================
Rectangle {
    id: root

    Theme { id: theme }

    property var reminders: []
    property color accent: "#ffe600"
    property bool active: false

    readonly property string iconFont: "GeistMono Nerd Font Propo"
    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/nsqk-mosca.jpg")
    property string posterPath: defaultPosterPath

    FontLoader {
        id: bebasFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/BebasNeue-Regular.ttf"
    }

    implicitWidth: 310
    implicitHeight: 330
    radius: 16
    color: theme.popupBg
    border.width: 1
    border.color: theme.border
    clip: true

    // Target countdown values
    property string eventTimeLabel: "8:00 PM"
    property string eventLocation: "Auditorio Josefa · Live"

    property int months: 0
    property int days: 0
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool eventPassed: false

    function pad2(n) {
        return (n < 10 ? "0" : "") + Math.max(0, n);
    }

    function formatTime12(t) {
        if (!t) return "8:00 PM";
        let p = t.split(":");
        let h = parseInt(p[0], 10);
        let m = p[1] || "00";
        let ap = h >= 12 ? "PM" : "AM";
        let h12 = h % 12;
        if (h12 === 0) h12 = 12;
        return h12 + ":" + m + " " + ap;
    }

    function resolveTargetDate() {
        let now = new Date();
        if (root.reminders && Array.isArray(root.reminders)) {
            for (let i = 0; i < root.reminders.length; i++) {
                let r = root.reminders[i];
                let title = (r.title || "").toLowerCase();
                if (title.indexOf("mosca") !== -1 || title.indexOf("nsqk") !== -1 || r.date === "2027-02-27") {
                    if (r.date) {
                        let parts = r.date.split("-");
                        let y = parseInt(parts[0], 10);
                        let m = parseInt(parts[1], 10) - 1;
                        let d = parseInt(parts[2], 10);
                        let hr = 20;
                        let mn = 0;
                        if (r.time) {
                            let tparts = r.time.split(":");
                            hr = parseInt(tparts[0], 10) || 20;
                            mn = parseInt(tparts[1], 10) || 0;
                            root.eventTimeLabel = root.formatTime12(r.time);
                        }
                        if (r.photo && r.photo.trim()) {
                            root.posterPath = (r.photo.startsWith("http") || r.photo.startsWith("file://")) ? r.photo : ("file://" + r.photo);
                        }
                        if (r.notes && r.notes.trim()) {
                            root.eventLocation = r.notes.trim() + " · Live";
                        }
                        let candidate = new Date(y, m, d, hr, mn, 0);
                        if (candidate.getTime() > now.getTime()) {
                            return candidate;
                        }
                    }
                }
            }
        }
        // Fallback default: February 27, 2027 at 20:00 (8:00 PM)
        return new Date(2027, 1, 27, 20, 0, 0);
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

        let totalDiffSecs = Math.max(0, Math.floor((target.getTime() - now.getTime()) / 1000));
        let sec = totalDiffSecs % 60;
        let min = Math.floor(totalDiffSecs / 60) % 60;
        let hr = Math.floor(totalDiffSecs / 3600) % 24;
        let dy = Math.floor(totalDiffSecs / 86400);

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

    // Masked Background Poster Image (Pure Obsidian Black Liquid Glass)
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: root.radius
            }
        }

        // Poster Artwork
        Image {
            anchors.fill: parent
            source: root.posterPath
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 480
            sourceSize.height: 640
            asynchronous: true
            opacity: 0.28

            // Pure neutral black darkening gradient (OLED black, no tint)
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.05, 0.07, 0.74) }
                    GradientStop { position: 0.50; color: Qt.rgba(0.03, 0.03, 0.05, 0.84) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.02, 0.03, 0.95) }
                }
            }
        }
    }

    // Top Specular Hairline (Apple liquid glass hallmark)
    Rectangle {
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
            GradientStop { position: 0.25; color: Qt.rgba(255, 255, 255, 0.20) }
            GradientStop { position: 0.75; color: Qt.rgba(255, 255, 255, 0.20) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ---- HEADER: NSQK Logo & MOSCA Typography ----
    Row {
        id: header
        x: 16; y: 14
        width: parent.width - 32
        spacing: 10
        z: 3

        Image {
            source: "file://" + Quickshell.shellPath("assets/nsqk-logo-white.png")
            width: 44
            height: 22
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            smooth: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "MOSCA"
            color: "#ffffff"
            font.family: root.iconFont
            font.pixelSize: 18
            font.weight: Font.Black
            font.italic: true
            font.letterSpacing: 2.5
        }
    }

    // STANDBY indicator in top right (Canal 600 CRT style)
    Text {
        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 16
        text: "STANDBY"
        color: Qt.rgba(125/255, 145/255, 199/255, 0.70)
        font.family: bebasFont.name ? bebasFont.name : "Bebas Neue"
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1.8
        z: 3
    }

    // Subtitle / Tour Tag
    Row {
        id: subHeader
        x: 16; y: 44
        spacing: 6
        z: 3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰽰"
            font.family: root.iconFont
            font.pixelSize: 12
            color: Qt.rgba(255, 255, 255, 0.65)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "NSQK presenta Mosca"
            color: Qt.rgba(255, 255, 255, 0.55)
            font.family: theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    // ---- MAIN COUNTDOWN (CRT Canal 600 style: DÍAS : HRS : MIN : SEG) ----
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -4
        spacing: 10
        z: 3

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            // 1. DÍAS
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                FallingDigits {
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: root.pad2(root.days)
                    fontFamily: "NotoSerif Nerd Font"
                    pixelSize: 36
                    fontWeight: Font.Black
                    fontItalic: false
                    textColor: "#ffe600"
                    textStyle: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.95)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "DÍAS"
                    font.family: bebasFont.name ? bebasFont.name : "Bebas Neue"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.8
                    color: "#7d91c7"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -8
                text: ":"
                font.family: "NotoSerif Nerd Font"
                font.pixelSize: 26
                font.weight: Font.Black
                color: "#ffe600"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.95)
            }

            // 2. HRS
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                FallingDigits {
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: root.pad2(root.hours)
                    fontFamily: "NotoSerif Nerd Font"
                    pixelSize: 36
                    fontWeight: Font.Black
                    fontItalic: false
                    textColor: "#ffe600"
                    textStyle: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.95)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "HRS"
                    font.family: bebasFont.name ? bebasFont.name : "Bebas Neue"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.8
                    color: "#7d91c7"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -8
                text: ":"
                font.family: "NotoSerif Nerd Font"
                font.pixelSize: 26
                font.weight: Font.Black
                color: "#ffe600"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.95)
            }

            // 3. MIN
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                FallingDigits {
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: root.pad2(root.minutes)
                    fontFamily: "NotoSerif Nerd Font"
                    pixelSize: 36
                    fontWeight: Font.Black
                    fontItalic: false
                    textColor: "#ffe600"
                    textStyle: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.95)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MIN"
                    font.family: bebasFont.name ? bebasFont.name : "Bebas Neue"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.8
                    color: "#7d91c7"
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -8
                text: ":"
                font.family: "NotoSerif Nerd Font"
                font.pixelSize: 26
                font.weight: Font.Black
                color: "#ffe600"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.95)
            }

            // 4. SEG
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                FallingDigits {
                    anchors.horizontalCenter: parent.horizontalCenter
                    value: root.pad2(root.seconds)
                    fontFamily: "NotoSerif Nerd Font"
                    pixelSize: 36
                    fontWeight: Font.Black
                    fontItalic: false
                    textColor: "#ffe600"
                    textStyle: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.95)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SEG"
                    font.family: bebasFont.name ? bebasFont.name : "Bebas Neue"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.8
                    color: "#7d91c7"
                }
            }
        }
    }

    // ---- MARQUEE BANNER: "¿ESTÁS PONIENDO ATENCIÓN?" (NSQK CRT style, full width edge-to-edge) ----
    Rectangle {
        id: marqueeStrip
        anchors.left: parent.left
        anchors.right: parent.right
        height: 46
        y: parent.height - height - 16
        clip: true
        color: "#163172"
        z: 3

        readonly property string phrase: "¿ESTÁS PONIENDO ATENCIÓN?               "

        Text {
            id: measurer
            visible: false
            text: marqueeStrip.phrase
            font.family: bebasFont.name ? bebasFont.name : "Bebas Neue"
            font.pixelSize: 17
            font.bold: true
            font.letterSpacing: 2.4
        }

        readonly property real chunkWidth: measurer.implicitWidth > 0 ? measurer.implicitWidth : 350

        Row {
            id: marqueeTrack
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            NumberAnimation on x {
                from: -marqueeStrip.chunkWidth
                to: 0
                duration: 8000
                loops: Animation.Infinite
                running: true
            }

            Repeater {
                model: 4
                Text {
                    text: marqueeStrip.phrase
                    font.family: bebasFont.name ? bebasFont.name : "Bebas Neue"
                    font.pixelSize: 17
                    font.bold: true
                    font.letterSpacing: 2.4
                    color: "#ffe600"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.95)
                }
            }
        }
    }
}
