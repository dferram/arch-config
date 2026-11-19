import QtQuick
import QtQuick.Controls
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
    property var timerService: null
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

    property string timerIconUri: {
        let col = theme.urlColor((root.timerService && root.timerService.finishedCount > 0) ? theme.red : theme.blueLight);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" +
               "<line x1='10' x2='14' y1='2' y2='2'/><line x1='12' x2='15' y1='14' y2='11'/><circle cx='12' cy='14' r='8'/>" +
               "</svg>";
    }

    // Pill in the top bar (Pure clean time & date text, plus live timer SVG + countdown if running)
    BarPill {
        id: pill
        iconSource: (root.timerService && root.timerService.barBadgeText !== "") ? root.timerIconUri : ""
        badgeText: (root.timerService && root.timerService.barBadgeText) ? root.timerService.barBadgeText : ""
        badgeColor: (root.timerService && root.timerService.finishedCount > 0) ? theme.red : theme.blueLight
        text: root.timeStr
        subText: root.dateShortStr
        accentColor: (root.timerService && root.timerService.finishedCount > 0) ? theme.red : theme.blue
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

    // Distinct Category Colors (Every single category has a unique hex color, with Marvel as Doom Green #10b981)
    readonly property var categoryColors: ({
        "F1": "#E10600",
        "Colgate-Palmolive": "#0067fe",
        "Projects": "#14b8a6",
        "Free Lance": "#06b6d4",
        "Workshops": "#8b5cf6",
        "Community": "#f59e0b",
        "School": "#a855f7",
        "Personal": "#f97316",
        "Sara": "#ff2d55",
        "Marvel": "#10b981"
    })

    function getCategoryColor(cat, title) {
        if (cat === "All") return theme.frost;
        let c = (cat || "").toLowerCase();
        let t = (title || "").toLowerCase();
        if (c === "sara" || t.indexOf("sara") !== -1) return "#ff2d55";
        if (c === "marvel" || t.indexOf("doomsday") !== -1 || t.indexOf("marvel") !== -1) return "#10b981";
        if (c === "f1") return "#E10600";
        if (c === "colgate-palmolive") return "#0067fe";
        if (c === "projects") return "#14b8a6";
        if (c === "workshops" || c === "workshop" || t.indexOf("workshop") !== -1) return "#8b5cf6";
        if (c === "community" || t.indexOf("figma") !== -1 || t.indexOf("meetup") !== -1) return "#f59e0b";
        if (c === "free lance" || c === "free-lance" || c === "freelance") return "#06b6d4";
        if (c === "school") return "#a855f7";
        if (c === "personal") return "#f97316";
        return categoryColors[cat] || "#38bdf8";
    }

    readonly property var repeatOptions: [
        { id: "none", label: "Once" },
        { id: "daily", label: "Daily" },
        { id: "weekdays", label: "Weekdays" },
        { id: "weekly", label: "Weekly" },
        { id: "biweekly", label: "Biweekly" },
        { id: "monthly", label: "Monthly" },
        { id: "yearly", label: "Yearly" }
    ]

    function getRepeatLabel(repId) {
        let r = (repId || "none").toLowerCase();
        for (let i = 0; i < repeatOptions.length; i++) {
            if (repeatOptions[i].id === r) return repeatOptions[i].label;
        }
        return "Once";
    }

    readonly property var communityLogos: [
        { id: "auto", label: "Auto", icon: "" },
        { id: "fof-qro", label: "FoF Qro", icon: "file://" + Quickshell.shellPath("icons/community-fof-qro.svg") },
        { id: "claude", label: "Claude", icon: "file://" + Quickshell.shellPath("icons/claude.svg") },
        { id: "devin", label: "Devin", icon: "file:///usr/share/pixmaps/devin-desktop.png" },
        { id: "gdg", label: "GDG", icon: "file://" + Quickshell.shellPath("icons/community-gdg.svg") },
        { id: "default", label: "Generic", icon: "file://" + Quickshell.shellPath("icons/community-default.svg") }
    ]

    function codeIconUri(hexCol) {
        let col = theme.urlColor(hexCol);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.4' stroke-linecap='round' stroke-linejoin='round'>" +
               "<path d='m18 16 4-4-4-4'/><path d='m6 8-4 4 4 4'/><path d='m14.5 4-5 16'/>" +
               "</svg>";
    }

    function personalIconUri() {
        let col = theme.urlColor("#f97316");
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
               "<path d='M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/>" +
               "</svg>";
    }

    function workshopsIconUri() {
        let col = theme.urlColor("#8b5cf6");
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'>" +
               "<path d='M2 3h20'/><path d='M21 3v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V3'/><path d='m7 21 5-5 5 5'/>" +
               "</svg>";
    }

    function resolveCommunityLogo(logoKey, title, notes) {
        let k = (logoKey || "").toLowerCase().trim();
        for (let i = 0; i < communityLogos.length; i++) {
            if (communityLogos[i].id !== "auto" && communityLogos[i].id === k) {
                return communityLogos[i].icon;
            }
        }
        let txt = ((title || "") + " " + (notes || "")).toLowerCase();
        if (txt.indexOf("figma") !== -1 || txt.indexOf("fof") !== -1) {
            return "file://" + Quickshell.shellPath("icons/community-fof-qro.svg");
        }
        if (txt.indexOf("claude") !== -1 || txt.indexOf("anthropic") !== -1) {
            return "file://" + Quickshell.shellPath("icons/claude.svg");
        }
        if (txt.indexOf("devin") !== -1 || txt.indexOf("cognition") !== -1) {
            return "file:///usr/share/pixmaps/devin-desktop.png";
        }
        if (txt.indexOf("gdg") !== -1 || txt.indexOf("google developer") !== -1 || txt.indexOf("devfest") !== -1 || txt.indexOf("google") !== -1) {
            return "file://" + Quickshell.shellPath("icons/community-gdg.svg");
        }
        return "file://" + Quickshell.shellPath("icons/community-default.svg");
    }

    function getCategoryIconMeta(cat, title, notes, logoKey) {
        let c = (cat || "").trim();
        let cLow = c.toLowerCase();
        let tLow = (title || "").toLowerCase();
        if (c === "All") return { source: "", width: 8, height: 8 };
        if (c === "F1") return { source: "file:///home/ferram/.local/share/icons/f1.svg", width: 14, height: 10 };
        if (c === "Colgate-Palmolive") return { source: "file:///home/ferram/.local/share/icons/cp.svg", width: 13, height: 9 };
        if (c === "School") return { source: "file:///home/ferram/.local/share/icons/troyanos.svg", width: 12, height: 12 };
        if (cLow === "sara" || tLow.indexOf("sara") !== -1) return { source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/holiday-heart.svg", width: 12, height: 12 };
        if (cLow === "marvel" || tLow.indexOf("doomsday") !== -1 || tLow.indexOf("marvel") !== -1) return { source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg", width: 18, height: 9 };
        if (cLow === "projects") return { source: codeIconUri("#14b8a6"), width: 13, height: 13 };
        if (cLow === "free lance" || cLow === "free-lance" || cLow === "freelance") return { source: codeIconUri("#06b6d4"), width: 13, height: 13 };
        if (cLow === "personal") return { source: personalIconUri(), width: 13, height: 13 };
        if (cLow === "workshops" || cLow === "workshop") return { source: workshopsIconUri(), width: 13, height: 13 };
        if (cLow === "community") return { source: resolveCommunityLogo(logoKey, title, notes), width: 13, height: 13 };
        return { source: "", width: 8, height: 8 };
    }

    property var baseCategories: ["F1", "Colgate-Palmolive", "Projects", "Free Lance", "Workshops", "Community", "School", "Personal", "Sara", "Marvel"]
    property var customCategories: []
    property var availableCategories: {
        let list = baseCategories.concat(customCategories);
        if (allReminders && Array.isArray(allReminders)) {
            for (let i = 0; i < allReminders.length; i++) {
                let c = allReminders[i].category;
                if (c && list.indexOf(c) === -1) {
                    list.push(c);
                }
            }
        }
        return list;
    }

    Process {
        id: loadCategoriesProc
        command: ["/home/ferram/.local/bin/hypr-reminders", "categories"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt || !txt.startsWith("[")) return;
                try {
                    let parsed = JSON.parse(txt);
                    if (Array.isArray(parsed)) {
                        for (let i = 0; i < parsed.length; i++) {
                            let item = parsed[i];
                            if (root.baseCategories.indexOf(item) === -1 && root.customCategories.indexOf(item) === -1) {
                                root.customCategories.push(item);
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: addCategoryProc
        property string catToAdd: ""
        command: ["/home/ferram/.local/bin/hypr-reminders", "add-category", catToAdd]
        onExited: {
            if (!loadCategoriesProc.running) loadCategoriesProc.running = true;
        }
    }

    function addNewCategory(catName) {
        let c = catName.trim();
        if (!c) return;
        if (root.availableCategories.indexOf(c) === -1) {
            let nextCustom = root.customCategories.slice();
            nextCustom.push(c);
            root.customCategories = nextCustom;
        }
        addCategoryProc.catToAdd = c;
        addCategoryProc.running = false;
        addCategoryProc.running = true;
    }

    // F1 Sound Preview Process
    Process {
        id: f1SoundProc
        command: ["pw-play", "/home/ferram/.local/share/sounds/f1.oga"]
    }

    function playF1Sound() {
        f1SoundProc.running = false;
        f1SoundProc.running = true;
    }

    // F1 Season Race Schedule
    property var f1Calendar: ({})
    readonly property var selectedF1Event: (root.f1Calendar && root.selectedDateStr) ? root.f1Calendar[root.selectedDateStr] : null

    Process {
        id: loadF1CalendarProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "f1-calendar"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    root.f1Calendar = JSON.parse(txt);
                } catch(e) {
                    console.log("Error parsing F1 calendar:", e);
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            if (!loadF1CalendarProc.running) loadF1CalendarProc.running = true;
        }
    }

    property string selectedCategory: "All"
    property bool filterDropdownOpen: false
    property bool showAddForm: false
    property string editingReminderId: ""

    // Zenity File Picker Process for attaching photos to reminders
    Process {
        id: photoPickerProc
        command: ["zenity", "--file-selection", "--title=Select Reminder Photo", "--file-filter=Images (*.png *.jpg *.jpeg *.webp *.svg) | *.png *.jpg *.jpeg *.webp *.svg"]
        stdout: StdioCollector {
            onTextChanged: {
                let p = text.trim();
                if (p) addFormRect.formPhoto = p;
            }
        }
    }

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

    function addReminder(title, dateStr, timeStr, category, notes, photo, repeatVal, logoVal) {
        if (!title.trim()) return;
        actionProc.running = false;
        let cmd = [
            "/home/ferram/.local/bin/hypr-reminders", "add",
            title.trim(),
            "--date", dateStr,
            "--time", timeStr,
            "--category", category,
            "--notes", notes || "",
            "--repeat", repeatVal || "none",
            "--logo", logoVal || ""
        ];
        if (photo && photo.trim()) {
            cmd.push("--photo");
            cmd.push(photo.trim());
        }
        actionProc.command = cmd;
        actionProc.running = true;
        resetForm();
    }

    function editReminder(remId, title, dateStr, timeStr, category, notes, photo, repeatVal, logoVal) {
        if (!remId || !title.trim()) return;
        actionProc.running = false;
        let cmd = [
            "/home/ferram/.local/bin/hypr-reminders", "edit", remId,
            "--title", title.trim(),
            "--date", dateStr,
            "--time", timeStr,
            "--category", category,
            "--notes", notes || "",
            "--photo", photo || "",
            "--repeat", repeatVal || "none",
            "--logo", logoVal || ""
        ];
        actionProc.command = cmd;
        actionProc.running = true;
        resetForm();
    }

    function startEdit(item) {
        if (!item) return;
        editingReminderId = item.id;
        showAddForm = true;
        titleInput.text = item.title || "";
        timeInput.text = item.time || "12:00";
        addFormRect.formCat = item.category || "Colgate-Palmolive";
        addFormRect.formNotes = item.notes || "";
        addFormRect.formPhoto = item.photo || "";
        addFormRect.formRepeat = item.repeat || "none";
        addFormRect.formLogo = item.logo || "auto";
        addFormRect.titleError = false;
        addFormRect.showTimePicker = false;
        addFormRect.formCatDropdownOpen = false;
        Qt.callLater(() => titleInput.forceActiveFocus());
    }

    function resetForm() {
        editingReminderId = "";
        showAddForm = false;
        if (titleInput) titleInput.text = "";
        addFormRect.formNotes = "";
        addFormRect.formPhoto = "";
        addFormRect.formRepeat = "none";
        addFormRect.formLogo = "auto";
        addFormRect.titleError = false;
        addFormRect.showTimePicker = false;
        addFormRect.formCatDropdownOpen = false;
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

    function parseDateParts(dStr) {
        if (!dStr) return null;
        let parts = dStr.split("-");
        if (parts.length !== 3) return null;
        let y = parseInt(parts[0], 10);
        let m = parseInt(parts[1], 10);
        let d = parseInt(parts[2], 10);
        if (isNaN(y) || isNaN(m) || isNaN(d)) return null;
        return { y: y, m: m, d: d, utcMs: Date.UTC(y, m - 1, d) };
    }

    function matchesReminderOnDate(rem, dStr) {
        if (!rem || !rem.date || !dStr) return false;
        let rep = (rem.repeat || "none").toLowerCase();
        if (rep === "" || rep === "none") return rem.date === dStr;

        let s = parseDateParts(rem.date);
        let t = parseDateParts(dStr);
        if (!s || !t) return rem.date === dStr;
        if (t.utcMs < s.utcMs) return false;

        let diffDays = Math.round((t.utcMs - s.utcMs) / 86400000);
        if (rep === "daily") return true;
        if (rep === "weekdays") {
            let dow = new Date(t.utcMs).getUTCDay();
            return dow >= 1 && dow <= 5;
        }
        if (rep === "weekly") return diffDays % 7 === 0;
        if (rep === "biweekly") return diffDays % 14 === 0;
        if (rep === "monthly") {
            let maxDay = new Date(Date.UTC(t.y, t.m, 0)).getUTCDate();
            return t.d === Math.min(s.d, maxDay);
        }
        if (rep === "yearly") {
            if (t.m !== s.m) return false;
            let maxDay = new Date(Date.UTC(t.y, t.m, 0)).getUTCDate();
            return t.d === Math.min(s.d, maxDay);
        }
        return rem.date === dStr;
    }

    function hasReminders(dStr) {
        if (root.f1Calendar && root.f1Calendar[dStr]) return true;
        if (!allReminders) return false;
        for (let i = 0; i < allReminders.length; i++) {
            if (matchesReminderOnDate(allReminders[i], dStr)) return true;
        }
        return false;
    }

    function getDayCategories(dStr) {
        let cats = [];
        if (root.f1Calendar && root.f1Calendar[dStr]) {
            cats.push("F1");
        }
        if (allReminders) {
            for (let i = 0; i < allReminders.length; i++) {
                let r = allReminders[i];
                if (matchesReminderOnDate(r, dStr)) {
                    let cat = r.category || "Colgate-Palmolive";
                    if (cats.indexOf(cat) === -1) {
                        cats.push(cat);
                        if (cats.length >= 3) break;
                    }
                }
            }
        }
        return cats;
    }

    function getDayReminderCount(dStr) {
        if (!allReminders) return 0;
        let count = 0;
        for (let i = 0; i < allReminders.length; i++) {
            let r = allReminders[i];
            if (matchesReminderOnDate(r, dStr)) count++;
        }
        return count;
    }

    function remindersForSelectedDate() {
        if (!allReminders) return [];
        let list = [];
        for (let i = 0; i < allReminders.length; i++) {
            let r = allReminders[i];
            if (matchesReminderOnDate(r, selectedDateStr)) {
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

    // Mexican Holidays Calculation (Official LFT & Traditional Mexican Dates)
    readonly property var selectedHoliday: root.getMexicanHoliday(root.selectedDateStr)

    function getHolidayIcon(hol) {
        if (!hol) return "../icons/google-calendar.svg";
        let k = hol.iconKey || "";
        if (k === "halloween") return "../icons/holiday-halloween.svg";
        if (k === "muertos") return "../icons/holiday-muertos.svg";
        if (k === "christmas") return "../icons/holiday-christmas.svg";
        if (k === "newyear") return "../icons/holiday-newyear.svg";
        if (k === "flag") return "../icons/holiday-flag.svg";
        if (k === "love") return "../icons/holiday-heart.svg";
        return "../icons/google-calendar.svg";
    }

    function getMexicanHoliday(dateStr) {
        if (!dateStr) return null;
        let parts = dateStr.split("-");
        if (parts.length !== 3) return null;
        let y = parseInt(parts[0], 10);
        let m = parseInt(parts[1], 10);
        let d = parseInt(parts[2], 10);

        // Fixed Mexican Holidays & Observances (in English matching Google Calendar)
        let fixed = {
            "1-1": { name: "New Year's Day", isOfficial: true, desc: "National Public Holiday (Federal Labor Law)", iconKey: "newyear" },
            "1-6": { name: "Three Kings' Day (Día de Reyes)", isOfficial: false, desc: "Traditional Mexican celebration of the Magi and Rosca de Reyes", iconKey: "calendar" },
            "2-2": { name: "Candlemas (Día de la Candelaria)", isOfficial: false, desc: "Traditional Tamales Feast & Blessing of the Christ Child", iconKey: "calendar" },
            "2-5": { name: "Constitution Day", isOfficial: false, desc: "Anniversary of Mexico's 1917 Political Constitution", iconKey: "flag" },
            "2-14": { name: "Valentine's Day", isOfficial: false, desc: "Celebration of Love & Friendship", iconKey: "love" },
            "2-24": { name: "Flag Day", isOfficial: false, desc: "National celebration honoring the Mexican Flag", iconKey: "flag" },
            "3-8": { name: "International Women's Day", isOfficial: false, desc: "Global celebration of women's rights and achievements", iconKey: "love" },
            "3-18": { name: "Oil Expropriation Day", isOfficial: false, desc: "Commemoration of the 1938 Petroleum Nationalization", iconKey: "flag" },
            "3-21": { name: "Benito Juárez's Birthday", isOfficial: false, desc: "Anniversary of the Great Reformer of Mexico", iconKey: "flag" },
            "4-30": { name: "Children's Day (Día del Niño)", isOfficial: false, desc: "Festivities honoring children across Mexico", iconKey: "newyear" },
            "5-1": { name: "Labor Day", isOfficial: true, desc: "National Public Holiday (Federal Labor Law)", iconKey: "calendar" },
            "5-5": { name: "Cinco de Mayo / Battle of Puebla", isOfficial: false, desc: "Historic Mexican victory in Puebla (1862)", iconKey: "flag" },
            "5-10": { name: "Mother's Day", isOfficial: false, desc: "National celebration honoring mothers across Mexico", iconKey: "love" },
            "5-15": { name: "Teacher's Day", isOfficial: false, desc: "National tribute recognizing teachers and educators", iconKey: "calendar" },
            "9-13": { name: "Heroic Cadets Day (Niños Héroes)", isOfficial: false, desc: "Defense of Chapultepec Castle (1847)", iconKey: "flag" },
            "9-15": { name: "Cry of Dolores (El Grito)", isOfficial: false, desc: "Independence Eve & traditional Cry of Freedom", iconKey: "flag" },
            "9-16": { name: "Independence Day", isOfficial: true, desc: "National Public Holiday (Federal Labor Law) · Fiesta Patria", iconKey: "flag" },
            "10-12": { name: "Columbus Day (Día de la Raza)", isOfficial: false, desc: "Meeting of Two Worlds and Cultural Diversity", iconKey: "flag" },
            "10-31": { name: "Halloween", isOfficial: false, desc: "All Hallows' Eve celebration", iconKey: "halloween" },
            "11-1": { name: "All Saints' Day", isOfficial: false, desc: "Día de los Angelitos · Day of the Dead celebration", iconKey: "muertos" },
            "11-2": { name: "Day of the Dead (Día de Muertos)", isOfficial: false, desc: "UNESCO Intangible Cultural Heritage of Humanity", iconKey: "muertos" },
            "11-20": { name: "Revolution Day", isOfficial: false, desc: "Anniversary of the 1910 Mexican Revolution", iconKey: "flag" },
            "12-12": { name: "Day of the Virgin of Guadalupe", isOfficial: false, desc: "Patron Saint of Mexico and beloved cultural tradition", iconKey: "love" },
            "12-24": { name: "Christmas Eve (Nochebuena)", isOfficial: false, desc: "Holiday family gathering and celebration", iconKey: "christmas" },
            "12-25": { name: "Christmas Day", isOfficial: true, desc: "National Public Holiday (Federal Labor Law)", iconKey: "christmas" },
            "12-28": { name: "Holy Innocents' Day", isOfficial: false, desc: "Traditional day of good-humored jokes and pranks", iconKey: "newyear" },
            "12-31": { name: "New Year's Eve", isOfficial: false, desc: "Celebration welcoming the New Year", iconKey: "newyear" }
        };

        // Cambio de Poder Ejecutivo Federal cada 6 años (1 de octubre a partir de 2024: 2024, 2030, etc.)
        if (m === 10 && d === 1 && (y % 6 === 2024 % 6)) {
            return {
                name: "Inauguration Day",
                isOfficial: true,
                desc: "National Public Holiday (Federal Labor Law - every 6 years)",
                typeLabel: "Official Holiday",
                badgeColor: "#10b981",
                iconKey: "flag"
            };
        }

        // Puentes oficiales de la Ley Federal del Trabajo (LFT Art. 74):
        // 1er lunes de febrero (en conmemoración del 5 de febrero)
        let febFirstDay = new Date(y, 1, 1).getDay();
        let febMonday = (febFirstDay === 1) ? 1 : ((8 - febFirstDay) % 7 + 1);
        if (m === 2 && d === febMonday) {
            return {
                name: "Constitution Day (Observed)",
                isOfficial: true,
                desc: "National Public Holiday (1st Monday of February)",
                typeLabel: "Official Holiday",
                badgeColor: "#10b981",
                iconKey: "flag"
            };
        }

        // 3er lunes de marzo (en conmemoración del 21 de marzo)
        let marFirstDay = new Date(y, 2, 1).getDay();
        let marMonday1 = (marFirstDay === 1) ? 1 : ((8 - marFirstDay) % 7 + 1);
        let marMonday3 = marMonday1 + 14;
        if (m === 3 && d === marMonday3) {
            return {
                name: "Benito Juárez Day (Observed)",
                isOfficial: true,
                desc: "National Public Holiday (3rd Monday of March)",
                typeLabel: "Official Holiday",
                badgeColor: "#10b981",
                iconKey: "flag"
            };
        }

        // 3er lunes de noviembre (en conmemoración del 20 de noviembre)
        let novFirstDay = new Date(y, 10, 1).getDay();
        let novMonday1 = (novFirstDay === 1) ? 1 : ((8 - novFirstDay) % 7 + 1);
        let novMonday3 = novMonday1 + 14;
        if (m === 11 && d === novMonday3) {
            return {
                name: "Revolution Day (Observed)",
                isOfficial: true,
                desc: "National Public Holiday (3rd Monday of November)",
                typeLabel: "Official Holiday",
                badgeColor: "#10b981",
                iconKey: "flag"
            };
        }

        // Semana Santa (Jueves y Viernes Santo con algoritmo Meeus/Jones)
        let a = y % 19;
        let b = Math.floor(y / 100);
        let c = y % 100;
        let dVal = Math.floor(b / 4);
        let e = b % 4;
        let f = Math.floor((b + 8) / 25);
        let g = Math.floor((b - f + 1) / 3);
        let h = (19 * a + b - dVal - g + 15) % 30;
        let i = Math.floor(c / 4);
        let k = c % 4;
        let l = (32 + 2 * e + 2 * i - h - k) % 7;
        let mVal = Math.floor((a + 11 * h + 22 * l) / 451);
        let easterMonth = Math.floor((h + l - 7 * mVal + 114) / 31);
        let easterDay = ((h + l - 7 * mVal + 114) % 31) + 1;
        let easterDate = new Date(y, easterMonth - 1, easterDay);

        let juevesSanto = new Date(easterDate);
        juevesSanto.setDate(easterDate.getDate() - 3);
        if (m === (juevesSanto.getMonth() + 1) && d === juevesSanto.getDate()) {
            return {
                name: "Maundy Thursday (Jueves Santo)",
                isOfficial: false,
                desc: "Holy Week Observance in Mexico",
                typeLabel: "Observance",
                badgeColor: "#f59e0b",
                iconKey: "calendar"
            };
        }

        let viernesSanto = new Date(easterDate);
        viernesSanto.setDate(easterDate.getDate() - 2);
        if (m === (viernesSanto.getMonth() + 1) && d === viernesSanto.getDate()) {
            return {
                name: "Good Friday (Viernes Santo)",
                isOfficial: false,
                desc: "Holy Week Observance in Mexico",
                typeLabel: "Observance",
                badgeColor: "#f59e0b",
                iconKey: "calendar"
            };
        }

        // Check fixed date
        let key = m + "-" + d;
        if (fixed[key]) {
            let item = fixed[key];
            return {
                name: item.name,
                isOfficial: item.isOfficial,
                desc: item.desc,
                typeLabel: item.isOfficial ? "Official Holiday" : "Observance",
                badgeColor: item.isOfficial ? "#10b981" : "#f59e0b",
                iconKey: item.iconKey || "calendar"
            };
        }

        return null;
    }

    function daySummaryText() {
        let hol = root.getMexicanHoliday(root.selectedDateStr);
        let prefix = hol ? (hol.name + " • ") : "";

        if (!allReminders) return prefix ? (prefix + "No scheduled events") : "No events scheduled";
        let count = 0;
        let doneCount = 0;
        for (let i = 0; i < allReminders.length; i++) {
            let r = allReminders[i];
            if (matchesReminderOnDate(r, selectedDateStr)) {
                if (selectedCategory === "All" || r.category === selectedCategory) {
                    count++;
                    if (r.done) doneCount++;
                }
            }
        }
        if (count === 0) {
            return prefix ? (prefix + (selectedCategory === "All" ? "No scheduled events" : "No " + selectedCategory + " events"))
                          : (selectedCategory === "All" ? "No scheduled events" : "No " + selectedCategory + " events");
        }
        let pending = count - doneCount;
        if (pending === 0) {
            return prefix + (count === 1 ? "1 task completed" : count + " tasks completed");
        }
        return prefix + count + (count === 1 ? " event" : " events") + " • " + pending + " pending";
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
        implicitHeight: Math.min(700, cardLayout.implicitHeight + 38)
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.95
            transformOrigin: Item.Top
            transform: Translate {
                y: popup.visible ? 0 : -6
                Behavior on y { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            }

            Behavior on opacity { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }

            Flickable {
                id: mainScroll
                anchors.fill: parent
                anchors.margins: 14
                contentWidth: width
                contentHeight: cardLayout.implicitHeight
                flickableDirection: Flickable.VerticalFlick
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
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: theme.borderSubtle
                    }

                    // Minimalist Page Dots Indicator (Calendar <-> Timers)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Repeater {
                            model: 2
                            Rectangle {
                                property bool isCur: pageSwipe.currentIndex === index
                                property bool hasAlert: index === 1 && !!(root.timerService && root.timerService.finishedCount > 0)
                                width: isCur ? 16 : 5
                                height: 4
                                radius: 2
                                color: hasAlert ? theme.red : (isCur ? theme.blueLight : (dotMa.containsMouse ? theme.textSub : theme.textDim))

                                MouseArea {
                                    id: dotMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pageSwipe.currentIndex = index
                                }
                            }
                        }
                    }

                    // Page Container (Calendar <-> Timers, no drag or transition animations)
                    Item {
                        width: parent.width
                        implicitHeight: pageSwipe.implicitHeight

                        Timer {
                            id: swipeCooldown
                            interval: 280
                            repeat: false
                        }

                        WheelHandler {
                            orientation: Qt.Horizontal
                            blocking: false
                            acceptedDevices: PointerDevice.AllDevices
                            onWheel: (event) => {
                                let dx = Math.abs(event.pixelDelta.x) > 0 ? event.pixelDelta.x : event.angleDelta.x;
                                let dy = Math.abs(event.pixelDelta.y) > 0 ? event.pixelDelta.y : event.angleDelta.y;
                                if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 10 && !swipeCooldown.running) {
                                    if (dx < 0 && pageSwipe.currentIndex < 1) {
                                        pageSwipe.currentIndex = 1;
                                        swipeCooldown.start();
                                    } else if (dx > 0 && pageSwipe.currentIndex > 0) {
                                        pageSwipe.currentIndex = 0;
                                        swipeCooldown.start();
                                    }
                                    event.accepted = true;
                                } else {
                                    event.accepted = false;
                                }
                            }
                        }

                        Item {
                            id: pageSwipe
                            width: parent.width
                            property int currentIndex: 0
                            implicitHeight: currentIndex === 0 ? calendarTabCol.implicitHeight : timersTabCol.implicitHeight

                            onCurrentIndexChanged: mainScroll.returnToBounds()

                            // PAGE 0: CALENDAR & EVENTS
                            Item {
                                id: calPageItem
                                width: pageSwipe.width
                                implicitHeight: calendarTabCol.implicitHeight
                                visible: pageSwipe.currentIndex === 0

                                Column {
                                    id: calendarTabCol
                                    width: parent.width
                                    spacing: 12

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

                                        scale: todayMa.pressed ? 0.94 : (todayMa.containsMouse ? 1.04 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

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

                                        scale: prevMa.pressed ? 0.88 : (prevMa.containsMouse ? 1.10 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

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

                                        scale: nextMa.pressed ? 0.88 : (nextMa.containsMouse ? 1.10 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

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
                                        property var mexicanHoliday: root.getMexicanHoliday(dateStr)

                                        Item {
                                            id: cellBox
                                            anchors.centerIn: parent
                                            width: 28
                                            height: 28

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 7
                                                visible: !dayCell.isSelected
                                                color: {
                                                    if (dayCellMa.containsMouse) return theme.surfaceHover;
                                                    if (dayCell.mexicanHoliday && dayCell.isCurrentMonth) return Qt.rgba(245/255, 158/255, 11/255, 0.15);
                                                    if (dayCell.isToday) return Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.14);
                                                    return "transparent";
                                                }
                                                border.color: dayCell.isToday ? theme.blue : "transparent"
                                                border.width: 1

                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            CalendarDayTile {
                                                id: selectedTile
                                                anchors.fill: parent
                                                visible: dayCell.isSelected
                                                accentColor: theme.blue
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                anchors.verticalCenterOffset: dayCell.isSelected ? (dayCell.dayCats.length > 0 ? -0.5 : 1) : 0
                                                text: dayCell.dayNum
                                                color: {
                                                    if (!dayCell.isCurrentMonth) return theme.textMuted;
                                                    if (dayCell.isSelected) return selectedTile.autoTextColor;
                                                    if (dayCell.isToday) return theme.blueLight;
                                                    if (dayCell.mexicanHoliday) return "#fbbf24";
                                                    return theme.text;
                                                }
                                                font.family: theme.fontFamily
                                                font.pixelSize: dayCell.isSelected ? 11 : 12
                                                font.weight: (dayCell.isSelected || dayCell.isToday || dayCell.mexicanHoliday) ? Font.Bold : Font.DemiBold
                                            }

                                            Row {
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 2.5
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 2
                                                
                                                Repeater {
                                                    model: Math.min(dayCell.dayCats.length, 3)
                                                    Rectangle {
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        color: dayCell.isSelected ? selectedTile.autoTextColor : root.getCategoryColor(dayCell.dayCats[index])
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
                                    width: addBtnRow.implicitWidth + 18
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
                                        id: addBtnRow
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
                                            if (root.showAddForm) {
                                                root.resetForm();
                                            } else {
                                                root.editingReminderId = "";
                                                root.showAddForm = true;
                                                if (titleInput) titleInput.text = "";
                                                addFormRect.formPhoto = "";
                                                addFormRect.formNotes = "";
                                                addFormRect.formRepeat = "none";
                                                addFormRect.formLogo = "auto";
                                                if (root.selectedCategory !== "All") {
                                                    addFormRect.formCat = root.selectedCategory;
                                                }
                                                Qt.callLater(() => titleInput.forceActiveFocus());
                                            }
                                        }
                                    }
                                }
                            }

                            // Category Filter Dropdown
                            Column {
                                width: parent.width
                                spacing: 4

                                // Dropdown Button
                                Rectangle {
                                    id: filterDropBtn
                                    width: parent.width
                                    height: 30
                                    radius: 7
                                    color: filterDropMa.containsMouse ? theme.surfaceHover : theme.surface
                                    border.color: root.filterDropdownOpen ? theme.frost : theme.borderSubtle
                                    border.width: 1

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 7

                                        Text {
                                            text: "󰈲"
                                            font.family: "GeistMono Nerd Font Propo"
                                            font.pixelSize: 11
                                            color: root.selectedCategory === "All" ? theme.textDim : root.getCategoryColor(root.selectedCategory)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Item {
                                            id: filterBtnIconBox
                                            visible: root.selectedCategory !== "All"
                                            property var iconMeta: root.getCategoryIconMeta(root.selectedCategory, "", "", "")
                                            width: iconMeta.width
                                            height: iconMeta.height
                                            anchors.verticalCenter: parent.verticalCenter

                                            Image {
                                                visible: filterBtnIconBox.iconMeta.source !== ""
                                                anchors.fill: parent
                                                source: filterBtnIconBox.iconMeta.source
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                            }
                                            Rectangle {
                                                visible: filterBtnIconBox.iconMeta.source === ""
                                                anchors.fill: parent
                                                radius: width / 2
                                                color: root.getCategoryColor(root.selectedCategory)
                                            }
                                        }

                                        Text {
                                            text: root.selectedCategory === "All" ? "Filter: All Categories" : ("Filter: " + root.selectedCategory)
                                            color: root.selectedCategory === "All" ? theme.textSub : theme.text
                                            font.family: theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: root.selectedCategory === "All" ? Font.Medium : Font.Bold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    // Right controls: Clear button (if filtered) + Chevron
                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Rectangle {
                                            visible: root.selectedCategory !== "All"
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: clearFMa.containsMouse ? Qt.rgba(255, 255, 255, 0.22) : Qt.rgba(255, 255, 255, 0.08)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                font.pixelSize: 7
                                                color: theme.textMuted
                                            }
                                            MouseArea {
                                                id: clearFMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectedCategory = "All"
                                            }
                                        }

                                        Text {
                                            text: root.filterDropdownOpen ? "▲" : "▼"
                                            color: theme.textDim
                                            font.pixelSize: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: filterDropMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.filterDropdownOpen = !root.filterDropdownOpen
                                    }
                                }

                                // Dropdown List Menu
                                Rectangle {
                                    visible: root.filterDropdownOpen
                                    width: parent.width
                                    implicitHeight: Math.min(210, filterListCol.implicitHeight + 10)
                                    color: theme.bgDark
                                    radius: 7
                                    border.color: theme.borderGlow
                                    border.width: 1
                                    clip: true

                                    Flickable {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        contentHeight: filterListCol.implicitHeight
                                        clip: true

                                        Column {
                                            id: filterListCol
                                            width: parent.width
                                            spacing: 2

                                            Repeater {
                                                model: ["All"].concat(root.availableCategories)
                                                Rectangle {
                                                    id: filterOptRect
                                                    property bool isAct: root.selectedCategory === modelData
                                                    property color catCol: root.getCategoryColor(modelData)
                                                    width: parent.width
                                                    height: 25
                                                    radius: 4
                                                    color: isAct ? Qt.rgba(catCol.r, catCol.g, catCol.b, 0.20) : (fOptMa.containsMouse ? theme.surfaceHover : "transparent")

                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 7

                                                        Item {
                                                            id: filterItemIconBox
                                                            property var iconMeta: root.getCategoryIconMeta(modelData, "", "", "")
                                                            width: iconMeta.source !== "" ? iconMeta.width : 7
                                                            height: iconMeta.source !== "" ? iconMeta.height : 7
                                                            anchors.verticalCenter: parent.verticalCenter

                                                            Image {
                                                                visible: filterItemIconBox.iconMeta.source !== ""
                                                                anchors.fill: parent
                                                                source: filterItemIconBox.iconMeta.source
                                                                fillMode: Image.PreserveAspectFit
                                                                smooth: true
                                                            }
                                                            Rectangle {
                                                                visible: filterItemIconBox.iconMeta.source === ""
                                                                anchors.fill: parent
                                                                radius: width / 2
                                                                color: modelData === "All" ? theme.frost : filterOptRect.catCol
                                                            }
                                                        }

                                                        Text {
                                                            text: modelData === "All" ? "All Categories" : modelData
                                                            color: filterOptRect.isAct ? (modelData === "All" ? theme.frost : filterOptRect.catCol) : (fOptMa.containsMouse ? theme.text : theme.textSub)
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 10
                                                            font.weight: filterOptRect.isAct ? Font.Bold : Font.Normal
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    Text {
                                                        visible: filterOptRect.isAct
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: "✓"
                                                        color: modelData === "All" ? theme.frost : filterOptRect.catCol
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                    }

                                                    MouseArea {
                                                        id: fOptMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.selectedCategory = modelData;
                                                            root.filterDropdownOpen = false;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Inline Add / Edit Form (if showAddForm)
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
                                property string formNotes: ""
                                property string formPhoto: ""
                                property string formRepeat: "none"
                                property string formLogo: "auto"
                                property bool titleError: false
                                property bool showTimePicker: false
                                property bool formCatDropdownOpen: false
                                property string timePickerMode: "hours"

                                function getCurH24() {
                                    let parts = (timeInput && timeInput.text) ? timeInput.text.split(":") : ["12", "00"];
                                    return parseInt(parts[0], 10) || 0;
                                }

                                function getCurMin() {
                                    let parts = (timeInput && timeInput.text) ? timeInput.text.split(":") : ["12", "00"];
                                    return parseInt(parts[1], 10) || 0;
                                }

                                function setTime(h24, min) {
                                    h24 = Math.max(0, Math.min(23, h24));
                                    min = Math.max(0, Math.min(59, min));
                                    let sH = h24 < 10 ? ("0" + h24) : ("" + h24);
                                    let sM = min < 10 ? ("0" + min) : ("" + min);
                                    if (timeInput) timeInput.text = sH + ":" + sM;
                                }

                                function doSave() {
                                    let t = titleInput.text.trim();
                                    if (!t) {
                                        addFormRect.titleError = true;
                                        titleInput.forceActiveFocus();
                                        return;
                                    }
                                    if (root.editingReminderId !== "") {
                                        root.editReminder(
                                            root.editingReminderId,
                                            t,
                                            root.selectedDateStr,
                                            timeInput.text,
                                            addFormRect.formCat,
                                            addFormRect.formNotes,
                                            addFormRect.formPhoto,
                                            addFormRect.formRepeat,
                                            addFormRect.formCat === "Community" ? addFormRect.formLogo : ""
                                        );
                                    } else {
                                        root.addReminder(
                                            t,
                                            root.selectedDateStr,
                                            timeInput.text,
                                            addFormRect.formCat,
                                            addFormRect.formNotes,
                                            addFormRect.formPhoto,
                                            addFormRect.formRepeat,
                                            addFormRect.formCat === "Community" ? addFormRect.formLogo : ""
                                        );
                                    }
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
                                            text: (root.editingReminderId !== "" ? "Edit Event • " : "Schedule Event • ") + root.selectedDateStr
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
                                                root.resetForm();
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

                                    // Optional Notes input
                                    Rectangle {
                                        width: parent.width
                                        height: 26
                                        radius: 6
                                        color: theme.surface
                                        border.color: notesInput.activeFocus ? theme.frost : theme.borderSubtle
                                        border.width: 1

                                        TextInput {
                                            id: notesInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            anchors.topMargin: 5
                                            anchors.bottomMargin: 5
                                            text: addFormRect.formNotes
                                            color: theme.text
                                            font.family: theme.fontFamily
                                            font.pixelSize: 10
                                            clip: true
                                            selectByMouse: true
                                            onTextChanged: addFormRect.formNotes = text

                                            Text {
                                                anchors.fill: parent
                                                visible: !parent.text
                                                text: "Optional note, location, or details..."
                                                color: theme.textDim
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                            }
                                        }
                                    }

                                    // Invisible backing state for timeInput to preserve existing API compatibility
                                    TextInput {
                                        id: timeInput
                                        visible: false
                                        text: Qt.formatDateTime(new Date(Date.now() + 300000), "hh:mm")
                                    }

                                    // Time and Category Trigger Buttons
                                    Row {
                                        width: parent.width
                                        spacing: 8

                                        // Android Clock Time Trigger Button
                                        Rectangle {
                                            id: timeBtnRect
                                            width: 110
                                            height: 32
                                            radius: 6
                                            color: timeBtnMa.containsMouse ? theme.surfaceHover : theme.surface
                                            border.color: addFormRect.showTimePicker ? theme.frost : theme.borderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: "󱑎"
                                                    font.family: "GeistMono Nerd Font Propo"
                                                    font.pixelSize: 13
                                                    color: addFormRect.showTimePicker ? theme.frost : theme.textSub
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: timeInput.text
                                                    color: theme.text
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: addFormRect.showTimePicker ? "▲" : "▼"
                                                    font.pixelSize: 7
                                                    color: theme.textDim
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: timeBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    addFormRect.showTimePicker = !addFormRect.showTimePicker;
                                                    if (addFormRect.showTimePicker) addFormRect.formCatDropdownOpen = false;
                                                }
                                            }
                                        }

                                        // Category Dropdown Button in Form
                                        Rectangle {
                                            id: formCatDropBtn
                                            width: parent.width - 118
                                            height: 32
                                            radius: 6
                                            color: fCatDropMa.containsMouse ? theme.surfaceHover : theme.surface
                                            border.color: addFormRect.formCatDropdownOpen ? theme.frost : theme.borderSubtle
                                            border.width: 1

                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                Item {
                                                    id: formCatBtnIconBox
                                                    property var iconMeta: root.getCategoryIconMeta(addFormRect.formCat, titleInput ? titleInput.text : "", addFormRect.formNotes, addFormRect.formLogo)
                                                    width: iconMeta.width
                                                    height: iconMeta.height
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    Image {
                                                        visible: formCatBtnIconBox.iconMeta.source !== ""
                                                        anchors.fill: parent
                                                        source: formCatBtnIconBox.iconMeta.source
                                                        fillMode: Image.PreserveAspectFit
                                                        smooth: true
                                                    }
                                                    Rectangle {
                                                        visible: formCatBtnIconBox.iconMeta.source === ""
                                                        anchors.fill: parent
                                                        radius: width / 2
                                                        color: root.getCategoryColor(addFormRect.formCat)
                                                    }
                                                }

                                                Text {
                                                    width: parent.width - 34
                                                    text: addFormRect.formCat
                                                    color: theme.text
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: addFormRect.formCatDropdownOpen ? "▲" : "▼"
                                                    font.pixelSize: 7
                                                    color: theme.textDim
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: fCatDropMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    addFormRect.formCatDropdownOpen = !addFormRect.formCatDropdownOpen;
                                                    if (addFormRect.formCatDropdownOpen) addFormRect.showTimePicker = false;
                                                }
                                            }
                                        }
                                    }

                                    // Android Material Radial Clock Picker Card
                                    Rectangle {
                                        id: androidClockCard
                                        visible: addFormRect.showTimePicker
                                        width: parent.width
                                        implicitHeight: clockPickerCol.implicitHeight + 16
                                        radius: 8
                                        color: theme.surface
                                        border.color: theme.borderGlow
                                        border.width: 1

                                        Column {
                                            id: clockPickerCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 8
                                            spacing: 10

                                            // 1. Digital Time Header (Hour chip : Minute chip + AM/PM toggle)
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 8

                                                // Hour Digital Chip
                                                Rectangle {
                                                    width: 52
                                                    height: 36
                                                    radius: 6
                                                    color: addFormRect.timePickerMode === "hours" ? Qt.rgba(theme.frost.r, theme.frost.g, theme.frost.b, 0.22) : theme.bgDark
                                                    border.color: addFormRect.timePickerMode === "hours" ? theme.frost : theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: {
                                                            let h24 = addFormRect.getCurH24();
                                                            let h12 = h24 % 12;
                                                            if (h12 === 0) h12 = 12;
                                                            return h12 < 10 ? ("0" + h12) : ("" + h12);
                                                        }
                                                        color: addFormRect.timePickerMode === "hours" ? theme.frost : theme.text
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: addFormRect.timePickerMode = "hours"
                                                    }
                                                }

                                                Text {
                                                    text: ":"
                                                    color: theme.textSub
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 18
                                                    font.weight: Font.Bold
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                // Minute Digital Chip
                                                Rectangle {
                                                    width: 52
                                                    height: 36
                                                    radius: 6
                                                    color: addFormRect.timePickerMode === "minutes" ? Qt.rgba(theme.frost.r, theme.frost.g, theme.frost.b, 0.22) : theme.bgDark
                                                    border.color: addFormRect.timePickerMode === "minutes" ? theme.frost : theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: {
                                                            let m = addFormRect.getCurMin();
                                                            return m < 10 ? ("0" + m) : ("" + m);
                                                        }
                                                        color: addFormRect.timePickerMode === "minutes" ? theme.frost : theme.text
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 18
                                                        font.weight: Font.Bold
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: addFormRect.timePickerMode = "minutes"
                                                    }
                                                }

                                                // AM / PM Switcher
                                                Column {
                                                    spacing: 2
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    // AM button
                                                    Rectangle {
                                                        property bool isAM: addFormRect.getCurH24() < 12
                                                        width: 32
                                                        height: 17
                                                        radius: 4
                                                        color: isAM ? theme.frost : theme.bgDark
                                                        border.color: isAM ? theme.frost : theme.borderSubtle
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "AM"
                                                            color: parent.isAM ? "#000000" : theme.textMuted
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 8
                                                            font.weight: Font.Bold
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                let h = addFormRect.getCurH24();
                                                                if (h >= 12) addFormRect.setTime(h - 12, addFormRect.getCurMin());
                                                            }
                                                        }
                                                    }

                                                    // PM button
                                                    Rectangle {
                                                        property bool isPM: addFormRect.getCurH24() >= 12
                                                        width: 32
                                                        height: 17
                                                        radius: 4
                                                        color: isPM ? theme.frost : theme.bgDark
                                                        border.color: isPM ? theme.frost : theme.borderSubtle
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "PM"
                                                            color: parent.isPM ? "#000000" : theme.textMuted
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 8
                                                            font.weight: Font.Bold
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                let h = addFormRect.getCurH24();
                                                                if (h < 12) addFormRect.setTime(h + 12, addFormRect.getCurMin());
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // 2. Android Radial Clock Face
                                            Item {
                                                width: 180
                                                height: 180
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                // Circular dial background
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 90
                                                    color: Qt.rgba(0, 0, 0, 0.45)
                                                    border.color: theme.borderSubtle
                                                    border.width: 1
                                                }

                                                // Center pivot pin
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    color: theme.frost
                                                    z: 6
                                                }

                                                // Rotating Clock Hand Line
                                                Rectangle {
                                                    id: radialHand
                                                    property real angleDeg: {
                                                        let curH24 = addFormRect.getCurH24();
                                                        let curM = addFormRect.getCurMin();
                                                        if (addFormRect.timePickerMode === "hours") {
                                                            let h12 = curH24 % 12;
                                                            return h12 * 30; // 0..360 deg
                                                        } else {
                                                            return curM * 6; // 60 min -> 360 deg
                                                        }
                                                    }
                                                    width: 2
                                                    height: 60
                                                    color: theme.frost
                                                    transformOrigin: Item.Bottom
                                                    x: 90 - 1
                                                    y: 90 - 60
                                                    rotation: angleDeg
                                                    z: 2

                                                    Behavior on rotation {
                                                        RotationAnimation { duration: 160; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic }
                                                    }
                                                }

                                                // Selection Bubble Circle at hand tip
                                                Rectangle {
                                                    property real angleRad: (radialHand.angleDeg - 90) * Math.PI / 180
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    color: theme.frost
                                                    x: 90 + 60 * Math.cos(angleRad) - 13
                                                    y: 90 + 60 * Math.sin(angleRad) - 13
                                                    z: 3

                                                    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                    Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                }

                                                // 12 Numbers around the dial
                                                Repeater {
                                                    model: 12
                                                    Item {
                                                        id: dialNumItem
                                                        property int numVal: {
                                                            if (addFormRect.timePickerMode === "hours") {
                                                                return index === 0 ? 12 : index;
                                                            } else {
                                                                return index * 5;
                                                            }
                                                        }
                                                        property string numLabel: {
                                                            if (addFormRect.timePickerMode === "hours") {
                                                                return "" + numVal;
                                                            } else {
                                                                return numVal < 10 ? ("0" + numVal) : ("" + numVal);
                                                            }
                                                        }
                                                        property real deg: index * 30
                                                        property real rad: (deg - 90) * Math.PI / 180
                                                        property real posX: 90 + 60 * Math.cos(rad)
                                                        property real posY: 90 + 60 * Math.sin(rad)
                                                        property bool isSelected: {
                                                            let curH24 = addFormRect.getCurH24();
                                                            let curM = addFormRect.getCurMin();
                                                            if (addFormRect.timePickerMode === "hours") {
                                                                let h12 = curH24 % 12;
                                                                if (h12 === 0) h12 = 12;
                                                                return h12 === numVal;
                                                            } else {
                                                                return Math.round(curM / 5) * 5 % 60 === numVal;
                                                            }
                                                        }

                                                        x: posX - 12
                                                        y: posY - 12
                                                        width: 24
                                                        height: 24
                                                        z: 5

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: dialNumItem.numLabel
                                                            color: dialNumItem.isSelected ? "#000000" : theme.text
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 10
                                                            font.weight: dialNumItem.isSelected ? Font.Bold : Font.DemiBold
                                                        }
                                                    }
                                                }

                                                // Interactive MouseArea for Clock Dial
                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    preventStealing: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    function updateFromPos(mx, my, isRelease) {
                                                        let dx = mx - 90;
                                                        let dy = my - 90;
                                                        let rad = Math.atan2(dy, dx);
                                                        let deg = rad * 180 / Math.PI + 90;
                                                        if (deg < 0) deg += 360;

                                                        if (addFormRect.timePickerMode === "hours") {
                                                            let step = Math.round(deg / 30) % 12;
                                                            let h12 = (step === 0 ? 12 : step);
                                                            let curH = addFormRect.getCurH24();
                                                            let isPM = curH >= 12;
                                                            let finalH = isPM ? (h12 === 12 ? 12 : h12 + 12) : (h12 === 12 ? 0 : h12);
                                                            addFormRect.setTime(finalH, addFormRect.getCurMin());
                                                            if (isRelease) {
                                                                addFormRect.timePickerMode = "minutes";
                                                            }
                                                        } else {
                                                            let step5 = Math.round(deg / 30) * 5 % 60;
                                                            addFormRect.setTime(addFormRect.getCurH24(), step5);
                                                        }
                                                    }

                                                    onPositionChanged: (mouse) => {
                                                        if (pressed) updateFromPos(mouse.x, mouse.y, false);
                                                    }
                                                    onPressed: (mouse) => {
                                                        updateFromPos(mouse.x, mouse.y, false);
                                                    }
                                                    onReleased: (mouse) => {
                                                        updateFromPos(mouse.x, mouse.y, true);
                                                    }
                                                }
                                            }

                                            // 3. Preset chips & Quick Action Row
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 5

                                                Repeater {
                                                    model: [":00", ":15", ":30", ":45"]
                                                    Rectangle {
                                                        width: 34
                                                        height: 22
                                                        radius: 11
                                                        color: pChipMa.containsMouse ? theme.surfaceHover : theme.bgDark
                                                        border.color: theme.borderSubtle
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            color: theme.textSub
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 9
                                                            font.weight: Font.DemiBold
                                                        }
                                                        MouseArea {
                                                            id: pChipMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                let m = parseInt(modelData.replace(":", ""), 10) || 0;
                                                                addFormRect.setTime(addFormRect.getCurH24(), m);
                                                                addFormRect.timePickerMode = "minutes";
                                                            }
                                                        }
                                                    }
                                                }

                                                // Stepper +15m
                                                Rectangle {
                                                    width: 40
                                                    height: 22
                                                    radius: 11
                                                    color: step15Ma.containsMouse ? theme.surfaceHover : theme.bgDark
                                                    border.color: theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "+15m"
                                                        color: theme.frost
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 9
                                                        font.weight: Font.DemiBold
                                                    }
                                                    MouseArea {
                                                        id: step15Ma
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.adjustTime(15)
                                                    }
                                                }

                                                // Done Button
                                                Rectangle {
                                                    width: 52
                                                    height: 22
                                                    radius: 11
                                                    color: doneClockMa.containsMouse ? Qt.rgba(theme.frost.r, theme.frost.g, theme.frost.b, 0.35) : Qt.rgba(theme.frost.r, theme.frost.g, theme.frost.b, 0.2)
                                                    border.color: theme.frost
                                                    border.width: 1

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 3
                                                        Text {
                                                            text: "✓"
                                                            color: theme.frost
                                                            font.pixelSize: 9
                                                            font.weight: Font.Bold
                                                        }
                                                        Text {
                                                            text: "Done"
                                                            color: theme.frost
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 9
                                                            font.weight: Font.Bold
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: doneClockMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: addFormRect.showTimePicker = false
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Category Dropdown List Menu inside Form
                                    Rectangle {
                                        id: formCatDropPanel
                                        visible: addFormRect.formCatDropdownOpen
                                        width: parent.width
                                        implicitHeight: Math.min(210, formCatListCol.implicitHeight + 12)
                                        radius: 8
                                        color: theme.surface
                                        border.color: theme.borderGlow
                                        border.width: 1
                                        clip: true

                                        Flickable {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            contentHeight: formCatListCol.implicitHeight
                                            clip: true

                                            Column {
                                                id: formCatListCol
                                                width: parent.width
                                                spacing: 2

                                                Repeater {
                                                    model: root.availableCategories
                                                    Rectangle {
                                                        id: fCatItemRect
                                                        property bool isSel: addFormRect.formCat === modelData
                                                        property color catCol: root.getCategoryColor(modelData)
                                                        width: parent.width
                                                        height: 26
                                                        radius: 4
                                                        color: isSel ? Qt.rgba(catCol.r, catCol.g, catCol.b, 0.22) : (fCatItemMa.containsMouse ? theme.surfaceHover : "transparent")

                                                        Row {
                                                            anchors.left: parent.left
                                                            anchors.leftMargin: 8
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            spacing: 7

                                                            Item {
                                                                id: formCatItemIconBox
                                                                property var iconMeta: root.getCategoryIconMeta(modelData, "", "", "")
                                                                width: iconMeta.source !== "" ? iconMeta.width : 7
                                                                height: iconMeta.source !== "" ? iconMeta.height : 7
                                                                anchors.verticalCenter: parent.verticalCenter

                                                                Image {
                                                                    visible: formCatItemIconBox.iconMeta.source !== ""
                                                                    anchors.fill: parent
                                                                    source: formCatItemIconBox.iconMeta.source
                                                                    fillMode: Image.PreserveAspectFit
                                                                    smooth: true
                                                                }
                                                                Rectangle {
                                                                    visible: formCatItemIconBox.iconMeta.source === ""
                                                                    anchors.fill: parent
                                                                    radius: width / 2
                                                                    color: fCatItemRect.catCol
                                                                }
                                                            }

                                                            Text {
                                                                text: modelData
                                                                color: fCatItemRect.isSel ? fCatItemRect.catCol : (fCatItemMa.containsMouse ? theme.text : theme.textSub)
                                                                font.family: theme.fontFamily
                                                                font.pixelSize: 10
                                                                font.weight: fCatItemRect.isSel ? Font.Bold : Font.Normal
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                        }

                                                        Text {
                                                            visible: fCatItemRect.isSel
                                                            anchors.right: parent.right
                                                            anchors.rightMargin: 8
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            text: "✓"
                                                            color: fCatItemRect.catCol
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                        }

                                                        MouseArea {
                                                            id: fCatItemMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                addFormRect.formCat = modelData;
                                                                addFormRect.formCatDropdownOpen = false;
                                                            }
                                                        }
                                                    }
                                                }

                                                // Divider before "+ Add Category"
                                                Rectangle {
                                                    width: parent.width
                                                    height: 1
                                                    color: theme.borderSubtle
                                                }

                                                // Inline "+ Add Category" input
                                                Row {
                                                    width: parent.width
                                                    height: 26
                                                    spacing: 4

                                                    Item { width: 4; height: 1 }

                                                    TextInput {
                                                        id: newCatFormInput
                                                        width: parent.width - 40
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        color: theme.text
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 10
                                                        clip: true
                                                        selectByMouse: true

                                                        function commitFormCat() {
                                                            let name = newCatFormInput.text.trim();
                                                            if (name) {
                                                                root.addNewCategory(name);
                                                                addFormRect.formCat = name;
                                                                newCatFormInput.text = "";
                                                                addFormRect.formCatDropdownOpen = false;
                                                            }
                                                        }

                                                        Keys.onReturnPressed: commitFormCat()
                                                        Keys.onEnterPressed: commitFormCat()

                                                        Text {
                                                            anchors.fill: parent
                                                            visible: !parent.text
                                                            text: "+ New Category..."
                                                            color: theme.textDim
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 10
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 20
                                                        height: 20
                                                        radius: 10
                                                        color: addCatSubmitMa.containsMouse ? theme.surfaceHover : "transparent"
                                                        anchors.verticalCenter: parent.verticalCenter

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "✔"
                                                            color: theme.frost
                                                            font.pixelSize: 9
                                                        }
                                                        MouseArea {
                                                            id: addCatSubmitMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: newCatFormInput.commitFormCat()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Community Brand Logo Picker (when Community category is selected)
                                    Column {
                                        visible: addFormRect.formCat === "Community"
                                        width: parent.width
                                        spacing: 5

                                        Text {
                                            text: "Community Logo"
                                            color: theme.textMuted
                                            font.family: theme.fontFamily
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 5

                                            Repeater {
                                                model: root.communityLogos
                                                Rectangle {
                                                    property bool isLogoSel: addFormRect.formLogo === modelData.id
                                                    height: 24
                                                    width: logoChipRow.implicitWidth + 14
                                                    radius: 6
                                                    color: isLogoSel ? Qt.rgba(245/255, 158/255, 11/255, 0.22) : (logoChipMa.containsMouse ? theme.surfaceHover : theme.surface)
                                                    border.color: isLogoSel ? "#f59e0b" : theme.borderSubtle
                                                    border.width: 1

                                                    Row {
                                                        id: logoChipRow
                                                        anchors.centerIn: parent
                                                        spacing: 5

                                                        Image {
                                                            visible: modelData.icon !== ""
                                                            width: 12
                                                            height: 12
                                                            source: modelData.icon
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: modelData.label
                                                            color: isLogoSel ? "#fbbf24" : theme.textSub
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 9
                                                            font.weight: isLogoSel ? Font.Bold : Font.Medium
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: logoChipMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: addFormRect.formLogo = modelData.id
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Event Recurrence / Repeat Picker
                                    Column {
                                        width: parent.width
                                        spacing: 5

                                        Row {
                                            spacing: 5
                                            Text {
                                                text: "󰑖"
                                                font.family: "GeistMono Nerd Font Propo"
                                                font.pixelSize: 10
                                                color: addFormRect.formRepeat !== "none" ? theme.blueLight : theme.textMuted
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: "Repeat"
                                                color: theme.textMuted
                                                font.family: theme.fontFamily
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 5

                                            Repeater {
                                                model: root.repeatOptions
                                                Rectangle {
                                                    property bool isRepSel: addFormRect.formRepeat === modelData.id
                                                    height: 22
                                                    width: repChipTxt.implicitWidth + 14
                                                    radius: 6
                                                    color: isRepSel ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.24) : (repChipMa.containsMouse ? theme.surfaceHover : theme.surface)
                                                    border.color: isRepSel ? theme.blue : theme.borderSubtle
                                                    border.width: 1

                                                    Text {
                                                        id: repChipTxt
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        color: isRepSel ? theme.blueLight : theme.textSub
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 9
                                                        font.weight: isRepSel ? Font.Bold : Font.Medium
                                                    }

                                                    MouseArea {
                                                        id: repChipMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: addFormRect.formRepeat = modelData.id
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Photo attachment row (Attach / Change / Remove photo)
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        anchors.verticalCenterOffset: 0

                                        Rectangle {
                                            height: 24
                                            width: photoBtnRow.implicitWidth + 16
                                            radius: 6
                                            color: photoBtnMa.containsMouse ? theme.surfaceHover : theme.surface
                                            border.color: addFormRect.formPhoto ? theme.blue : theme.borderSubtle
                                            border.width: 1

                                            Row {
                                                id: photoBtnRow
                                                anchors.centerIn: parent
                                                spacing: 5

                                                Text {
                                                    text: "󰄄"
                                                    font.family: "GeistMono Nerd Font Propo"
                                                    font.pixelSize: 12
                                                    color: addFormRect.formPhoto ? theme.blue : theme.textSub
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                Text {
                                                    text: addFormRect.formPhoto ? "Change Photo" : "Attach Photo"
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 10
                                                    color: addFormRect.formPhoto ? theme.blue : theme.textSub
                                                    font.weight: Font.Medium
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            MouseArea {
                                                id: photoBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    photoPickerProc.running = false;
                                                    photoPickerProc.running = true;
                                                }
                                            }
                                        }

                                        // Photo Preview & Clear Chip
                                        Row {
                                            visible: addFormRect.formPhoto !== ""
                                            spacing: 6
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 4
                                                clip: true
                                                color: "black"
                                                border.color: theme.borderSubtle
                                                border.width: 1

                                                Image {
                                                    anchors.fill: parent
                                                    source: addFormRect.formPhoto ? (addFormRect.formPhoto.startsWith("http") || addFormRect.formPhoto.startsWith("file://") ? addFormRect.formPhoto : ("file://" + addFormRect.formPhoto)) : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                }
                                            }

                                            Text {
                                                text: {
                                                    let p = addFormRect.formPhoto || "";
                                                    return p.substring(p.lastIndexOf("/") + 1) || "photo";
                                                }
                                                color: theme.textMuted
                                                font.family: theme.fontFamily
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                                width: Math.min(120, parent.parent.width - 160)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Rectangle {
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: removePhotoMa.containsMouse ? theme.red : Qt.rgba(255, 255, 255, 0.08)
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    font.pixelSize: 8
                                                    color: removePhotoMa.containsMouse ? "#ffffff" : theme.textMuted
                                                }
                                                MouseArea {
                                                    id: removePhotoMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: addFormRect.formPhoto = ""
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
                                                onClicked: root.resetForm()
                                            }
                                        }

                                        Rectangle {
                                            width: root.editingReminderId !== "" ? 84 : 76
                                            height: 24
                                            radius: 6
                                            color: saveMa.containsMouse ? theme.text : theme.frost

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.editingReminderId !== "" ? "Update" : "Save Event"
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
                                spacing: 6

                                property var dayItems: root.remindersForSelectedDate()

                                // Formula 1 Grand Prix Thematic Card (Google Calendar style with F1 SVG, Red Color & Speed Animation)
                                Rectangle {
                                    id: f1EventCard
                                    visible: !!root.selectedF1Event && (root.selectedCategory === "All" || root.selectedCategory === "F1")
                                    width: parent.width
                                    radius: 8
                                    implicitHeight: f1Row.implicitHeight + 20
                                    color: Qt.rgba(225/255, 6/255, 0/255, 0.16)
                                    border.color: Qt.rgba(225/255, 6/255, 0/255, 0.60)
                                    border.width: 1
                                    clip: true

                                    // Continuous Red Neon Racing Breathing Glow Animation
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        border.color: "#E10600"
                                        border.width: 1.5
                                        opacity: 0.70

                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite
                                            running: f1EventCard.visible
                                            NumberAnimation { from: 0.25; to: 0.95; duration: 1100; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 0.95; to: 0.25; duration: 1100; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    // Formula 1 Left Racing Stripe Bar
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        color: "#E10600"
                                        radius: 2
                                    }

                                    // Official Round / Race Tag in top-right corner
                                    Rectangle {
                                        id: roundBadge
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 10
                                        z: 2
                                        height: 18
                                        width: roundTxt.implicitWidth + 10
                                        radius: 4
                                        color: "#E10600"

                                        Text {
                                            id: roundTxt
                                            anchors.centerIn: parent
                                            text: (root.selectedF1Event && root.selectedF1Event.round) ? root.selectedF1Event.round.toUpperCase() : "F1"
                                            color: "#ffffff"
                                            font.family: theme.fontFamily
                                            font.pixelSize: 8
                                            font.weight: Font.Bold
                                        }
                                    }

                                    RowLayout {
                                        id: f1Row
                                        anchors.left: parent.left
                                        anchors.right: roundBadge.left
                                        anchors.rightMargin: 8
                                        anchors.top: parent.top
                                        anchors.margins: 10
                                        spacing: 10

                                        // Official F1 SVG Emblem Container with animated breathing scale
                                        Rectangle {
                                            Layout.preferredWidth: 42
                                            Layout.preferredHeight: 38
                                            radius: 8
                                            color: Qt.rgba(225/255, 6/255, 0/255, 0.22)
                                            border.color: Qt.rgba(225/255, 6/255, 0/255, 0.65)
                                            border.width: 1

                                            Image {
                                                id: f1SvgIcon
                                                anchors.centerIn: parent
                                                source: "file:///home/ferram/.local/share/icons/f1.svg"
                                                sourceSize.width: 32
                                                sourceSize.height: 22
                                                width: 28
                                                height: 18
                                                smooth: true
                                                fillMode: Image.PreserveAspectFit

                                                scale: 1.0
                                                SequentialAnimation on scale {
                                                    loops: Animation.Infinite
                                                    running: f1EventCard.visible
                                                    NumberAnimation { from: 0.94; to: 1.08; duration: 1100; easing.type: Easing.InOutSine }
                                                    NumberAnimation { from: 1.08; to: 0.94; duration: 1100; easing.type: Easing.InOutSine }
                                                }
                                            }
                                        }

                                        // F1 Race Information
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                text: root.selectedF1Event ? root.selectedF1Event.raceName : ""
                                                color: "#ffffff"
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: {
                                                    if (!root.selectedF1Event) return "";
                                                    let s = root.selectedF1Event.session || "Grand Prix";
                                                    if (root.selectedF1Event.circuit) s += " • " + root.selectedF1Event.circuit;
                                                    if (root.selectedF1Event.location) s += " (" + root.selectedF1Event.location + ")";
                                                    return s;
                                                }
                                                color: Qt.rgba(255, 255, 255, 0.85)
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.playF1Sound()
                                    }
                                }

                                // Mexican Holiday Festive Card (Google Calendar style with festive thematic SVG)
                                Rectangle {
                                    visible: !!root.selectedHoliday
                                    width: parent.width
                                    radius: 8
                                    implicitHeight: holidayRow.implicitHeight + 20
                                    color: root.selectedHoliday ? (root.selectedHoliday.isOfficial ? Qt.rgba(16/255, 185/255, 129/255, 0.14) : Qt.rgba(245/255, 158/255, 11/255, 0.12)) : "transparent"
                                    border.color: root.selectedHoliday ? (root.selectedHoliday.isOfficial ? Qt.rgba(16/255, 185/255, 129/255, 0.5) : Qt.rgba(245/255, 158/255, 11/255, 0.45)) : "transparent"
                                    border.width: 1
                                    clip: true

                                    // Google Calendar Left Accent Strip
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 4
                                        color: root.selectedHoliday && root.selectedHoliday.isOfficial ? "#10b981" : "#fbbf24"
                                        radius: 2
                                    }

                                    RowLayout {
                                        id: holidayRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 10
                                        spacing: 10

                                        // Google Calendar Thematic Holiday Emblem
                                        Rectangle {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            radius: 10
                                            color: Qt.rgba(255, 255, 255, 0.08)
                                            border.color: Qt.rgba(255, 255, 255, 0.16)
                                            border.width: 1

                                            Image {
                                                anchors.centerIn: parent
                                                source: root.getHolidayIcon(root.selectedHoliday)
                                                sourceSize.width: 26
                                                sourceSize.height: 26
                                                width: 26
                                                height: 26
                                                smooth: true
                                                fillMode: Image.PreserveAspectFit
                                            }
                                        }

                                        // Holiday Title & Description
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                text: root.selectedHoliday ? root.selectedHoliday.name : ""
                                                color: theme.text
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: root.selectedHoliday ? root.selectedHoliday.desc : ""
                                                color: root.selectedHoliday && root.selectedHoliday.isOfficial ? Qt.rgba(255, 255, 255, 0.8) : theme.textSub
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }

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
                                                text: root.selectedHoliday ? "Holiday • No scheduled tasks" : "No reminders for this day"
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

                                // Google Calendar Style Event Cards
                                Repeater {
                                    model: parent.dayItems
                                    Rectangle {
                                        id: remCard
                                        property color catCol: root.getCategoryColor(modelData.category, modelData.title)
                                        property bool hasPhoto: !!(modelData.photo && modelData.photo.trim().length > 0)
                                        property string catLow: (modelData.category || "").toLowerCase()
                                        property string titleLow: (modelData.title || "").toLowerCase()
                                        property bool isSara: catLow === "sara" || titleLow.indexOf("sara") !== -1
                                        property bool isMarvel: catLow === "marvel" || titleLow.indexOf("doomsday") !== -1 || titleLow.indexOf("marvel") !== -1
                                        property bool isNSQK: titleLow.indexOf("nsqk") !== -1 || titleLow.indexOf("mosca") !== -1
                                        width: dayDetailCol.width
                                        height: hasPhoto ? 58 : 50
                                        radius: 8
                                        color: cardMa.containsMouse
                                            ? Qt.rgba(remCard.catCol.r, remCard.catCol.g, remCard.catCol.b, 0.18)
                                            : Qt.rgba(remCard.catCol.r, remCard.catCol.g, remCard.catCol.b, 0.08)
                                        border.color: cardMa.containsMouse
                                            ? remCard.catCol
                                            : Qt.rgba(remCard.catCol.r, remCard.catCol.g, remCard.catCol.b, 0.30)
                                        border.width: 1
                                        clip: true

                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }

                                        // Google Calendar Left Accent Bar
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: 4
                                            color: remCard.catCol
                                            radius: 2
                                        }

                                        // F1 Dynamic Red Racing Pulse Animation
                                        Rectangle {
                                            visible: modelData.category === "F1"
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.color: "#E10600"
                                            border.width: 1.5
                                            opacity: 0.65

                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: modelData.category === "F1"
                                                NumberAnimation { from: 0.25; to: 0.85; duration: 1000; easing.type: Easing.InOutSine }
                                                NumberAnimation { from: 0.85; to: 0.25; duration: 1000; easing.type: Easing.InOutSine }
                                            }
                                        }

                                        // Sara Soft Romantic Pulse Animation
                                        Rectangle {
                                            visible: remCard.isSara
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.color: "#ff2d55"
                                            border.width: 1.5
                                            opacity: 0.65

                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: remCard.isSara
                                                NumberAnimation { from: 0.25; to: 0.85; duration: 1100; easing.type: Easing.InOutSine }
                                                NumberAnimation { from: 0.85; to: 0.25; duration: 1100; easing.type: Easing.InOutSine }
                                            }
                                        }

                                        // Marvel Energetic Doctor Doom Green Pulse Animation
                                        Rectangle {
                                            visible: remCard.isMarvel
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.color: "#10b981"
                                            border.width: 1.5
                                            opacity: 0.65

                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: remCard.isMarvel
                                                NumberAnimation { from: 0.25; to: 0.85; duration: 1100; easing.type: Easing.InOutSine }
                                                NumberAnimation { from: 0.85; to: 0.25; duration: 1100; easing.type: Easing.InOutSine }
                                            }
                                        }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.right: actionsRow.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 8
                                            spacing: 10

                                            // Event Photo Thumbnail (if attached)
                                            Rectangle {
                                                visible: remCard.hasPhoto
                                                width: 40
                                                height: 40
                                                radius: 6
                                                clip: true
                                                color: Qt.rgba(0, 0, 0, 0.45)
                                                border.color: Qt.rgba(255, 255, 255, 0.14)
                                                border.width: 1
                                                anchors.verticalCenter: parent.verticalCenter

                                                Image {
                                                    anchors.fill: parent
                                                    source: remCard.hasPhoto ? (modelData.photo.startsWith("http") || modelData.photo.startsWith("file://")) ? modelData.photo : ("file://" + modelData.photo) : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }

                                            // Text Info
                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3
                                                width: parent.width - (remCard.hasPhoto ? 50 : 0)

                                                Text {
                                                    width: parent.width
                                                    text: modelData.title
                                                    color: theme.text
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                }

                                                Row {
                                                    spacing: 6

                                                    Row {
                                                        spacing: 4
                                                        Image {
                                                            width: 11
                                                            height: 11
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(remCard.catCol) + "' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='9'/><polyline points='12 7 12 12 15 14'/></svg>"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }
                                                        Text {
                                                            text: modelData.time
                                                            color: theme.textSub
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 11
                                                            font.weight: Font.Medium
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    Text {
                                                        text: "•"
                                                        color: theme.borderSubtle
                                                        font.pixelSize: 10
                                                    }

                                                    Row {
                                                        spacing: 4
                                                        anchors.verticalCenter: parent.verticalCenter

                                                        Item {
                                                            id: remCardIconBox
                                                            property var iconMeta: root.getCategoryIconMeta(modelData.category, modelData.title, modelData.notes, modelData.logo)
                                                            visible: iconMeta.source !== ""
                                                            width: iconMeta.width
                                                            height: iconMeta.height
                                                            anchors.verticalCenter: parent.verticalCenter

                                                            Image {
                                                                anchors.fill: parent
                                                                source: remCardIconBox.iconMeta.source
                                                                fillMode: Image.PreserveAspectFit
                                                                smooth: true
                                                            }
                                                        }

                                                        Image {
                                                            visible: remCard.isNSQK
                                                            width: 26
                                                            height: 13
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file://" + Quickshell.shellPath("assets/nsqk-logo-white.png")
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Text {
                                                            text: remCard.isSara ? (modelData.category === "Personal" ? "Sara" : modelData.category) : (remCard.isMarvel ? (modelData.category === "Personal" ? "Marvel" : modelData.category) : modelData.category)
                                                            color: remCard.catCol
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }

                                                    Text {
                                                        visible: !!(modelData.repeat && modelData.repeat !== "none")
                                                        text: "󰑖 " + root.getRepeatLabel(modelData.repeat)
                                                        color: theme.blueLight
                                                        font.family: "GeistMono Nerd Font Propo"
                                                        font.pixelSize: 9
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        visible: !!(modelData.notes && modelData.notes.trim().length > 0)
                                                        text: "• 󰍨"
                                                        color: theme.textDim
                                                        font.family: "GeistMono Nerd Font Propo"
                                                        font.pixelSize: 10
                                                    }

                                                    Text {
                                                        visible: remCard.hasPhoto
                                                        text: "󰄄"
                                                        color: theme.blue
                                                        font.family: "GeistMono Nerd Font Propo"
                                                        font.pixelSize: 10
                                                        opacity: 0.85
                                                    }
                                                }
                                            }
                                        }

                                        // Actions Row (Edit & Delete buttons on hover)
                                        Row {
                                            id: actionsRow
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            opacity: cardMa.containsMouse ? 1.0 : 0.0
                                            Behavior on opacity { NumberAnimation { duration: 140 } }

                                            // Edit Button
                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 12
                                                color: editMa.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                                                border.color: editMa.containsMouse ? theme.frost : theme.borderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰏫"
                                                    font.family: "GeistMono Nerd Font Propo"
                                                    font.pixelSize: 11
                                                    color: editMa.containsMouse ? "#ffffff" : theme.textSub
                                                }

                                                MouseArea {
                                                    id: editMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.startEdit(modelData)
                                                }
                                            }

                                            // Delete Button
                                            Rectangle {
                                                id: delBtn
                                                width: 24
                                                height: 24
                                                radius: 12
                                                color: delMa.containsMouse ? theme.red : Qt.rgba(255, 255, 255, 0.08)
                                                border.color: delMa.containsMouse ? theme.red : theme.borderSubtle
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: delMa.containsMouse ? "#ffffff" : theme.textMuted
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

                                        // Full Card click opens Edit mode
                                        MouseArea {
                                            id: cardMa
                                            anchors.fill: parent
                                            z: -1
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.startEdit(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    } // end calendarTabCol
                            } // end calPageItem

                            // PAGE 1: TIMERS (iOS-inspired Scroll Wheel + Grouped Card + Active & Recents)
                            Item {
                                id: tmrPageItem
                                width: pageSwipe.width
                                implicitHeight: timersTabCol.implicitHeight
                                visible: pageSwipe.currentIndex === 1

                                Column {
                                    id: timersTabCol
                                    width: parent.width
                                    spacing: 12

                        property int customHours: 0
                        property int customMins: 15
                        property int customSecs: 0
                        property string selectedSound: "alarm"
                        property bool soundPickerOpen: false
                        signal wheelReset()

                        function startCustomTimer() {
                            if (!root.timerService) return;
                            let total = (customHours * 3600) + (customMins * 60) + customSecs;
                            if (total <= 0) return;
                            root.timerService.addTimer(timerLabelInput.text, total, true, selectedSound);
                            timerLabelInput.text = "";
                            soundPickerOpen = false;
                        }

                        function resetWheel() {
                            customHours = 0;
                            customMins = 0;
                            customSecs = 0;
                            timerLabelInput.text = "";
                            wheelReset();
                        }

                        // 1. iOS Top Action Row: Circular Reset (X) | "Timer" | Circular Dynamic Start (▶)
                        Item {
                            width: parent.width
                            height: 36

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                height: 32
                                radius: 16
                                color: wheelResetMa.containsMouse ? theme.surfaceHover : theme.surface
                                border.color: theme.borderSubtle
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: theme.textSub
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: wheelResetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: timersTabCol.resetWheel()
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Timer"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                property bool canStart: (timersTabCol.customHours + timersTabCol.customMins + timersTabCol.customSecs) > 0
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                height: 32
                                radius: 16
                                color: canStart
                                    ? (topStartMa.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.34) : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.22))
                                    : theme.surface
                                border.color: canStart ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.55) : theme.borderSubtle
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on border.color { ColorAnimation { duration: 180 } }

                                Image {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 1
                                    width: 12
                                    height: 12
                                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='" + theme.urlColor(parent.canStart ? theme.blueLight : theme.textDim) + "'><polygon points='6 4 20 12 6 20 6 4'/></svg>"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                MouseArea {
                                    id: topStartMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: parent.canStart
                                    cursorShape: parent.canStart ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: timersTabCol.startCustomTimer()
                                }
                            }
                        }

                        // 2. iOS 3-Column Scroll Wheel Picker (hours | min | sec)
                        Item {
                            width: parent.width
                            height: 140
                            clip: true

                            // Center rounded highlight pill bar across all 3 columns
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                y: 56
                                height: 28
                                radius: 9
                                color: theme.surfaceHover
                                border.color: theme.borderSubtle
                                border.width: 1
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 4

                                Repeater {
                                    model: [
                                        { key: "hours", count: 24, unit: "hours", initVal: 0 },
                                        { key: "mins", count: 60, unit: "min", initVal: 15 },
                                        { key: "secs", count: 60, unit: "sec", initVal: 0 }
                                    ]

                                    Item {
                                        width: (parent.width - 8) / 3
                                        height: parent.height

                                        Connections {
                                            target: timersTabCol
                                            function onWheelReset() {
                                                wheelList.positionViewAtIndex(0, ListView.Center);
                                                wheelList.currentIndex = 0;
                                            }
                                        }

                                        Connections {
                                            target: tmrPageItem
                                            function onVisibleChanged() {
                                                Qt.callLater(wheelList.initWheelPos);
                                            }
                                        }

                                        Connections {
                                            target: popup
                                            function onVisibleChanged() {
                                                Qt.callLater(wheelList.initWheelPos);
                                            }
                                        }

                                        ListView {
                                            id: wheelList
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * 0.52
                                            model: modelData.count
                                            clip: true
                                            property bool wheelPositioned: false
                                            snapMode: ListView.SnapToItem
                                            highlightRangeMode: ListView.StrictlyEnforceRange
                                            preferredHighlightBegin: 56
                                            preferredHighlightEnd: 84
                                            highlightMoveDuration: 150
                                            boundsBehavior: Flickable.StopAtBounds
                                            currentIndex: modelData.initVal

                                            function initWheelPos() {
                                                if (wheelPositioned || !tmrPageItem.visible || !popup.visible || height <= 0 || width <= 0) return;
                                                wheelPositioned = true;
                                                currentIndex = modelData.initVal;
                                                positionViewAtIndex(modelData.initVal, ListView.Center);
                                            }

                                            onCurrentIndexChanged: {
                                                if (currentIndex < 0) return;
                                                if (modelData.key === "hours") timersTabCol.customHours = currentIndex;
                                                else if (modelData.key === "mins") timersTabCol.customMins = currentIndex;
                                                else timersTabCol.customSecs = currentIndex;
                                            }

                                            onWidthChanged: Qt.callLater(initWheelPos)
                                            onHeightChanged: Qt.callLater(initWheelPos)
                                            Component.onCompleted: Qt.callLater(initWheelPos)

                                            delegate: Item {
                                                width: wheelList.width
                                                height: 28
                                                property int dist: Math.abs(index - wheelList.currentIndex)

                                                Text {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: index
                                                    color: theme.text
                                                    opacity: dist === 0 ? 1.0 : (dist === 1 ? 0.50 : (dist === 2 ? 0.22 : 0.08))
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: dist === 0 ? 18 : (dist === 1 ? 15 : 13)
                                                    font.weight: dist === 0 ? Font.DemiBold : Font.Normal
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: wheelList.currentIndex = index
                                                }
                                            }
                                        }

                                        WheelHandler {
                                            acceptedDevices: PointerDevice.AllDevices
                                            property real wheelAccum: 0
                                            onWheel: (event) => {
                                                let d = event.angleDelta.y;
                                                if (d === 0 && event.pixelDelta.y !== 0) d = event.pixelDelta.y * 2;
                                                wheelAccum += d;
                                                if (wheelAccum >= 60) {
                                                    wheelAccum = 0;
                                                    if (wheelList.currentIndex > 0) wheelList.currentIndex--;
                                                } else if (wheelAccum <= -60) {
                                                    wheelAccum = 0;
                                                    if (wheelList.currentIndex < modelData.count - 1) wheelList.currentIndex++;
                                                }
                                                event.accepted = true;
                                            }
                                        }

                                        Text {
                                            x: wheelList.width + 2
                                            y: 56
                                            height: 28
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.unit
                                            color: theme.text
                                            font.family: theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }

                        // 3. iOS Grouped Settings Card: Label + When Timer Ends
                        Rectangle {
                            width: parent.width
                            implicitHeight: tmrSettingsCol.implicitHeight
                            radius: 12
                            color: theme.surface
                            border.color: theme.borderSubtle
                            border.width: 1
                            clip: true

                            Column {
                                id: tmrSettingsCol
                                width: parent.width

                                // Row 1: Label
                                Item {
                                    width: parent.width
                                    height: 36

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Label"
                                        color: theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    TextInput {
                                        id: timerLabelInput
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 80
                                        horizontalAlignment: Text.AlignRight
                                        color: theme.textSub
                                        font.family: theme.fontFamily
                                        font.pixelSize: 12
                                        clip: true
                                        selectByMouse: true

                                        Keys.onReturnPressed: timersTabCol.startCustomTimer()
                                        Keys.onEnterPressed: timersTabCol.startCustomTimer()

                                        Text {
                                            anchors.fill: parent
                                            horizontalAlignment: Text.AlignRight
                                            verticalAlignment: Text.AlignVCenter
                                            visible: !parent.text
                                            text: "Timer"
                                            color: theme.textDim
                                            font.family: theme.fontFamily
                                            font.pixelSize: 12
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: timerLabelInput.forceActiveFocus()
                                    }
                                }

                                // Hairline divider
                                Rectangle {
                                    width: parent.width - 12
                                    anchors.right: parent.right
                                    height: 1
                                    color: theme.borderSubtle
                                }

                                // Row 2: When Timer Ends
                                Item {
                                    width: parent.width
                                    height: 36

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "When Timer Ends"
                                        color: theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Text {
                                            text: root.timerService ? root.timerService.getSoundLabel(timersTabCol.selectedSound) : "Alarm"
                                            color: theme.textSub
                                            font.family: theme.fontFamily
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: timersTabCol.soundPickerOpen ? "⌄" : "›"
                                            color: theme.textDim
                                            font.pixelSize: 13
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: timersTabCol.soundPickerOpen = !timersTabCol.soundPickerOpen
                                    }
                                }

                                // Expandable Sound Options Row
                                Flow {
                                    visible: timersTabCol.soundPickerOpen
                                    width: parent.width - 20
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    topPadding: 2
                                    bottomPadding: 10
                                    spacing: 6

                                    Repeater {
                                        model: root.timerService ? root.timerService.soundOptions : []
                                        Rectangle {
                                            property bool isSel: timersTabCol.selectedSound === modelData.id
                                            height: 24
                                            width: sndTxt.implicitWidth + 14
                                            radius: 7
                                            color: isSel ? Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.22) : (sndMa.containsMouse ? theme.surfaceHover : theme.bgDark)
                                            border.color: isSel ? theme.peach : theme.borderSubtle
                                            border.width: 1

                                            Text {
                                                id: sndTxt
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: isSel ? theme.peach : theme.textSub
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: isSel ? Font.Bold : Font.Medium
                                            }

                                            MouseArea {
                                                id: sndMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    timersTabCol.selectedSound = modelData.id;
                                                    if (root.timerService) root.timerService.playSound(modelData.id);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 4. Active / Running Timers (if any)
                        Column {
                            visible: !!(root.timerService && root.timerService.timers.length > 0)
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Running"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Repeater {
                                model: root.timerService ? root.timerService.timers : []

                                Rectangle {
                                    id: runningTmrCard
                                    readonly property int liveRemainingSec: root.timerService ? root.timerService.getRemainingSec(modelData) : (modelData.remainingSec || 0)
                                    width: timersTabCol.width
                                    height: 68
                                    radius: 12
                                    color: modelData.finished
                                        ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.16)
                                        : theme.surface
                                    border.color: modelData.finished
                                        ? theme.red
                                        : (modelData.running ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.45) : theme.borderSubtle)
                                    border.width: 1
                                    clip: true

                                    // Bottom progress indicator
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        height: 2.5
                                        width: {
                                            if (!modelData.totalSec || modelData.totalSec <= 0) return 0;
                                            let pct = Math.max(0, Math.min(1, parent.liveRemainingSec / modelData.totalSec));
                                            return Math.round(parent.width * pct);
                                        }
                                        color: modelData.finished ? theme.red : (modelData.running ? theme.blueLight : theme.textDim)
                                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }

                                    Item {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12

                                        Column {
                                            anchors.left: parent.left
                                            anchors.right: runTmrBtns.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                text: root.timerService ? root.timerService.formatDuration(runningTmrCard.liveRemainingSec) : "0:00"
                                                color: modelData.finished ? theme.red : theme.text
                                                font.family: theme.fontFamily
                                                font.pixelSize: 24
                                                font.weight: Font.Light
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.label + (modelData.finished ? " • Done!" : (" • " + (root.timerService ? root.timerService.formatDuration(modelData.totalSec) : "")))
                                                color: modelData.finished ? theme.red : theme.textSub
                                                font.family: theme.fontFamily
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Row {
                                            id: runTmrBtns
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6

                                            Rectangle {
                                                width: 28; height: 28; radius: 14
                                                color: p1Ma.containsMouse ? theme.surfaceHover : theme.bgDark
                                                border.color: theme.borderSubtle; border.width: 1
                                                Text { anchors.centerIn: parent; text: "+1m"; color: theme.textSub; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: Font.Bold }
                                                MouseArea { id: p1Ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.timerService) root.timerService.addMinutes(modelData.id, 1) }
                                            }

                                            Rectangle {
                                                width: 30; height: 30; radius: 15
                                                color: modelData.running ? Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.22) : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.22)
                                                border.color: modelData.running ? theme.peach : theme.blue; border.width: 1
                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 12
                                                    height: 12
                                                    source: modelData.running
                                                        ? ("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='" + theme.urlColor(theme.peach) + "'><rect x='6' y='4' width='4' height='16' rx='1'/><rect x='14' y='4' width='4' height='16' rx='1'/></svg>")
                                                        : ("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='" + theme.urlColor(theme.blueLight) + "'><polygon points='6 4 20 12 6 20 6 4'/></svg>")
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.timerService) root.timerService.toggleTimer(modelData.id) }
                                            }

                                            Rectangle {
                                                width: 28; height: 28; radius: 14
                                                color: rResetMa.containsMouse ? theme.surfaceHover : theme.bgDark
                                                border.color: theme.borderSubtle; border.width: 1
                                                Text { anchors.centerIn: parent; text: "↺"; color: theme.textSub; font.pixelSize: 12; font.bold: true }
                                                MouseArea { id: rResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.timerService) root.timerService.resetTimer(modelData.id) }
                                            }

                                            Rectangle {
                                                width: 28; height: 28; radius: 14
                                                color: rDelMa.containsMouse ? theme.red : theme.bgDark
                                                border.color: rDelMa.containsMouse ? theme.red : theme.borderSubtle; border.width: 1
                                                Text { anchors.centerIn: parent; text: "✕"; color: rDelMa.containsMouse ? "#ffffff" : theme.textMuted; font.pixelSize: 9; font.bold: true }
                                                MouseArea { id: rDelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.timerService) root.timerService.removeTimer(modelData.id) }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 6. Recents Section (matching iOS bottom Recents list with big numerals + green play button)
                        Column {
                            visible: !!(root.timerService && root.timerService.recents.length > 0)
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Recents"
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                width: parent.width
                                implicitHeight: recentsListCol.implicitHeight
                                radius: 12
                                color: theme.surface
                                border.color: theme.borderSubtle
                                border.width: 1
                                clip: true

                                Column {
                                    id: recentsListCol
                                    width: parent.width

                                    Repeater {
                                        model: root.timerService ? root.timerService.recents : []

                                        Item {
                                            id: recRowItem
                                            width: recentsListCol.width
                                            height: 58

                                            Rectangle {
                                                visible: index > 0
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.leftMargin: 12
                                                anchors.right: parent.right
                                                height: 1
                                                color: theme.borderSubtle
                                            }

                                            Column {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 12
                                                anchors.right: recPlayBtn.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1

                                                Text {
                                                    text: root.timerService ? root.timerService.formatDuration(modelData.totalSec) : "0:00"
                                                    color: theme.textSub
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 22
                                                    font.weight: Font.Light
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: modelData.label
                                                    color: theme.textMuted
                                                    font.family: theme.fontFamily
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // Subtle delete button on hover
                                            Rectangle {
                                                id: recDelBtn
                                                anchors.right: recPlayBtn.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 22
                                                height: 22
                                                radius: 11
                                                opacity: (recRowMa.containsMouse || recDelMa.containsMouse) ? 1.0 : 0.0
                                                color: recDelMa.containsMouse ? theme.red : theme.bgDark
                                                border.color: recDelMa.containsMouse ? theme.red : theme.borderSubtle
                                                border.width: 1
                                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    color: recDelMa.containsMouse ? "#ffffff" : theme.textMuted
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: recDelMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: if (root.timerService) root.timerService.removeRecent(modelData.id)
                                                }
                                            }

                                            // Circular Dynamic Play button
                                            Rectangle {
                                                id: recPlayBtn
                                                anchors.right: parent.right
                                                anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 34
                                                height: 34
                                                radius: 17
                                                color: recPlayMa.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.34) : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.20)
                                                border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.50)
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: 180 } }

                                                Image {
                                                    anchors.centerIn: parent
                                                    anchors.horizontalCenterOffset: 1
                                                    width: 12
                                                    height: 12
                                                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='" + theme.urlColor(theme.blueLight) + "'><polygon points='6 4 20 12 6 20 6 4'/></svg>"
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                }

                                                MouseArea {
                                                    id: recPlayMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.timerService) {
                                                            root.timerService.addTimer(modelData.label, modelData.totalSec, true, modelData.sound || "alarm");
                                                        }
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: recRowMa
                                                anchors.fill: parent
                                                z: -1
                                                hoverEnabled: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } // end timersTabCol
                            } // end tmrPageItem
                        } // end pageSwipe
                    } // end pageContainer wrapper Item
                }
            }
        }
    }
}
