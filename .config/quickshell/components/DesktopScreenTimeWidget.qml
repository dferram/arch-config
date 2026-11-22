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
    // Apple Sonoma Obsidian Frosted Glass
    color: theme.widgetGlass
    border.color: hoverArea.containsMouse ? theme.border : theme.borderSubtle
    border.width: 1
    clip: true

    Behavior on border.color { ColorAnimation { duration: 180 } }

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null

    // Telemetry state
    property string totalFormatted: "0s"
    property int totalSeconds: 0
    property int productivityScore: 100
    property string workFormatted: "0s"
    property int workSeconds: 0
    property string slackingFormatted: "0s"
    property int slackingSeconds: 0
    property string currentClass: ""
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true
    property string currentCategory: "Other"
    property double lastFetchMs: 0

    // Ratios
    readonly property real workRatio: totalSeconds > 0 ? Math.min(1.0, workSeconds / totalSeconds) : 0
    readonly property real slackingRatio: totalSeconds > 0 ? Math.min(1.0, slackingSeconds / totalSeconds) : 0
    readonly property real otherRatio: totalSeconds > 0 ? Math.max(0, 1.0 - workRatio - slackingRatio) : 0

    // Fetch stats
    Process {
        id: statsProc
        command: ["/home/ferram/.local/bin/hypr-screentime", "stats", "--json"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                root.lastFetchMs = Date.now();
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.totalFormatted = d.formatted_total || "0s";
                    root.totalSeconds = d.total_seconds || 0;
                    root.productivityScore = d.productivity_score !== undefined ? d.productivity_score : 100;
                    root.workFormatted = d.work_formatted || "0s";
                    root.workSeconds = d.work_seconds || 0;
                    root.slackingFormatted = d.slacking_formatted || d.wey_formatted || "0s";
                    root.slackingSeconds = d.slacking_seconds || d.wey_seconds || 0;
                    if (d.current_window) {
                        root.currentClass = d.current_window.class || "";
                        root.currentCategory = d.current_window.category || "Other";
                    }
                    donutCanvas.requestPaint();
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.isLive
        onTriggered: {
            if (root.isLive && !statsProc.running) statsProc.running = true;
        }
    }

    Component.onCompleted: {
        if (!statsProc.running) statsProc.running = true;
    }

    onIsLiveChanged: {
        if (isLive && !statsProc.running && (Date.now() - root.lastFetchMs > 10000)) {
            statsProc.running = true;
        }
    }

    Process {
        id: guiProc
        command: ["/home/ferram/.local/bin/hypr-screentime-gui"]
    }

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
            if (isDragging && root.wrapper) {
                root.wrapper.updateDrag(dx, dy);
            }
        }

        onReleased: (mouse) => {
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
            if (isDragging) return;
            if (root.wrapper && root.wrapper.overlay && root.wrapper.overlay.showGridGuide) {
                return;
            }
            guiProc.running = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 11

        // Header: Title + Productivity Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Screen Time"
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: theme.textSub
                Layout.fillWidth: true
            }

            // Productivity Pill
            Rectangle {
                implicitHeight: 20
                implicitWidth: scoreText.implicitWidth + 12
                radius: 10
                color: root.productivityScore >= 70 ? Qt.rgba(0.19, 0.82, 0.35, 0.16) : Qt.rgba(1.0, 0.27, 0.23, 0.16)
                border.color: root.productivityScore >= 70 ? "#30d158" : "#ff453a"
                border.width: 1

                Text {
                    id: scoreText
                    anchors.centerIn: parent
                    text: root.productivityScore + "%"
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: root.productivityScore >= 70 ? "#30d158" : "#ff453a"
                }
            }
        }

        // Helicopter View Row: Big Metric + Mini Radial Donut Chart
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Column {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: root.totalFormatted
                    font.family: theme.fontFamily
                    font.pixelSize: 27
                    font.weight: Font.Bold
                    color: theme.text
                }

                Text {
                    text: "Total Today"
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: theme.textDim
                }
            }

            // Mini Radial Donut (Helicopter View Chart)
            Item {
                width: 56
                height: 56

                Canvas {
                    id: donutCanvas
                    anchors.fill: parent
                    antialiasing: true

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.reset();

                        let cx = width / 2;
                        let cy = height / 2;
                        let radius = (width - 10) / 2;
                        let lw = 6;

                        // Background ring
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.10)";
                        ctx.lineWidth = lw;
                        ctx.stroke();

                        if (root.totalSeconds <= 0) return;

                        let startAngle = -0.5 * Math.PI;

                        // Work slice (Emerald)
                        if (root.workRatio > 0.01) {
                            let endAngle = startAngle + (root.workRatio * 2 * Math.PI);
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, startAngle, endAngle);
                            ctx.strokeStyle = "#30d158";
                            ctx.lineWidth = lw;
                            ctx.lineCap = "round";
                            ctx.stroke();
                            startAngle = endAngle;
                        }

                        // Entertainment slice (Coral Red)
                        if (root.slackingRatio > 0.01) {
                            let endAngle = startAngle + (root.slackingRatio * 2 * Math.PI);
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, startAngle, endAngle);
                            ctx.strokeStyle = "#ff453a";
                            ctx.lineWidth = lw;
                            ctx.lineCap = "round";
                            ctx.stroke();
                            startAngle = endAngle;
                        }

                        // Other slice (Zinc)
                        if (root.otherRatio > 0.01) {
                            let endAngle = startAngle + (root.otherRatio * 2 * Math.PI);
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, startAngle, endAngle);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.35)";
                            ctx.lineWidth = lw;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Stats with individual progress graphs
        Column {
            Layout.fillWidth: true
            spacing: 10

            // Work & Dev Stat Row
            Column {
                width: parent.width
                spacing: 4

                RowLayout {
                    width: parent.width
                    Row {
                        spacing: 6
                        Layout.fillWidth: true
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#30d158"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Work"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: theme.textSub
                        }
                    }
                    Text {
                        text: root.workFormatted + " (" + Math.round(root.workRatio * 100) + "%)"
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#30d158"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle {
                        height: parent.height
                        width: Math.max(0, Math.round(parent.width * root.workRatio))
                        radius: 3
                        color: "#30d158"
                    }
                }
            }

            // Entertainment Stat Row
            Column {
                width: parent.width
                spacing: 4

                RowLayout {
                    width: parent.width
                    Row {
                        spacing: 6
                        Layout.fillWidth: true
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#ff453a"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Entertainment"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: theme.textSub
                        }
                    }
                    Text {
                        text: root.slackingFormatted + " (" + Math.round(root.slackingRatio * 100) + "%)"
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#ff453a"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle {
                        height: parent.height
                        width: Math.max(0, Math.round(parent.width * root.slackingRatio))
                        radius: 3
                        color: "#ff453a"
                    }
                }
            }
        }
    }
}
