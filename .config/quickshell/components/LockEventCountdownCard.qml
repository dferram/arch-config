import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../theme"

// ==============================================================================
// LOCK EVENT COUNTDOWN CARD — 310x330 Vintage Canal 600 CRT TV
// Sits directly next to LockDoomsdayCountdownCard in the lock screen control panel.
// Target: "NSQK presenta Mosca" (2027-02-27 at 20:00).
// ==============================================================================
Rectangle {
    id: root

    Theme { id: theme }

    property var reminders: []
    property color accent: "#f5d033"
    property bool active: false
    property bool fullscreen: false
    readonly property real ds: fullscreen ? Math.min(Math.max(1.0, width / 520), Math.max(1.0, height / 340)) : 1.0

    readonly property string digitFont: "Iosevka Nerd Font"
    readonly property string osdFont: "IosevkaTerm Nerd Font"
    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/nsqk-mosca.jpg")
    property string posterPath: defaultPosterPath

    implicitWidth: 310
    implicitHeight: 330

    // Vintage CRT TV Grey Plastic Cabinet Housing
    radius: root.fullscreen ? 0 : 16
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#454954" }
        GradientStop { position: 0.14; color: "#363a44" }
        GradientStop { position: 0.86; color: "#2c3039" }
        GradientStop { position: 1.0; color: "#22252d" }
    }
    border.width: root.fullscreen ? 0 : 1.2
    border.color: "#585d6b"
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
    property real glitchX: 0
    property real glitchOpacity: 1.0

    component CrtDigitColumn : Item {
        property string value: "00"
        property string label: "DÍAS"
        width: Math.round(46 * root.ds)
        height: Math.round(52 * root.ds)

        Column {
            anchors.centerIn: parent
            spacing: Math.round(2 * root.ds)

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: digitsMain.implicitWidth
                height: digitsMain.implicitHeight

                // Subtle CRT RGB chromatic phosphor ghost
                Text {
                    x: 1.1 * root.ds
                    y: 0
                    text: parent.parent.parent.value
                    font.family: root.digitFont
                    font.pixelSize: Math.round(30 * root.ds)
                    font.weight: Font.Bold
                    color: "#ff2d55"
                    opacity: 0.28
                }
                Text {
                    x: -1.1 * root.ds
                    y: 0
                    text: parent.parent.parent.value
                    font.family: root.digitFont
                    font.pixelSize: Math.round(30 * root.ds)
                    font.weight: Font.Bold
                    color: "#38bdf8"
                    opacity: 0.28
                }

                FallingDigits {
                    id: digitsMain
                    anchors.centerIn: parent
                    value: parent.parent.parent.value
                    fontFamily: root.digitFont
                    pixelSize: Math.round(30 * root.ds)
                    fontWeight: Font.Bold
                    fontItalic: false
                    textColor: "#f5d033"
                    textStyle: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.96)
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.label
                font.family: root.osdFont
                font.pixelSize: Math.round(9 * root.ds)
                font.weight: Font.Medium
                font.letterSpacing: 1.4 * root.ds
                color: "#cbd5e1"
            }
        }
    }

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

    // RF Static & Interference Flicker Driver
    Timer {
        interval: 130
        running: root.active && root.visible
        repeat: true
        onTriggered: {
            noiseCanvas.requestPaint();
            let roll = Math.random();
            if (roll > 0.90) {
                root.glitchX = (Math.random() - 0.5) * 3.0;
                root.glitchOpacity = 0.84;
            } else {
                root.glitchX = 0;
                root.glitchOpacity = 1.0;
            }
        }
    }

    onRemindersChanged: updateCountdown()
    Component.onCompleted: updateCountdown()

    // =========================================================================
    // RECESSED CRT BEZEL LIP + SCREEN CONTAINER
    // =========================================================================
    Rectangle {
        id: crtBezel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.fullscreen ? 22 : 10
        anchors.rightMargin: root.fullscreen ? 22 : 10
        anchors.topMargin: root.fullscreen ? 18 : 10
        anchors.bottomMargin: root.fullscreen ? 52 : 34
        radius: root.fullscreen ? 18 : 9
        color: "#050608"
        border.color: "#0b0c10"
        border.width: root.fullscreen ? 3 : 2

        Item {
            id: crtScreen
            anchors.fill: parent
            anchors.margins: root.fullscreen ? 5 : 3
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: crtScreen.width
                    height: crtScreen.height
                    radius: root.fullscreen ? 14 : 7
                }
            }

            // 1. Background Mosca Poster (aligned so the top yellow text sits right at the top edge)
            Image {
                width: parent.width
                height: Math.max(parent.height, parent.width * (858.0 / 600.0))
                anchors.horizontalCenter: parent.horizontalCenter
                y: -Math.round(height * 0.084)
                source: root.posterPath
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.fullscreen ? 1200 : 600
                smooth: true
                asynchronous: true
                opacity: 0.48
            }

            // 2. Canal 600 Cobalt-Blue CRT Broadcast Wash
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.16, 0.48, 0.58) }
                    GradientStop { position: 0.52; color: Qt.rgba(0.07, 0.22, 0.62, 0.52) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.10, 0.34, 0.72) }
                }
            }

            // 3. CRT Curved Glass Horizontal Vignette
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.42) }
                    GradientStop { position: 0.12; color: "transparent" }
                    GradientStop { position: 0.88; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.42) }
                }
            }

            // 4. Rolling VHS / CRT Tracking Interference Band
            Rectangle {
                width: parent.width
                height: root.fullscreen ? 58 : 30
                y: -height
                color: Qt.rgba(0.02, 0.08, 0.28, 0.36)

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1.5
                    color: Qt.rgba(147/255, 197/255, 253/255, 0.22)
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.rgba(0, 0, 0, 0.35)
                }

                NumberAnimation on y {
                    from: root.fullscreen ? -58 : -30
                    to: crtScreen.height + (root.fullscreen ? 58 : 30)
                    duration: 5600
                    loops: Animation.Infinite
                    running: root.active && root.visible
                }
            }

            // 5. Fine Horizontal CRT Scanlines
            Canvas {
                anchors.fill: parent
                z: 4
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "rgba(0, 0, 0, 0.26)";
                    let step = root.fullscreen ? 4 : 3;
                    let lineH = root.fullscreen ? 1.5 : 1;
                    for (let y = 0; y < height; y += step) {
                        ctx.fillRect(0, y, width, lineH);
                    }
                }
            }

            // 6. Live RF Static Snow + Horizontal Tear Streaks
            Canvas {
                id: noiseCanvas
                anchors.fill: parent
                z: 5
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    let count = root.fullscreen ? 90 : 36;
                    for (let i = 0; i < count; i++) {
                        let rx = Math.random() * width;
                        let ry = Math.random() * height;
                        let rw = 1 + Math.random() * (root.fullscreen ? 4.5 : 2.5);
                        let alpha = 0.06 + Math.random() * 0.14;
                        ctx.fillStyle = "rgba(219, 234, 254, " + alpha.toFixed(2) + ")";
                        ctx.fillRect(rx, ry, rw, root.fullscreen ? 1.5 : 1);
                    }

                    if (Math.random() > 0.45) {
                        let lineCount = Math.random() > 0.7 ? 2 : 1;
                        for (let j = 0; j < lineCount; j++) {
                            let ly = Math.random() * height;
                            let lx = Math.random() * (width * 0.4);
                            let lw = width * (0.35 + Math.random() * 0.65);
                            ctx.fillStyle = Math.random() > 0.5
                                ? "rgba(191, 219, 254, 0.18)"
                                : "rgba(0, 0, 0, 0.32)";
                            ctx.fillRect(lx, ly, lw, 1.5);
                        }
                    }
                }
            }

            // 7. Top-Left Official CANAL 600 Logo & Top-Right STANDBY OSD
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: root.fullscreen ? 24 : 10
                anchors.leftMargin: root.fullscreen ? 26 : 10
                anchors.rightMargin: root.fullscreen ? 28 : 12
                height: root.fullscreen ? 84 : 46
                z: 6

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: root.fullscreen ? 104 : 56
                    height: root.fullscreen ? 80 : 43
                    color: "#090a0d"
                    border.color: "#040507"
                    border.width: 1

                    Image {
                        anchors.fill: parent
                        anchors.margins: root.fullscreen ? 2 : 1
                        sourceSize: Qt.size(280, 216)
                        source: "file://" + Quickshell.shellPath("assets/canal-600.jpg")
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    spacing: root.fullscreen ? 4 : 2

                    Text {
                        anchors.right: parent.right
                        text: "STANDBY"
                        color: Qt.rgba(226/255, 232/255, 240/255, 0.85)
                        font.family: root.osdFont
                        font.pixelSize: root.fullscreen ? 18 : 10
                        font.weight: Font.Medium
                        font.letterSpacing: root.fullscreen ? 2.8 : 1.6
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.9)
                    }

                    Text {
                        anchors.right: parent.right
                        text: root.eventTimeLabel
                        color: Qt.rgba(203/255, 213/255, 225/255, 0.65)
                        font.family: root.osdFont
                        font.pixelSize: root.fullscreen ? 13 : 8
                        font.letterSpacing: root.fullscreen ? 1.6 : 1.0
                    }
                }
            }

            // 8. Center Canal 600 Countdown (DÍAS : HRS : MIN : SEG)
            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.fullscreen ? -12 : 2
                anchors.horizontalCenterOffset: root.glitchX
                opacity: root.glitchOpacity
                spacing: Math.round(4 * root.ds)
                z: 6

                CrtDigitColumn { value: root.pad2(root.days); label: "DÍAS" }

                Text {
                    text: ":"
                    font.family: root.digitFont
                    font.pixelSize: Math.round(24 * root.ds)
                    font.weight: Font.Bold
                    color: "#f5d033"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.96)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(7 * root.ds)
                }

                CrtDigitColumn { value: root.pad2(root.hours); label: "HRS" }

                Text {
                    text: ":"
                    font.family: root.digitFont
                    font.pixelSize: Math.round(24 * root.ds)
                    font.weight: Font.Bold
                    color: "#f5d033"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.96)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(7 * root.ds)
                }

                CrtDigitColumn { value: root.pad2(root.minutes); label: "MIN" }

                Text {
                    text: ":"
                    font.family: root.digitFont
                    font.pixelSize: Math.round(24 * root.ds)
                    font.weight: Font.Bold
                    color: "#f5d033"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.96)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(7 * root.ds)
                }

                CrtDigitColumn { value: root.pad2(root.seconds); label: "SEG" }
            }

            // 9. Bottom Broadcast Ticker Bar ("¿ESTÁS PONIENDO ATENCIÓN?")
            Rectangle {
                id: marqueeStrip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.fullscreen ? 28 : 12
                height: root.fullscreen ? 48 : 26
                color: Qt.rgba(0.02, 0.08, 0.24, 0.56)
                clip: true
                z: 6

                readonly property string phrase: "¿ESTÁS PONIENDO ATENCIÓN?               "

                Text {
                    id: measurer
                    visible: false
                    text: marqueeStrip.phrase
                    font.family: root.osdFont
                    font.pixelSize: root.fullscreen ? 22 : 11
                    font.weight: Font.Medium
                    font.letterSpacing: root.fullscreen ? 3.0 : 1.8
                }

                readonly property real chunkWidth: measurer.implicitWidth > 0 ? measurer.implicitWidth : 520

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    NumberAnimation on x {
                        from: -marqueeStrip.chunkWidth
                        to: 0
                        duration: 12000
                        loops: Animation.Infinite
                        running: root.active && root.visible
                    }

                    Repeater {
                        model: root.fullscreen ? 5 : 3
                        Text {
                            text: marqueeStrip.phrase
                            font.family: root.osdFont
                            font.pixelSize: root.fullscreen ? 22 : 11
                            font.weight: Font.Medium
                            font.letterSpacing: root.fullscreen ? 3.0 : 1.8
                            color: "#f5d033"
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.95)
                        }
                    }
                }
            }

            // Subtle curved CRT glass reflection
            Rectangle {
                anchors.fill: parent
                z: 7
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                    GradientStop { position: 0.25; color: "transparent" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // =========================================================================
    // VINTAGE TV BOTTOM CHIN (IR Window + Tactile Control Buttons + Standby LED)
    // =========================================================================
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.fullscreen ? 52 : 34
        z: 3

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#181a20"
        }
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#4a4f5c"
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            spacing: 10

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: 4
                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: "#4a4f5c"
                        border.color: "#1a1c22"
                        border.width: 0.6
                    }
                }
            }

            Rectangle {
                width: 28
                height: 13
                radius: 2
                color: "#090a0e"
                border.color: "#525766"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: 4
                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: "#4a4f5c"
                        border.color: "#1a1c22"
                        border.width: 0.6
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            spacing: 8

            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: "#ef4444"
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.active && root.visible
                    NumberAnimation { from: 0.45; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        width: 3
                        height: 2
                        radius: 0.5
                        color: "#090a0e"
                    }
                }
            }
        }
    }
}
