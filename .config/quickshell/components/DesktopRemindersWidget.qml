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
    color: Qt.rgba(0.06, 0.06, 0.09, 0.55)
    border.color: Qt.rgba(255, 255, 255, 0.10)
    border.width: 1
    clip: true

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null
    property var monthReminders: []
    property int currentMonthCount: 0
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

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
                let txt = text.trim();
                if (!txt) return;
                try {
                    let list = JSON.parse(txt);
                    if (Array.isArray(list)) {
                        // FILTER: Reminders for CURRENT MONTH ONLY, and ONLY UPCOMING (today or future dates, not past)
                        let now = new Date();
                        let y = now.getFullYear();
                        let m = String(now.getMonth() + 1).padStart(2, '0');
                        let d = String(now.getDate()).padStart(2, '0');
                        let todayStr = y + "-" + m + "-" + d;

                        let filtered = list.filter(r => r.date && r.date.startsWith(root.currentMonthPrefix) && r.date >= todayStr);
                        // Sort by date and time
                        filtered.sort((a, b) => {
                            let da = (a.date || "") + " " + (a.time || "");
                            let db = (b.date || "") + " " + (b.time || "");
                            return da.localeCompare(db);
                        });
                        root.monthReminders = filtered;
                        root.currentMonthCount = filtered.length;
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
        if (isLive && !readRemindersProc.running) {
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

            // Month Counter Badge
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: countTxt.implicitWidth + 12
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Text {
                    id: countTxt
                    anchors.centerIn: parent
                    text: root.currentMonthCount.toString()
                    color: theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
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

                            // Category / Reminder Indicator (Heart for Sara, Marvel for Doomsday, F1, CP, Troyanos, or bullet)
                            Item {
                                readonly property string catLow: (modelData.category || "").toLowerCase()
                                readonly property string titleLow: (modelData.title || "").toLowerCase()
                                readonly property bool isSara: catLow === "sara" || titleLow.indexOf("sara") !== -1
                                readonly property bool isMarvel: catLow === "marvel" || titleLow.indexOf("doomsday") !== -1 || titleLow.indexOf("marvel") !== -1
                                readonly property bool isF1: catLow === "f1" || titleLow.indexOf("formula 1") !== -1 || titleLow.indexOf("grand prix") !== -1
                                readonly property bool isCP: catLow === "colgate-palmolive" || catLow === "colgate"
                                readonly property bool isSchool: catLow === "school" || catLow === "troyanos"

                                width: isSara ? 11 : (isMarvel ? 16 : (isF1 ? 12 : (isCP ? 11 : (isSchool ? 10 : 8))))
                                height: isSara ? 11 : (isMarvel ? 8 : (isF1 ? 8 : (isCP ? 8 : (isSchool ? 10 : 8))))
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    visible: !parent.isSara && !parent.isMarvel && !parent.isF1 && !parent.isCP && !parent.isSchool
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: {
                                        if (parent.catLow === "projects") return "#10b981";
                                        if (parent.catLow === "workshops" || parent.catLow === "workshop") return "#8b5cf6";
                                        if (parent.catLow === "community") return "#06b6d4";
                                        if (parent.catLow === "free lance" || parent.catLow === "free-lance" || parent.catLow === "freelance") return "#06b6d4";
                                        if (parent.catLow === "gym") return "#eab308";
                                        if (parent.catLow === "family") return "#f43f5e";
                                        if (parent.catLow === "personal") return "#f97316";
                                        return "#38bdf8";
                                    }
                                }

                                Image {
                                    visible: parent.isSara
                                    anchors.fill: parent
                                    source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/holiday-heart.svg"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                Image {
                                    visible: parent.isMarvel
                                    anchors.fill: parent
                                    source: "file:///home/ferram/Personal/dotfiles/.config/quickshell/icons/marvel.svg"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }


                                Image {
                                    visible: parent.isF1
                                    anchors.fill: parent
                                    source: "file:///home/ferram/.local/share/icons/f1.svg"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                Image {
                                    visible: parent.isCP
                                    anchors.fill: parent
                                    source: "file:///home/ferram/.local/share/icons/cp.svg"
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                Image {
                                    visible: parent.isSchool
                                    anchors.fill: parent
                                    source: "file:///home/ferram/.local/share/icons/troyanos.svg"
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
