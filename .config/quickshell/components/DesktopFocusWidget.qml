import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 216
    implicitHeight: 207
    width: implicitWidth
    height: implicitHeight

    radius: 20
    // Apple Sonoma Translucent Obsidian Glass
    color: theme.widgetGlass
    border.color: hoverArea.containsMouse ? theme.border : theme.borderSubtle
    border.width: 1
    clip: true

    Behavior on border.color { ColorAnimation { duration: 180 } }

    function findWrapper() {
        let p = root.parent;
        while (p) {
            if (p.overlay !== undefined && p.startDrag !== undefined) return p;
            if (p.wrapperRef !== undefined) return p.wrapperRef;
            p = p.parent;
        }
        return null;
    }
    readonly property var wrapper: findWrapper()
    property var timerService: null
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    property int selectedMinutes: 25
    property string selectedLabel: "Focus"

    // Find active focus/first timer in sharedTimerService
    readonly property var activeTimer: {
        if (!timerService || !timerService.timers || timerService.timers.length === 0) return null;
        for (let i = 0; i < timerService.timers.length; i++) {
            if (timerService.timers[i].running) return timerService.timers[i];
        }
        for (let j = 0; j < timerService.timers.length; j++) {
            let lbl = (timerService.timers[j].label || "").toLowerCase();
            if (lbl.indexOf("focus") !== -1 || lbl.indexOf("break") !== -1 || lbl.indexOf("pomodoro") !== -1) {
                return timerService.timers[j];
            }
        }
        return timerService.timers[0];
    }

    readonly property bool isRunning: !!(activeTimer && activeTimer.running)
    readonly property bool isFinished: !!(activeTimer && activeTimer.finished)
    readonly property int totalSeconds: activeTimer ? Math.max(1, activeTimer.totalSec || (selectedMinutes * 60)) : (selectedMinutes * 60)
    readonly property int remainingSeconds: {
        if (!activeTimer) return selectedMinutes * 60;
        return timerService ? timerService.getRemainingSec(activeTimer) : (activeTimer.remainingSec || 0);
    }
    readonly property real progressRatio: totalSeconds > 0 ? Math.max(0, Math.min(1, remainingSeconds / totalSeconds)) : 1.0
    readonly property string timeText: timerService ? timerService.formatDuration(remainingSeconds) : (selectedMinutes + ":00")
    readonly property color accentColor: isFinished ? "#ff453a" : (isRunning ? "#30d158" : (theme.blueLight != "" ? theme.blueLight : "#0a84ff"))

    function selectPreset(mins, label) {
        selectedMinutes = mins;
        selectedLabel = label;
        if (!timerService) return;
        if (activeTimer && !activeTimer.running) {
            timerService.removeTimer(activeTimer.id);
            timerService.addTimer(label, mins * 60, false, "complete");
        }
    }

    function toggleStartPause() {
        if (!timerService) return;
        if (activeTimer) {
            timerService.toggleTimer(activeTimer.id);
        } else {
            timerService.addTimer(selectedLabel, selectedMinutes * 60, true, "complete");
        }
    }

    function resetFocus() {
        if (!timerService || !activeTimer) return;
        timerService.resetTimer(activeTimer.id);
    }

    function addFiveMin() {
        if (!timerService) return;
        if (activeTimer) {
            timerService.addMinutes(activeTimer.id, 5);
        } else {
            selectedMinutes = Math.min(120, selectedMinutes + 5);
        }
    }

    // Drag & right-click menu MouseArea
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (root.wrapper) root.wrapper.menuOpen = !root.wrapper.menuOpen;
                return;
            }
            if (mouse.button !== Qt.LeftButton) return;
            if (root.wrapper && root.wrapper.menuOpen) root.wrapper.menuOpen = false;
            let canvasPt = mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
            startScreenX = canvasPt.x;
            startScreenY = canvasPt.y;
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!hoverArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                if (isDragging) {
                    isDragging = false;
                    if (root.wrapper) root.wrapper.endDrag();
                }
                return;
            }
            let canvasPt = mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
            let dx = canvasPt.x - startScreenX;
            let dy = canvasPt.y - startScreenY;
            if (!isDragging && Math.hypot(dx, dy) > 4) {
                isDragging = true;
                if (root.wrapper) root.wrapper.startDrag(mouse.x, mouse.y);
            }
            if (isDragging && root.wrapper) root.wrapper.updateDrag(dx, dy);
        }

        onReleased: {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
        }

        onCanceled: {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 9

        // Header: Focus Title + State Pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.activeTimer ? (root.activeTimer.label || "Focus") : root.selectedLabel
                color: "#ffffff"
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredHeight: 18
                Layout.preferredWidth: stateTxt.implicitWidth + 10
                radius: 9
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                border.width: 1

                Text {
                    id: stateTxt
                    anchors.centerIn: parent
                    text: root.isFinished ? "Done" : (root.isRunning ? "Active" : (root.activeTimer ? "Paused" : "Ready"))
                    color: root.accentColor
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }

        // Countdown Hero + Progress Bar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.timeText
                color: root.isFinished ? "#ff453a" : "#ffffff"
                font.family: theme.fontFamily
                font.pixelSize: 32
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.08)

                Rectangle {
                    height: parent.height
                    width: Math.max(4, Math.round(parent.width * root.progressRatio))
                    radius: 2.5
                    color: root.accentColor
                    Behavior on width { NumberAnimation { duration: 250 } }
                }
            }
        }

        // Preset Pills (5m, 15m, 25m, 50m)
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: [
                    { "m": 5,  "lbl": "Break", "txt": "5m" },
                    { "m": 15, "lbl": "Focus", "txt": "15m" },
                    { "m": 25, "lbl": "Focus", "txt": "25m" },
                    { "m": 50, "lbl": "Focus", "txt": "50m" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isSel: !root.isRunning && (Math.round(root.totalSeconds / 60) === modelData.m)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    radius: 6
                    color: isSel ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.25) : (preMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: isSel ? root.accentColor : Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.txt
                        color: isSel ? "#ffffff" : theme.textSub
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.bold: isSel
                    }

                    MouseArea {
                        id: preMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectPreset(modelData.m, modelData.lbl)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Action Controls Row: Start/Pause, Reset, +5m
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 8
                color: startMa.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.36) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
                border.color: root.accentColor
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: root.isRunning ? "󰏤" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.isFinished ? "Restart" : (root.isRunning ? "Pause" : "Start")
                        color: "#ffffff"
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: startMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleStartPause()
                }
            }

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: rstMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰑙"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: theme.textSub
                }

                MouseArea {
                    id: rstMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetFocus()
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 28
                radius: 8
                color: plusMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "+5m"
                    color: theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }

                MouseArea {
                    id: plusMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addFiveMin()
                }
            }
        }
    }
}
