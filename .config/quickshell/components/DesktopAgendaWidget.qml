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
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true
    property double lastFetchMs: 0

    property var todayEvents: []
    property var nextEvent: null
    property var laterEvents: []
    property int upcomingCount: 0

    function categoryColor(cat, title) {
        let c = (cat || "").toLowerCase();
        let t = (title || "").toLowerCase();
        if (c === "sara" || t.indexOf("sara") !== -1) return "#ff2d55";
        if (c === "marvel" || t.indexOf("marvel") !== -1 || t.indexOf("doomsday") !== -1) return "#10b981";
        if (c === "f1") return "#E10600";
        if (c === "colgate-palmolive") return "#0067fe";
        if (c === "projects") return "#14b8a6";
        if (c === "workshops" || c === "workshop") return "#8b5cf6";
        if (c === "community") return "#f59e0b";
        if (c === "free lance" || c === "free-lance" || c === "freelance") return "#06b6d4";
        if (c === "school") return "#a855f7";
        if (c === "personal") return "#f97316";
        return "#38bdf8";
    }

    function timeToMinutes(tStr) {
        if (!tStr) return 0;
        let parts = tStr.split(":");
        if (parts.length < 2) return 0;
        return (parseInt(parts[0], 10) || 0) * 60 + (parseInt(parts[1], 10) || 0);
    }

    function relativeLabel(ev) {
        if (!ev) return "";
        if (ev.all_day) return "All day";
        let now = new Date();
        let nowMin = now.getHours() * 60 + now.getMinutes();
        let evMin = timeToMinutes(ev.time);
        let dur = ev.duration_min || 60;
        let diff = evMin - nowMin;
        if (diff <= 0 && diff >= -dur) return "Now";
        if (diff > 0 && diff < 60) return "in " + diff + "m";
        if (diff >= 60) {
            let h = Math.floor(diff / 60);
            let m = diff % 60;
            return m > 0 ? ("in " + h + "h " + m + "m") : ("in " + h + "h");
        }
        return ev.time || "";
    }

    function rebuildSchedule(list) {
        let now = new Date();
        let nowMin = now.getHours() * 60 + now.getMinutes();
        let sorted = (list || []).slice().filter(r => !r.done);
        sorted.sort((a, b) => {
            if (!!a.all_day !== !!b.all_day) return a.all_day ? 1 : -1;
            return timeToMinutes(a.time) - timeToMinutes(b.time);
        });

        let upcoming = [];
        for (let i = 0; i < sorted.length; i++) {
            let r = sorted[i];
            if (r.all_day) {
                upcoming.push(r);
                continue;
            }
            let evMin = timeToMinutes(r.time);
            let dur = r.duration_min || 60;
            // Include ongoing or upcoming today
            if (evMin + Math.min(dur, 45) >= nowMin) {
                upcoming.push(r);
            }
        }

        root.todayEvents = sorted;
        root.upcomingCount = upcoming.length;
        root.nextEvent = upcoming.length > 0 ? upcoming[0] : null;
        root.laterEvents = upcoming.length > 1 ? upcoming.slice(1, 4) : [];
    }

    Process {
        id: agendaProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastFetchMs = Date.now();
                let txt = text.trim();
                if (!txt || !txt.startsWith("[")) return;
                try {
                    let list = JSON.parse(txt);
                    if (Array.isArray(list)) root.rebuildSchedule(list);
                } catch(e) {}
            }
        }
    }

    function fetchToday() {
        if (agendaProc.running) return;
        let dStr = Qt.formatDate(new Date(), "yyyy-MM-dd");
        agendaProc.command = ["/home/ferram/.local/bin/hypr-reminders", "list", "--date", dStr];
        agendaProc.running = true;
    }

    Component.onCompleted: fetchToday()

    Timer {
        interval: 60000
        repeat: true
        running: root.isLive
        onTriggered: {
            if (root.isLive) root.fetchToday();
        }
    }

    onIsLiveChanged: {
        if (isLive && (Date.now() - root.lastFetchMs > 30000)) {
            fetchToday();
        } else if (isLive && root.todayEvents.length > 0) {
            rebuildSchedule(root.todayEvents);
        }
    }

    // Drag & right-click menu MouseArea
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : (containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor)
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

        onClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton || isDragging) return;
            if (root.wrapper && root.wrapper.overlay && root.wrapper.overlay.showGridGuide) return;
            root.fetchToday();
        }
    }

    // Specular top hairline highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(255, 255, 255, 0.16)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // Header: Today + Date Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Today"
                color: "#ffffff"
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredHeight: 18
                Layout.preferredWidth: dateBadgeTxt.implicitWidth + 10
                radius: 9
                color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.20)
                border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.45)
                border.width: 1

                Text {
                    id: dateBadgeTxt
                    anchors.centerIn: parent
                    text: Qt.formatDate(new Date(), "ddd d")
                    color: theme.blueLight != "" ? theme.blueLight : theme.blue
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }

        // Next Up Spotlight Card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 10
            visible: !!root.nextEvent
            readonly property color evCol: root.nextEvent ? root.categoryColor(root.nextEvent.category, root.nextEvent.title) : theme.blue
            color: Qt.rgba(evCol.r, evCol.g, evCol.b, 0.14)
            border.color: Qt.rgba(evCol.r, evCol.g, evCol.b, 0.40)
            border.width: 1
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3.5
                color: parent.evCol
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 9
                anchors.topMargin: 7
                anchors.bottomMargin: 7
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: root.nextEvent ? (root.nextEvent.all_day ? "ALL DAY" : root.nextEvent.time) : ""
                        color: parent.parent.parent.evCol
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.relativeLabel(root.nextEvent)
                        color: "#ffffff"
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.nextEvent ? (root.nextEvent.title || "") : ""
                    color: "#ffffff"
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
        }

        // Empty State when all done for today
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.nextEvent

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰄬"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22
                    color: "#30d158"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "All clear today"
                    color: theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        // Remaining Upcoming Events Today
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.laterEvents.length > 0
            spacing: 5

            Repeater {
                model: root.laterEvents
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: 7
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.06)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: root.categoryColor(modelData.category, modelData.title)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || ""
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.all_day ? "Day" : (modelData.time || "")
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        Item {
            Layout.fillHeight: true
            visible: !!root.nextEvent && root.laterEvents.length === 0
        }
    }
}
