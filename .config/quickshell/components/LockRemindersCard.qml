import QtQuick
import "../theme"

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
    implicitHeight: 56 + upcoming.length * 40
    visible: upcoming.length > 0

    function toDate(r, dateOverride) {
        const d = (dateOverride || r.date).split("-");
        const t = (r.time || "00:00").split(":");
        return new Date(+d[0], +d[1] - 1, +d[2], +t[0] || 0, +t[1] || 0);
    }
    function occursOnDate(r, dateObj) {
        const dStr = dateObj.getFullYear() + "-" + String(dateObj.getMonth() + 1).padStart(2, '0') + "-" + String(dateObj.getDate()).padStart(2, '0');
        const rep = (r.repeat || "none").toLowerCase();
        if (rep === "" || rep === "none") return r.date === dStr;
        const sp = (r.date || "").split("-");
        if (sp.length !== 3) return false;
        const sUtc = Date.UTC(+sp[0], +sp[1] - 1, +sp[2]);
        const tUtc = Date.UTC(dateObj.getFullYear(), dateObj.getMonth(), dateObj.getDate());
        if (tUtc < sUtc) return false;
        if (r.repeat_until) {
            const up = r.repeat_until.split("-");
            if (up.length === 3 && tUtc > Date.UTC(+up[0], +up[1] - 1, +up[2])) return false;
        }
        if (Array.isArray(r.exdates) && r.exdates.indexOf(dStr) !== -1) return false;
        const diffDays = Math.round((tUtc - sUtc) / 86400000);
        const dow = dateObj.getDay();
        const dayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
        if (rep === "daily") return true;
        if (rep === "weekdays") return dow >= 1 && dow <= 5;
        if (rep === "weekly") {
            if (Array.isArray(r.repeat_days) && r.repeat_days.length > 0) return r.repeat_days.indexOf(dayCodes[dow]) !== -1;
            return diffDays % 7 === 0;
        }
        if (rep === "biweekly") return diffDays % 14 === 0;
        if (rep === "monthly") {
            const maxDay = new Date(dateObj.getFullYear(), dateObj.getMonth() + 1, 0).getDate();
            return dateObj.getDate() === Math.min(+sp[2], maxDay);
        }
        if (rep === "yearly") {
            if (dateObj.getMonth() + 1 !== +sp[1]) return false;
            const maxDay = new Date(dateObj.getFullYear(), dateObj.getMonth() + 1, 0).getDate();
            return dateObj.getDate() === Math.min(+sp[2], maxDay);
        }
        return false;
    }
    readonly property var upcoming: {
        // Only surface what is imminent: due within the next 2 hours (or up to 15 min late)
        const from = now.getTime() - 15 * 60000;
        const to = now.getTime() + 120 * 60000;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const list = [];
        for (let i = 0; i < reminders.length; i++) {
            const r = reminders[i];
            if (!r.date) continue;
            const cands = [today, tomorrow];
            for (let c = 0; c < cands.length; c++) {
                if (!occursOnDate(r, cands[c])) continue;
                const cStr = cands[c].getFullYear() + "-" + String(cands[c].getMonth() + 1).padStart(2, '0') + "-" + String(cands[c].getDate()).padStart(2, '0');
                const dt = toDate(r, cStr);
                if (dt.getTime() >= from && dt.getTime() <= to) {
                    list.push({ title: r.title, category: r.category || "", dt: dt });
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
