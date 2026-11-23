import QtQuick
import "../theme"
import "ReminderUtils.js" as ReminderUtils

// Upcoming calendar reminders (from hypr-reminders) for the lock screen.
Rectangle {
    id: root
    Theme { id: theme }
    property date now: new Date()
    property var reminders: []
    property color accent: theme.blue
    property bool active: false
    property int maxItems: 3
    radius: 16
    color: theme.popupBg
    border.width: 1
    border.color: theme.border
    implicitHeight: 56 + upcoming.length * 42
    visible: upcoming.length > 0

    readonly property var upcoming: {
        // Only surface what is imminent: due within the next 2 hours (or up to 15 min late)
        const from = now.getTime() - 15 * 60000;
        const to = now.getTime() + 120 * 60000;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const list = [];
        for (let i = 0; i < reminders.length; i++) {
            const r = reminders[i];
            if (!r || r.done || !r.date) continue;
            const cands = [today, tomorrow];
            for (let c = 0; c < cands.length; c++) {
                if (!ReminderUtils.occursOnDate(r, cands[c])) continue;
                const cStr = cands[c].getFullYear() + "-" + String(cands[c].getMonth() + 1).padStart(2, '0') + "-" + String(cands[c].getDate()).padStart(2, '0');
                const dt = ReminderUtils.toDate(r, cStr);
                if (dt.getTime() >= from && dt.getTime() <= to) {
                    list.push({
                        title: r.title || "",
                        category: r.category || "",
                        notes: r.notes || "",
                        logo: r.logo || "",
                        dt: dt
                    });
                }
            }
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
                height: 36
                radius: 10
                readonly property bool soon: (modelData.dt - root.now) < 3600000
                readonly property color catColor: Qt.color(ReminderUtils.categoryColor(modelData.category, modelData.title))
                color: Qt.rgba(catColor.r, catColor.g, catColor.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(catColor.r, catColor.g, catColor.b, 0.24)
                // staggered slide/fade-in whenever the panel is revealed
                opacity: root.active ? 1 : 0
                transform: Translate { y: root.active ? 0 : 12 }
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 260 + index * 90 } NumberAnimation { duration: 320; easing.type: Easing.OutCubic } } }

                Rectangle {
                    id: bar
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 18; radius: 1.5
                    color: row.catColor
                    SequentialAnimation on opacity {
                        running: row.soon && root.active
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    id: iconBadge
                    anchors.left: bar.right; anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 6
                    color: Qt.rgba(row.catColor.r, row.catColor.g, row.catColor.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(row.catColor.r, row.catColor.g, row.catColor.b, 0.28)
                    ReminderCategoryIcon {
                        anchors.centerIn: parent
                        boxSize: 13
                        category: modelData.category
                        title: modelData.title
                        notes: modelData.notes
                        logo: modelData.logo
                    }
                }
                Text {
                    anchors.left: iconBadge.right; anchors.leftMargin: 9
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
                    color: row.soon ? theme.peach : Qt.lighter(row.catColor, 1.38)
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }
        }
    }
}
