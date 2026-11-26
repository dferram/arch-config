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

    // Vintage CRT TV Molded Plastic Cabinet Housing (3D chamfered bevel + dark recessed frame)
    radius: root.fullscreen ? 0 : 13
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#4e5360" }
        GradientStop { position: 0.06; color: "#3d424d" }
        GradientStop { position: 0.50; color: "#2f333d" }
        GradientStop { position: 0.94; color: "#252831" }
        GradientStop { position: 1.0; color: "#191c23" }
    }
    border.width: root.fullscreen ? 0 : 1
    border.color: "#616777"
    clip: true

    // Inner molded chassis highlight & seam
    Rectangle {
        visible: !root.fullscreen
        anchors.fill: parent
        anchors.margins: 1.5
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.09)
        border.width: 1
        z: 1
    }

    // Target countdown values
    property string eventTimeLabel: "8:00 PM"
    property string eventLocation: "Auditorio Josefa · Live"

    property int months: 0
    property int days: 0
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool eventPassed: false
    property bool eventLive: false
    property bool eventEnded: false
    property bool lockPreviewState: false
    property bool glitchActive: false
    property real glitchX: 0
    property real glitchY: 0
    property real glitchLabelX: 0
    property real glitchSplit: 1.1
    property real glitchTearY: 0.5
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
                transform: Translate {
                    x: root.glitchActive ? root.glitchX * root.ds : 0
                    y: root.glitchActive ? root.glitchY * root.ds : 0
                }

                // Subtle CRT RGB chromatic phosphor ghost (widens briefly during glitch)
                Text {
                    x: root.glitchSplit * root.ds
                    y: root.glitchActive ? -0.6 * root.ds : 0
                    text: parent.parent.parent.value
                    font.family: root.digitFont
                    font.pixelSize: Math.round(30 * root.ds)
                    font.weight: Font.Bold
                    color: "#ff2d55"
                    opacity: root.glitchActive ? 0.58 : 0.28
                }
                Text {
                    x: -root.glitchSplit * root.ds
                    y: root.glitchActive ? 0.6 * root.ds : 0
                    text: parent.parent.parent.value
                    font.family: root.digitFont
                    font.pixelSize: Math.round(30 * root.ds)
                    font.weight: Font.Bold
                    color: "#38bdf8"
                    opacity: root.glitchActive ? 0.58 : 0.28
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

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: labelMain.implicitWidth
                height: labelMain.implicitHeight
                transform: Translate { x: root.glitchActive ? root.glitchLabelX * root.ds : 0 }

                Text {
                    visible: root.glitchActive
                    x: 1.8 * root.ds
                    text: parent.parent.parent.label
                    font.family: root.osdFont
                    font.pixelSize: Math.round(9 * root.ds)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.4 * root.ds
                    color: "#ff2d55"
                    opacity: 0.55
                }
                Text {
                    visible: root.glitchActive
                    x: -1.8 * root.ds
                    text: parent.parent.parent.label
                    font.family: root.osdFont
                    font.pixelSize: Math.round(9 * root.ds)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.4 * root.ds
                    color: "#38bdf8"
                    opacity: 0.55
                }
                Text {
                    id: labelMain
                    text: parent.parent.parent.label
                    font.family: root.osdFont
                    font.pixelSize: Math.round(9 * root.ds)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.4 * root.ds
                    color: "#cbd5e1"
                }
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
        if (root.lockPreviewState) return;
        let target = resolveTargetDate();
        let now = new Date();

        if (target.getTime() <= now.getTime()) {
            let elapsedMs = now.getTime() - target.getTime();
            root.months = 0;
            root.days = 0;
            root.hours = 0;
            root.minutes = 0;
            root.seconds = 0;
            root.eventPassed = true;
            root.eventLive = elapsedMs < (6 * 3600000);
            root.eventEnded = !root.eventLive;
            return;
        }

        root.eventPassed = false;
        root.eventLive = false;
        root.eventEnded = false;

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

    // RF Static & Interference Flicker Driver (matches DesktopNsqkWidget)
    Timer {
        id: glitchResetTimer
        interval: 135
        repeat: false
        onTriggered: {
            root.glitchActive = false;
            root.glitchX = 0;
            root.glitchY = 0;
            root.glitchLabelX = 0;
            root.glitchSplit = 1.1;
            root.glitchOpacity = 1.0;
        }
    }

    Timer {
        interval: root.eventEnded ? 140 : 260
        running: (root.active && root.visible) || root.eventEnded
        repeat: true
        onTriggered: {
            noiseCanvas.requestPaint();
            if (!root.glitchActive && Math.random() > (root.eventEnded ? 0.80 : 0.89)) {
                root.glitchActive = true;
                root.glitchX = (Math.random() > 0.5 ? 1 : -1) * (1.8 + Math.random() * 2.2);
                root.glitchY = (Math.random() - 0.5) * 2.0;
                root.glitchLabelX = -root.glitchX * 0.85;
                root.glitchSplit = 3.0 + Math.random() * 1.8;
                root.glitchTearY = 0.2 + Math.random() * 0.65;
                root.glitchOpacity = 0.82;
                glitchResetTimer.restart();
            }
        }
    }

    onRemindersChanged: updateCountdown()
    Component.onCompleted: updateCountdown()

    // =========================================================================
    // DEEP RECESSED 2-STEP CRT BEZEL + GLASS TUBE HOUSING
    // =========================================================================
    Rectangle {
        id: crtBezel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.fullscreen ? 22 : 10
        anchors.rightMargin: root.fullscreen ? 22 : 10
        anchors.topMargin: root.fullscreen ? 18 : 9
        anchors.bottomMargin: root.fullscreen ? 52 : 30
        radius: root.fullscreen ? 18 : 9
        color: "#0b0d11"
        border.color: "#151820"
        border.width: root.fullscreen ? 2.5 : 1.5
        z: 2

        // Bezel inner bottom-right highlight catching ambient light
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.fullscreen ? 16 : 8
            color: "#050608"
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
        }

        Item {
            id: crtScreen
            anchors.fill: parent
            anchors.margins: root.fullscreen ? 5 : 4
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
                opacity: 0.46
            }

            // 2. Canal 600 Cobalt-Blue CRT Broadcast Wash
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.16, 0.48, 0.60) }
                    GradientStop { position: 0.52; color: Qt.rgba(0.07, 0.22, 0.62, 0.54) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.10, 0.34, 0.74) }
                }
            }

            // 3. Top-Left CANAL 600 Logo & Top-Right CH 600 • STANDBY OSD (UNDER CRT interference)
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: root.fullscreen ? 24 : 9
                anchors.leftMargin: root.fullscreen ? 26 : 10
                anchors.rightMargin: root.fullscreen ? 28 : 12
                height: root.fullscreen ? 84 : 44
                z: 4

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: root.fullscreen ? 104 : 56
                    height: root.fullscreen ? 80 : 43
                    radius: 3
                    color: "#090a0d"
                    border.color: Qt.rgba(0, 0, 0, 0.75)
                    border.width: 1
                    opacity: 0.90
                    clip: true

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
                        text: root.eventLive ? "CH 600 • ON AIR" : (root.eventEnded ? "CH 600 • OFF AIR" : "CH 600 • STANDBY")
                        color: root.eventLive ? "#ef4444" : Qt.rgba(226/255, 232/255, 240/255, 0.84)
                        font.family: root.osdFont
                        font.pixelSize: root.fullscreen ? 18 : 10
                        font.weight: Font.Medium
                        font.letterSpacing: root.fullscreen ? 2.6 : 1.4
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

            // 4. Center Canal 600 Countdown (DÍAS : HRS : MIN : SEG)
            Item {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.fullscreen ? -10 : 2
                width: root.eventPassed ? broadcastStatusItem.implicitWidth : countdownRow.implicitWidth
                height: root.eventPassed ? broadcastStatusItem.implicitHeight : countdownRow.implicitHeight
                z: 4

                Item {
                    id: broadcastStatusItem
                    visible: root.eventPassed
                    anchors.centerIn: parent
                    implicitWidth: statusMain.implicitWidth
                    implicitHeight: statusMain.implicitHeight
                    opacity: root.glitchOpacity
                    transform: Translate {
                        x: root.glitchActive ? root.glitchX * root.ds : 0
                        y: root.glitchActive ? root.glitchY * root.ds : 0
                    }

                    readonly property string statusText: root.eventLive ? "TRANSMISIÓN\nEN CURSO" : "TRANSMISIÓN\nFINALIZADA"

                    Text {
                        x: root.glitchSplit * root.ds
                        y: root.glitchActive ? -0.6 * root.ds : 0
                        horizontalAlignment: Text.AlignHCenter
                        text: broadcastStatusItem.statusText
                        font.family: root.osdFont
                        font.pixelSize: Math.round(20 * root.ds)
                        font.weight: Font.Bold
                        font.letterSpacing: 2.0 * root.ds
                        color: "#ff2d55"
                        opacity: root.glitchActive ? 0.58 : 0.28
                    }
                    Text {
                        x: -root.glitchSplit * root.ds
                        y: root.glitchActive ? 0.6 * root.ds : 0
                        horizontalAlignment: Text.AlignHCenter
                        text: broadcastStatusItem.statusText
                        font.family: root.osdFont
                        font.pixelSize: Math.round(20 * root.ds)
                        font.weight: Font.Bold
                        font.letterSpacing: 2.0 * root.ds
                        color: "#38bdf8"
                        opacity: root.glitchActive ? 0.58 : 0.28
                    }
                    Text {
                        id: statusMain
                        horizontalAlignment: Text.AlignHCenter
                        text: broadcastStatusItem.statusText
                        font.family: root.osdFont
                        font.pixelSize: Math.round(20 * root.ds)
                        font.weight: Font.Bold
                        font.letterSpacing: 2.0 * root.ds
                        color: root.eventLive ? "#f5d033" : "#cbd5e1"
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.96)
                    }
                }

                Row {
                    id: countdownRow
                    visible: !root.eventPassed
                    anchors.centerIn: parent
                    opacity: root.glitchOpacity
                    spacing: Math.round(4 * root.ds)

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

                // Brief horizontal sync-tear streak across countdown during glitch
                Rectangle {
                    visible: root.glitchActive
                    x: -16 * root.ds
                    width: parent.width + 32 * root.ds
                    y: Math.round(parent.height * root.glitchTearY)
                    height: Math.max(1.5, Math.round(2 * root.ds))
                    color: Qt.rgba(191/255, 219/255, 254/255, 0.45)
                }
            }

            // 5. Bottom Broadcast Ticker Bar ("¿ESTÁS PONIENDO ATENCIÓN?")
            Rectangle {
                id: marqueeStrip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.fullscreen ? 28 : 10
                height: root.fullscreen ? 48 : 24
                color: Qt.rgba(0.02, 0.07, 0.22, 0.46)
                clip: true
                z: 4

                readonly property string phrase: "¿ESTÁS PONIENDO ATENCIÓN?               "

                Text {
                    id: measurer
                    visible: false
                    text: marqueeStrip.phrase
                    font.family: root.osdFont
                    font.pixelSize: root.fullscreen ? 22 : 10
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
                        duration: 11000
                        loops: Animation.Infinite
                        running: root.active && root.visible
                    }

                    Repeater {
                        model: root.fullscreen ? 5 : 4
                        Text {
                            text: marqueeStrip.phrase
                            font.family: root.osdFont
                            font.pixelSize: root.fullscreen ? 22 : 10
                            font.weight: Font.Medium
                            font.letterSpacing: root.fullscreen ? 3.0 : 1.8
                            color: "#f5d033"
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.95)
                        }
                    }
                }
            }

            // 6. Rolling VHS / CRT Tracking Interference Band (ABOVE Canal 600 & screen content)
            Rectangle {
                width: parent.width
                height: root.fullscreen ? 58 : 30
                y: -height
                z: 6
                color: Qt.rgba(0.03, 0.09, 0.28, 0.34)

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1.5
                    color: Qt.rgba(147/255, 197/255, 253/255, 0.28)
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1.5
                    color: Qt.rgba(0, 0, 0, 0.42)
                }

                NumberAnimation on y {
                    from: root.fullscreen ? -58 : -30
                    to: crtScreen.height + (root.fullscreen ? 58 : 30)
                    duration: 5200
                    loops: Animation.Infinite
                    running: root.active && root.visible
                }
            }

            // 7. Fine Horizontal CRT Scanlines (over ENTIRE tube including Canal 600)
            Canvas {
                anchors.fill: parent
                z: 7
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "rgba(0, 0, 0, 0.28)";
                    let step = root.fullscreen ? 4 : 3;
                    let lineH = root.fullscreen ? 1.5 : 1;
                    for (let y = 0; y < height; y += step) {
                        ctx.fillRect(0, y, width, lineH);
                    }
                }
            }

            // 8. Live RF Static Snow + Horizontal Tear Streaks (over ENTIRE tube including Canal 600)
            Canvas {
                id: noiseCanvas
                anchors.fill: parent
                z: 8
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    let baseCount = root.fullscreen ? 95 : 55;
                    let count = root.eventEnded ? (root.fullscreen ? 260 : 155) : baseCount;
                    for (let i = 0; i < count; i++) {
                        let rx = Math.random() * width;
                        let ry = Math.random() * height;
                        let rw = 1 + Math.random() * (root.fullscreen ? 4.5 : 2.5);
                        let alpha = root.eventEnded ? (0.08 + Math.random() * 0.18) : (0.06 + Math.random() * 0.16);
                        ctx.fillStyle = (root.eventEnded && Math.random() > 0.75)
                            ? "rgba(0, 0, 0, " + (alpha + 0.08).toFixed(2) + ")"
                            : "rgba(219, 234, 254, " + alpha.toFixed(2) + ")";
                        ctx.fillRect(rx, ry, rw, root.fullscreen ? 1.5 : 1);
                    }

                    if (root.eventEnded || Math.random() > 0.35) {
                        let lineCount = root.eventEnded ? (Math.random() > 0.45 ? 2 : 1) : (Math.random() > 0.6 ? 2 : 1);
                        for (let j = 0; j < lineCount; j++) {
                            let ly = Math.random() * height;
                            let lx = Math.random() * (width * 0.30);
                            let lw = width * (0.38 + Math.random() * 0.62);
                            ctx.fillStyle = Math.random() > 0.45
                                ? (root.eventEnded ? "rgba(219, 234, 254, 0.24)" : "rgba(191, 219, 254, 0.22)")
                                : (root.eventEnded ? "rgba(0, 0, 0, 0.38)" : "rgba(0, 0, 0, 0.36)");
                            ctx.fillRect(lx, ly, lw, 1.2);
                        }
                    }
                }
            }

            // 9. Realistic 4-Edge CRT Tube Curvature Vignette + Glass Specular Glare
            Rectangle {
                anchors.fill: parent
                z: 9
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.48) }
                    GradientStop { position: 0.08; color: "transparent" }
                    GradientStop { position: 0.92; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.48) }
                }
            }
            Rectangle {
                anchors.fill: parent
                z: 9
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.40) }
                    GradientStop { position: 0.09; color: Qt.rgba(1, 1, 1, 0.05) }
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 0.90; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.50) }
                }
            }
        }
    }

    // =========================================================================
    // VINTAGE TV BOTTOM CHIN (Tactile 3D Buttons, Clean IR Window, Speaker Grilles)
    // =========================================================================
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.fullscreen ? 52 : 30
        z: 3

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#14161c"
        }
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // Left Recessed Speaker Vent Slits
        Column {
            anchors.left: parent.left
            anchors.leftMargin: root.fullscreen ? 22 : 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            spacing: 2.5
            Repeater {
                model: 2
                Row {
                    spacing: 2.5
                    Repeater {
                        model: 4
                        Rectangle {
                            width: 3.5
                            height: 2
                            radius: 0.5
                            color: "#0b0d12"
                        }
                    }
                }
            }
        }

        // Centered 3D Tactile Buttons + Smoked Acrylic IR Receiver Window (no red dot)
        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            spacing: root.fullscreen ? 12 : 7

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: 4
                    Rectangle {
                        width: 4.5
                        height: 4.5
                        radius: 2.25
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#646b7d" }
                            GradientStop { position: 1.0; color: "#2d313b" }
                        }
                        border.color: "#111318"
                        border.width: 0.8
                    }
                }
            }

            Rectangle {
                width: root.fullscreen ? 36 : 26
                height: root.fullscreen ? 15 : 12
                radius: 2
                color: "#06070a"
                border.color: "#4d5362"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: 4
                    Rectangle {
                        width: 4.5
                        height: 4.5
                        radius: 2.25
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#646b7d" }
                            GradientStop { position: 1.0; color: "#2d313b" }
                        }
                        border.color: "#111318"
                        border.width: 0.8
                    }
                }
            }
        }

        // Standby LED with subtle glow + Right Speaker Vent Slits
        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.fullscreen ? 22 : 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            spacing: 7

            Item {
                width: 8
                height: 8
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Qt.rgba(239/255, 68/255, 68/255, 0.25)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: "#ef4444"

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.active && root.visible
                        NumberAnimation { from: 0.45; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.0; to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2.5
                Repeater {
                    model: 2
                    Row {
                        spacing: 2.5
                        Repeater {
                            model: 4
                            Rectangle {
                                width: 3.5
                                height: 2
                                radius: 0.5
                                color: "#0b0d12"
                            }
                        }
                    }
                }
            }
        }
    }
}
