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

    radius: theme.radius
    color: theme.widgetGlass
    border.width: 0
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
    readonly property string nbaPng: Quickshell.shellPath("icons/nba.png")

    // State properties
    property var games: []
    property int selectedGameIndex: 0
    property int pendingGameIndex: 0
    property int slideDirection: 1
    property var activeGame: (games && games.length > selectedGameIndex) ? games[selectedGameIndex] : null
    property var eastStandings: []
    property var westStandings: []
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true
    property double lastFetchMs: 0

    function switchGame(delta) {
        if (!games || games.length <= 1) return;
        let nextIdx = (selectedGameIndex + delta + games.length) % games.length;
        if (nextIdx === selectedGameIndex) return;
        slideDirection = delta >= 0 ? 1 : -1;
        pendingGameIndex = nextIdx;
        gameSlideAnim.restart();
    }

    SequentialAnimation {
        id: gameSlideAnim

        ParallelAnimation {
            NumberAnimation {
                target: matchupSlideContainer
                property: "xOffset"
                to: -root.slideDirection * 32
                duration: 110
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: matchupSlideContainer
                property: "slideOpacity"
                to: 0.0
                duration: 110
                easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                root.selectedGameIndex = root.pendingGameIndex;
                matchupSlideContainer.xOffset = root.slideDirection * 32;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: matchupSlideContainer
                property: "xOffset"
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: matchupSlideContainer
                property: "slideOpacity"
                to: 1.0
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    // Smoked Obsidian Liquid Glass 3-stop surface sheen
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        z: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.015) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.035) }
        }
    }

    // Fetch data process
    Process {
        id: nbaProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "nba-data"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastFetchMs = Date.now();
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

    // Periodic refresh from ESPN API every 60 seconds when visible
    Timer {
        interval: 60000
        running: root.isLive
        repeat: true
        onTriggered: {
            if (root.isLive && !nbaProc.running) nbaProc.running = true;
        }
    }

    Component.onCompleted: {
        if (!nbaProc.running) nbaProc.running = true;
    }

    onIsLiveChanged: {
        if (isLive && !nbaProc.running && (Date.now() - root.lastFetchMs > 55000)) {
            nbaProc.running = true;
        }
    }

    // =========================================================================
    // DUAL ACCENT BORDER (NBA Royal Blue left half & Official Red right half)
    // =========================================================================
    Item {
        id: fullAccentBorder
        anchors.fill: parent
        z: 10

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
                border.width: 1.5
            }
        }

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
                border.width: 1.5
            }
        }
    }

    // =========================================================================
    // MAIN CONTENT LAYOUT
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 13
        anchors.bottomMargin: 12
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8
        z: 2

        // 1. Header: NBA Badge + Title + Switcher + Status Pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
                radius: 6
                color: "#1D428A"
                border.color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1

                Image {
                    anchors.centerIn: parent
                    source: root.nbaPng
                    width: 20
                    height: 18
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    spacing: 8

                    Text {
                        text: "NBA"
                        font.family: theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Black
                        color: "#FFFFFF"
                    }

                    // Clean Game Index Counter
                    Rectangle {
                        height: 17
                        width: counterText.implicitWidth + 12
                        radius: 5
                        color: Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: counterText
                            anchors.centerIn: parent
                            text: (root.selectedGameIndex + 1) + " / " + Math.max(1, root.games.length)
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: theme.textMuted
                        }
                    }
                }

                Text {
                    text: root.activeGame ? (root.activeGame.name || "Matchup") : "No games scheduled"
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    color: theme.textDim
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Status Pill (LIVE / FINAL / SCHEDULED)
            Rectangle {
                Layout.preferredHeight: 22
                Layout.preferredWidth: statusRow.implicitWidth + 16
                radius: 6
                color: {
                    if (root.activeGame && root.activeGame.state === "in") return Qt.rgba(201/255, 8/255, 42/255, 0.24);
                    if (root.activeGame && root.activeGame.state === "post") return Qt.rgba(0, 0, 0, 0.30);
                    return Qt.rgba(29/255, 66/255, 138/255, 0.28);
                }
                border.color: {
                    if (root.activeGame && root.activeGame.state === "in") return "#C9082A";
                    if (root.activeGame && root.activeGame.state === "post") return Qt.rgba(1, 1, 1, 0.16);
                    return "#3B82F6";
                }
                border.width: 1

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: "#FF3B5C"
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.activeGame && root.activeGame.state === "in"
                        SequentialAnimation on opacity {
                            running: root.isLive && root.activeGame && root.activeGame.state === "in"
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 500 }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 500 }
                        }
                    }

                    Text {
                        text: {
                            if (!root.activeGame) return "SCHEDULED";
                            if (root.activeGame.state === "in") return "LIVE • " + root.activeGame.status;
                            if (root.activeGame.state === "post") return "FINAL";
                            return "SCHEDULED";
                        }
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // 2. Hero Matchup Card (Deep Smoked Glass + Smooth Lateral Slide Transition)
        Rectangle {
            id: matchupBox
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            radius: 9
            color: Qt.rgba(0.03, 0.04, 0.07, 0.56)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            clip: true

            readonly property color awayCol: (root.activeGame && root.activeGame.away && root.activeGame.away.color) ? root.activeGame.away.color : "#1D428A"
            readonly property color homeCol: (root.activeGame && root.activeGame.home && root.activeGame.home.color) ? root.activeGame.home.color : "#C9082A"

            // Subtle dual team-color ambient wash
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(matchupBox.awayCol.r, matchupBox.awayCol.g, matchupBox.awayCol.b, 0.14) }
                    GradientStop { position: 0.45; color: "transparent" }
                    GradientStop { position: 0.55; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(matchupBox.homeCol.r, matchupBox.homeCol.g, matchupBox.homeCol.b, 0.14) }
                }
            }

            // Sliding matchup content
            Item {
                id: matchupSlideContainer
                width: parent.width
                height: parent.height
                property real xOffset: 0
                property real slideOpacity: 1.0
                x: xOffset
                opacity: slideOpacity

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    // Away Team
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 145
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 9
                            color: Qt.rgba(matchupBox.awayCol.r, matchupBox.awayCol.g, matchupBox.awayCol.b, 0.18)
                            border.color: Qt.rgba(matchupBox.awayCol.r, matchupBox.awayCol.g, matchupBox.awayCol.b, 0.55)
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                sourceSize: Qt.size(64, 64)
                                source: Quickshell.shellPath("icons/nba-teams/" + (root.activeGame && root.activeGame.away ? root.activeGame.away.team.toLowerCase() : "nba") + ".png")
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: root.activeGame && root.activeGame.away ? root.activeGame.away.name : "Away"
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.activeGame && root.activeGame.away && root.activeGame.away.record ? (root.activeGame.away.record + " • AWAY") : "AWAY"
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: theme.textDim
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Center Score / Schedule
                    Item {
                        Layout.preferredWidth: 112
                        Layout.fillHeight: true

                        // Case A: Scheduled
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            visible: !root.activeGame || root.activeGame.state === "pre"

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "VS"
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Black
                                color: theme.textDim
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 18
                                width: schedTimeText.implicitWidth + 12
                                radius: 5
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                border.width: 1

                                Text {
                                    id: schedTimeText
                                    anchors.centerIn: parent
                                    text: root.activeGame ? (root.activeGame.status.replace(/^[0-9\/]+\s*-\s*/, "")) : "Tonight"
                                    font.family: theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                }
                            }
                        }

                        // Case B: Live or Final Score
                        RowLayout {
                            id: scoreRow
                            anchors.centerIn: parent
                            spacing: 8
                            visible: root.activeGame && root.activeGame.state !== "pre"

                            readonly property int awayScore: root.activeGame && root.activeGame.away ? parseInt(root.activeGame.away.score || "0") : 0
                            readonly property int homeScore: root.activeGame && root.activeGame.home ? parseInt(root.activeGame.home.score || "0") : 0

                            Text {
                                text: root.activeGame && root.activeGame.away ? root.activeGame.away.score : "--"
                                font.family: theme.fontFamily
                                font.pixelSize: 23
                                font.weight: Font.Black
                                color: (scoreRow.awayScore >= scoreRow.homeScore) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.48)
                            }

                            Text {
                                text: "-"
                                font.family: theme.fontFamily
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: theme.textDim
                            }

                            Text {
                                text: root.activeGame && root.activeGame.home ? root.activeGame.home.score : "--"
                                font.family: theme.fontFamily
                                font.pixelSize: 23
                                font.weight: Font.Black
                                color: (scoreRow.homeScore >= scoreRow.awayScore) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.48)
                            }
                        }
                    }

                    // Home Team
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 145
                        Layout.alignment: Qt.AlignRight
                        spacing: 9

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
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 9
                            color: Qt.rgba(matchupBox.homeCol.r, matchupBox.homeCol.g, matchupBox.homeCol.b, 0.18)
                            border.color: Qt.rgba(matchupBox.homeCol.r, matchupBox.homeCol.g, matchupBox.homeCol.b, 0.55)
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                sourceSize: Qt.size(64, 64)
                                source: Quickshell.shellPath("icons/nba-teams/" + (root.activeGame && root.activeGame.home ? root.activeGame.home.team.toLowerCase() : "nba") + ".png")
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                asynchronous: true
                            }
                        }
                    }
                }
            }

            // Left/Right half click navigation + drag support
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
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
                    let w = root.wrapper || root.findWrapper();
                    let target = (w && w.parent) ? w.parent : null;
                    if (target) {
                        let pt = mapToItem(target, mouse.x, mouse.y);
                        startScreenX = pt.x;
                        startScreenY = pt.y;
                    } else {
                        startScreenX = mouse.x;
                        startScreenY = mouse.y;
                    }
                    isDragging = false;
                }

                onPositionChanged: (mouse) => {
                    if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                        if (isDragging) {
                            isDragging = false;
                            let w = root.wrapper || root.findWrapper();
                            if (w) w.endDrag();
                        }
                        return;
                    }
                    let w = root.wrapper || root.findWrapper();
                    let target = (w && w.parent) ? w.parent : null;
                    let curX = mouse.x;
                    let curY = mouse.y;
                    if (target) {
                        let pt = mapToItem(target, mouse.x, mouse.y);
                        curX = pt.x;
                        curY = pt.y;
                    }
                    let dx = curX - startScreenX;
                    let dy = curY - startScreenY;

                    if (!isDragging && Math.hypot(dx, dy) > 5) {
                        isDragging = true;
                        if (w) w.startDrag(mouse.x, mouse.y);
                    }
                    if (isDragging && w) {
                        w.updateDrag(dx, dy);
                    }
                }

                onReleased: (mouse) => {
                    let w = root.wrapper || root.findWrapper();
                    if (isDragging) {
                        isDragging = false;
                        if (w) w.endDrag();
                    } else if (mouse.button === Qt.LeftButton) {
                        if (mouse.x < matchupBox.width * 0.5) {
                            root.switchGame(-1);
                        } else {
                            root.switchGame(1);
                        }
                    }
                }

                onCanceled: {
                    if (isDragging) {
                        isDragging = false;
                        let w = root.wrapper || root.findWrapper();
                        if (w) w.endDrag();
                    }
                }
            }
        }

        // 3. Conference Top Seeds (Clean Obsidian Glass Strips)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Eastern Conference Leader
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 8
                color: Qt.rgba(0.03, 0.04, 0.07, 0.45)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 9
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.fillHeight: true
                        radius: 1.5
                        color: "#3B82F6"
                    }

                    Image {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        sourceSize: Qt.size(48, 48)
                        source: Quickshell.shellPath("icons/nba-teams/" + ((root.eastStandings && root.eastStandings.length > 0) ? root.eastStandings[0].team.toLowerCase() : "det") + ".png")
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        asynchronous: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "EAST"
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: "#60A5FA"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "#1 SEED"
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Black
                                color: "#60A5FA"
                            }
                        }

                        Text {
                            text: (root.eastStandings && root.eastStandings.length > 0) ? (root.eastStandings[0].name + " (" + root.eastStandings[0].record + ")") : "Pistons (3-0)"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
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
                Layout.preferredHeight: 38
                radius: 8
                color: Qt.rgba(0.03, 0.04, 0.07, 0.45)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 9
                    anchors.topMargin: 6
                    anchors.bottomMargin: 6
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.fillHeight: true
                        radius: 1.5
                        color: "#EF4444"
                    }

                    Image {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        sourceSize: Qt.size(48, 48)
                        source: Quickshell.shellPath("icons/nba-teams/" + ((root.westStandings && root.westStandings.length > 0) ? root.westStandings[0].team.toLowerCase() : "min") + ".png")
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        asynchronous: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "WEST"
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: "#F87171"
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "#1 SEED"
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Black
                                color: "#F87171"
                            }
                        }

                        Text {
                            text: (root.westStandings && root.westStandings.length > 0) ? (root.westStandings[0].name + " (" + root.westStandings[0].record + ")") : "Timberwolves (3-0)"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
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

    // Background Drag / Interaction MouseArea
    MouseArea {
        id: bgDragArea
        anchors.fill: parent
        z: 1
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
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
            let w = root.wrapper || root.findWrapper();
            let target = (w && w.parent) ? w.parent : null;
            if (target) {
                let pt = bgDragArea.mapToItem(target, mouse.x, mouse.y);
                startScreenX = pt.x;
                startScreenY = pt.y;
            } else {
                startScreenX = mouse.x;
                startScreenY = mouse.y;
            }
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!bgDragArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                if (isDragging) {
                    isDragging = false;
                    let w = root.wrapper || root.findWrapper();
                    if (w) w.endDrag();
                }
                return;
            }
            let w = root.wrapper || root.findWrapper();
            let target = (w && w.parent) ? w.parent : null;
            let curX = mouse.x;
            let curY = mouse.y;
            if (target) {
                let pt = bgDragArea.mapToItem(target, mouse.x, mouse.y);
                curX = pt.x;
                curY = pt.y;
            }
            let dx = curX - startScreenX;
            let dy = curY - startScreenY;

            if (!isDragging && Math.hypot(dx, dy) > 5) {
                isDragging = true;
                if (w) w.startDrag(mouse.x, mouse.y);
            }
            if (isDragging && w) {
                w.updateDrag(dx, dy);
            }
        }

        onReleased: (mouse) => {
            let w = root.wrapper || root.findWrapper();
            if (isDragging) {
                isDragging = false;
                if (w) w.endDrag();
            } else if (mouse.button === Qt.LeftButton) {
                Quickshell.execDetached(["xdg-open", "https://www.nba.com/games"]);
            }
        }

        onCanceled: {
            if (isDragging) {
                isDragging = false;
                let w = root.wrapper || root.findWrapper();
                if (w) w.endDrag();
            }
        }
    }
}
