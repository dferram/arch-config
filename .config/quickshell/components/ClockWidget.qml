import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Item {
    id: root

    Theme { id: theme }

    required property var parentWindow
    property string activePopupId: ""
    signal togglePopup(string id)

    implicitHeight: pill.implicitHeight
    implicitWidth: pill.implicitWidth

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    property string uptimeStr: "Up"
    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (txt.startsWith("up ")) txt = txt.substring(3);
                root.uptimeStr = txt;
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: uptimeProc.running = true
    }

    // Time & Date strings
    property string timeStr: Qt.formatDateTime(clock.date, "hh:mm")
    property string secondsStr: Qt.formatDateTime(clock.date, "ss")
    property string dateShortStr: Qt.formatDateTime(clock.date, "ddd, MMM d")
    property string dateFullStr: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy")

    // Pill in the top bar (Pure clean time & date text, no redundant icon)
    BarPill {
        id: pill
        iconSource: ""
        text: root.timeStr
        subText: root.dateShortStr
        accentColor: theme.blue
        active: root.activePopupId === "clock"
        customPadding: 12

        onClicked: {
            root.togglePopup("clock");
        }
    }

    // Calendar Navigation State
    property int navYear: clock.date.getFullYear()
    property int navMonth: clock.date.getMonth() // 0 to 11
    property string selectedDateStr: Qt.formatDate(clock.date, "yyyy-MM-dd")

    function prevMonth() {
        if (navMonth === 0) {
            navMonth = 11;
            navYear -= 1;
        } else {
            navMonth -= 1;
        }
    }

    function nextMonth() {
        if (navMonth === 11) {
            navMonth = 0;
            navYear += 1;
        } else {
            navMonth += 1;
        }
    }

    function goToToday() {
        let d = new Date();
        navYear = d.getFullYear();
        navMonth = d.getMonth();
        selectedDateStr = Qt.formatDate(d, "yyyy-MM-dd");
    }

    // Month Names Array
    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    // Distinct Category Colors
    readonly property var categoryColors: ({
        "Colgate-Palmolive": "#ef4444",
        "Projects": "#06b6d4",
        "School": "#a855f7",
        "Personal": "#10b981",
        "Health": "#f59e0b",
        "Urgent": "#f97316"
    })

    function getCategoryColor(cat) {
        if (cat === "All") return theme.frost;
        return categoryColors[cat] || theme.textSub;
    }

    property string selectedCategory: "All"
    property bool showAddForm: false

    // Reminders Data
    property var allReminders: []

    Process {
        id: loadRemindersProc
        command: ["/home/ferram/.local/bin/hypr-reminders", "list"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    root.allReminders = JSON.parse(txt);
                } catch(e) {
                    console.log("Error parsing reminders:", e);
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!loadRemindersProc.running) loadRemindersProc.running = true;
        }
    }

    function reloadReminders() {
        loadRemindersProc.running = false;
        loadRemindersProc.running = true;
    }

    Process {
        id: actionProc
        onExited: {
            root.reloadReminders();
        }
    }

    function addReminder(title, dateStr, timeStr, category, notes) {
        if (!title.trim()) return;
        actionProc.running = false;
        actionProc.command = [
            "/home/ferram/.local/bin/hypr-reminders", "add",
            title.trim(),
            "--date", dateStr,
            "--time", timeStr,
            "--category", category,
            "--notes", notes || ""
        ];
        actionProc.running = true;
        showAddForm = false;
    }

    function toggleReminder(remId) {
        actionProc.running = false;
        actionProc.command = ["/home/ferram/.local/bin/hypr-reminders", "toggle", remId];
        actionProc.running = true;
    }

    function deleteReminder(remId) {
        actionProc.running = false;
        actionProc.command = ["/home/ferram/.local/bin/hypr-reminders", "delete", remId];
        actionProc.running = true;
    }

    function adjustTime(deltaMinutes) {
        let cur = (timeInput && timeInput.text) ? timeInput.text : "12:00";
        let parts = cur.split(":");
        let h = 12, m = 0;
        if (parts.length === 2) {
            h = parseInt(parts[0], 10) || 0;
            m = parseInt(parts[1], 10) || 0;
        }
        let total = h * 60 + m + deltaMinutes;
        while (total < 0) total += 24 * 60;
        total = total % (24 * 60);
        let newH = String(Math.floor(total / 60)).padStart(2, '0');
        let newM = String(total % 60).padStart(2, '0');
        if (timeInput) timeInput.text = newH + ":" + newM;
    }

    function hasReminders(dStr) {
        if (!allReminders) return false;
        for (let i = 0; i < allReminders.length; i++) {
            if (allReminders[i].date === dStr && !allReminders[i].done) return true;
        }
        return false;
    }

    function getDayCategories(dStr) {
        if (!allReminders) return [];
        let cats = [];
        for (let i = 0; i < allReminders.length; i++) {
            let r = allReminders[i];
            if (r.date === dStr && !r.done) {
                let cat = r.category || "Colgate-Palmolive";
                if (cats.indexOf(cat) === -1) {
                    cats.push(cat);
                    if (cats.length >= 3) break;
                }
            }
        }
        return cats;
    }

    function remindersForSelectedDate() {
        if (!allReminders) return [];
        let list = [];
        for (let i = 0; i < allReminders.length; i++) {
            let r = allReminders[i];
            if (r.date === selectedDateStr) {
                if (selectedCategory === "All" || r.category === selectedCategory) {
                    list.push(r);
                }
            }
        }
        return list;
    }

    function formatSelectedDateHeading(dateStr) {
        if (!dateStr) return "";
        let parts = dateStr.split("-");
        if (parts.length !== 3) return dateStr;
        let y = parseInt(parts[0], 10);
        let m = parseInt(parts[1], 10) - 1;
        let d = parseInt(parts[2], 10);
        let dt = new Date(y, m, d);

        let today = new Date();
        let todayStr = Qt.formatDate(today, "yyyy-MM-dd");

        let tomorrow = new Date();
        tomorrow.setDate(today.getDate() + 1);
        let tomorrowStr = Qt.formatDate(tomorrow, "yyyy-MM-dd");

        let yesterday = new Date();
        yesterday.setDate(today.getDate() - 1);
        let yesterdayStr = Qt.formatDate(yesterday, "yyyy-MM-dd");

        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
        let monthNamesShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

        let dayName = dayNames[dt.getDay()];
        let monthName = monthNamesShort[m];

        if (dateStr === todayStr) {
            return "Today • " + dayName + ", " + monthName + " " + d;
        } else if (dateStr === tomorrowStr) {
            return "Tomorrow • " + dayName + ", " + monthName + " " + d;
        } else if (dateStr === yesterdayStr) {
            return "Yesterday • " + dayName + ", " + monthName + " " + d;
        } else {
            return dayName + ", " + monthName + " " + d;
        }
    }

    function daySummaryText() {
        if (!allReminders) return "No events scheduled";
        let count = 0;
        let doneCount = 0;
        for (let i = 0; i < allReminders.length; i++) {
            let r = allReminders[i];
            if (r.date === selectedDateStr) {
                if (selectedCategory === "All" || r.category === selectedCategory) {
                    count++;
                    if (r.done) doneCount++;
                }
            }
        }
        if (count === 0) {
            return selectedCategory === "All" ? "No scheduled events" : "No " + selectedCategory + " events";
        }
        let pending = count - doneCount;
        if (pending === 0) {
            return count === 1 ? "1 task completed" : count + " tasks completed";
        }
        return count + (count === 1 ? " event" : " events") + " • " + pending + " pending";
    }

    // Detailed Popover Card with Full Calendar & Reminders
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "clock"
        implicitWidth: 390
        implicitHeight: Math.min(690, cardLayout.implicitHeight + 28)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentHeight: cardLayout.implicitHeight
                clip: true

                Column {
                    id: cardLayout
                    width: parent.width
                    spacing: 12

                    // 1. Clock Header Display
                    Column {
                        width: parent.width
                        spacing: 2

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4

                            Text {
                                text: root.timeStr
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 28
                                font.weight: Font.Bold
                            }

                            Text {
                                text: ":" + root.secondsStr
                                color: theme.frost
                                font.family: theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                anchors.baseline: parent.children[0].baseline
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.dateFullStr
                            color: theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 5

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: theme.green
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Uptime: " + root.uptimeStr
                                color: theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: theme.borderSubtle
                    }

                    // 2. Calendar Month & Grid Container
                    Rectangle {
                        width: parent.width
                        implicitHeight: calCol.implicitHeight + 18
                        color: theme.surface
                        radius: theme.radiusSmall
                        border.color: theme.borderSubtle
                        border.width: 1

                        Column {
                            id: calCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 8

                            // Month Navigation Header (Cleanly anchored Left & Right)
                            Item {
                                width: parent.width
                                height: 26

                                // Left: Month and Year Title
                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        text: root.monthNames[root.navMonth]
                                        color: theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        text: root.navYear
                                        color: theme.textMuted
                                        font.family: theme.fontFamily
                                        font.pixelSize: 15
                                        font.weight: Font.Normal
                                    }
                                }

                                // Right: Header Navigation Controls (Today + Prev + Next)
                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    // "Today" button
                                    Rectangle {
                                        width: 48
                                        height: 24
                                        radius: 12
                                        property bool isCurMonth: root.navYear === clock.date.getFullYear() && root.navMonth === clock.date.getMonth()
                                        color: todayMa.containsMouse ? theme.surfaceHover : (isCurMonth ? theme.surface : Qt.rgba(255, 255, 255, 0.12))
                                        border.color: todayMa.containsMouse ? theme.borderGlow : theme.borderSubtle
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Today"
                                            color: parent.isCurMonth ? theme.textSub : theme.frost
                                            font.family: theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: todayMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.goToToday()
                                        }
                                    }

                                    // Previous Month Button
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: prevMa.containsMouse ? theme.surfaceHover : "transparent"
                                        border.color: prevMa.containsMouse ? theme.border : "transparent"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "‹"
                                            color: prevMa.containsMouse ? theme.text : theme.textSub
                                            font.family: theme.fontFamily
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: prevMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.prevMonth()
                                        }
                                    }

                                    // Next Month Button
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: nextMa.containsMouse ? theme.surfaceHover : "transparent"
                                        border.color: nextMa.containsMouse ? theme.border : "transparent"
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "›"
                                            color: nextMa.containsMouse ? theme.text : theme.textSub
                                            font.family: theme.fontFamily
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: nextMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.nextMonth()
                                        }
                                    }
                                }
                            }

                            // Day of week headers (7 equal columns)
                            Row {
                                width: parent.width
                                spacing: 0
                                Repeater {
                                    model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                                    Item {
                                        width: calCol.width / 7
                                        height: 20
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: (index >= 5) ? theme.textDim : theme.textMuted
                                            font.family: theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }

                            // 42-day Grid (6 full weeks, centered, dynamic width)
                            Grid {
                                id: daysGrid
                                width: parent.width
                                columns: 7
                                rowSpacing: 4

                                property int curYear: clock.date.getFullYear()
                                property int curMonth: clock.date.getMonth()
                                property int curDay: clock.date.getDate()

                                property int firstDayIndex: (new Date(root.navYear, root.navMonth, 1).getDay() + 6) % 7
                                property int daysInNavMonth: new Date(root.navYear, root.navMonth + 1, 0).getDate()
                                property int daysInPrevMonth: new Date(root.navYear, root.navMonth, 0).getDate()

                                Repeater {
                                    model: 42
                                    Item {
                                        id: dayCell
                                        width: daysGrid.width / 7
                                        height: 30

                                        // Compute cell date information
                                        property int offset: index - daysGrid.firstDayIndex
                                        property bool isPrevMonth: offset < 0
                                        property bool isNextMonth: offset >= daysGrid.daysInNavMonth
                                        property bool isCurrentMonth: !isPrevMonth && !isNextMonth

                                        property int dayNum: {
                                            if (isPrevMonth) {
                                                return daysGrid.daysInPrevMonth + offset + 1;
                                            } else if (isNextMonth) {
                                                return offset - daysGrid.daysInNavMonth + 1;
                                            } else {
                                                return offset + 1;
                                            }
                                        }

                                        property string dateStr: {
                                            let y = root.navYear;
                                            let m = root.navMonth + 1;
                                            if (isPrevMonth) {
                                                m -= 1;
                                                if (m < 1) { m = 12; y -= 1; }
                                            } else if (isNextMonth) {
                                                m += 1;
                                                if (m > 12) { m = 1; y += 1; }
                                            }
                                            let mm = String(m).padStart(2, '0');
                                            let dd = String(dayNum).padStart(2, '0');
                                            return y + "-" + mm + "-" + dd;
                                        }

                                        property bool isToday: isCurrentMonth && (dayNum === daysGrid.curDay) && (root.navMonth === daysGrid.curMonth) && (root.navYear === daysGrid.curYear)
                                        property bool isSelected: dateStr === root.selectedDateStr
                                        property var dayCats: root.getDayCategories(dateStr)

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 28
                                            height: 28
                                            radius: 8

                                            color: {
                                                if (dayCell.isSelected && dayCell.isToday) return Qt.rgba(255, 255, 255, 0.22);
                                                if (dayCell.isSelected) return Qt.rgba(255, 255, 255, 0.16);
                                                if (dayCell.isToday) return Qt.rgba(255, 255, 255, 0.08);
                                                if (dayCellMa.containsMouse) return theme.surfaceHover;
                                                return "transparent";
                                            }

                                            border.color: {
                                                if (dayCell.isSelected) return theme.frost;
                                                if (dayCell.isToday) return theme.borderGlow;
                                                if (dayCellMa.containsMouse) return theme.border;
                                                return "transparent";
                                            }
                                            border.width: dayCell.isSelected ? 1.5 : (dayCell.isToday ? 1 : 0)

                                            // Day number text
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.top: parent.top
                                                anchors.topMargin: dayCell.dayCats.length > 0 ? 3 : 6
                                                text: dayCell.dayNum
                                                color: {
                                                    if (dayCell.isSelected || dayCell.isToday) return theme.text;
                                                    if (!dayCell.isCurrentMonth) return theme.textDim;
                                                    return theme.textSub;
                                                }
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: (dayCell.isToday || dayCell.isSelected) ? Font.Bold : Font.Normal
                                            }

                                            // Category dots row (up to 3 distinct category dots)
                                            Row {
                                                visible: dayCell.dayCats.length > 0
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 2.5

                                                Repeater {
                                                    model: dayCell.dayCats
                                                    Rectangle {
                                                        width: 3.5
                                                        height: 3.5
                                                        radius: 2
                                                        color: root.getCategoryColor(modelData)
                                                    }
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: dayCellMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.selectedDateStr = dayCell.dateStr;
                                                if (dayCell.isPrevMonth) root.prevMonth();
                                                else if (dayCell.isNextMonth) root.nextMonth();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. Day Detail Card Container
                    Rectangle {
                        width: parent.width
                        implicitHeight: dayDetailCol.implicitHeight + 20
                        color: theme.surface
                        radius: theme.radiusSmall
                        border.color: theme.borderSubtle
                        border.width: 1

                        Column {
                            id: dayDetailCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10

                            // Day Detail Header (Cleanly anchored Left & Right)
                            Item {
                                width: parent.width
                                height: 28

                                Column {
                                    anchors.left: parent.left
                                    anchors.right: addBtnRect.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: root.formatSelectedDateHeading(root.selectedDateStr)
                                        color: theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.daySummaryText()
                                        color: theme.textMuted
                                        font.family: theme.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                // Add / Close Button
                                Rectangle {
                                    id: addBtnRect
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.showAddForm ? 64 : 76
                                    height: 24
                                    radius: 12
                                    color: root.showAddForm
                                        ? (addBtnMa.containsMouse ? Qt.rgba(255, 69, 58, 0.25) : Qt.rgba(255, 69, 58, 0.15))
                                        : (addBtnMa.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.1))
                                    border.color: root.showAddForm
                                        ? theme.red
                                        : (addBtnMa.containsMouse ? theme.borderGlow : theme.borderSubtle)
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: root.showAddForm ? "✕" : "+"
                                            color: root.showAddForm ? theme.red : theme.frost
                                            font.pixelSize: root.showAddForm ? 10 : 12
                                            font.weight: Font.Bold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: root.showAddForm ? "Close" : "New Event"
                                            color: root.showAddForm ? theme.red : theme.text
                                            font.family: theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: addBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.showAddForm = !root.showAddForm;
                                            if (root.showAddForm) {
                                                if (root.selectedCategory !== "All") {
                                                    addFormRect.formCat = root.selectedCategory;
                                                }
                                                Qt.callLater(() => titleInput.forceActiveFocus());
                                            }
                                        }
                                    }
                                }
                            }

                            // Category Filter Segmented Pills (Flow Layout)
                            Flow {
                                width: parent.width
                                spacing: 5

                                Repeater {
                                    model: ["All", "Colgate-Palmolive", "Projects", "School", "Personal", "Health", "Urgent"]
                                    Rectangle {
                                        id: segPill
                                        property bool isAct: root.selectedCategory === modelData
                                        property color catCol: root.getCategoryColor(modelData)
                                        width: segRow.implicitWidth + 14
                                        height: 22
                                        radius: 11

                                        color: {
                                            if (isAct) {
                                                if (modelData === "All") return Qt.rgba(255, 255, 255, 0.18);
                                                return Qt.rgba(catCol.r, catCol.g, catCol.b, 0.2);
                                            }
                                            return segMa.containsMouse ? theme.surfaceHover : "transparent";
                                        }

                                        border.color: {
                                            if (isAct) {
                                                if (modelData === "All") return theme.frost;
                                                return catCol;
                                            }
                                            if (segMa.containsMouse) {
                                                return Qt.rgba(catCol.r, catCol.g, catCol.b, 0.4);
                                            }
                                            return theme.borderSubtle;
                                        }
                                        border.width: 1

                                        Row {
                                            id: segRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            // Category Dot
                                            Rectangle {
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: segPill.catCol
                                                opacity: segPill.isAct ? 1.0 : 0.6
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData === "All" ? "All" : modelData
                                                color: {
                                                    if (segPill.isAct) {
                                                        return modelData === "All" ? theme.text : segPill.catCol;
                                                    }
                                                    return segMa.containsMouse ? theme.textSub : theme.textMuted;
                                                }
                                                font.family: theme.fontFamily
                                                font.pixelSize: 9
                                                font.weight: segPill.isAct ? Font.Bold : Font.Normal
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: segMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.selectedCategory = modelData
                                        }
                                    }
                                }
                            }

                            // Inline Add Form (if showAddForm)
                            Rectangle {
                                id: addFormRect
                                visible: root.showAddForm
                                width: parent.width
                                implicitHeight: addCol.implicitHeight + 16
                                color: theme.bgDark
                                radius: theme.radiusSmall
                                border.color: titleError ? theme.red : theme.borderGlow
                                border.width: 1

                                property string formCat: "Colgate-Palmolive"
                                property bool titleError: false

                                function doSave() {
                                    let t = titleInput.text.trim();
                                    if (!t) {
                                        addFormRect.titleError = true;
                                        titleInput.forceActiveFocus();
                                        return;
                                    }
                                    root.addReminder(
                                        t,
                                        root.selectedDateStr,
                                        timeInput.text,
                                        addFormRect.formCat,
                                        ""
                                    );
                                    titleInput.text = "";
                                    addFormRect.titleError = false;
                                }

                                Column {
                                    id: addCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 8

                                    // Form Header with Date
                                    Row {
                                        width: parent.width
                                        spacing: 4

                                        Text {
                                            text: "Schedule Event • " + root.selectedDateStr
                                            color: theme.frost
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            width: parent.width - 240
                                            height: 1
                                        }

                                        Text {
                                            visible: addFormRect.titleError
                                            text: "Title is required!"
                                            color: theme.red
                                            font.family: theme.fontFamily
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }
                                    }

                                    // Title input
                                    Rectangle {
                                        width: parent.width
                                        height: 28
                                        radius: 6
                                        color: theme.surface
                                        border.color: addFormRect.titleError ? theme.red : (titleInput.activeFocus ? theme.frost : theme.border)
                                        border.width: 1

                                        TextInput {
                                            id: titleInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            anchors.topMargin: 5
                                            anchors.bottomMargin: 5
                                            color: theme.text
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            focus: root.showAddForm
                                            clip: true
                                            selectByMouse: true

                                            onTextChanged: {
                                                if (addFormRect.titleError && text.trim().length > 0) {
                                                    addFormRect.titleError = false;
                                                }
                                            }

                                            Keys.onReturnPressed: addFormRect.doSave()
                                            Keys.onEnterPressed: addFormRect.doSave()
                                            Keys.onEscapePressed: {
                                                root.showAddForm = false;
                                                addFormRect.titleError = false;
                                            }

                                            Text {
                                                anchors.fill: parent
                                                visible: !parent.text
                                                text: addFormRect.titleError ? "Title is required! Type here..." : "Event title or task name..."
                                                color: addFormRect.titleError ? theme.red : theme.textDim
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            z: -1
                                            onClicked: titleInput.forceActiveFocus()
                                        }
                                    }

                                    // Time and Category selector
                                    Row {
                                        width: parent.width
                                        spacing: 8

                                        // Time input with stepper buttons
                                        Row {
                                            spacing: 3
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                width: 58
                                                height: 24
                                                radius: 6
                                                color: theme.surface
                                                border.color: timeInput.activeFocus ? theme.frost : theme.borderSubtle
                                                border.width: 1

                                                TextInput {
                                                    id: timeInput
                                                    anchors.fill: parent
                                                    anchors.margins: 3
                                                    text: Qt.formatDateTime(new Date(Date.now() + 300000), "hh:mm")
                                                    color: theme.text
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    horizontalAlignment: TextInput.AlignHCenter
                                                    selectByMouse: true

                                                    Keys.onUpPressed: root.adjustTime(15)
                                                    Keys.onDownPressed: root.adjustTime(-15)
                                                    Keys.onReturnPressed: addFormRect.doSave()
                                                    Keys.onEnterPressed: addFormRect.doSave()
                                                }
                                            }

                                            // Time stepper buttons (+ / -)
                                            Column {
                                                spacing: 2
                                                anchors.verticalCenter: parent.verticalCenter

                                                Rectangle {
                                                    width: 16
                                                    height: 11
                                                    radius: 3
                                                    color: tUpMa.containsMouse ? theme.surfaceHover : theme.surface
                                                    border.color: theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "▲"
                                                        color: theme.textSub
                                                        font.pixelSize: 6
                                                    }
                                                    MouseArea {
                                                        id: tUpMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.adjustTime(15)
                                                    }
                                                }

                                                Rectangle {
                                                    width: 16
                                                    height: 11
                                                    radius: 3
                                                    color: tDownMa.containsMouse ? theme.surfaceHover : theme.surface
                                                    border.color: theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "▼"
                                                        color: theme.textSub
                                                        font.pixelSize: 6
                                                    }
                                                    MouseArea {
                                                        id: tDownMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.adjustTime(-15)
                                                    }
                                                }
                                            }
                                        }

                                        // Category pills in form (Flow layout)
                                        Flow {
                                            width: parent.width - 90
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter

                                            Repeater {
                                                model: ["Colgate-Palmolive", "Projects", "School", "Personal", "Health", "Urgent"]
                                                Rectangle {
                                                    id: formCatPill
                                                    property bool sel: addFormRect.formCat === modelData
                                                    property color catCol: root.getCategoryColor(modelData)
                                                    width: formCatTxt.implicitWidth + 12
                                                    height: 22
                                                    radius: 11

                                                    color: sel ? Qt.rgba(catCol.r, catCol.g, catCol.b, 0.22) : theme.surface
                                                    border.color: sel ? catCol : theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        id: formCatTxt
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: parent.sel ? parent.catCol : (fCatMa.containsMouse ? theme.textSub : theme.textMuted)
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 9
                                                        font.weight: parent.sel ? Font.Bold : Font.Normal
                                                    }

                                                    MouseArea {
                                                        id: fCatMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: addFormRect.formCat = modelData
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Save and Cancel buttons
                                    Row {
                                        anchors.right: parent.right
                                        spacing: 6

                                        Rectangle {
                                            width: 60
                                            height: 24
                                            radius: 6
                                            color: cancelMa.containsMouse ? theme.surfaceHover : "transparent"
                                            border.color: theme.borderSubtle
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Cancel"
                                                color: theme.textMuted
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                            }

                                            MouseArea {
                                                id: cancelMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.showAddForm = false;
                                                    addFormRect.titleError = false;
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 76
                                            height: 24
                                            radius: 6
                                            color: saveMa.containsMouse ? theme.text : theme.frost

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Save Event"
                                                color: theme.bgDark
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: saveMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: addFormRect.doSave()
                                            }
                                        }
                                    }
                                }
                            }

                            // 4. Reminders List for Selected Day
                            Column {
                                width: parent.width
                                spacing: 5

                                property var dayItems: root.remindersForSelectedDate()

                                // Empty State Card
                                Rectangle {
                                    visible: parent.dayItems.length === 0 && !root.showAddForm
                                    width: parent.width
                                    height: 72
                                    radius: 8
                                    color: emptyMa.containsMouse ? theme.surfaceHover : Qt.rgba(255, 255, 255, 0.03)
                                    border.color: emptyMa.containsMouse ? theme.borderGlow : theme.borderSubtle
                                    border.width: 1

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        Row {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 6

                                            Image {
                                                width: 15
                                                height: 15
                                                anchors.verticalCenter: parent.verticalCenter
                                                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(theme.textSub) + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><rect x='3' y='4' width='18' height='18' rx='2' ry='2'/><line x1='16' y1='2' x2='16' y2='6'/><line x1='8' y1='2' x2='8' y2='6'/><line x1='3' y1='10' x2='21' y2='10'/></svg>"
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            Text {
                                                text: "No reminders for this day"
                                                color: theme.textSub
                                                font.family: theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "Click \"+ New Event\" to schedule a task"
                                            color: theme.textDim
                                            font.family: theme.fontFamily
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        id: emptyMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.showAddForm = true;
                                            Qt.callLater(() => titleInput.forceActiveFocus());
                                        }
                                    }
                                }

                                // Task Cards
                                Repeater {
                                    model: parent.dayItems
                                    Rectangle {
                                        id: remCard
                                        property color catCol: root.getCategoryColor(modelData.category)
                                        width: dayDetailCol.width
                                        height: 42
                                        radius: 8
                                        color: modelData.done
                                            ? Qt.rgba(255, 255, 255, 0.02)
                                            : (cardMa.containsMouse ? theme.surfaceHover : theme.surface)
                                        border.color: modelData.done
                                            ? theme.borderSubtle
                                            : (cardMa.containsMouse ? theme.borderGlow : theme.border)
                                        border.width: 1
                                        clip: true

                                        // Category colored left accent stripe
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: 3.5
                                            color: remCard.catCol
                                            opacity: modelData.done ? 0.4 : 1.0
                                        }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: delBtn.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 6
                                            spacing: 8

                                            // Checkbox circle
                                            Rectangle {
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: modelData.done ? remCard.catCol : (chkMa.containsMouse ? theme.surfaceHover : "transparent")
                                                border.color: modelData.done ? remCard.catCol : (chkMa.containsMouse ? theme.frost : theme.borderGlow)
                                                border.width: 1.5
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    visible: modelData.done
                                                    anchors.centerIn: parent
                                                    text: "✓"
                                                    color: theme.bgDark
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                }

                                                MouseArea {
                                                    id: chkMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.toggleReminder(modelData.id)
                                                }
                                            }

                                            // Task Details Column (Time, Category, Title)
                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 2
                                                width: parent.width - 26

                                                Row {
                                                    spacing: 5

                                                    // Time badge
                                                    Rectangle {
                                                        height: 14
                                                        width: timeTxt.implicitWidth + 8
                                                        radius: 3
                                                        color: Qt.rgba(255, 255, 255, 0.06)
                                                        border.color: theme.borderSubtle
                                                        border.width: 1

                                                        Text {
                                                            id: timeTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.time
                                                            color: theme.textSub
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 9
                                                            font.weight: Font.DemiBold
                                                        }
                                                    }

                                                    // Category capsule badge
                                                    Rectangle {
                                                        height: 14
                                                        width: catTxt.implicitWidth + 8
                                                        radius: 3
                                                        color: Qt.rgba(remCard.catCol.r, remCard.catCol.g, remCard.catCol.b, 0.15)
                                                        border.color: Qt.rgba(remCard.catCol.r, remCard.catCol.g, remCard.catCol.b, 0.35)
                                                        border.width: 1

                                                        Text {
                                                            id: catTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.category
                                                            color: remCard.catCol
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 8
                                                            font.weight: Font.DemiBold
                                                        }
                                                    }
                                                }

                                                // Title Text
                                                Text {
                                                    width: parent.width
                                                    text: modelData.title
                                                    color: modelData.done ? theme.textDim : theme.text
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: modelData.done ? Font.Normal : Font.Medium
                                                    font.strikeout: modelData.done
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        // Delete Button
                                        Rectangle {
                                            id: delBtn
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: delMa.containsMouse ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.2) : "transparent"
                                            border.color: delMa.containsMouse ? theme.red : "transparent"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: delMa.containsMouse ? theme.red : theme.textDim
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                id: delMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.deleteReminder(modelData.id)
                                            }
                                        }

                                        MouseArea {
                                            id: cardMa
                                            anchors.fill: parent
                                            z: -1
                                            hoverEnabled: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
