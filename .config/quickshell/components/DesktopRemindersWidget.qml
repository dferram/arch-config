import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 216
    implicitHeight: 207

    radius: 20
    // Apple Sonoma Translucent Obsidian Glass
    color: theme.widgetGlass
    border.color: theme.borderSubtle
    border.width: 1
    clip: true

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null
    property var monthReminders: []
    property int currentMonthCount: 0
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true
    property double lastFetchMs: 0

    readonly property string currentMonthPrefix: {
        let now = new Date();
        let y = now.getFullYear();
        let m = String(now.getMonth() + 1).padStart(2, '0');
        return y + "-" + m; // e.g. "2026-10"
    }

    readonly property string currentMonthName: {
        let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        return names[new Date().getMonth()];
    }

    // Read reminders from backend hypr-reminders
    Process {
        id: readRemindersProc
        command: ["/home/ferram/Personal/dotfiles/.local/bin/hypr-reminders", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastFetchMs = Date.now();
                let txt = text.trim();
                if (!txt) return;
                try {
                    let list = JSON.parse(txt);
                    if (Array.isArray(list)) {
                        let now = new Date();
                        let curY = now.getFullYear();
                        let curM = now.getMonth() + 1;
                        let curD = now.getDate();
                        let daysInCurM = new Date(curY, curM, 0).getDate();

                        let dayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
                        let expanded = [];
                        for (let i = 0; i < list.length; i++) {
                            let r = list[i];
                            if (!r.date) continue;
                            let exdates = Array.isArray(r.exdates) ? r.exdates : [];
                            let rep = (r.repeat || "none").toLowerCase();
                            if (rep === "" || rep === "none") {
                                let y = curY;
                                let m = String(curM).padStart(2, '0');
                                let d = String(curD).padStart(2, '0');
                                let todayStr = y + "-" + m + "-" + d;
                                if (r.date.startsWith(root.currentMonthPrefix) && r.date >= todayStr) {
                                    expanded.push(r);
                                }
                            } else {
                                let sp = r.date.split("-");
                                if (sp.length !== 3) continue;
                                let startUtc = Date.UTC(parseInt(sp[0], 10), parseInt(sp[1], 10) - 1, parseInt(sp[2], 10));
                                let startM = parseInt(sp[1], 10);
                                let startD = parseInt(sp[2], 10);
                                let untilUtc = null;
                                if (r.repeat_until) {
                                    let up = r.repeat_until.split("-");
                                    if (up.length === 3) {
                                        untilUtc = Date.UTC(parseInt(up[0], 10), parseInt(up[1], 10) - 1, parseInt(up[2], 10));
                                    }
                                }
                                let repDays = Array.isArray(r.repeat_days) ? r.repeat_days : [];
                                for (let day = curD; day <= daysInCurM; day++) {
                                    let candStr = root.currentMonthPrefix + "-" + String(day).padStart(2, '0');
                                    if (exdates.indexOf(candStr) !== -1) continue;
                                    let tUtc = Date.UTC(curY, curM - 1, day);
                                    if (tUtc < startUtc) continue;
                                    if (untilUtc !== null && tUtc > untilUtc) continue;
                                    let diffDays = Math.round((tUtc - startUtc) / 86400000);
                                    let dow = new Date(tUtc).getUTCDay();
                                    let match = false;
                                    if (rep === "daily") match = true;
                                    else if (rep === "weekdays") match = (dow >= 1 && dow <= 5);
                                    else if (rep === "weekly") match = (repDays.length > 0) ? (repDays.indexOf(dayCodes[dow]) !== -1) : (diffDays % 7 === 0);
                                    else if (rep === "biweekly") match = (diffDays % 14 === 0);
                                    else if (rep === "monthly") match = (day === Math.min(startD, daysInCurM));
                                    else if (rep === "yearly") match = (curM === startM && day === Math.min(startD, daysInCurM));
                                    if (match) {
                                        let occ = Object.assign({}, r);
                                        occ.date = candStr;
                                        expanded.push(occ);
                                        break; // show next upcoming occurrence in this month
                                    }
                                }
                            }
                        }

                        // Sort by date and time
                        expanded.sort((a, b) => {
                            let da = (a.date || "") + " " + (a.time || "");
                            let db = (b.date || "") + " " + (b.time || "");
                            return da.localeCompare(db);
                        });
                        root.monthReminders = expanded;
                        root.currentMonthCount = expanded.length;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.isLive
        onTriggered: {
            if (root.isLive && !readRemindersProc.running) readRemindersProc.running = true;
        }
    }

    onIsLiveChanged: {
        if (isLive && !readRemindersProc.running && (Date.now() - root.lastFetchMs > 25000)) {
            readRemindersProc.running = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header: Apple Reminders Badge & Month Counter (Smooth Drag Handle)
        Item {
            id: reminderHeader
            width: parent.width
            height: 24

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real startScreenX: 0
                property real startScreenY: 0
                property bool isDragging: false

                onPressed: (mouse) => {
                    if (mouse.button !== Qt.LeftButton) return;
                    let targetParent = (root.wrapper && root.wrapper.parent) ? root.wrapper.parent : root.parent;
                    let pt = mapToItem(targetParent, mouse.x, mouse.y);
                    startScreenX = pt.x;
                    startScreenY = pt.y;
                    isDragging = false;
                }
                onPositionChanged: (mouse) => {
                    if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                        if (isDragging) {
                            isDragging = false;
                            if (root.wrapper) root.wrapper.endDrag();
                        }
                        return;
                    }
                    let targetParent = (root.wrapper && root.wrapper.parent) ? root.wrapper.parent : root.parent;
                    let pt = mapToItem(targetParent, mouse.x, mouse.y);
                    let dx = pt.x - startScreenX;
                    let dy = pt.y - startScreenY;
                    if (!isDragging && Math.hypot(dx, dy) > 4) {
                        isDragging = true;
                        if (root.wrapper) root.wrapper.startDrag(mouse.x, mouse.y);
                    }
                    if (isDragging && root.wrapper) {
                        root.wrapper.updateDrag(dx, dy);
                    }
                }
                onReleased: {
                    if (isDragging && root.wrapper) {
                        isDragging = false;
                        root.wrapper.endDrag();
                    }
                }
                onCanceled: {
                    if (isDragging && root.wrapper) {
                        isDragging = false;
                        root.wrapper.endDrag();
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                // Orange circular icon badge (Apple Reminders signature look)
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: "#ff9500"

                    Text {
                        anchors.centerIn: parent
                        text: "󰄟"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: "#ffffff"
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: "Reminders"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                    Text {
                        text: root.currentMonthName
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Medium
                    }
                }
            }
        }

        // Reminders List for Current Month (Clean display - No clicks)
        Flickable {
            width: parent.width
            height: parent.height - 38
            contentWidth: width
            contentHeight: remColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: remColumn
                width: parent.width
                spacing: 5

                Repeater {
                    model: root.monthReminders.slice(0, 7)
                    delegate: Rectangle {
                        width: parent.width
                        height: 30
                        radius: 7
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.color: Qt.rgba(255, 255, 255, 0.05)
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 7

                            // Category / Reminder Indicator
                            Item {
                                readonly property string catLow: (modelData.category || "").toLowerCase()
                                readonly property string titleLow: (modelData.title || "").toLowerCase()
                                readonly property string notesLow: (modelData.notes || "").toLowerCase()
                                readonly property string logoLow: (modelData.logo || "").toLowerCase()
                                readonly property bool isSara: catLow === "sara" || titleLow.indexOf("sara") !== -1
                                readonly property bool isMarvel: catLow === "marvel" || titleLow.indexOf("doomsday") !== -1 || titleLow.indexOf("marvel") !== -1
                                readonly property bool isF1: catLow === "f1" || titleLow.indexOf("formula 1") !== -1 || titleLow.indexOf("grand prix") !== -1
                                readonly property bool isCP: catLow === "colgate-palmolive" || catLow === "colgate"
                                readonly property bool isSchool: catLow === "school" || catLow === "troyanos"
                                readonly property bool isCode: catLow === "projects" || catLow === "free lance" || catLow === "free-lance" || catLow === "freelance"
                                readonly property bool isCommunity: catLow === "community"
                                readonly property bool isPersonal: catLow === "personal"
                                readonly property bool isWorkshops: catLow === "workshops" || catLow === "workshop"

                                readonly property string iconSource: {
                                    if (isSara) return "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/holiday-heart.svg";
                                    if (isMarvel) return "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg";
                                    if (isF1) return "file:///home/ferram/.local/share/icons/f1.svg";
                                    if (isCP) return "file:///home/ferram/.local/share/icons/cp.svg";
                                    if (isSchool) return "file:///home/ferram/.local/share/icons/troyanos.svg";
                                    if (isPersonal) return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23f97316' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><path d='M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/></svg>";
                                    if (isWorkshops) return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%238b5cf6' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><path d='M2 3h20'/><path d='M21 3v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V3'/><path d='m7 21 5-5 5 5'/></svg>";
                                    if (isCode) {
                                        let hex = catLow === "projects" ? "%2314b8a6" : "%2306b6d4";
                                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + hex + "' stroke-width='2.4' stroke-linecap='round' stroke-linejoin='round'><path d='m18 16 4-4-4-4'/><path d='m6 8-4 4 4 4'/><path d='m14.5 4-5 16'/></svg>";
                                    }
                                    if (isCommunity) {
                                        if (logoLow === "fof-qro") return "file://" + Quickshell.shellPath("icons/community-fof-qro.svg");
                                        if (logoLow === "claude") return "file://" + Quickshell.shellPath("icons/claude.svg");
                                        if (logoLow === "devin") return "file:///usr/share/pixmaps/devin-desktop.png";
                                        if (logoLow === "gdg") return "file://" + Quickshell.shellPath("icons/community-gdg.svg");
                                        if (logoLow === "default") return "file://" + Quickshell.shellPath("icons/community-default.svg");
                                        let full = titleLow + " " + notesLow;
                                        if (full.indexOf("figma") !== -1 || full.indexOf("fof") !== -1) return "file://" + Quickshell.shellPath("icons/community-fof-qro.svg");
                                        if (full.indexOf("claude") !== -1 || full.indexOf("anthropic") !== -1) return "file://" + Quickshell.shellPath("icons/claude.svg");
                                        if (full.indexOf("devin") !== -1 || full.indexOf("cognition") !== -1) return "file:///usr/share/pixmaps/devin-desktop.png";
                                        if (full.indexOf("gdg") !== -1 || full.indexOf("google developer") !== -1 || full.indexOf("devfest") !== -1 || full.indexOf("google") !== -1) return "file://" + Quickshell.shellPath("icons/community-gdg.svg");
                                        return "file://" + Quickshell.shellPath("icons/community-default.svg");
                                    }
                                    return "";
                                }

                                width: isSara ? 11 : (isMarvel ? 16 : (isF1 ? 12 : (isCP ? 11 : (isSchool ? 10 : ((isCode || isCommunity || isPersonal || isWorkshops) ? 12 : 8)))))
                                height: isSara ? 11 : (isMarvel ? 8 : (isF1 ? 8 : (isCP ? 8 : (isSchool ? 10 : ((isCode || isCommunity || isPersonal || isWorkshops) ? 12 : 8)))))
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    visible: parent.iconSource === ""
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#38bdf8"
                                }

                                Image {
                                    visible: parent.iconSource !== ""
                                    anchors.fill: parent
                                    source: parent.iconSource
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                            }

                            // Optional photo thumbnail
                            Rectangle {
                                visible: !!(modelData.photo && modelData.photo.trim().length > 0)
                                width: 22
                                height: 22
                                radius: 4
                                clip: true
                                color: "black"
                                border.color: Qt.rgba(255, 255, 255, 0.15)
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    anchors.fill: parent
                                    source: (modelData.photo && modelData.photo.trim().length > 0) ? ((modelData.photo.startsWith("http") || modelData.photo.startsWith("file://")) ? modelData.photo : ("file://" + modelData.photo)) : ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }

                            // Reminder Title & Schedule
                            Column {
                                width: parent.width - 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: modelData.title || "Reminder"
                                    color: theme.text
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Row {
                                    spacing: 4

                                    Text {
                                        // Format date: e.g. "Oct 23"
                                        text: {
                                            let d = modelData.date ? modelData.date.split("-") : [];
                                            let mNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                                            let mIdx = (d.length === 3) ? (parseInt(d[1], 10) - 1) : -1;
                                            let dayStr = (mIdx >= 0 && mIdx < 12) ? (mNames[mIdx] + " " + parseInt(d[2], 10)) : "";
                                            return (dayStr ? dayStr + (modelData.time ? " • " + modelData.time : "") : (modelData.time || ""));
                                        }
                                        color: theme.textDim
                                        font.family: theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Normal
                                    }

                                    Text {
                                        text: "• " + (modelData.category || "")
                                        color: theme.textDim
                                        font.family: theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Normal
                                        visible: !!modelData.category
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state for current month
                Item {
                    width: parent.width
                    height: 90
                    visible: root.currentMonthCount === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰄟"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            color: theme.textDim
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No Reminders This Month"
                            color: theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
