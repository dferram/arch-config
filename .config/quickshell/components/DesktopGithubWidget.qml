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
    color: theme.widgetGlass
    border.color: theme.borderSubtle
    border.width: 1
    clip: true

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
    readonly property string githubSvg: Quickshell.shellPath("icons/github.svg")

    // State
    property string username: "dferram"
    property int currentYear: 2026
    property string displayName: "Fernando Ramírez"
    property int totalContributions: 0
    property int currentMonthCount: 0
    property string currentMonthName: Qt.formatDate(new Date(), "MMM").toUpperCase()
    property var monthlyTotals: []
    property int maxMonthTotal: 1
    property var monthsData: []
    property var daysData: []
    property int totalCols: 53
    property string lastUpdated: ""
    property bool isLoading: false

    // Hover state for interactive inspection
    property var hoveredDay: null
    property var hoveredMonth: null
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    function recomputeInsights(days) {
        if (!days || days.length === 0) return;
        const mNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        let mSums = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        let mHasPast = [false, false, false, false, false, false, false, false, false, false, false, false];
        let curMonth = new Date().getMonth() + 1;

        for (let i = 0; i < days.length; i++) {
            let d = days[i];
            if (d.isFuture) continue;
            if (d.isToday) {
                curMonth = d.month || curMonth;
            }
            let mi = (d.month || 1) - 1;
            if (mi >= 0 && mi < 12) {
                mSums[mi] += (d.count || 0);
                mHasPast[mi] = true;
            }
        }

        let maxM = 1;
        let mArr = [];
        for (let m = 0; m < 12; m++) {
            if (mSums[m] > maxM) maxM = mSums[m];
            mArr.push({
                name: mNames[m],
                total: mSums[m],
                isCurrent: (m + 1) === curMonth,
                isFuture: !mHasPast[m]
            });
        }

        root.currentMonthCount = mSums[Math.max(0, curMonth - 1)] || 0;
        root.currentMonthName = mNames[Math.max(0, curMonth - 1)].toUpperCase();
        root.maxMonthTotal = maxM;
        root.monthlyTotals = mArr;
    }

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
                    if (d.months) root.monthsData = d.months;
                    if (d.totalCols) root.totalCols = d.totalCols;
                    if (d.updatedAt) root.lastUpdated = d.updatedAt;
                    if (d.days && d.days.length > 0) {
                        root.daysData = d.days;
                        root.recomputeInsights(d.days);
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
        running: root.isLive
        onTriggered: {
            if (root.isLive) root.refreshData(true);
        }
    }

    // Click anywhere on the widget background to refresh
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.refreshData(true)
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

                    // Subtle sync indicator while refreshing
                    Rectangle {
                        visible: root.isLoading
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: "#30d158"

                        SequentialAnimation on opacity {
                            running: root.isLive && root.isLoading
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.25; to: 1.0; duration: 400 }
                            NumberAnimation { from: 1.0; to: 0.25; duration: 400 }
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

            // Current Month Contributions pill
            Rectangle {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 36
                radius: 8
                color: Qt.rgba(255, 255, 255, 0.05)
                border.color: Qt.rgba(48, 209, 88, 0.35)
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(root.currentMonthCount)
                        color: "#30d158"
                        font.family: "sans-serif"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentMonthName
                        color: theme.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 7
                        font.bold: true
                    }
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
            Layout.preferredHeight: 68

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
                                    running: root.isLive && cellItem.isToday
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
                                root.refreshData(true);
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // MONTHLY CONTRIBUTIONS STRIP: Full-Width 12-Month Bars (Jan..Dec)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 32
            radius: 9
            color: Qt.rgba(255, 255, 255, 0.04)
            border.color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                spacing: 6

                Repeater {
                    model: root.monthlyTotals

                    delegate: Item {
                        id: mBarItem
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property real barRatio: root.maxMonthTotal > 0 ? Math.max(0.15, modelData.total / root.maxMonthTotal) : 0.15
                        readonly property bool isHov: mBarMa.containsMouse

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 2

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: mBarItem.modelData.isFuture ? 3 : Math.max(3, Math.round(parent.height * mBarItem.barRatio))
                                    radius: 3
                                    color: mBarItem.modelData.isFuture
                                        ? Qt.rgba(255, 255, 255, 0.08)
                                        : (mBarItem.isHov ? "#39d353" : (mBarItem.modelData.isCurrent ? "#30d158" : "#26a641"))
                                    border.width: mBarItem.isHov ? 1 : 0
                                    border.color: "#ffffff"
                                    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: mBarItem.modelData.name
                                color: mBarItem.isHov ? "#ffffff" : (mBarItem.modelData.isCurrent ? "#30d158" : theme.textDim)
                                font.family: "sans-serif"
                                font.pixelSize: 7
                                font.bold: mBarItem.modelData.isCurrent || mBarItem.isHov
                            }
                        }

                        MouseArea {
                            id: mBarMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoveredMonth = mBarItem.modelData
                            onExited: {
                                if (root.hoveredMonth && root.hoveredMonth.name === mBarItem.modelData.name) {
                                    root.hoveredMonth = null;
                                }
                            }
                            onClicked: root.refreshData(true)
                        }
                    }
                }
            }
        }

        // =====================================================================
        // FOOTER: Live Hover Details (only when hovering) & Green Color Scale
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 8

            // Hover-only inspection text (empty by default so only green scale shows)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 14

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    visible: !!(root.hoveredDay || root.hoveredMonth)

                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 4
                        radius: 2
                        color: (root.hoveredDay && root.hoveredDay.count === 0) ? theme.textDim : "#30d158"
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
                            if (root.hoveredMonth) {
                                if (root.hoveredMonth.isFuture) {
                                    return root.hoveredMonth.name + " " + root.currentYear + " • Upcoming";
                                }
                                let mt = root.hoveredMonth.total;
                                return root.hoveredMonth.name + " " + root.currentYear + " • " + mt.toLocaleString() + (mt === 1 ? " contribution" : " contributions");
                            }
                            return "";
                        }
                        color: "#ffffff"
                        font.family: "sans-serif"
                        font.pixelSize: 9
                        font.bold: true
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
