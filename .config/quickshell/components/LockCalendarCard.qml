import QtQuick
import "../theme"

// Month calendar for the lock screen. The grid stretches to fill the card;
// a highlighted "Next up" strip at the bottom surfaces the closest reminder.
Rectangle {
    id: root
    property date now: new Date()
    property var reminders: []
    property color accent: "#42a0bf"
    property bool active: false

    Theme { id: theme }
    radius: 16
    color: theme.popupBg
    border.width: 1
    border.color: theme.border
    clip: true

    readonly property int year: now.getFullYear()
    readonly property int month: now.getMonth()
    readonly property int firstDow: (new Date(year, month, 1).getDay() + 6) % 7   // Monday first
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    readonly property int weeks: Math.ceil((firstDow + daysInMonth) / 7)

    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function dateKey(d) { return year + "-" + pad(month + 1) + "-" + pad(d); }
    function countFor(d) {
        const k = dateKey(d);
        let c = 0;
        for (let i = 0; i < reminders.length; i++)
            if (reminders[i].date === k && !reminders[i].done) c++;
        return c;
    }
    function toDate(r) {
        const d = r.date.split("-");
        const t = (r.time || "00:00").split(":");
        return new Date(+d[0], +d[1] - 1, +d[2], +t[0] || 0, +t[1] || 0);
    }
    readonly property var upcoming: {
        const from = now.getTime() - 15 * 60000;
        const list = [];
        for (let i = 0; i < reminders.length; i++) {
            const r = reminders[i];
            if (r.done || !r.date) continue;
            const dt = toDate(r);
            if (dt.getTime() >= from) list.push({ title: r.title, category: r.category || "", dt: dt });
        }
        list.sort((a, b) => a.dt - b.dt);
        return list;
    }
    function relative(dt) {
        const mins = Math.round((dt - now) / 60000);
        if (mins < 0) return "Overdue";
        if (mins < 1) return "Now";
        if (mins < 60) return "in " + mins + " min";
        if (dt.toDateString() === now.toDateString()) return "Today · " + Qt.formatDateTime(dt, "h:mm AP");
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        if (dt.toDateString() === tomorrow.toDateString()) return "Tomorrow · " + Qt.formatDateTime(dt, "h:mm AP");
        return Qt.locale("en_US").toString(dt, "ddd d") + " · " + Qt.formatDateTime(dt, "h:mm AP");
    }

    // ---- header ----
    Row {
        id: header
        x: 16; y: 14
        width: parent.width - 32
        Text {
            text: Qt.locale("en_US").monthName(root.month)
            color: theme.text
            font.family: theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Bold
        }
        Text {
            leftPadding: 6
            text: root.year
            color: theme.textDim
            font.family: theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Medium
        }
    }

    // ---- footer: next-up highlight ----
    Rectangle {
        id: footer
        x: 12
        width: parent.width - 24
        height: 54
        y: parent.height - height - 12
        radius: 12
        clip: true
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
        border.width: 1
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)

        opacity: root.active ? 1 : 0
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 240 } NumberAnimation { duration: 360; easing.type: Easing.OutCubic } } }

        // slow light sweep
        Rectangle {
            id: sweep
            width: 60; height: parent.height * 2
            y: -parent.height / 2
            rotation: 20
            opacity: root.upcoming.length > 0 ? 1 : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            SequentialAnimation on x {
                running: root.active && root.upcoming.length > 0
                loops: Animation.Infinite
                NumberAnimation { from: -80; to: footer.width + 40; duration: 2600; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 3400 }
            }
        }

        readonly property var next: root.upcoming.length > 0 ? root.upcoming[0] : null
        readonly property bool soon: next !== null && (next.dt - root.now) < 3600000

        // date badge
        Rectangle {
            id: badge
            x: 9; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 10
            color: footer.soon ? theme.peach : root.accent
            Column {
                anchors.centerIn: parent
                spacing: -1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: footer.next ? Qt.locale("en_US").toString(footer.next.dt, "MMM").toUpperCase() : "—"
                    color: "#000000"; opacity: 0.7
                    font.family: theme.fontFamily; font.pixelSize: 8; font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: footer.next ? footer.next.dt.getDate() : ""
                    color: "#000000"
                    font.family: theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold
                }
            }
        }
        Column {
            anchors.left: badge.right; anchors.leftMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: footer.next ? footer.next.title : "All clear"
                elide: Text.ElideRight
                color: theme.text
                font.family: theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: footer.next
                      ? root.relative(footer.next.dt) + (root.upcoming.length > 1 ? "   +" + (root.upcoming.length - 1) + " more" : "")
                      : "No upcoming reminders"
                elide: Text.ElideRight
                color: footer.soon ? theme.peach : theme.textMuted
                font.family: theme.fontFamily; font.pixelSize: 11
            }
        }
    }

    // ---- month grid (fills the space between header and footer) ----
    Item {
        id: gridArea
        x: 12
        y: header.y + header.height + 8
        width: parent.width - 24
        height: footer.y - y - 8

        readonly property real cellW: width / 7
        readonly property real wdH: 18
        readonly property real cellH: Math.max(18, (height - wdH) / root.weeks)

        Row {
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                delegate: Text {
                    width: gridArea.cellW
                    height: gridArea.wdH
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8) : theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }

        Repeater {
            model: root.weeks * 7
            delegate: Item {
                id: cellItem
                x: (index % 7) * gridArea.cellW
                y: gridArea.wdH + Math.floor(index / 7) * gridArea.cellH
                width: gridArea.cellW
                height: gridArea.cellH
                readonly property int day: index - root.firstDow + 1
                readonly property bool valid: day >= 1 && day <= root.daysInMonth
                readonly property bool isToday: valid && day === root.now.getDate()
                readonly property bool past: valid && day < root.now.getDate()
                readonly property int count: valid ? root.countFor(day) : 0
                readonly property real d: Math.min(gridArea.cellW, gridArea.cellH) - 6

                // staggered pop-in
                scale: root.active ? 1 : 0.6
                opacity: root.active ? 1 : 0
                Behavior on scale { SequentialAnimation { PauseAnimation { duration: 120 + index * 9 } NumberAnimation { duration: 320; easing.type: Easing.OutBack } } }
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 120 + index * 9 } NumberAnimation { duration: 260 } } }

                Rectangle {
                    anchors.centerIn: parent
                    width: cellItem.d; height: cellItem.d; radius: cellItem.d / 2
                    visible: cellItem.isToday
                    color: root.accent
                    SequentialAnimation on opacity {
                        running: cellItem.isToday && root.active
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.65; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.65; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
                // soft ring on days with reminders
                Rectangle {
                    anchors.centerIn: parent
                    width: cellItem.d; height: cellItem.d; radius: cellItem.d / 2
                    visible: cellItem.count > 0 && !cellItem.isToday
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: cellItem.count > 0 ? -2 : 0
                    visible: cellItem.valid
                    text: cellItem.day
                    color: cellItem.isToday ? "#000000" : cellItem.past ? theme.textDim : theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 12
                    font.weight: cellItem.isToday ? Font.Bold : Font.Medium
                }
                Rectangle {
                    visible: cellItem.count > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 0
                    y: parent.height / 2 + cellItem.d / 2 - 8
                    width: 4; height: 4; radius: 2
                    color: cellItem.isToday ? "#000000" : root.accent
                }
            }
        }
    }
}
