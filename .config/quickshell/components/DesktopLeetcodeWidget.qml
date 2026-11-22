import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root

    Theme { id: theme }

    implicitWidth: 224
    implicitHeight: 208
    width: implicitWidth
    height: implicitHeight

    radius: 20
    // Obsidian Translucent Glass matching GitHub & Sonoma widgets
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

    readonly property string leetcodeSvg: Quickshell.shellPath("icons/leetcode.svg")
    readonly property color lcAmber: "#ffa116"
    readonly property color easyCol: "#00b8a3"
    readonly property color medCol: "#ffc01e"
    readonly property color hardCol: "#ff375f"

    // State
    property string username: "dferram"
    property int totalSolved: 0
    property int easySolved: 0
    property int mediumSolved: 0
    property int hardSolved: 0
    property int streak: 0
    property int bestStreak: 0
    property bool solvedToday: false
    property string dailyTitle: "Loading daily..."
    property string dailyDifficulty: "Medium"
    property string dailyUrl: "https://leetcode.com/problemset/"
    property bool isLoading: false
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    function difficultyColor(diff) {
        let d = (diff || "").toLowerCase();
        if (d === "easy") return root.easyCol;
        if (d === "hard") return root.hardCol;
        return root.medCol;
    }

    Process {
        id: leetcodeProc
        command: ["python3", Quickshell.shellPath("scripts/leetcode-stats.py"), "get", root.username]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.isLoading = false;
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.error) return;
                    if (d.username) root.username = d.username;
                    if (d.totalSolved !== undefined) root.totalSolved = d.totalSolved;
                    if (d.easySolved !== undefined) root.easySolved = d.easySolved;
                    if (d.mediumSolved !== undefined) root.mediumSolved = d.mediumSolved;
                    if (d.hardSolved !== undefined) root.hardSolved = d.hardSolved;
                    if (d.streak !== undefined) root.streak = d.streak;
                    if (d.bestStreak !== undefined) root.bestStreak = d.bestStreak;
                    if (d.solvedToday !== undefined) root.solvedToday = !!d.solvedToday;
                    if (d.daily) {
                        if (d.daily.title) root.dailyTitle = d.daily.title;
                        if (d.daily.difficulty) root.dailyDifficulty = d.daily.difficulty;
                        if (d.daily.url) root.dailyUrl = d.daily.url;
                    }
                } catch(e) {
                    console.log("Error parsing LeetCode stats JSON:", e);
                }
            }
        }

        onExited: {
            root.isLoading = false;
        }
    }

    function refreshData(force) {
        if (leetcodeProc.running) return;
        root.isLoading = true;
        let action = force ? "fetch" : "get";
        leetcodeProc.command = ["python3", Quickshell.shellPath("scripts/leetcode-stats.py"), action, root.username];
        leetcodeProc.running = true;
    }

    Component.onCompleted: refreshData(false)

    Timer {
        interval: 1800000
        repeat: true
        running: root.isLive
        onTriggered: {
            if (root.isLive) root.refreshData(true);
        }
    }

    function handleDragPress(item, mouse) {
        if (mouse.button === Qt.RightButton) {
            if (root.wrapper) root.wrapper.menuOpen = !root.wrapper.menuOpen;
            return;
        }
        if (mouse.button !== Qt.LeftButton) return;
        if (root.wrapper && root.wrapper.menuOpen) root.wrapper.menuOpen = false;
        let canvasPt = item.mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
        item.startScreenX = canvasPt.x;
        item.startScreenY = canvasPt.y;
        item.isDragging = false;
    }

    function handleDragMove(item, mouse) {
        if (!item.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
            if (item.isDragging) {
                item.isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
            return;
        }
        let canvasPt = item.mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
        let dx = canvasPt.x - item.startScreenX;
        let dy = canvasPt.y - item.startScreenY;
        if (!item.isDragging && Math.hypot(dx, dy) > 4) {
            item.isDragging = true;
            if (root.wrapper) root.wrapper.startDrag(mouse.x, mouse.y);
        }
        if (item.isDragging && root.wrapper) {
            root.wrapper.updateDrag(dx, dy);
        }
    }

    function handleDragEnd(item) {
        if (item.isDragging) {
            item.isDragging = false;
            if (root.wrapper) root.wrapper.endDrag();
        }
    }

    // Drag, right-click menu, and click-to-refresh MouseArea (Sonoma grid integration)
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : (containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor)
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => root.handleDragPress(hoverArea, mouse)
        onPositionChanged: (mouse) => root.handleDragMove(hoverArea, mouse)
        onReleased: root.handleDragEnd(hoverArea)
        onCanceled: root.handleDragEnd(hoverArea)

        onClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton || isDragging) return;
            if (root.wrapper && root.wrapper.overlay && root.wrapper.overlay.showGridGuide) return;
            root.refreshData(true);
        }
    }

    // Specular top hairline highlight (Apple Sonoma aesthetic)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(255, 255, 255, 0.16)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 13
        anchors.bottomMargin: 12
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 7

        // =====================================================================
        // HEADER: LeetCode Logo, Username & Solved-Today Status Pill
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 9

            // LeetCode Icon squircle (click opens profile)
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 10
                color: iconMa.containsMouse ? Qt.rgba(255, 161, 22, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                border.color: iconMa.containsMouse ? root.lcAmber : Qt.rgba(255, 255, 255, 0.16)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: root.leetcodeSvg
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    property real startScreenX: 0
                    property real startScreenY: 0
                    property bool isDragging: false
                    onPressed: (mouse) => root.handleDragPress(iconMa, mouse)
                    onPositionChanged: (mouse) => root.handleDragMove(iconMa, mouse)
                    onReleased: root.handleDragEnd(iconMa)
                    onCanceled: root.handleDragEnd(iconMa)
                    onClicked: (mouse) => {
                        if (mouse.button !== Qt.LeftButton || isDragging) return;
                        Quickshell.execDetached(["xdg-open", "https://leetcode.com/u/" + root.username]);
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    spacing: 5
                    Text {
                        text: "@" + root.username
                        color: "#ffffff"
                        font.family: "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: root.isLoading
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: root.lcAmber

                        SequentialAnimation on opacity {
                            running: root.isLoading
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.25; to: 1.0; duration: 400 }
                            NumberAnimation { from: 1.0; to: 0.25; duration: 400 }
                        }
                    }
                }

                Text {
                    text: root.streak > 0 ? (root.streak + "d streak") : (root.bestStreak > 0 ? ("0d · best " + root.bestStreak + "d") : "0d streak")
                    color: root.streak > 0 ? root.lcAmber : theme.textDim
                    font.family: "sans-serif"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        // Hairline Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(255, 255, 255, 0.07)
        }

        // =====================================================================
        // TOTAL SOLVED HERO ROW
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 6

            Text {
                text: String(root.totalSolved)
                color: "#ffffff"
                font.family: "sans-serif"
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                text: "solved"
                color: root.lcAmber
                font.family: "sans-serif"
                font.pixelSize: 11
                font.bold: true
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 4
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "LeetCode"
                color: theme.textDim
                font.family: "sans-serif"
                font.pixelSize: 9
                font.bold: true
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 4
            }
        }

        // =====================================================================
        // EASY / MEDIUM / HARD THREE SMALL COLUMNS (NO BARS)
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            spacing: 6

            Repeater {
                model: [
                    { "label": "Easy", "count": root.easySolved, "col": root.easyCol },
                    { "label": "Medium", "count": root.mediumSolved, "col": root.medCol },
                    { "label": "Hard", "count": root.hardSolved, "col": root.hardCol }
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: Qt.rgba(255, 255, 255, 0.04)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(modelData.count)
                            color: modelData.col
                            font.family: "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: theme.textDim
                            font.family: "sans-serif"
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }
                }
            }
        }

        // =====================================================================
        // DAILY PROBLEM CARD (click opens in browser)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40
            radius: 9
            color: dailyMa.containsMouse ? Qt.rgba(255, 161, 22, 0.14) : Qt.rgba(255, 255, 255, 0.04)
            border.color: dailyMa.containsMouse ? root.lcAmber : Qt.rgba(255, 161, 22, 0.25)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 2

                Text {
                    text: "DAILY"
                    color: root.lcAmber
                    font.family: "sans-serif"
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 0.6
                }

                Text {
                    Layout.fillWidth: true
                    text: root.dailyTitle
                    color: "#ffffff"
                    font.family: "sans-serif"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: dailyMa
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                property real startScreenX: 0
                property real startScreenY: 0
                property bool isDragging: false
                onPressed: (mouse) => root.handleDragPress(dailyMa, mouse)
                onPositionChanged: (mouse) => root.handleDragMove(dailyMa, mouse)
                onReleased: root.handleDragEnd(dailyMa)
                onCanceled: root.handleDragEnd(dailyMa)
                onClicked: (mouse) => {
                    if (mouse.button !== Qt.LeftButton || isDragging) return;
                    Quickshell.execDetached(["xdg-open", root.dailyUrl]);
                }
            }
        }
    }
}
