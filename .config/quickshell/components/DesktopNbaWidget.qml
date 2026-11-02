import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 448
    implicitHeight: 207

    radius: 20
    // Flat clean dark obsidian glass - NO gradients
    color: Qt.rgba(0.05, 0.05, 0.08, 0.90)
    border.width: 0
    clip: true

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null
    readonly property string nbaPng: Quickshell.shellPath("icons/nba.png")

    // State properties
    property var games: []
    property int selectedGameIndex: 0
    property var activeGame: (games && games.length > selectedGameIndex) ? games[selectedGameIndex] : null
    property var eastStandings: []
    property var westStandings: []

    // Fetch data process
    Process {
        id: nbaProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "nba-data"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.games && d.games.length > 0) {
                        root.games = d.games;
                        if (root.selectedGameIndex >= d.games.length) {
                            root.selectedGameIndex = 0;
                        }
                    }
                    if (d.standings) {
                        if (d.standings.east) root.eastStandings = d.standings.east;
                        if (d.standings.west) root.westStandings = d.standings.west;
                    }
                } catch(e) {}
            }
        }
    }

    // Auto rotate games disabled per user preference (game stays static where user left it)
    Timer {
        interval: 12000
        running: false
        repeat: true
        onTriggered: {
            if (root.games && root.games.length > 1) {
                root.selectedGameIndex = (root.selectedGameIndex + 1) % root.games.length;
            }
        }
    }

    // Periodic refresh from ESPN API every 60 seconds
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: nbaProc.running = true
    }

    // =========================================================================
    // DUAL ACCENT FULL BORDER (NBA Royal Blue left half & Official Red right half)
    // =========================================================================
    Item {
        id: fullAccentBorder
        anchors.fill: parent
        z: 10

        // Left half: NBA Royal Blue
        Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width / 2
            clip: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                width: root.width
                height: root.height
                radius: root.radius
                color: "transparent"
                border.color: "#1D428A"
                border.width: 2
            }
        }

        // Right half: NBA Official Red
        Item {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.width / 2
            clip: true

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                width: root.width
                height: root.height
                radius: root.radius
                color: "transparent"
                border.color: "#C9082A"
                border.width: 2
            }
        }
    }

    // =========================================================================
    // MAIN CONTENT LAYOUT
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 12
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 9

        // 1. Header: NBA Logo + Title + Interactive Game Navigation + Status Pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // NBA Jerry West Badge
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 24
                radius: 5
                color: "#1D428A"

                Image {
                    anchors.centerIn: parent
                    source: root.nbaPng
                    width: 22
                    height: 20
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            // Title & Matchup Details
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    spacing: 8

                    Text {
                        text: "NBA SCOREBOARD"
                        font.family: theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Black
                        color: "#FFFFFF"
                    }

                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 4
                        radius: 2
                        color: "#C9082A"
                    }

                    // Interactive Game Switcher (< 1 of 9 >)
                    Row {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: prevBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "‹"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                id: prevBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.games.length > 0) {
                                        root.selectedGameIndex = (root.selectedGameIndex - 1 + root.games.length) % root.games.length;
                                    }
                                }
                            }
                        }

                        Text {
                            text: (root.selectedGameIndex + 1) + " of " + Math.max(1, root.games.length)
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: theme.textDim
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: nextBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: "›"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                id: nextBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.games.length > 0) {
                                        root.selectedGameIndex = (root.selectedGameIndex + 1) % root.games.length;
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    text: root.activeGame ? (root.activeGame.name || "Live Matchup") : "Matchup"
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.65)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Status Pill (Final / Live / Scheduled)
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: statusText.implicitWidth + 20
                radius: 12
                color: root.activeGame && root.activeGame.state === "in" ? Qt.rgba(201, 8, 42, 0.22) : (root.activeGame && root.activeGame.state === "post" ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(29, 66, 138, 0.25))
                border.color: root.activeGame && root.activeGame.state === "in" ? "#C9082A" : (root.activeGame && root.activeGame.state === "post" ? Qt.rgba(255, 255, 255, 0.20) : "#1D428A")
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: root.activeGame && root.activeGame.state === "in" ? "#C9082A" : (theme.blueLight != "" ? theme.blueLight : theme.blue)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.activeGame && root.activeGame.state === "in"
                        SequentialAnimation on opacity {
                            running: root.visible && root.activeGame && root.activeGame.state === "in"
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 500 }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 500 }
                        }
                    }

                    Text {
                        id: statusText
                        text: {
                            if (!root.activeGame) return "Scheduled";
                            if (root.activeGame.state === "in") return "LIVE • " + root.activeGame.status;
                            if (root.activeGame.state === "post") return "FINAL";
                            return "SCHEDULED";
                        }
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 2. Arena LED Scoreboard Matchup Box (With Official Team Logos)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.42)
            border.color: Qt.rgba(255, 255, 255, 0.09)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                // Away Team
                RowLayout {
                    Layout.preferredWidth: 140
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 34
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: root.activeGame && root.activeGame.away && root.activeGame.away.color ? root.activeGame.away.color : Qt.rgba(255, 255, 255, 0.20)
                        border.width: 1.5

                        Image {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            source: Quickshell.shellPath("icons/nba-teams/" + (root.activeGame && root.activeGame.away ? root.activeGame.away.team.toLowerCase() : "nba") + ".png")
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: root.activeGame && root.activeGame.away ? root.activeGame.away.name : "Away"
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.activeGame && root.activeGame.away && root.activeGame.away.record ? ("AWAY • " + root.activeGame.away.record) : "AWAY"
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: theme.textDim
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Center Scoreboard or Pre-game VS + Time Badge
                Item {
                    Layout.preferredWidth: 110
                    Layout.fillHeight: true

                    // Case A: Pre-game (Scheduled for Tonight)
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        visible: !root.activeGame || root.activeGame.state === "pre"

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "VS"
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Black
                            color: theme.textDim
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 18
                            width: schedTimeText.implicitWidth + 12
                            radius: 9
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(255, 255, 255, 0.12)
                            border.width: 1

                            Text {
                                id: schedTimeText
                                anchors.centerIn: parent
                                text: root.activeGame ? (root.activeGame.status.replace(/^[0-9\/]+\s*-\s*/, "")) : "Tonight"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                            }
                        }
                    }

                    // Case B: In-progress or Final (Live Scores)
                    RowLayout {
                        id: scoreRow
                        anchors.centerIn: parent
                        spacing: 10
                        visible: root.activeGame && root.activeGame.state !== "pre"

                        readonly property int awayScore: root.activeGame && root.activeGame.away ? parseInt(root.activeGame.away.score || "0") : 0
                        readonly property int homeScore: root.activeGame && root.activeGame.home ? parseInt(root.activeGame.home.score || "0") : 0

                        Text {
                            text: root.activeGame && root.activeGame.away ? root.activeGame.away.score : "--"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            font.weight: Font.Black
                            color: (scoreRow.awayScore >= scoreRow.homeScore) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.65)
                        }

                        Text {
                            text: "—"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            color: theme.textDim
                        }

                        Text {
                            text: root.activeGame && root.activeGame.home ? root.activeGame.home.score : "--"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 22
                            font.weight: Font.Black
                            color: (scoreRow.homeScore >= scoreRow.awayScore) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.65)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Home Team
                RowLayout {
                    Layout.preferredWidth: 140
                    Layout.alignment: Qt.AlignRight
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: root.activeGame && root.activeGame.home ? root.activeGame.home.name : "Home"
                            font.family: theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                            horizontalAlignment: Text.AlignRight
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.activeGame && root.activeGame.home && root.activeGame.home.record ? (root.activeGame.home.record + " • HOME") : "HOME"
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: theme.textDim
                            horizontalAlignment: Text.AlignRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 34
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: root.activeGame && root.activeGame.home && root.activeGame.home.color ? root.activeGame.home.color : Qt.rgba(255, 255, 255, 0.20)
                        border.width: 1.5

                        Image {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            source: Quickshell.shellPath("icons/nba-teams/" + (root.activeGame && root.activeGame.home ? root.activeGame.home.team.toLowerCase() : "nba") + ".png")
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                        }
                    }
                }
            }
        }

        // 3. Conference Standings Preview (East vs West Top Seeds with Official Team Logos)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Eastern Conference Leader
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.fillHeight: true
                        radius: 2
                        color: "#1D428A"
                    }

                    Image {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        source: Quickshell.shellPath("icons/nba-teams/" + ((root.eastStandings && root.eastStandings.length > 0) ? root.eastStandings[0].team.toLowerCase() : "det") + ".png")
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        asynchronous: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "EASTERN CONFERENCE"
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: theme.textDim
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 14
                                width: 36
                                radius: 4
                                color: Qt.rgba(29, 66, 138, 0.3)
                                Text {
                                    anchors.centerIn: parent
                                    text: "#1 SEED"
                                    font.family: theme.fontFamily
                                    font.pixelSize: 7
                                    font.weight: Font.Black
                                    color: "#6BA4FF"
                                }
                            }
                        }

                        Text {
                            text: (root.eastStandings && root.eastStandings.length > 0) ? (root.eastStandings[0].name + " (" + root.eastStandings[0].record + ")") : "Pistons (3-0)"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Western Conference Leader
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.fillHeight: true
                        radius: 2
                        color: "#C9082A"
                    }

                    Image {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        source: Quickshell.shellPath("icons/nba-teams/" + ((root.westStandings && root.westStandings.length > 0) ? root.westStandings[0].team.toLowerCase() : "min") + ".png")
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        asynchronous: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "WESTERN CONFERENCE"
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: theme.textDim
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 14
                                width: 36
                                radius: 4
                                color: Qt.rgba(201, 8, 42, 0.3)
                                Text {
                                    anchors.centerIn: parent
                                    text: "#1 SEED"
                                    font.family: theme.fontFamily
                                    font.pixelSize: 7
                                    font.weight: Font.Black
                                    color: "#FF6B81"
                                }
                            }
                        }

                        Text {
                            text: (root.westStandings && root.westStandings.length > 0) ? (root.westStandings[0].name + " (" + root.westStandings[0].record + ")") : "Timberwolves (3-0)"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: "#FFFFFF"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // Drag / Interaction MouseArea (Apple Sonoma smooth dragging)
    MouseArea {
        id: bgDragArea
        anchors.fill: parent
        z: 0
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                nbaProc.running = true;
                return;
            }
            if (mouse.button !== Qt.LeftButton) return;
            let canvasPt = mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
            startScreenX = canvasPt.x;
            startScreenY = canvasPt.y;
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!bgDragArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
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
            } else if (mouse.button === Qt.LeftButton) {
                if (root.games.length > 1) {
                    root.selectedGameIndex = (root.selectedGameIndex + 1) % root.games.length;
                } else {
                    Quickshell.execDetached(["xdg-open", "https://www.nba.com/games"]);
                }
            }
        }

        onCanceled: {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
        }
    }
}
