import QtQuick
import "../theme"

// Upcoming calendar reminders (from hypr-reminders) for the lock screen.
Rectangle {
    id: root
    property date now: new Date()
    property var reminders: []
    property color accent: "#42a0bf"
    property bool active: false
    property int maxItems: 3

    Theme { id: theme }
    radius: 16
    color: theme.popupBg
    border.width: 1
    border.color: theme.border
    implicitHeight: 56 + upcoming.length * 40
    visible: upcoming.length > 0

    function toDate(r) {
        const d = r.date.split("-");
        const t = (r.time || "00:00").split(":");
        return new Date(+d[0], +d[1] - 1, +d[2], +t[0] || 0, +t[1] || 0);
    }
    readonly property var upcoming: {
        // Only surface what is imminent: due within the next 2 hours (or up to 15 min late)
        const from = now.getTime() - 15 * 60000;
        const to = now.getTime() + 120 * 60000;
        const list = [];
        for (let i = 0; i < reminders.length; i++) {
            const r = reminders[i];
            if (r.done || !r.date) continue;
            const dt = toDate(r);
            if (dt.getTime() >= from && dt.getTime() <= to) list.push({ title: r.title, category: r.category || "", dt: dt });
        }
        list.sort((a, b) => a.dt - b.dt);
        return list.slice(0, maxItems);
    }
    function relative(dt) {
        const mins = Math.round((dt - now) / 60000);
        if (mins < 0) return "Overdue";
        if (mins < 1) return "Now";
        if (mins < 60) return "in " + mins + " min";
        const sameDay = dt.toDateString() === now.toDateString();
        if (sameDay) return "in " + Math.floor(mins / 60) + "h " + (mins % 60) + "m";
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        if (dt.toDateString() === tomorrow.toDateString()) return "Tomorrow " + Qt.formatDateTime(dt, "h:mm AP");
        return Qt.locale("en_US").toString(dt, "ddd d") + " " + Qt.formatDateTime(dt, "h:mm AP");
    }

    Text {
        id: head
        x: 18; y: 16
        text: "Coming up soon"
        color: theme.text
        font.family: theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: head.verticalCenter
        text: "Heads up"
        color: theme.textDim
        font.family: theme.fontFamily
        font.pixelSize: 11
    }

    Column {
        x: 18; y: 48
        width: parent.width - 36
        spacing: 6
        Repeater {
            model: root.upcoming
            delegate: Rectangle {
                id: row
                width: parent.width
                height: 34
                radius: 10
                color: theme.surface
                readonly property bool soon: (modelData.dt - root.now) < 3600000
                // staggered slide/fade-in whenever the panel is revealed
                opacity: root.active ? 1 : 0
                transform: Translate { y: root.active ? 0 : 12 }
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 260 + index * 90 } NumberAnimation { duration: 320; easing.type: Easing.OutCubic } } }

                Rectangle {
                    id: bar
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 18; radius: 1.5
                    color: row.soon ? theme.peach : root.accent
                    SequentialAnimation on opacity {
                        running: row.soon && root.active
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.left: bar.right; anchors.leftMargin: 10
                    anchors.right: whenText.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title
                    elide: Text.ElideRight
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                Text {
                    id: whenText
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.relative(modelData.dt)
                    color: row.soon ? theme.peach : theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
