import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../theme"

// ==============================================================================
// LOCK FRIENDLY NEIGHBORHOOD SPIDER-MAN COUNTDOWN CARD — 280x330
// Target: "Your Friendly Neighborhood Spider-Man Season 2" (2027-01-13 at 00:00)
// ==============================================================================
Item {
    id: root
    Theme { id: theme }

    property var reminders: []
    property color accent: "#3b82f6"
    property bool active: false
    property bool fullscreen: false
    readonly property real k: fullscreen ? Math.min(Math.max(1.0, width / 500), Math.max(1.0, height / 300)) : 1.0

    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/friendly-spidey-bg.jpg")
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

    function pad2(n) {
        return (n < 10 ? "0" : "") + Math.max(0, n);
    }

    function resolveTargetDate() {
        let now = new Date();
        if (root.reminders && Array.isArray(root.reminders)) {
            for (let i = 0; i < root.reminders.length; i++) {
                let r = root.reminders[i];
                let title = (r.title || "").toLowerCase();
                if (title.indexOf("friendly") !== -1 || title.indexOf("neighborhood") !== -1 || r.date === "2027-01-13") {
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
        return new Date(2027, 0, 13, 0, 0, 0);
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
            glowRadius: 22
            spread: 0.04
            color: Qt.rgba(239/255, 68/255, 68/255, 0.20)
            cornerRadius: 24
        }

        RectangularGlow {
            width: parent.width * 0.65
            height: parent.height * 0.65
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            glowRadius: 22
            spread: 0.04
            color: Qt.rgba(37/255, 99/255, 235/255, 0.22)
            cornerRadius: 24
        }
    }

    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.fullscreen ? 0 : 16
        color: "#090c16"
        border.width: root.fullscreen ? 0 : 2.5
        border.color: "#05070d"
        clip: true
        z: 1

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
                anchors.topMargin: 8
                anchors.bottomMargin: -8
                source: root.posterPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: root.fullscreen ? 0.45 : 0.40

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0.03, 0.04, 0.09, 0.62) }
                        GradientStop { position: 0.50; color: Qt.rgba(0.02, 0.03, 0.07, 0.78) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.02, 0.05, 0.92) }
                    }
                }
            }
        }

        Row {
            x: root.fullscreen ? 36 : 16
            y: root.fullscreen ? 28 : 14
            width: parent.width - (root.fullscreen ? 120 : 90)
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
                text: "DISNEY+ · JAN 13, 2027"
                color: Qt.rgba(255, 255, 255, 0.78)
                font.family: theme.fontFamily
                font.pixelSize: root.fullscreen ? 14 : 9
                font.weight: Font.Bold
                font.letterSpacing: 1.1
            }
        }

        // Full-widget Retro Comic-Book Ben-Day Halftone Pattern + Classic Panel Inset Frame
        Canvas {
            anchors.fill: parent
            z: 2
            opacity: 0.34
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                let step = 9;
                for (let row = 0, y = 5; y < height - 5; y += step, row++) {
                    let xOff = (row % 2 === 0) ? 5 : 9;
                    for (let x = xOff; x < width - 5; x += step) {
                        let u = x / width;
                        let v = y / height;
                        let distCenter = Math.hypot((u - 0.5) * 1.1, (v - 0.5) * 1.1);
                        let r = 0.70 + Math.min(1.0, distCenter) * 1.10;
                        if (u < 0.48) {
                            ctx.fillStyle = "rgba(239, 68, 68, " + (0.24 + (0.48 - u) * 0.55).toFixed(2) + ")";
                        } else {
                            ctx.fillStyle = "rgba(59, 130, 246, " + (0.24 + (u - 0.48) * 0.55).toFixed(2) + ")";
                        }
                        ctx.beginPath();
                        ctx.arc(x, y, r, 0, Math.PI * 2);
                        ctx.fill();
                    }
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
            border.color: Qt.rgba(254/255, 243/255, 199/255, 0.28)
            z: 2
        }

        // Top-right Aesthetic Comic Spiderweb (no spider)
        Canvas {
            anchors.top: parent.top
            anchors.right: parent.right
            width: Math.round(118 * root.k)
            height: Math.round(112 * root.k)
            z: 4
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                let spokes = [
                    { a: Math.PI * 0.50, len: width * 0.84 },
                    { a: Math.PI * 0.59, len: width * 0.92 },
                    { a: Math.PI * 0.69, len: width * 0.96 },
                    { a: Math.PI * 0.79, len: width * 0.90 },
                    { a: Math.PI * 0.90, len: width * 0.84 },
                    { a: Math.PI * 1.00, len: width * 0.78 }
                ];

                function drawWebPass(strokeStyle, lineWidth) {
                    ctx.strokeStyle = strokeStyle;
                    ctx.lineWidth = lineWidth;
                    ctx.lineCap = "round";

                    for (let i = 0; i < spokes.length; i++) {
                        let sp = spokes[i];
                        ctx.beginPath();
                        ctx.moveTo(width, 0);
                        ctx.lineTo(width + Math.cos(sp.a) * sp.len, Math.sin(sp.a) * sp.len);
                        ctx.stroke();
                    }

                    let rings = [0.15, 0.28, 0.43, 0.60, 0.78];
                    for (let rIdx = 0; rIdx < rings.length; rIdx++) {
                        let baseR = width * rings[rIdx];
                        for (let s = 0; s < spokes.length - 1; s++) {
                            let a1 = spokes[s].a;
                            let a2 = spokes[s + 1].a;
                            let r1 = Math.min(baseR, spokes[s].len * 0.92);
                            let r2 = Math.min(baseR, spokes[s + 1].len * 0.92);
                            let x1 = width + Math.cos(a1) * r1;
                            let y1 = Math.sin(a1) * r1;
                            let x2 = width + Math.cos(a2) * r2;
                            let y2 = Math.sin(a2) * r2;
                            let am = (a1 + a2) * 0.5;
                            let sag = ((r1 + r2) * 0.5) * 0.83;
                            ctx.beginPath();
                            ctx.moveTo(x1, y1);
                            ctx.quadraticCurveTo(width + Math.cos(am) * sag, Math.sin(am) * sag, x2, y2);
                            ctx.stroke();
                        }
                    }
                }

                drawWebPass("rgba(4, 6, 12, 0.92)", 2.6);
                drawWebPass("rgba(248, 250, 252, 0.88)", 1.1);
            }
        }

        Column {
            visible: !root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.fullscreen ? 0 : 14
            spacing: Math.round(16 * root.k)
            z: 3
            width: parent.width - 24

            // Comic-book yellow title badge
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, comicLockTitle.implicitWidth + Math.round(20 * root.k))
                height: Math.round(22 * root.k)
                radius: 4
                color: "#facc15"
                border.color: "#05070d"
                border.width: 2

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 3
                    anchors.topMargin: 3
                    anchors.rightMargin: -3
                    anchors.bottomMargin: -3
                    radius: 4
                    color: "#05070d"
                    z: -1
                }

                Text {
                    id: comicLockTitle
                    anchors.centerIn: parent
                    text: "FRIENDLY SPIDER-MAN · S2"
                    color: "#05070d"
                    font.family: theme.fontFamily
                    font.pixelSize: Math.round(10 * root.k)
                    font.weight: Font.Black
                    font.italic: true
                    font.letterSpacing: 1.3 * root.k
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(3 * root.k)

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lMon.implicitWidth; height: lMon.implicitHeight
                        FallingDigits { x: 2; y: 2; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: lMon; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MONTHS"; font.family: theme.fontFamily; font.pixelSize: Math.round(8 * root.k); font.weight: Font.Black; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lDay.implicitWidth; height: lDay.implicitHeight
                        FallingDigits { x: 2; y: 2; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: lDay; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "DAYS"; font.family: theme.fontFamily; font.pixelSize: Math.round(8 * root.k); font.weight: Font.Black; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lHr.implicitWidth; height: lHr.implicitHeight
                        FallingDigits { x: 2; y: 2; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: lHr; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "HOURS"; font.family: theme.fontFamily; font.pixelSize: Math.round(8 * root.k); font.weight: Font.Black; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lMin.implicitWidth; height: lMin.implicitHeight
                        FallingDigits { x: 2; y: 2; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: lMin; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MIN"; font.family: theme.fontFamily; font.pixelSize: Math.round(8 * root.k); font.weight: Font.Black; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: Math.round(16 * root.k); font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -Math.round(7 * root.k) }

                Column {
                    width: Math.round(40 * root.k)
                    spacing: Math.round(3 * root.k)
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: lSec.implicitWidth; height: lSec.implicitHeight
                        FallingDigits { x: 2; y: 2; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: lSec; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: Math.round(22 * root.k); fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "SEC"; font.family: theme.fontFamily; font.pixelSize: Math.round(8 * root.k); font.weight: Font.Black; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
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
            text: "SEASON 2\nSTREAMING NOW"
            color: "#ffffff"
            font.family: theme.fontFamily
            font.pixelSize: Math.round(21 * root.k)
            font.weight: Font.Black
            font.letterSpacing: 2.6 * root.k
        }
    }
}
