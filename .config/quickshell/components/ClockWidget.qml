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
        "F1": "#E10600",
        "Colgate-Palmolive": "#0067fe",
        "Projects": "#10b981",
        "Free Lance": "#06b6d4",
        "School": "#a855f7",
        "Personal": "#f97316",
        "Sara": "#ff2d55",
        "Marvel": "#ed1d24",
        "Gym": "#eab308",
        "Family": "#f43f5e",
        "Travel": "#38bdf8"
    })

    function getCategoryColor(cat, title) {
        if (cat === "All") return theme.frost;
        let c = (cat || "").toLowerCase();
        let t = (title || "").toLowerCase();
        if (c === "sara" || t.indexOf("sara") !== -1) return "#ff2d55";
        if (c === "marvel" || t.indexOf("doomsday") !== -1 || t.indexOf("marvel") !== -1) return "#ed1d24";
        if (c === "f1") return "#E10600";
        if (c === "colgate-palmolive") return "#0067fe";
        if (c === "projects") return "#10b981";
        if (c === "free lance" || c === "free-lance" || c === "freelance") return "#06b6d4";
        if (c === "school") return "#a855f7";
        if (c === "personal") return "#f97316";
        if (c === "gym") return "#eab308";
        if (c === "family") return "#f43f5e";
        if (c === "travel") return "#38bdf8";
        return categoryColors[cat] || "#38bdf8";
    }

    property var baseCategories: ["F1", "Colgate-Palmolive", "Projects", "Free Lance", "School", "Personal", "Sara", "Marvel", "Gym", "Family"]
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

    function addReminder(title, dateStr, timeStr, category, notes, photo) {
        if (!title.trim()) return;
        actionProc.running = false;
        let cmd = [
            "/home/ferram/.local/bin/hypr-reminders", "add",
            title.trim(),
            "--date", dateStr,
            "--time", timeStr,
            "--category", category,
            "--notes", notes || ""
        ];
        if (photo && photo.trim()) {
            cmd.push("--photo");
            cmd.push(photo.trim());
        }
        actionProc.command = cmd;
        actionProc.running = true;
        resetForm();
    }

    function editReminder(remId, title, dateStr, timeStr, category, notes, photo) {
        if (!remId || !title.trim()) return;
        actionProc.running = false;
        let cmd = [
            "/home/ferram/.local/bin/hypr-reminders", "edit", remId,
            "--title", title.trim(),
            "--date", dateStr,
            "--time", timeStr,
            "--category", category,
            "--notes", notes || "",
            "--photo", photo || ""
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
        addFormRect.titleError = false;
        Qt.callLater(() => titleInput.forceActiveFocus());
    }

    function resetForm() {
        editingReminderId = "";
        showAddForm = false;
        if (titleInput) titleInput.text = "";
        addFormRect.formNotes = "";
        addFormRect.formPhoto = "";
        addFormRect.titleError = false;
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
        if (root.f1Calendar && root.f1Calendar[dStr]) return true;
        if (!allReminders) return false;
        for (let i = 0; i < allReminders.length; i++) {
            if (allReminders[i].date === dStr) return true;
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
                if (r.date === dStr) {
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
            if (r.date === dStr) count++;
        }
        return count;
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
            if (r.date === selectedDateStr) {
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

                                        Rectangle {
                                            id: cellBox
                                            anchors.centerIn: parent
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: {
                                                if (dayCell.isSelected) return theme.blue;
                                                if (dayCellMa.containsMouse) return theme.surfaceHover;
                                                if (dayCell.mexicanHoliday && dayCell.isCurrentMonth) return Qt.rgba(245/255, 158/255, 11/255, 0.15);
                                                return "transparent";
                                            }
                                            border.color: (dayCell.isToday && !dayCell.isSelected) ? theme.blue : "transparent"
                                            border.width: 1

                                            Behavior on color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: dayCell.dayNum
                                                color: {
                                                    if (!dayCell.isCurrentMonth) return theme.textMuted;
                                                    if (dayCell.isSelected) return theme.bgDark;
                                                    if (dayCell.isToday) return theme.blueLight;
                                                    if (dayCell.mexicanHoliday) return "#fbbf24";
                                                    return theme.text;
                                                }
                                                font.family: theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: (dayCell.isSelected || dayCell.isToday || dayCell.mexicanHoliday) ? Font.Bold : Font.DemiBold
                                            }

                                            Row {
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 2
                                                
                                                Repeater {
                                                    model: Math.min(dayCell.dayCats.length, 3)
                                                    Rectangle {
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        color: dayCell.isSelected ? theme.bgDark : root.getCategoryColor(dayCell.dayCats[index])
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
                                    model: ["All"].concat(root.availableCategories)
                                    Rectangle {
                                        id: segPill
                                        property bool isAct: root.selectedCategory === modelData
                                        property color catCol: root.getCategoryColor(modelData)
                                        width: segRow.implicitWidth + (modelData === "F1" ? 18 : (modelData === "Colgate-Palmolive" ? 18 : (modelData === "School" ? 16 : (modelData === "Sara" ? 16 : (modelData === "Marvel" ? 22 : 14)))))
                                        height: 22
                                        radius: 11

                                        color: {
                                            if (isAct) {
                                                if (modelData === "All") return Qt.rgba(255, 255, 255, 0.18);
                                                return Qt.rgba(catCol.r, catCol.g, catCol.b, 0.22);
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

                                        // F1 Active Red Pulse
                                        Rectangle {
                                            visible: modelData === "F1" && segPill.isAct
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.color: "#E10600"
                                            border.width: 1
                                            opacity: 0.8
                                            SequentialAnimation on opacity {
                                                running: modelData === "F1" && segPill.isAct
                                                loops: Animation.Infinite
                                                NumberAnimation { from: 0.35; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                                NumberAnimation { from: 1.0; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                            }
                                        }

                                        // Sara Active Heart Pulse
                                        Rectangle {
                                            visible: modelData === "Sara" && segPill.isAct
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.color: "#ff2d55"
                                            border.width: 1
                                            opacity: 0.8
                                            SequentialAnimation on opacity {
                                                running: modelData === "Sara" && segPill.isAct
                                                loops: Animation.Infinite
                                                NumberAnimation { from: 0.35; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                                NumberAnimation { from: 1.0; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                            }
                                        }

                                        Row {
                                            id: segRow
                                            anchors.centerIn: parent
                                            spacing: 5

                                            // Category Indicator (F1 SVG, CP SVG, Troyanos SVG, Heart SVG, Marvel SVG, or Dot)
                                            Item {
                                                width: modelData === "F1" ? 14 : (modelData === "Colgate-Palmolive" ? 13 : (modelData === "School" ? 11 : (modelData === "Sara" ? 12 : (modelData === "Marvel" ? 18 : 5))))
                                                height: modelData === "F1" ? 10 : (modelData === "Colgate-Palmolive" ? 9 : (modelData === "School" ? 11 : (modelData === "Sara" ? 12 : (modelData === "Marvel" ? 8 : 5))))
                                                anchors.verticalCenter: parent.verticalCenter

                                                Rectangle {
                                                    visible: modelData !== "F1" && modelData !== "Colgate-Palmolive" && modelData !== "School" && modelData !== "Sara" && modelData !== "Marvel"
                                                    anchors.fill: parent
                                                    radius: width / 2
                                                    color: segPill.catCol
                                                    opacity: segPill.isAct ? 1.0 : 0.6
                                                }

                                                Image {
                                                    visible: modelData === "F1"
                                                    anchors.fill: parent
                                                    source: segPill.isAct ? "file:///home/ferram/.local/share/icons/f1-white.svg" : "file:///home/ferram/.local/share/icons/f1.svg"
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true

                                                    scale: 1.0
                                                    SequentialAnimation on scale {
                                                        running: modelData === "F1" && segPill.isAct
                                                        loops: Animation.Infinite
                                                        NumberAnimation { from: 0.90; to: 1.10; duration: 900; easing.type: Easing.InOutSine }
                                                        NumberAnimation { from: 1.10; to: 0.90; duration: 900; easing.type: Easing.InOutSine }
                                                    }
                                                }

                                                Image {
                                                    visible: modelData === "Colgate-Palmolive"
                                                    anchors.fill: parent
                                                    source: "file:///home/ferram/.local/share/icons/cp.svg"
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    opacity: segPill.isAct ? 1.0 : 0.75
                                                }

                                                Image {
                                                    visible: modelData === "School"
                                                    anchors.fill: parent
                                                    source: "file:///home/ferram/.local/share/icons/troyanos.svg"
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    opacity: segPill.isAct ? 1.0 : 0.75
                                                }

                                                Image {
                                                    visible: modelData === "Sara"
                                                    anchors.fill: parent
                                                    source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/holiday-heart.svg"
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                }

                                                Image {
                                                    visible: modelData === "Marvel"
                                                    anchors.fill: parent
                                                    source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg"
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                }
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
                                property bool titleError: false

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
                                            addFormRect.formPhoto
                                        );
                                    } else {
                                        root.addReminder(
                                            t,
                                            root.selectedDateStr,
                                            timeInput.text,
                                            addFormRect.formCat,
                                            addFormRect.formNotes,
                                            addFormRect.formPhoto
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
                                                model: root.availableCategories
                                                Rectangle {
                                                    id: formCatPill
                                                    property bool sel: addFormRect.formCat === modelData
                                                    property color catCol: root.getCategoryColor(modelData)
                                                    width: formCatTxt.implicitWidth + (modelData === "F1" ? 22 : (modelData === "Colgate-Palmolive" ? 22 : (modelData === "School" ? 20 : (modelData === "Sara" ? 20 : (modelData === "Marvel" ? 26 : 14)))))
                                                    height: 22
                                                    radius: 11

                                                    color: sel ? Qt.rgba(catCol.r, catCol.g, catCol.b, 0.22) : theme.surface
                                                    border.color: sel ? catCol : theme.borderSubtle
                                                    border.width: 1

                                                    Row {
                                                        anchors.centerIn: parent
                                                        spacing: 4

                                                        Image {
                                                            visible: modelData === "F1"
                                                            width: 12
                                                            height: 9
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: formCatPill.sel ? "file:///home/ferram/.local/share/icons/f1-white.svg" : "file:///home/ferram/.local/share/icons/f1.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Image {
                                                            visible: modelData === "Colgate-Palmolive"
                                                            width: 12
                                                            height: 8
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/.local/share/icons/cp.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            opacity: formCatPill.sel ? 1.0 : 0.75
                                                        }

                                                        Image {
                                                            visible: modelData === "School"
                                                            width: 10
                                                            height: 10
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/.local/share/icons/troyanos.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            opacity: formCatPill.sel ? 1.0 : 0.75
                                                        }

                                                        Image {
                                                            visible: modelData === "Sara"
                                                            width: 11
                                                            height: 11
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/holiday-heart.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Image {
                                                            visible: modelData === "Marvel"
                                                            width: 16
                                                            height: 8
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Text {
                                                            id: formCatTxt
                                                            text: modelData
                                                            color: formCatPill.sel ? formCatPill.catCol : (fCatMa.containsMouse ? theme.textSub : theme.textMuted)
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 9
                                                            font.weight: formCatPill.sel ? Font.Bold : Font.Normal
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
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

                                            // "+ Add Category" button / inline input
                                            Rectangle {
                                                id: addCatButton
                                                property bool editing: false
                                                width: editing ? 110 : 22
                                                height: 22
                                                radius: 11
                                                color: editing ? theme.surface : (addCatMa.containsMouse ? theme.surfaceHover : "transparent")
                                                border.color: editing ? theme.frost : (addCatMa.containsMouse ? theme.borderGlow : theme.borderSubtle)
                                                border.width: 1
                                                clip: true

                                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                                Row {
                                                    anchors.centerIn: parent
                                                    visible: !addCatButton.editing
                                                    Text {
                                                        text: "+"
                                                        color: theme.frost
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 12
                                                        font.weight: Font.Bold
                                                    }
                                                }

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 6
                                                    anchors.rightMargin: 4
                                                    visible: addCatButton.editing
                                                    spacing: 4

                                                    TextInput {
                                                        id: newCatInput
                                                        width: parent.width - 20
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        color: theme.text
                                                        font.family: theme.fontFamily
                                                        font.pixelSize: 9
                                                        clip: true
                                                        selectByMouse: true

                                                        Keys.onReturnPressed: commitNewCat()
                                                        Keys.onEnterPressed: commitNewCat()
                                                        Keys.onEscapePressed: {
                                                            addCatButton.editing = false;
                                                            newCatInput.text = "";
                                                        }

                                                        function commitNewCat() {
                                                            let name = newCatInput.text.trim();
                                                            if (name) {
                                                                root.addNewCategory(name);
                                                                addFormRect.formCat = name;
                                                                newCatInput.text = "";
                                                                addCatButton.editing = false;
                                                            }
                                                        }

                                                        Text {
                                                            anchors.fill: parent
                                                            visible: !parent.text
                                                            text: "Category..."
                                                            color: theme.textDim
                                                            font.family: theme.fontFamily
                                                            font.pixelSize: 9
                                                        }
                                                    }

                                                    Text {
                                                        text: "✔"
                                                        color: theme.frost
                                                        font.pixelSize: 9
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: newCatInput.commitNewCat()
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: addCatMa
                                                    anchors.fill: parent
                                                    visible: !addCatButton.editing
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        addCatButton.editing = true;
                                                        Qt.callLater(() => newCatInput.forceActiveFocus());
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

                                        // Marvel Energetic Crimson Pulse Animation
                                        Rectangle {
                                            visible: remCard.isMarvel
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.color: "#ed1d24"
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
                                                        Text {
                                                            text: "⏱"
                                                            color: remCard.catCol
                                                            font.pixelSize: 10
                                                            opacity: 0.9
                                                            anchors.verticalCenter: parent.verticalCenter
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

                                                        Image {
                                                            visible: modelData.category === "F1"
                                                            width: 14
                                                            height: 10
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/.local/share/icons/f1.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Image {
                                                            visible: modelData.category === "Colgate-Palmolive"
                                                            width: 13
                                                            height: 9
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/.local/share/icons/cp.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Image {
                                                            visible: modelData.category === "School"
                                                            width: 11
                                                            height: 11
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/.local/share/icons/troyanos.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Image {
                                                            visible: remCard.isSara
                                                            width: 12
                                                            height: 12
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/holiday-heart.svg"
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                        }

                                                        Image {
                                                            visible: remCard.isMarvel
                                                            width: 20
                                                            height: 9
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg"
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
                }
            }
        }
    }
}
