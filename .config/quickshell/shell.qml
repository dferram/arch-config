import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "components"
import "theme"

ShellRoot {
    id: shell

    // Central OSD Event Broker for smooth cross-component synchronization
    QtObject {
        id: osdService
        property string osdType: "volume"
        property int level: 50
        property bool isMuted: false
        property string customText: ""
        signal triggered()

        function show(type, val, muted, text) {
            osdType = type;
            level = Math.max(0, Math.min(100, val !== undefined ? val : 50));
            isMuted = !!muted;
            customText = text || "";
            triggered();
        }
    }

    // Shared Multi-Screen Timer Service (persisted via hypr-reminders)
    QtObject {
        id: sharedTimerService
        property var timers: []
        property var recents: []
        property real currentNowMs: Date.now()

        readonly property var soundOptions: [
            { id: "alarm", label: "Alarm", path: "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga" },
            { id: "bell", label: "Bell", path: "/usr/share/sounds/freedesktop/stereo/bell.oga" },
            { id: "complete", label: "Complete", path: "/usr/share/sounds/freedesktop/stereo/complete.oga" },
            { id: "message", label: "Chime", path: "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga" },
            { id: "f1", label: "F1 Radio", path: "/home/ferram/.local/share/sounds/f1.oga" },
            { id: "silent", label: "Stop Playing", path: "" }
        ]

        function getSoundLabel(soundId) {
            let k = (soundId || "alarm").toLowerCase();
            for (let i = 0; i < soundOptions.length; i++) {
                if (soundOptions[i].id === k) return soundOptions[i].label;
            }
            return "Alarm";
        }

        function playSound(soundId) {
            let k = (soundId || "alarm").toLowerCase();
            if (k === "silent") return;
            let p = "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
            for (let i = 0; i < soundOptions.length; i++) {
                if (soundOptions[i].id === k) {
                    p = soundOptions[i].path;
                    break;
                }
            }
            if (!p) return;
            timerSoundProc.running = false;
            timerSoundProc.command = ["pw-play", p];
            timerSoundProc.running = true;
        }

        readonly property int runningCount: {
            let c = 0;
            for (let i = 0; i < timers.length; i++) {
                if (timers[i].running) c++;
            }
            return c;
        }

        readonly property int finishedCount: {
            let c = 0;
            for (let i = 0; i < timers.length; i++) {
                if (timers[i].finished) c++;
            }
            return c;
        }

        function getRemainingSec(t) {
            if (!t || t.finished) return 0;
            if (!t.running || !t.endEpochMs) return Math.max(0, Math.floor(t.remainingSec || 0));
            return Math.max(0, Math.ceil((t.endEpochMs - currentNowMs) / 1000));
        }

        readonly property string barBadgeText: {
            if (finishedCount > 0) return "Done";
            let minRem = -1;
            for (let i = 0; i < timers.length; i++) {
                let t = timers[i];
                if (t.running) {
                    let rem = getRemainingSec(t);
                    if (rem > 0 && (minRem < 0 || rem < minRem)) minRem = rem;
                }
            }
            if (minRem >= 0) return formatDuration(minRem);
            return "";
        }

        function formatDuration(sec) {
            let s = Math.max(0, Math.floor(sec));
            let h = Math.floor(s / 3600);
            let m = Math.floor((s % 3600) / 60);
            let r = s % 60;
            let rr = (r < 10 ? "0" : "") + r;
            if (h > 0) {
                let mm = (m < 10 ? "0" : "") + m;
                return h + ":" + mm + ":" + rr;
            }
            return m + ":" + rr;
        }

        function persist() {
            saveTimersProc.running = false;
            let payload = { timers: timers, recents: recents };
            saveTimersProc.command = ["/home/ferram/.local/bin/hypr-reminders", "timers-save", "--data", JSON.stringify(payload)];
            saveTimersProc.running = true;
        }

        function recordRecent(label, totalSec, soundId) {
            let cleanLabel = (label || "").trim() || "Timer";
            let sId = soundId || "alarm";
            let filtered = recents.filter(r => !(r.label === cleanLabel && r.totalSec === totalSec));
            filtered.unshift({
                id: "rec_" + Date.now() + "_" + Math.floor(Math.random() * 1000),
                label: cleanLabel,
                totalSec: totalSec,
                sound: sId
            });
            recents = filtered.slice(0, 6);
        }

        function addTimer(label, totalSeconds, autoStart, soundId) {
            let sec = Math.max(1, Math.floor(totalSeconds));
            let cleanLabel = (label || "").trim() || "Timer";
            let sId = soundId || "alarm";
            let nowMs = Date.now();
            currentNowMs = nowMs;
            let item = {
                id: "tmr_" + nowMs + "_" + Math.floor(Math.random() * 1000),
                label: cleanLabel,
                totalSec: sec,
                remainingSec: sec,
                running: !!autoStart,
                finished: false,
                sound: sId,
                endEpochMs: autoStart ? (nowMs + sec * 1000) : 0
            };
            let next = timers.slice();
            next.unshift(item);
            timers = next;
            recordRecent(cleanLabel, sec, sId);
            persist();
        }

        function removeRecent(recId) {
            recents = recents.filter(r => r.id !== recId);
            persist();
        }

        function toggleTimer(id) {
            let nowMs = Date.now();
            currentNowMs = nowMs;
            let next = [];
            for (let i = 0; i < timers.length; i++) {
                let t = Object.assign({}, timers[i]);
                if (t.id === id) {
                    if (t.finished) {
                        t.remainingSec = t.totalSec;
                        t.finished = false;
                        t.running = true;
                        t.endEpochMs = nowMs + t.totalSec * 1000;
                    } else if (t.running) {
                        t.remainingSec = Math.max(0, Math.ceil((t.endEpochMs - nowMs) / 1000));
                        t.running = false;
                        t.endEpochMs = 0;
                    } else {
                        if (t.remainingSec <= 0) t.remainingSec = t.totalSec;
                        t.running = true;
                        t.endEpochMs = nowMs + t.remainingSec * 1000;
                    }
                }
                next.push(t);
            }
            timers = next;
            persist();
        }

        function resetTimer(id) {
            currentNowMs = Date.now();
            let next = [];
            for (let i = 0; i < timers.length; i++) {
                let t = Object.assign({}, timers[i]);
                if (t.id === id) {
                    t.running = false;
                    t.finished = false;
                    t.remainingSec = t.totalSec;
                    t.endEpochMs = 0;
                }
                next.push(t);
            }
            timers = next;
            persist();
        }

        function addMinutes(id, mins) {
            let delta = mins * 60;
            let nowMs = Date.now();
            currentNowMs = nowMs;
            let next = [];
            for (let i = 0; i < timers.length; i++) {
                let t = Object.assign({}, timers[i]);
                if (t.id === id) {
                    let curRem = t.running ? Math.max(0, Math.ceil((t.endEpochMs - nowMs) / 1000)) : (t.remainingSec || 0);
                    t.totalSec = Math.max(1, t.totalSec + delta);
                    t.remainingSec = Math.max(1, curRem + delta);
                    t.finished = false;
                    if (t.running) {
                        t.endEpochMs = nowMs + t.remainingSec * 1000;
                    }
                }
                next.push(t);
            }
            timers = next;
            persist();
        }

        function removeTimer(id) {
            let next = timers.filter(t => t.id !== id);
            timers = next;
            persist();
        }

        function notifyFinished(t) {
            timerNotifyProc.running = false;
            timerNotifyProc.command = [
                "notify-send", "-a", "Timer",
                "-i", "/home/ferram/.local/share/icons/calendar-3d.svg",
                "-u", "critical",
                "-t", "12000",
                "Timer Finished: " + t.label,
                formatDuration(t.totalSec) + " countdown completed"
            ];
            timerNotifyProc.running = true;

            playSound(t.sound || "alarm");
        }

        function tick() {
            let nowMs = Date.now();
            currentNowMs = nowMs;
            let changed = false;
            let finishedItems = [];
            let next = [];
            for (let i = 0; i < timers.length; i++) {
                let t = Object.assign({}, timers[i]);
                if (t.running) {
                    let rem = Math.max(0, Math.ceil((t.endEpochMs - nowMs) / 1000));
                    if (rem <= 0) {
                        t.running = false;
                        t.finished = true;
                        t.remainingSec = 0;
                        t.endEpochMs = 0;
                        changed = true;
                        finishedItems.push(t);
                    }
                }
                next.push(t);
            }
            if (changed) {
                timers = next;
                for (let j = 0; j < finishedItems.length; j++) {
                    notifyFinished(finishedItems[j]);
                }
                persist();
            }
        }
    }

    Timer {
        id: timerServiceTicker
        interval: 500
        repeat: true
        running: sharedTimerService.runningCount > 0
        onTriggered: sharedTimerService.tick()
    }

    Process {
        id: loadTimersProc
        command: ["/home/ferram/.local/bin/hypr-reminders", "timers-list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let parsed = JSON.parse(txt);
                    let rawTimers = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.timers) ? parsed.timers : []);
                    let rawRecents = (!Array.isArray(parsed) && Array.isArray(parsed.recents)) ? parsed.recents : [];
                    let nowMs = Date.now();
                    let restored = [];
                    for (let i = 0; i < rawTimers.length; i++) {
                        let t = Object.assign({}, rawTimers[i]);
                        if (t.running && t.endEpochMs > 0) {
                            let rem = Math.max(0, Math.ceil((t.endEpochMs - nowMs) / 1000));
                            t.remainingSec = rem;
                            if (rem <= 0) {
                                t.running = false;
                                t.finished = true;
                                t.endEpochMs = 0;
                            }
                        }
                        restored.push(t);
                    }
                    sharedTimerService.currentNowMs = nowMs;
                    sharedTimerService.timers = restored;
                    sharedTimerService.recents = rawRecents;
                } catch(e) {}
            }
        }
    }

    Process { id: saveTimersProc }
    Process { id: timerNotifyProc }
    Process {
        id: timerSoundProc
        command: ["pw-play", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]
    }
    // Desktop Notification Daemon with Dynamic App Colors & Moving LED Border
    NotificationOverlay {
        osdService: osdService
    }

    // Top-Center Dynamic Island Liquid Glass OSD for Volume & Brightness
    OsdOverlay {
        osdService: osdService
    }

    // Lock screen: OLED flip clock -> control panel on click / typing (Super+L)
    LockScreen {}

    // Spotlight / Raycast-style Liquid Obsidian App Launcher (Super+R)
    AppLauncher {}

    // Dynamic Top Bar visibility state and IPC controller
    property bool barVisible: true
    property bool widgetsVisible: true
    property bool showGridGuide: false

    IpcHandler {
        target: "bar"
        function toggle() {
            shell.barVisible = !shell.barVisible;
        }
        function open() {
            shell.barVisible = true;
        }
        function close() {
            shell.barVisible = false;
        }
        function setVisible(v: bool) {
            shell.barVisible = v;
        }
        function isVisible(): bool {
            return shell.barVisible;
        }
    }

    // Dynamic Desktop Widgets IPC controller
    IpcHandler {
        target: "widgets"
        function toggle() {
            shell.widgetsVisible = !shell.widgetsVisible;
        }
        function open() {
            shell.widgetsVisible = true;
        }
        function close() {
            shell.widgetsVisible = false;
        }
        function setVisible(v: bool) {
            shell.widgetsVisible = v;
        }
        function isVisible(): bool {
            return shell.widgetsVisible;
        }
        function toggleGrid() {
            shell.showGridGuide = !shell.showGridGuide;
        }
        function setGrid(v: bool) {
            shell.showGridGuide = v;
        }
        function isGridVisible(): bool {
            return shell.showGridGuide;
        }
        function reloadGrid() {
            shell.showGridGuide = shell.showGridGuide; // tickle
            shell.gridReloadTick = shell.gridReloadTick + 1;
        }
    }

    property int gridReloadTick: 0

    // Apple Sonoma Desktop Widgets Overlay (Workspace 1 on laptop, Workspace 6 on external display)
    Variants {
        model: Quickshell.screens

        delegate: Component {
            DesktopWidgetsOverlay {
                modelData: modelData
                enabled: shell.widgetsVisible
                showGridGuide: shell.showGridGuide
                timerService: sharedTimerService
            }
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData
                screen: modelData

                visible: shell.barVisible

                onVisibleChanged: {
                    if (!visible) currentPopup = "";
                }

                // Layer shell anchors
                anchors {
                    top: true
                    left: true
                    right: true
                }

                // Margins for modern floating bar
                margins {
                    top: 6
                    left: 12
                    right: 12
                }

                // Bar height
                implicitHeight: 38

                // Window background is transparent for rounded floating effect
                color: "transparent"

                // Accept keyboard focus when clock popup with text input is open
                focusable: currentPopup === "clock"

                // Shared active popup state for this bar
                property string currentPopup: ""

                function togglePopup(id) {
                    if (currentPopup === id) {
                        currentPopup = "";
                    } else {
                        currentPopup = id;
                    }
                }

                Theme { id: theme }

                // Background click area to dismiss active popups
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: barWindow.currentPopup = ""
                }

                // Left Island: Arch Badge + Workspaces + Media
                Rectangle {
                    id: leftIsland
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: leftSection.implicitWidth + 16
                    radius: theme.radius
                    color: theme.bgGlass
                    border.color: theme.border
                    border.width: 1

                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    // Specular Liquid Glass inner sheen
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        z: -1
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
                            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.015) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04) }
                        }
                    }

                    Row {
                        id: leftSection
                        anchors.centerIn: parent
                        spacing: 10

                        HostBadge {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        // Subtle vertical separator
                        Rectangle {
                            width: 1
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            color: theme.borderSubtle
                        }

                        WorkspacesWidget {
                            anchors.verticalCenter: parent.verticalCenter
                            targetScreen: barWindow.screen ? barWindow.screen : modelData
                        }

                        MediaWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                    }
                }

                // Center Island: Clock
                Rectangle {
                    id: centerIsland
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: centerSection.implicitWidth + 24
                    radius: theme.radius
                    color: theme.bgGlass
                    border.color: theme.border
                    border.width: 1

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        z: -1
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
                            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.015) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04) }
                        }
                    }

                    Row {
                        id: centerSection
                        anchors.centerIn: parent
                        spacing: 14

                        WeatherWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                        ClockWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            timerService: sharedTimerService
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                    }
                }

                // Right Island: System Widgets
                Rectangle {
                    id: rightIsland
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: rightSection.implicitWidth + 24
                    radius: theme.radius
                    color: theme.bgGlass
                    border.color: theme.border
                    border.width: 1

                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    // Specular Liquid Glass inner sheen
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        z: -1
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
                            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.015) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04) }
                        }
                    }

                    Row {
                        id: rightSection
                        anchors.centerIn: parent
                        spacing: 14

                        SysResourceWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        StorageWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        BluetoothWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        WifiWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        DisplayWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        BatteryWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                    }
                }
            }
        }
    }
}
