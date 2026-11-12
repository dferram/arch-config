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

    radius: 20
    color: Qt.rgba(0.04, 0.04, 0.06, 0.90)
    border.color: Qt.rgba(255, 255, 255, 0.08)
    border.width: 1
    clip: true

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

    property color accent: "#38bdf8" // NSQK Electric Cyan / Ice Blue
    readonly property string iconFont: "GeistMono Nerd Font Propo"
    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/nsqk-mosca.jpg")
    property string posterPath: defaultPosterPath

    // Target countdown values
    property string eventTitle: "NSQK PRESENTS MOSCA"
    property string eventDateLabel: "Feb 27, 2027"
    property string eventTimeLabel: "8:00 PM"
    property string eventLocation: "Auditorio Josefa · Querétaro"

    property int months: 0
    property int days: 0
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool eventPassed: false

    property var reminders: []

    // Segment helper component matching clean typography
    component CountdownPill : Item {
        property string value: "00"
        property string label: "DAYS"
        width: root.width > 400 ? 54 : 44
        height: root.width > 400 ? 56 : 48

        Column {
            anchors.centerIn: parent
            spacing: 2

            FallingDigits {
                anchors.horizontalCenter: parent.horizontalCenter
                value: parent.parent.value
                fontFamily: root.iconFont
                pixelSize: root.width > 400 ? 34 : 28
                fontWeight: Font.Bold
                fontItalic: true
                textColor: "#ffffff"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.label
                font.family: theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1.0
                color: Qt.rgba(255, 255, 255, 0.75)
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
                            root.eventLocation = r.notes.trim();
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
    // POSTER BACKGROUND WITH OBSIDIAN GRADIENT MASK
    // =========================================================================
    Item {
        id: posterContainer
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: posterContainer.width
                height: posterContainer.height
                radius: root.radius
            }
        }

        Image {
            id: posterImg
            width: parent.width
            height: parent.width * (858.0 / 600.0)
            anchors.horizontalCenter: parent.horizontalCenter
            y: -Math.round(parent.width * 0.04)
            source: root.posterPath
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 640
            sourceSize.height: 915
            asynchronous: true
            opacity: 0.38
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.03, 0.05, 0.60) }
                GradientStop { position: 0.50; color: Qt.rgba(0.01, 0.02, 0.04, 0.75) }
                GradientStop { position: 1.0; color: Qt.rgba(0.01, 0.02, 0.03, 0.90) }
            }
        }
    }

    // =========================================================================
    // MAIN CARD BODY
    // =========================================================================

    // ---- HEADER: NSQK Logo & Subtitle ----
    Row {
        id: header
        x: 16; y: 12
        width: parent.width - 32
        spacing: 8
        z: 3

        Image {
            source: "file://" + Quickshell.shellPath("assets/nsqk-logo-white.png")
            width: 36
            height: 16
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            smooth: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "MOSCA TOUR"
            color: Qt.rgba(255, 255, 255, 0.75)
            font.family: theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1.2
        }
    }

    // ---- MAIN COUNTDOWN (5-SEGMENT LIQUID GLASS PILLS) ----
    Column {
        id: centerCountdown
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 14
        spacing: 12
        z: 3
        width: parent.width - 24

        // Top Banner Title: "NSQK PRESENTS MOSCA"
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NSQK PRESENTS MOSCA"
            color: "#ffffff"
            font.family: theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Black
            font.letterSpacing: 2.2
        }

        // 5-Segment Countdown Row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.width > 400 ? 10 : 6

            CountdownPill { value: root.pad2(root.months); label: "MONTHS" }

            Text {
                text: ":"
                font.family: theme.fontFamily
                font.pixelSize: root.width > 400 ? 24 : 20
                font.weight: Font.Bold
                color: Qt.rgba(255, 255, 255, 0.45)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -7
            }

            CountdownPill { value: root.pad2(root.days); label: "DAYS" }

            Text {
                text: ":"
                font.family: theme.fontFamily
                font.pixelSize: root.width > 400 ? 24 : 20
                font.weight: Font.Bold
                color: Qt.rgba(255, 255, 255, 0.45)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -7
            }

            CountdownPill { value: root.pad2(root.hours); label: "HOURS" }

            Text {
                text: ":"
                font.family: theme.fontFamily
                font.pixelSize: root.width > 400 ? 24 : 20
                font.weight: Font.Bold
                color: Qt.rgba(255, 255, 255, 0.45)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -7
            }

            CountdownPill { value: root.pad2(root.minutes); label: "MIN" }

            Text {
                text: ":"
                font.family: theme.fontFamily
                font.pixelSize: root.width > 400 ? 24 : 20
                font.weight: Font.Bold
                color: Qt.rgba(255, 255, 255, 0.45)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -7
            }

            CountdownPill { value: root.pad2(root.seconds); label: "SEC" }
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
