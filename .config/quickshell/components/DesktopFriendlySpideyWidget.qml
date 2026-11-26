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

    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/friendly-spidey-bg.jpg")
    property string posterPath: defaultPosterPath

    property int months: 0
    property int days: 0
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool eventPassed: false
    property bool lockPreviewState: false

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

    Component.onCompleted: updateCountdown()

    // Classic Crimson & Cobalt Spidey Glow
    Item {
        anchors.fill: parent
        z: 0

        RectangularGlow {
            width: parent.width * 0.55
            height: parent.height * 0.72
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            glowRadius: 22
            spread: 0.04
            color: Qt.rgba(239/255, 68/255, 68/255, 0.22)
            cornerRadius: 24
        }

        RectangularGlow {
            width: parent.width * 0.55
            height: parent.height * 0.72
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glowRadius: 22
            spread: 0.04
            color: Qt.rgba(37/255, 99/255, 235/255, 0.24)
            cornerRadius: 24
        }
    }

    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: 20
        color: "#090c16"
        border.color: "#05070d"
        border.width: 2.5
        clip: true
        z: 1

        Item {
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
                anchors.fill: parent
                anchors.topMargin: 10
                anchors.bottomMargin: -10
                source: root.posterPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.55

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0.03, 0.04, 0.09, 0.50) }
                        GradientStop { position: 0.50; color: Qt.rgba(0.02, 0.03, 0.07, 0.65) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.02, 0.05, 0.86) }
                    }
                }
            }
        }

        // Top crimson-to-cobalt hairline
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1.5
            z: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: "#ef4444" }
                GradientStop { position: 0.7; color: "#3b82f6" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Header (Marvel logo matching Doomsday)
        Row {
            x: 16; y: 14
            width: parent.width - 110
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
                text: "DISNEY+ · JAN 13, 2027"
                color: Qt.rgba(255, 255, 255, 0.78)
                font.family: theme.fontFamily
                font.pixelSize: 10
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
                        let distCenter = Math.hypot((u - 0.5) * 1.1, (v - 0.5) * 1.4);
                        let r = 0.70 + Math.min(1.0, distCenter) * 1.15;
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

        // Classic aged-cream comic-panel inset frame
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 16
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(254/255, 243/255, 199/255, 0.28)
            z: 2
        }

        // Top-right Aesthetic Comic Spiderweb (no spider)
        Canvas {
            anchors.top: parent.top
            anchors.right: parent.right
            width: 136
            height: 128
            z: 4
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                let spokes = [
                    { a: Math.PI * 0.50, len: 112 },
                    { a: Math.PI * 0.59, len: 124 },
                    { a: Math.PI * 0.69, len: 130 },
                    { a: Math.PI * 0.79, len: 124 },
                    { a: Math.PI * 0.90, len: 114 },
                    { a: Math.PI * 1.00, len: 106 }
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

                    let rings = [18, 34, 52, 72, 94];
                    for (let rIdx = 0; rIdx < rings.length; rIdx++) {
                        let baseR = rings[rIdx];
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

                // Crisp comic ink outline + bright silver-white web silk
                drawWebPass("rgba(4, 6, 12, 0.92)", 2.8);
                drawWebPass("rgba(248, 250, 252, 0.88)", 1.15);
            }
        }

        // Active Countdown (Comic-book hard ink drop-shadow + yellow-red-blue pop accents)
        Column {
            visible: !root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 14
            spacing: 12
            z: 3
            width: parent.width - 24

            // Comic-book slanted title badge
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: comicTitleTxt.implicitWidth + 20
                height: 22
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
                    id: comicTitleTxt
                    anchors.centerIn: parent
                    text: "SPIDER-MAN · SEASON 2"
                    color: "#05070d"
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Black
                    font.italic: true
                    font.letterSpacing: 1.8
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.width > 400 ? 14 : 10

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dMon.implicitWidth; height: dMon.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: dMon; value: root.pad2(root.months); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MONTHS"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dDay.implicitWidth; height: dDay.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: dDay; value: root.pad2(root.days); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "DAYS"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dHr.implicitWidth; height: dHr.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: dHr; value: root.pad2(root.hours); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "HOURS"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dMin.implicitWidth; height: dMin.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: dMin; value: root.pad2(root.minutes); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MIN"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }

                Text { text: ":"; font.family: theme.fontFamily; font.pixelSize: root.width > 400 ? 24 : 20; font.weight: Font.Black; color: "#ffffff"; style: Text.Outline; styleColor: "#05070d"; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -7 }

                Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: dSec.implicitWidth; height: dSec.implicitHeight
                        FallingDigits { x: 2.5; y: 2.5; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#05070d" }
                        FallingDigits { id: dSec; value: root.pad2(root.seconds); fontFamily: theme.fontFamily; pixelSize: root.width > 400 ? 34 : 28; fontWeight: Font.Black; textColor: "#ffffff" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "SEC"; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 1.0; color: "#facc15"; style: Text.Outline; styleColor: "#05070d" }
                }
            }
        }

        // Event Arrived State
        Text {
            visible: root.eventPassed
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 10
            width: parent.width - 32
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            z: 3
            text: "SEASON 2 STREAMING NOW"
            color: "#ffffff"
            font.family: theme.fontFamily
            font.pixelSize: root.width > 400 ? 22 : 17
            font.weight: Font.Black
            font.letterSpacing: 2.8
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.96)
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
