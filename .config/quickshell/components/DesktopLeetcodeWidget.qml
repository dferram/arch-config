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
    border.color: theme.borderSubtle
    border.width: 1
    clip: true

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
            Layout.preferredHeight: 34
            spacing: 8

            // LeetCode Icon squircle (click opens profile)
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 9
                color: iconMa.containsMouse ? Qt.rgba(255, 161, 22, 0.18) : Qt.rgba(255, 255, 255, 0.08)
                border.color: iconMa.containsMouse ? root.lcAmber : Qt.rgba(255, 255, 255, 0.16)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: root.leetcodeSvg
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: iconMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", "https://leetcode.com/u/" + root.username])
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
                    text: root.streak + "d streak"
                    color: root.lcAmber
                    font.family: "sans-serif"
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            // Solved-today status pill
            Rectangle {
                Layout.preferredHeight: 20
                Layout.preferredWidth: todayTxt.implicitWidth + 12
                radius: 10
                color: root.solvedToday ? Qt.rgba(48, 209, 88, 0.16) : Qt.rgba(255, 161, 22, 0.14)
                border.color: root.solvedToday ? Qt.rgba(48, 209, 88, 0.45) : Qt.rgba(255, 161, 22, 0.35)
                border.width: 1

                Text {
                    id: todayTxt
                    anchors.centerIn: parent
                    text: root.solvedToday ? "Solved today" : "Pending"
                    color: root.solvedToday ? "#30d158" : root.lcAmber
                    font.family: "sans-serif"
                    font.pixelSize: 8
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "DAILY"
                        color: root.lcAmber
                        font.family: "sans-serif"
                        font.pixelSize: 7
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    Rectangle {
                        Layout.preferredHeight: 13
                        Layout.preferredWidth: diffBadgeTxt.implicitWidth + 8
                        radius: 4
                        color: Qt.rgba(root.difficultyColor(root.dailyDifficulty).r, root.difficultyColor(root.dailyDifficulty).g, root.difficultyColor(root.dailyDifficulty).b, 0.18)

                        Text {
                            id: diffBadgeTxt
                            anchors.centerIn: parent
                            text: root.dailyDifficulty
                            color: root.difficultyColor(root.dailyDifficulty)
                            font.family: "sans-serif"
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "↗"
                        color: dailyMa.containsMouse ? root.lcAmber : theme.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 10
                        font.bold: true
                    }
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
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["xdg-open", root.dailyUrl])
            }
        }
    }
}
