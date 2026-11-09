import QtQuick
import QtQuick.Layouts
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

    property color accent: "#10b981" // Refined Doctor Doom Emerald
    readonly property string iconFont: "GeistMono Nerd Font Propo"
    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/doomsday-desktop.jpg")
    property string posterPath: defaultPosterPath

    // Target countdown values
    property string eventTitle: "AVENGERS: DOOMSDAY"
    property string eventDateLabel: "Dec 16, 2026"
    property string eventTimeLabel: "12:00 AM"
    property string eventLocation: "Cinemex Paseo Querétaro · Premiere"

    property int months: 0
    property int days: 0
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool eventPassed: false

    property var reminders: []

    function pad2(n) {
        return (n < 10 ? "0" : "") + Math.max(0, n);
    }

    function formatTime12(t) {
        if (!t) return "12:00 AM";
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
                            root.eventTimeLabel = root.formatTime12(r.time);
                        }
                        if (r.photo && r.photo.trim() && r.photo.indexOf("doomsday.jpg") === -1) {
                            root.posterPath = (r.photo.startsWith("http") || r.photo.startsWith("file://")) ? r.photo : ("file://" + r.photo);
                        }
                        if (r.notes && r.notes.trim()) {
                            root.eventLocation = r.notes.trim() + " · Premiere";
                        }
                        let candidate = new Date(y, m, d, hr, mn, 0);
                        if (candidate.getTime() > now.getTime()) {
                            return candidate;
                        }
                    }
                }
            }
        }
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

    // Read reminders from backend hypr-reminders
    Process {
        id: readRemindersProc
        command: ["/home/ferram/Personal/dotfiles/.local/bin/hypr-reminders", "list"]
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

    // =========================================================================
    // AMBIENT GLOW BEHIND THE WIDGET (Clean, high-performance Doctor Doom emerald)
    // =========================================================================
    Item {
        anchors.fill: parent
        z: 0

        RectangularGlow {
            anchors.fill: parent
            glowRadius: 26
            spread: 0.12
            color: Qt.rgba(16/255, 185/255, 129/255, 0.20)
            cornerRadius: 20
        }
    }

    // =========================================================================
    // MAIN WIDGET CARD BODY (Clean Obsidian Liquid Glass Container)
    // =========================================================================
    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: 20
        color: Qt.rgba(0.04, 0.04, 0.06, 0.90)
        border.color: Qt.rgba(16/255, 185/255, 129/255, 0.28)
        border.width: 1
        clip: true
        z: 1

        // =====================================================================
        // POSTER BACKGROUND WITH OBSIDIAN GRADIENT MASK
        // =====================================================================
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
                anchors.fill: parent
                source: root.posterPath
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.52

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.03, 0.04, 0.45) }
                        GradientStop { position: 0.50; color: Qt.rgba(0.01, 0.02, 0.03, 0.60) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.02, 0.02, 0.82) }
                    }
                }
            }
        }

        // Top Specular Hairline (Subtle Candlelight Sheen)
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
                GradientStop { position: 0.25; color: Qt.rgba(16/255, 185/255, 129/255, 0.25) }
                GradientStop { position: 0.50; color: Qt.rgba(16/255, 185/255, 129/255, 0.40) }
                GradientStop { position: 0.75; color: Qt.rgba(16/255, 185/255, 129/255, 0.25) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ---- HEADER: Marvel Badge & Subtitle ----
        Row {
            id: header
            x: 16; y: 14
            width: parent.width - 32
            spacing: 8
            z: 3

            Image {
                source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg"
                width: 38
                height: 15
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                smooth: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "STUDIOS · CINEMA PREMIERE"
                color: Qt.rgba(255, 255, 255, 0.75)
                font.family: theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.2
            }
        }

        // ---- MAIN COUNTDOWN (Centered with breathing room - NO date box below, NO boxes around numbers) ----
        Column {
            id: centerCountdown
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 14
            spacing: 14
            z: 3
            width: parent.width - 24

            // Top Banner Title: "DOOMSDAY IS COMING"
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DOOMSDAY IS COMING"
                color: "#ffffff"
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Black
                font.letterSpacing: 2.2
            }

            // 5-Segment Clean White Countdown Row (NO BOXES / CUADROS)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.width > 400 ? 14 : 10

                // 1. MONTHS
                Column {
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.months)
                        font.family: theme.fontFamily
                        font.pixelSize: root.width > 400 ? 34 : 28
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MONTHS"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: root.width > 400 ? 24 : 20
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -7
                }

                // 2. DAYS
                Column {
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.days)
                        font.family: theme.fontFamily
                        font.pixelSize: root.width > 400 ? 34 : 28
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "DAYS"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: root.width > 400 ? 24 : 20
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -7
                }

                // 3. HOURS
                Column {
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.hours)
                        font.family: theme.fontFamily
                        font.pixelSize: root.width > 400 ? 34 : 28
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "HOURS"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: root.width > 400 ? 24 : 20
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -7
                }

                // 4. MINUTES
                Column {
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.minutes)
                        font.family: theme.fontFamily
                        font.pixelSize: root.width > 400 ? 34 : 28
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MIN"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        color: Qt.rgba(255, 255, 255, 0.75)
                    }
                }

                Text {
                    text: ":"
                    font.family: theme.fontFamily
                    font.pixelSize: root.width > 400 ? 24 : 20
                    font.weight: Font.Bold
                    color: Qt.rgba(255, 255, 255, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -7
                }

                // 5. SECONDS
                Column {
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.seconds)
                        font.family: theme.fontFamily
                        font.pixelSize: root.width > 400 ? 34 : 28
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "SEC"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        color: Qt.rgba(255, 255, 255, 0.75)
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
}
