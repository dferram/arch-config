import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root

    Theme { id: theme }

    implicitWidth: 448
    implicitHeight: 208

    radius: 20
    // Obsidian Translucent Glass matching other widgets
    color: Qt.rgba(0.06, 0.06, 0.09, 0.72)
    border.color: Qt.rgba(255, 255, 255, 0.10)
    border.width: 1
    clip: true

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null
    readonly property string githubSvg: Quickshell.shellPath("icons/github.svg")

    // State
    property string username: "dferram"
    property int currentYear: 2026
    property string displayName: "Fernando Ramírez"
    property int totalContributions: 0
    property int currentStreak: 0
    property int longestStreak: 0
    property var monthsData: []
    property var daysData: []
    property int totalCols: 53
    property string lastUpdated: ""
    property bool isLoading: false

    // Hover state for interactive inspection
    property var hoveredDay: null

    // Cascade entrance wave animation
    property real animPhase: 0.0

    NumberAnimation {
        id: cascadeAnim
        target: root
        property: "animPhase"
        from: 0.0
        to: 56.0
        duration: 900
        easing.type: Easing.OutCubic
    }

    // Authentic GitHub Dark Mode Contribution Shades
    readonly property color colLevel0: Qt.rgba(1, 1, 1, 0.05)
    readonly property color colLevel1: "#0e4429"
    readonly property color colLevel2: "#006d32"
    readonly property color colLevel3: "#26a641"
    readonly property color colLevel4: "#39d353"
    readonly property color colFuture: Qt.rgba(1, 1, 1, 0.02)

    function getColorForLevel(level, isFuture) {
        if (isFuture) return root.colFuture;
        switch (level) {
            case 1: return root.colLevel1;
            case 2: return root.colLevel2;
            case 3: return root.colLevel3;
            case 4: return root.colLevel4;
            default: return root.colLevel0;
        }
    }

    // Refresh process
    Process {
        id: githubProc
        command: ["python3", Quickshell.shellPath("scripts/github-contributions.py"), "get", root.username, String(root.currentYear)]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.isLoading = false;
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.username) root.username = d.username;
                    if (d.name) root.displayName = d.name;
                    if (d.total !== undefined) root.totalContributions = d.total;
                    if (d.currentStreak !== undefined) root.currentStreak = d.currentStreak;
                    if (d.longestStreak !== undefined) root.longestStreak = d.longestStreak;
                    if (d.months) root.monthsData = d.months;
                    if (d.totalCols) root.totalCols = d.totalCols;
                    if (d.updatedAt) root.lastUpdated = d.updatedAt;
                    if (d.days && d.days.length > 0) {
                        root.daysData = d.days;
                        root.animPhase = 0.0;
                        cascadeAnim.restart();
                    }
                } catch(e) {
                    console.log("Error parsing GitHub contributions JSON:", e);
                }
            }
        }

        onExited: {
            root.isLoading = false;
        }
    }

    function refreshData(force) {
        root.isLoading = true;
        let action = force ? "fetch" : "get";
        githubProc.command = ["python3", Quickshell.shellPath("scripts/github-contributions.py"), action, root.username, String(root.currentYear)];
        githubProc.running = true;
    }

    Component.onCompleted: {
        refreshData(false);
    }

    Timer {
        interval: 1800000
        repeat: true
        running: true
        onTriggered: root.refreshData(true)
    }

    // Specular top hairline highlight (Apple Sonoma aesthetic)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(255, 255, 255, 0.16)
    }

    // Content container filling the card with balanced margins
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 13
        anchors.bottomMargin: 12
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 7

        // =====================================================================
        // HEADER: GitHub Logo, User & Two Elegant Stat Tiles (NO EMOJIS)
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 8

            // GitHub Icon squircle
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 9
                color: Qt.rgba(255, 255, 255, 0.08)
                border.color: Qt.rgba(255, 255, 255, 0.16)
                border.width: 1

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: root.githubSvg
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/" + root.username])
                }
            }

            // User Info & Large Commit Count
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                RowLayout {
                    spacing: 5
                    Text {
                        text: "@" + root.username
                        color: "#ffffff"
                        font.family: "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Rectangle {
                        Layout.preferredHeight: 14
                        Layout.preferredWidth: yearBadgeText.implicitWidth + 8
                        radius: 4
                        color: Qt.rgba(48, 209, 88, 0.18)

                        Text {
                            id: yearBadgeText
                            anchors.centerIn: parent
                            text: String(root.currentYear)
                            color: "#30d158"
                            font.family: "sans-serif"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                Text {
                    text: root.totalContributions.toLocaleString() + " contributions"
                    color: "#30d158"
                    font.family: "sans-serif"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            // Stat Tile 1: Current Streak
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 36
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.05)
                border.color: Qt.rgba(255, 159, 10, 0.28)
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentStreak + "d"
                        color: "#ff9f0a"
                        font.family: "sans-serif"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "STREAK"
                        color: theme.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 7
                        font.bold: true
                    }
                }
            }

            // Stat Tile 2: Best Streak
            Rectangle {
                Layout.preferredWidth: 72
                Layout.preferredHeight: 36
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.05)
                border.color: Qt.rgba(255, 214, 10, 0.25)
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.longestStreak + "d"
                        color: "#ffd60a"
                        font.family: "sans-serif"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "BEST"
                        color: theme.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 7
                        font.bold: true
                    }
                }
            }

            // Refresh Button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 36
                radius: 8
                color: refHover.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.12)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: root.isLoading ? "#30d158" : (refHover.containsMouse ? "#ffffff" : theme.textMuted)

                    RotationAnimation on rotation {
                        running: root.isLoading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                    }
                }

                MouseArea {
                    id: refHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refreshData(true)
                }
            }
        }

        // Elegant Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(255, 255, 255, 0.07)
        }

        // =====================================================================
        // GREEN WALL MATRIX: PERFECT 1:1 SQUARES (NEVER STRETCHED)
        // =====================================================================
        Item {
            id: matrixArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real dayLabelWidth: 10
            readonly property real labelSpacing: 6
            readonly property real availableWidth: matrixArea.width - dayLabelWidth - labelSpacing
            readonly property int numCols: Math.max(53, root.totalCols)
            readonly property real cellGap: 1.5
            // Pure 1:1 Square Size
            readonly property real cellSize: Math.max(4.0, (availableWidth - (numCols - 1) * cellGap) / numCols)
            readonly property real totalGridW: numCols * cellSize + (numCols - 1) * cellGap
            readonly property real startX: dayLabelWidth + labelSpacing

            // Month Labels Header
            Item {
                id: monthHeadersContainer
                x: matrixArea.startX
                y: 0
                width: matrixArea.totalGridW
                height: 11

                Repeater {
                    model: root.monthsData
                    delegate: Text {
                        required property var modelData
                        x: modelData.col * (matrixArea.cellSize + matrixArea.cellGap)
                        y: 0
                        text: modelData.name
                        color: theme.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 8
                        font.bold: true
                    }
                }
            }

            // Weekday Labels ("M", "W", "F")
            Item {
                id: dayLabelsContainer
                x: 0
                y: 14
                width: matrixArea.dayLabelWidth
                height: 7 * matrixArea.cellSize + 6 * matrixArea.cellGap

                Repeater {
                    model: [
                        { "name": "M", "row": 1 },
                        { "name": "W", "row": 3 },
                        { "name": "F", "row": 5 }
                    ]
                    delegate: Text {
                        required property var modelData
                        x: 0
                        y: modelData.row * (matrixArea.cellSize + matrixArea.cellGap) + (matrixArea.cellSize - 7) / 2
                        text: modelData.name
                        color: theme.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 7
                        font.bold: true
                    }
                }
            }

            // 53x7 Grid of Contributions (1:1 SQUARES)
            Item {
                id: daysContainer
                x: matrixArea.startX
                y: 14
                width: matrixArea.totalGridW
                height: 7 * matrixArea.cellSize + 6 * matrixArea.cellGap

                Repeater {
                    model: root.daysData

                    delegate: Item {
                        id: cellItem
                        required property var modelData

                        readonly property int col: modelData.col
                        readonly property int row: modelData.row
                        readonly property int level: modelData.level
                        readonly property int count: modelData.count
                        readonly property bool isToday: !!modelData.isToday
                        readonly property bool isFuture: !!modelData.isFuture
                        readonly property string dayDate: modelData.date
                        readonly property string dayLabel: modelData.label

                        x: col * (matrixArea.cellSize + matrixArea.cellGap)
                        y: row * (matrixArea.cellSize + matrixArea.cellGap)
                        // Exact square dimensions
                        width: matrixArea.cellSize
                        height: matrixArea.cellSize

                        // Cascade entrance wave animation
                        readonly property real cellProgress: Math.max(0.0, Math.min(1.0, (root.animPhase - col) / 2.0))
                        opacity: cellProgress
                        scale: 0.3 + 0.7 * cellProgress

                        z: cellMouseArea.containsMouse ? 20 : (isToday ? 10 : 1)

                        // 1:1 Square
                        Rectangle {
                            id: square
                            anchors.centerIn: parent
                            width: cellMouseArea.containsMouse ? parent.width + 3 : parent.width
                            height: cellMouseArea.containsMouse ? parent.height + 3 : parent.height
                            radius: 1.4

                            color: root.getColorForLevel(cellItem.level, cellItem.isFuture)
                            border.width: (cellMouseArea.containsMouse || cellItem.isToday) ? 1.2 : (cellItem.isFuture ? 0.6 : 0)
                            border.color: cellMouseArea.containsMouse ? "#ffffff" : (cellItem.isToday ? "#30d158" : (cellItem.isFuture ? Qt.rgba(255, 255, 255, 0.05) : "transparent"))

                            Behavior on width { NumberAnimation { duration: 90 } }
                            Behavior on height { NumberAnimation { duration: 90 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Pulsing halo on Today
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width + 3
                                height: parent.height + 3
                                radius: 2.5
                                color: "transparent"
                                border.color: "#30d158"
                                border.width: 1
                                visible: cellItem.isToday

                                SequentialAnimation on opacity {
                                    running: cellItem.isToday
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.2; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 1.0; to: 0.2; duration: 900; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        MouseArea {
                            id: cellMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                root.hoveredDay = {
                                    "date": cellItem.dayDate,
                                    "count": cellItem.count,
                                    "level": cellItem.level,
                                    "label": cellItem.dayLabel,
                                    "isFuture": cellItem.isFuture
                                };
                            }

                            onExited: {
                                if (root.hoveredDay && root.hoveredDay.date === cellItem.dayDate) {
                                    root.hoveredDay = null;
                                }
                            }

                            onClicked: {
                                Quickshell.execDetached(["xdg-open", "https://github.com/" + root.username]);
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // FOOTER: Dynamic Hover Inspection & Color Scale
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 16
            spacing: 8

            // Inspection text
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 4
                        radius: 2
                        color: root.hoveredDay ? (root.hoveredDay.count > 0 ? "#30d158" : theme.textDim) : "#30d158"
                    }

                    Text {
                        text: {
                            if (root.hoveredDay) {
                                if (root.hoveredDay.isFuture) {
                                    return root.hoveredDay.label + " • Upcoming";
                                }
                                let c = root.hoveredDay.count;
                                return root.hoveredDay.label + " • " + (c === 0 ? "No contributions" : (c + (c === 1 ? " contribution" : " contributions")));
                            }
                            return "Hover a day to inspect • " + root.currentYear + " Green Wall";
                        }
                        color: root.hoveredDay ? "#ffffff" : theme.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 9
                        font.bold: !!root.hoveredDay
                    }
                }
            }

            // Legend scale (1:1 mini squares)
            Row {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 3

                Text {
                    text: "Less"
                    color: theme.textDim
                    font.family: "sans-serif"
                    font.pixelSize: 8
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: [0, 1, 2, 3, 4]
                    delegate: Rectangle {
                        width: 6.5
                        height: 6.5
                        radius: 1.2
                        color: root.getColorForLevel(modelData, false)
                        border.width: modelData === 0 ? 0.6 : 0
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: "More"
                    color: theme.textDim
                    font.family: "sans-serif"
                    font.pixelSize: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
