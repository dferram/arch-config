import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 448
    implicitHeight: 207

    // Vintage CRT TV Molded Plastic Cabinet Housing (3D chamfered bevel + dark recessed frame)
    radius: 13
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#4e5360" }
        GradientStop { position: 0.06; color: "#3d424d" }
        GradientStop { position: 0.50; color: "#2f333d" }
        GradientStop { position: 0.94; color: "#252831" }
        GradientStop { position: 1.0; color: "#191c23" }
    }
    border.color: "#616777"
    border.width: 1
    clip: true

    // Inner molded chassis highlight & seam
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1.5
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.09)
        border.width: 1
        z: 1
    }

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

    property color accent: "#f5d033" // Canal 600 CRT Gold
    readonly property string digitFont: "Iosevka Nerd Font"
    readonly property string osdFont: "IosevkaTerm Nerd Font"
    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/nsqk-mosca.jpg")
    property string posterPath: defaultPosterPath

    property int months: 0
    property int days: 0
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool eventPassed: false
    property bool glitchActive: false
    property real glitchX: 0
    property real glitchY: 0
    property real glitchLabelX: 0
    property real glitchSplit: 1.2
    property real glitchTearY: 0.5
    property real glitchOpacity: 1.0

    property var reminders: []

    // Segment helper component matching nsqk.com Canal 600 tall condensed CRT numerals
    component CountdownPill : Item {
        property string value: "00"
        property string label: "DÍAS"
        width: root.width > 400 ? 52 : 42
        height: root.width > 400 ? 54 : 46

        Column {
            anchors.centerIn: parent
            spacing: 1

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: digitsMain.implicitWidth
                height: digitsMain.implicitHeight
                transform: Translate {
                    x: root.glitchActive ? root.glitchX : 0
                    y: root.glitchActive ? root.glitchY : 0
                }

                // Subtle CRT RGB chromatic phosphor ghost (widens briefly during glitch)
                Text {
                    x: root.glitchSplit
                    y: root.glitchActive ? -0.6 : 0
                    text: parent.parent.parent.value
                    font.family: root.digitFont
                    font.pixelSize: root.width > 400 ? 36 : 30
                    font.weight: Font.Bold
                    color: "#ff2d55"
                    opacity: root.glitchActive ? 0.58 : 0.28
                }
                Text {
                    x: -root.glitchSplit
                    y: root.glitchActive ? 0.6 : 0
                    text: parent.parent.parent.value
                    font.family: root.digitFont
                    font.pixelSize: root.width > 400 ? 36 : 30
                    font.weight: Font.Bold
                    color: "#38bdf8"
                    opacity: root.glitchActive ? 0.58 : 0.28
                }

                FallingDigits {
                    id: digitsMain
                    anchors.centerIn: parent
                    value: parent.parent.parent.value
                    fontFamily: root.digitFont
                    pixelSize: root.width > 400 ? 36 : 30
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
                transform: Translate { x: root.glitchActive ? root.glitchLabelX : 0 }

                Text {
                    visible: root.glitchActive
                    x: 1.8
                    text: parent.parent.parent.label
                    font.family: root.osdFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 1.5
                    color: "#ff2d55"
                    opacity: 0.55
                }
                Text {
                    visible: root.glitchActive
                    x: -1.8
                    text: parent.parent.parent.label
                    font.family: root.osdFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 1.5
                    color: "#38bdf8"
                    opacity: 0.55
                }
                Text {
                    id: labelMain
                    text: parent.parent.parent.label
                    font.family: root.osdFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 1.5
                    color: "#cbd5e1"
                }
            }
        }
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

    // Read reminders from backend hypr-reminders
    Process {
        id: readRemindersProc
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

    // RF Static & Interference Flicker Driver (throttled to reduce Canvas CPU usage)
    Timer {
        id: glitchResetTimer
        interval: 135
        repeat: false
        onTriggered: {
            root.glitchActive = false;
            root.glitchX = 0;
            root.glitchY = 0;
            root.glitchLabelX = 0;
            root.glitchSplit = 1.2;
            root.glitchOpacity = 1.0;
        }
    }

    Timer {
        interval: 320
        running: root.isLive
        repeat: true
        onTriggered: {
            noiseCanvas.requestPaint();
            if (!root.glitchActive && Math.random() > 0.89) {
                root.glitchActive = true;
                root.glitchX = (Math.random() > 0.5 ? 1 : -1) * (1.8 + Math.random() * 2.4);
                root.glitchY = (Math.random() - 0.5) * 2.0;
                root.glitchLabelX = -root.glitchX * 0.85;
                root.glitchSplit = 3.2 + Math.random() * 1.8;
                root.glitchTearY = 0.2 + Math.random() * 0.65;
                root.glitchOpacity = 0.82;
                glitchResetTimer.restart();
            }
        }
    }

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
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 9
        anchors.bottomMargin: 28
        radius: 9
        color: "#0b0d11"
        border.color: "#151820"
        border.width: 1.5
        z: 2

        // Bezel inner bottom-right highlight catching ambient light
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 8
            color: "#050608"
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
        }

        // Inner CRT Glass Surface (Clipped with OpacityMask)
        Item {
            id: crtScreen
            anchors.fill: parent
            anchors.margins: 4
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: crtScreen.width
                    height: crtScreen.height
                    radius: 7
                }
            }

            // 1. Background Mosca Poster (aligned so the top yellow text sits right at the top edge)
            Image {
                id: posterImg
                width: parent.width
                height: parent.width * (858.0 / 600.0)
                anchors.horizontalCenter: parent.horizontalCenter
                y: -Math.round(height * 0.084)
                source: root.posterPath
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 600
                sourceSize.height: 858
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

            // 3. Top-Left CANAL 600 + Spotted Dog Badge & Top-Right STANDBY OSD (UNDER CRT interference)
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                height: 40
                z: 4

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: 56
                    height: 43
                    radius: 3
                    color: "#090a0d"
                    border.color: Qt.rgba(0, 0, 0, 0.75)
                    border.width: 1
                    opacity: 0.90
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        sourceSize: Qt.size(160, 124)
                        source: "file://" + Quickshell.shellPath("assets/canal-600.jpg")
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    text: "CH 600 • STANDBY"
                    color: Qt.rgba(226/255, 232/255, 240/255, 0.84)
                    font.family: root.osdFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 1.4
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.9)
                }
            }

            // 4. Center Canal 600 Countdown (affected by CRT glitch + scanlines)
            Item {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 2
                width: countdownContent.implicitWidth
                height: countdownContent.implicitHeight
                z: 4

                Row {
                    id: countdownContent
                    anchors.centerIn: parent
                    opacity: root.glitchOpacity
                    spacing: 8

                    CountdownPill { value: root.pad2(root.days); label: "DÍAS" }

                    Text {
                        text: ":"
                        font.family: root.digitFont
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: "#f5d033"
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.96)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -7
                    }

                    CountdownPill { value: root.pad2(root.hours); label: "HRS" }

                    Text {
                        text: ":"
                        font.family: root.digitFont
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: "#f5d033"
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.96)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -7
                    }

                    CountdownPill { value: root.pad2(root.minutes); label: "MIN" }

                    Text {
                        text: ":"
                        font.family: root.digitFont
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        color: "#f5d033"
                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.96)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -7
                    }

                    CountdownPill { value: root.pad2(root.seconds); label: "SEG" }
                }

                // Brief horizontal sync-tear streak across countdown during glitch
                Rectangle {
                    visible: root.glitchActive
                    x: -16
                    width: parent.width + 32
                    y: Math.round(parent.height * root.glitchTearY)
                    height: 2
                    color: Qt.rgba(191/255, 219/255, 254/255, 0.45)
                }
            }

            // 5. Bottom Broadcast Ticker Bar ("¿ESTÁS PONIENDO ATENCIÓN?")
            Rectangle {
                id: tickerBand
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                height: 22
                color: Qt.rgba(0.02, 0.07, 0.22, 0.46)
                clip: true
                z: 4

                readonly property string phrase: "¿ESTÁS PONIENDO ATENCIÓN?               "

                Text {
                    id: tickerMeasurer
                    visible: false
                    text: tickerBand.phrase
                    font.family: root.osdFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                }

                readonly property real chunkWidth: tickerMeasurer.implicitWidth > 0 ? tickerMeasurer.implicitWidth : 340

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    NumberAnimation on x {
                        from: -tickerBand.chunkWidth
                        to: 0
                        duration: 9000
                        loops: Animation.Infinite
                        running: root.isLive
                    }

                    Repeater {
                        model: 4
                        Text {
                            text: tickerBand.phrase
                            font.family: root.osdFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.letterSpacing: 1.8
                            color: "#f5d033"
                            style: Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, 0.95)
                        }
                    }
                }
            }

            // 6. Rolling VHS / CRT Tracking Interference Band (ABOVE Canal 600 & screen content)
            Rectangle {
                id: trackingBand
                width: parent.width
                height: 30
                y: -30
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
                    from: -30
                    to: crtScreen.height + 30
                    duration: 5200
                    loops: Animation.Infinite
                    running: root.isLive
                }
            }

            // 7. Horizontal CRT Scanlines (over ENTIRE tube including Canal 600)
            Canvas {
                id: scanlineCanvas
                anchors.fill: parent
                z: 7
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = "rgba(0, 0, 0, 0.28)";
                    for (let y = 0; y < height; y += 3) {
                        ctx.fillRect(0, y, width, 1);
                    }
                }
            }

            // 8. Live RF Static Snow + Chrominance Interference Streaks (over ENTIRE tube including Canal 600)
            Canvas {
                id: noiseCanvas
                anchors.fill: parent
                z: 8
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    // Fine grain RF static specks
                    for (let i = 0; i < 65; i++) {
                        let rx = Math.random() * width;
                        let ry = Math.random() * height;
                        let rw = 1 + Math.random() * 2.5;
                        let alpha = 0.06 + Math.random() * 0.16;
                        ctx.fillStyle = "rgba(219, 234, 254, " + alpha.toFixed(2) + ")";
                        ctx.fillRect(rx, ry, rw, 1);
                    }

                    // Horizontal VHS sync tear & subtle chroma jitter streaks
                    if (Math.random() > 0.35) {
                        let lineCount = Math.random() > 0.6 ? 2 : 1;
                        for (let j = 0; j < lineCount; j++) {
                            let ly = Math.random() * height;
                            let lx = Math.random() * (width * 0.35);
                            let lw = width * (0.38 + Math.random() * 0.62);
                            ctx.fillStyle = Math.random() > 0.45
                                ? "rgba(191, 219, 254, 0.22)"
                                : "rgba(0, 0, 0, 0.36)";
                            ctx.fillRect(lx, ly, lw, 1.5);
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
    // VINTAGE TV BOTTOM CHIN (Tactile 3D Buttons, IR Sensor, Speaker Grilles)
    // =========================================================================
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 28
        z: 3

        // Deep molded bezel seam
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
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            spacing: 2.5
            Repeater {
                model: 2
                Row {
                    spacing: 2.5
                    Repeater {
                        model: 5
                        Rectangle {
                            width: 4
                            height: 2
                            radius: 0.5
                            color: "#0b0d12"
                        }
                    }
                }
            }
        }

        // Centered 3D Tactile Buttons + Smoked Acrylic IR Receiver Window
        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            spacing: 9

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: 4
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#646b7d" }
                            GradientStop { position: 1.0; color: "#2d313b" }
                        }
                        border.color: "#111318"
                        border.width: 0.8
                    }
                }
            }

            // Smoked Infrared Sensor Window (clean dark acrylic, no center red dot)
            Rectangle {
                width: 30
                height: 12
                radius: 2
                color: "#06070a"
                border.color: "#4d5362"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: 4
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
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
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            spacing: 8

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
                        running: root.isLive
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
                            model: 5
                            Rectangle {
                                width: 4
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

    // Drag Interaction Handler
    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
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
            if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                if (isDragging) {
                    isDragging = false;
                    let w = root.wrapper || root.findWrapper();
                    if (w) w.endDrag();
                }
                return;
            }
            let w = root.wrapper || root.findWrapper();
            let target = (w && w.parent) ? w.parent : null;
            let curX = mouse.x;
            let curY = mouse.y;
            if (target) {
                let pt = dragArea.mapToItem(target, mouse.x, mouse.y);
                curX = pt.x;
                curY = pt.y;
            }
            let dx = curX - startScreenX;
            let dy = curY - startScreenY;

            if (!isDragging && Math.hypot(dx, dy) > 5) {
                isDragging = true;
                if (w) w.startDrag(mouse.x, mouse.y);
            }
            if (isDragging && w) {
                w.updateDrag(dx, dy);
            }
        }

        onReleased: {
            if (isDragging) {
                let w = root.wrapper || root.findWrapper();
                if (w) w.endDrag();
                isDragging = false;
            }
        }

        onCanceled: {
            if (isDragging) {
                let w = root.wrapper || root.findWrapper();
                if (w) w.endDrag();
                isDragging = false;
            }
        }
    }
}
