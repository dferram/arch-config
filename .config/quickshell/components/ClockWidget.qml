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

    // Pill in the top bar
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

    // Categories Configuration
    readonly property var categoryColors: ({
        "Colgate-Palmolive": "#ef4444",
        "Projects": theme.cyan,
        "School": theme.purple,
        "Personal": theme.green,
        "Health": theme.yellow,
        "Urgent": "#f97316"
    })

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

    // Detailed Popover Card with Full Calendar & Reminders
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "clock"
        implicitWidth: 380
        implicitHeight: Math.min(680, cardLayout.implicitHeight + 28)
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
                                color: theme.blue
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

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Uptime: " + root.uptimeStr
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: theme.borderSubtle
                    }

                    // 2. Calendar Container
                    Rectangle {
                        width: parent.width
                        implicitHeight: calCol.implicitHeight + 20
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

                            // Month Navigation Header
                            Row {
                                width: parent.width

                                // Previous Month Button
                                Rectangle {
                                    width: 28
                                    height: 24
                                    radius: 6
                                    color: prevMa.containsMouse ? theme.surfaceHover : "transparent"
                                    border.color: prevMa.containsMouse ? theme.border : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "◀"
                                        color: theme.textSub
                                        font.pixelSize: 10
                                    }
                                    MouseArea {
                                        id: prevMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.prevMonth()
                                    }
                                }

                                // Month and Year Title
                                Item {
                                    width: parent.width - 120
                                    height: 24

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.monthNames[root.navMonth] + " " + root.navYear
                                        color: theme.blueLight
                                        font.family: theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                }

                                // "Today" button
                                Rectangle {
                                    width: 44
                                    height: 22
                                    radius: 6
                                    color: todayMa.containsMouse ? theme.surfaceHover : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.15)
                                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.4)
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Today"
                                        color: theme.blue
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

                                Item { width: 4; height: 1 }

                                // Next Month Button
                                Rectangle {
                                    width: 28
                                    height: 24
                                    radius: 6
                                    color: nextMa.containsMouse ? theme.surfaceHover : "transparent"
                                    border.color: nextMa.containsMouse ? theme.border : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶"
                                        color: theme.textSub
                                        font.pixelSize: 10
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

                            // Day of week headers (Perfect 7 equal columns)
                            Row {
                                width: parent.width
                                spacing: 0
                                Repeater {
                                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                    Item {
                                        width: calCol.width / 7
                                        height: 18
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: index >= 5 ? theme.textDim : theme.textMuted
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }

                            // 42-day Grid (6 full weeks, perfectly centered, dynamic width)
                            Grid {
                                id: daysGrid
                                width: parent.width
                                columns: 7
                                rowSpacing: 3

                                property int curYear: clock.date.getFullYear()
                                property int curMonth: clock.date.getMonth()
                                property int curDay: clock.date.getDate()

                                property int firstDayIndex: (new Date(root.navYear, root.navMonth, 1).getDay() + 6) % 7
                                property int daysInNavMonth: new Date(root.navYear, root.navMonth + 1, 0).getDate()
                                property int daysInPrevMonth: new Date(root.navYear, root.navMonth, 0).getDate()

                                Repeater {
                                    model: 42
                                    Item {
                                        width: daysGrid.width / 7
                                        height: 26

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
                                        property bool hasTasks: root.hasReminders(dateStr)

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: {
                                                if (parent.isToday) return theme.blue;
                                                if (parent.isSelected) return Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.2);
                                                if (dayCellMa.containsMouse) return theme.surfaceHover;
                                                return "transparent";
                                            }
                                            border.color: {
                                                if (parent.isSelected && !parent.isToday) return theme.blue;
                                                if (dayCellMa.containsMouse) return theme.border;
                                                return "transparent";
                                            }
                                            border.width: parent.isSelected ? 1 : 0

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.parent.dayNum
                                                color: {
                                                    if (parent.parent.isToday) return theme.bgDark;
                                                    if (!parent.parent.isCurrentMonth) return theme.textDim;
                                                    if (parent.parent.isSelected) return theme.blueLight;
                                                    return theme.text;
                                                }
                                                font.pixelSize: 10
                                                font.weight: (parent.parent.isToday || parent.parent.isSelected) ? Font.Bold : Font.Normal
                                            }

                                            // Task dot indicator
                                            Rectangle {
                                                visible: parent.parent.hasTasks
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 1
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 4
                                                height: 4
                                                radius: 2
                                                color: parent.parent.isToday ? theme.bgDark : theme.blue
                                            }
                                        }

                                        MouseArea {
                                            id: dayCellMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.selectedDateStr = parent.dateStr;
                                                if (parent.isPrevMonth) root.prevMonth();
                                                else if (parent.isNextMonth) root.nextMonth();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. Reminders Section Header & Controls
                    Row {
                        width: parent.width
                        height: 26

                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "Reminders"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "(" + root.selectedDateStr + ")"
                                color: theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            width: parent.width - 240
                            height: 1
                        }

                        // Add Button (+ New) - Sleek modern pill design
                        Rectangle {
                            width: 66
                            height: 24
                            radius: 12
                            color: addBtnMa.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.3) : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.15)
                            border.color: addBtnMa.containsMouse ? theme.blueLight : theme.blue
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: root.showAddForm ? "✕" : "+"
                                    color: theme.blue
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.showAddForm ? "Close" : "New"
                                    color: theme.text
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

                    // Category Filter Pills
                    Flow {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: ["All", "Colgate-Palmolive", "Projects", "School", "Personal", "Health", "Urgent"]
                            Rectangle {
                                property bool isAct: root.selectedCategory === modelData
                                width: catText.implicitWidth + 12
                                height: 20
                                radius: 10
                                color: isAct ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : theme.surface
                                border.color: isAct ? theme.blue : theme.borderSubtle
                                border.width: 1

                                Text {
                                    id: catText
                                    anchors.centerIn: parent
                                    text: modelData === "All" ? "All" : modelData
                                    color: {
                                        if (parent.isAct) return theme.blue;
                                        return root.categoryColors[modelData] || theme.textMuted;
                                    }
                                    font.pixelSize: 9
                                    font.weight: parent.isAct ? Font.Bold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedCategory = modelData
                                }
                            }
                        }
                    }

                    // 4. Inline Add Form (if showAddForm)
                    Rectangle {
                        id: addFormRect
                        visible: root.showAddForm
                        width: parent.width
                        implicitHeight: addCol.implicitHeight + 16
                        color: theme.surface
                        radius: theme.radiusSmall
                        border.color: titleError ? theme.red : theme.blue
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
                            spacing: 6

                            // Form Header with Date
                            Row {
                                width: parent.width
                                spacing: 4

                                Text {
                                    text: "New Event • " + root.selectedDateStr
                                    color: theme.blueLight
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }

                                Item {
                                    width: parent.width - 240
                                    height: 1
                                }

                                Text {
                                    visible: addFormRect.titleError
                                    text: "Title is required!"
                                    color: theme.red
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }

                            // Title input
                            Rectangle {
                                width: parent.width
                                height: 26
                                radius: 4
                                color: theme.bgDark
                                border.color: addFormRect.titleError ? theme.red : (titleInput.activeFocus ? theme.blue : theme.border)
                                border.width: 1

                                TextInput {
                                    id: titleInput
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    color: theme.text
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
                                        text: addFormRect.titleError ? "Title is required! Type here..." : "Reminder title..."
                                        color: addFormRect.titleError ? theme.red : theme.textDim
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
                                spacing: 6

                                // Time input with stepper buttons
                                Row {
                                    spacing: 3

                                    Rectangle {
                                        width: 62
                                        height: 24
                                        radius: 4
                                        color: theme.bgDark
                                        border.color: timeInput.activeFocus ? theme.blue : theme.border
                                        border.width: 1

                                        TextInput {
                                            id: timeInput
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            text: Qt.formatDateTime(new Date(Date.now() + 300000), "hh:mm")
                                            color: theme.blue
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
                                        Rectangle {
                                            width: 16
                                            height: 11
                                            radius: 2
                                            color: tUpMa.containsMouse ? theme.surfaceHover : theme.surface
                                            Text {
                                                anchors.centerIn: parent
                                                text: "▲"
                                                color: theme.blue
                                                font.pixelSize: 7
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
                                            radius: 2
                                            color: tDownMa.containsMouse ? theme.surfaceHover : theme.surface
                                            Text {
                                                anchors.centerIn: parent
                                                text: "▼"
                                                color: theme.blue
                                                font.pixelSize: 7
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

                                // Category pills in form (Flow layout for clean multi-row fit)
                                Flow {
                                    width: parent.width - 92
                                    spacing: 4
                                    Repeater {
                                        model: ["Colgate-Palmolive", "Projects", "School", "Personal", "Health", "Urgent"]
                                        Rectangle {
                                            property bool sel: addFormRect.formCat === modelData
                                            width: formCatTxt.implicitWidth + 8
                                            height: 24
                                            radius: 4
                                            color: sel ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.3) : theme.bgDark
                                            border.color: sel ? theme.blue : theme.borderSubtle
                                            border.width: 1

                                            Text {
                                                id: formCatTxt
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: root.categoryColors[modelData] || theme.text
                                                font.pixelSize: 9
                                                font.weight: sel ? Font.Bold : Font.Normal
                                            }

                                            MouseArea {
                                                anchors.fill: parent
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
                                    height: 22
                                    radius: 4
                                    color: cancelMa.containsMouse ? theme.surfaceHover : "transparent"
                                    border.color: theme.borderSubtle
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: theme.textSub
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
                                    width: 70
                                    height: 22
                                    radius: 4
                                    color: saveMa.containsMouse ? theme.blueLight : theme.blue
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Save"
                                        color: theme.bgDark
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

                    // 5. Reminders List for Selected Day
                    Column {
                        width: parent.width
                        spacing: 4

                        property var dayItems: root.remindersForSelectedDate()

                        // Empty State
                        Rectangle {
                            visible: parent.dayItems.length === 0 && !root.showAddForm
                            width: parent.width
                            height: 36
                            radius: theme.radiusSmall
                            color: theme.surface
                            border.color: theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "No reminders for this day"
                                color: theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        // Task Cards
                        Repeater {
                            model: parent.dayItems
                            Rectangle {
                                width: cardLayout.width
                                height: 32
                                radius: 6
                                color: modelData.done ? Qt.rgba(255, 255, 255, 0.04) : theme.surface
                                border.color: modelData.done ? theme.borderSubtle : theme.border
                                border.width: 1

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: delBtn.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    // Checkbox circle
                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: modelData.done ? theme.blue : "transparent"
                                        border.color: theme.blue
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            visible: modelData.done
                                            anchors.centerIn: parent
                                            text: "✓"
                                            color: theme.bgDark
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleReminder(modelData.id)
                                        }
                                    }

                                    // Time badge
                                    Text {
                                        text: modelData.time
                                        color: theme.blueLight
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Category Pill
                                    Rectangle {
                                        width: itemCatTxt.implicitWidth + 8
                                        height: 14
                                        radius: 3
                                        color: Qt.rgba(
                                            (root.categoryColors[modelData.category] || theme.blue).r,
                                            (root.categoryColors[modelData.category] || theme.blue).g,
                                            (root.categoryColors[modelData.category] || theme.blue).b,
                                            0.2
                                        )
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            id: itemCatTxt
                                            anchors.centerIn: parent
                                            text: modelData.category
                                            color: root.categoryColors[modelData.category] || theme.blue
                                            font.pixelSize: 8
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    // Title Text
                                    Text {
                                        width: parent.width - 130
                                        text: modelData.title
                                        color: modelData.done ? theme.textDim : theme.text
                                        font.pixelSize: 10
                                        font.strikeout: modelData.done
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Delete Button
                                Rectangle {
                                    id: delBtn
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: delMa.containsMouse ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.2) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: delMa.containsMouse ? theme.red : theme.textDim
                                        font.pixelSize: 9
                                    }

                                    MouseArea {
                                        id: delMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteReminder(modelData.id)
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
