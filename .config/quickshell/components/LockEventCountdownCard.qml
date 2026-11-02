import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../theme"

// ==============================================================================
// LOCK EVENT COUNTDOWN CARD — 280x330 Apple Obsidian Liquid Glass
// Sits directly next to LockCalendarCard in the lock screen control panel.
// Target: "NSQK presenta Mosca" (2027-02-27 at 18:00).
// ==============================================================================
Rectangle {
    id: root

    Theme { id: theme }

    property var reminders: []
    property color accent: theme.blue
    property bool active: false

    readonly property string iconFont: "GeistMono Nerd Font Propo"
    readonly property string defaultPosterPath: "file://" + Quickshell.shellPath("assets/nsqk-mosca.jpg")
    property string posterPath: defaultPosterPath

    implicitWidth: 280
    implicitHeight: 330
    radius: 16
    color: theme.popupBg
    border.width: 1
    border.color: theme.border
    clip: true

    // Target countdown values
    property string eventTitle: "NSQK PRESENTS MOSCA"
    property string eventDateLabel: "Feb 27, 2027"
    property string eventTimeLabel: "8:00 PM"
    property string eventLocation: "Auditorio Josefa · Live"

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
                // Specifically match the future Mosca concert reminder
                if (title.indexOf("mosca") !== -1 || r.date === "2027-02-27") {
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
        let diff = target.getTime() - now.getTime();

        if (diff <= 0) {
            root.days = 0;
            root.hours = 0;
            root.minutes = 0;
            root.seconds = 0;
            root.eventPassed = true;
            return;
        }

        root.eventPassed = false;
        let totalSecs = Math.floor(diff / 1000);
        root.days = Math.floor(totalSecs / 86400);
        totalSecs %= 86400;
        root.hours = Math.floor(totalSecs / 3600);
        totalSecs %= 3600;
        root.minutes = Math.floor(totalSecs / 60);
        root.seconds = totalSecs % 60;
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

    // ---- HEADER (matches LockCalendarCard layout: x: 16, y: 14) ----
    Row {
        id: header
        x: 16; y: 14
        width: parent.width - 32
        z: 3

        Text {
            text: "NSQK"
            color: theme.text
            font.family: theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Text {
            leftPadding: 6
            text: "Mosca"
            color: theme.textDim
            font.family: theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Medium
        }
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
            color: Qt.rgba(255, 255, 255, 0.50)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Third Studio Album"
            color: Qt.rgba(255, 255, 255, 0.55)
            font.family: theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Normal
        }
    }

    // ---- MAIN COUNTDOWN (4 SEGMENTED GLASS PILLS) ----
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 6
        spacing: 12
        z: 3

        // 4 Segmented countdown units
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 5

            // 1. DAYS
            Rectangle {
                width: 55
                height: 54
                radius: 10
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.09)

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.days.toString()
                        font.family: root.iconFont
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "DAYS"
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: Qt.rgba(255, 255, 255, 0.50)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -4
                text: ":"
                font.family: root.iconFont
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Qt.rgba(255, 255, 255, 0.35)
            }

            // 2. HOURS
            Rectangle {
                width: 53
                height: 54
                radius: 10
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.09)

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.hours)
                        font.family: root.iconFont
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "HOURS"
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: Qt.rgba(255, 255, 255, 0.50)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -4
                text: ":"
                font.family: root.iconFont
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Qt.rgba(255, 255, 255, 0.35)
            }

            // 3. MINUTES
            Rectangle {
                width: 53
                height: 54
                radius: 10
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.09)

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.minutes)
                        font.family: root.iconFont
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MIN"
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: Qt.rgba(255, 255, 255, 0.50)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -4
                text: ":"
                font.family: root.iconFont
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Qt.rgba(255, 255, 255, 0.35)
            }

            // 4. SECONDS
            Rectangle {
                width: 53
                height: 54
                radius: 10
                color: Qt.rgba(255, 255, 255, 0.05)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.09)

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.pad2(root.seconds)
                        font.family: root.iconFont
                        font.pixelSize: 19
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "SEC"
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                        color: Qt.rgba(255, 255, 255, 0.50)
                    }
                }
            }
        }
    }

    // ---- FOOTER STRIP (matches LockCalendarCard footer: x: 12, height: 54, radius: 12) ----
    Rectangle {
        id: footer
        x: 12
        width: parent.width - 24
        height: 54
        y: parent.height - height - 12
        radius: 12
        clip: true
        color: Qt.rgba(255, 255, 255, 0.04)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.08)
        z: 3

        // Date badge
        Rectangle {
            id: dateBadge
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 10
            color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.12)

            Column {
                anchors.centerIn: parent
                spacing: -1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "FEB"
                    color: Qt.rgba(255, 255, 255, 0.70)
                    font.family: theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Font.Bold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "27"
                    color: "#ffffff"
                    font.family: theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
            }
        }

        // Details next to badge
        Column {
            anchors.left: dateBadge.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - dateBadge.width - 28

            Text {
                text: "Saturday, Feb 27 · " + root.eventTimeLabel
                color: theme.text
                font.family: theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: root.eventLocation
                color: Qt.rgba(255, 255, 255, 0.50)
                font.family: theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
}
