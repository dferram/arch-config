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
    color: theme.popupBg
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
    readonly property string f1WhitePng: Quickshell.shellPath("icons/f1-white.png")

    // State properties (dynamically populated from live Jolpica / ESPN F1 API)
    property string raceName: "Las Vegas Grand Prix"
    property string shortName: "Las Vegas GP"
    property string circuitName: "Las Vegas Strip Street Circuit"
    property string location: "Las Vegas, USA"
    property string raceDate: "Sunday, Nov 22"
    property string raceTime: "04:00 UTC"
    property string roundStr: "Round 21 / 24"
    property string sessionLabel: "RACE"
    property string sessionFullLabel: "Grand Prix Race"
    property string countdownStr: "02d 10h 30m"
    property int remainingSecs: 9000
    property string circuitLength: "5.8 km"
    property int laps: 53

    property bool showConstructors: false
    property int selectedDriverIndex: 0
    property int selectedConstructorIndex: 0
    property int pendingIndex: 0
    property int slideDirection: 1

    property var standings: []
    property var constructorStandings: []

    readonly property var activeList: showConstructors ? constructorStandings : standings
    readonly property int activeIndex: showConstructors ? selectedConstructorIndex : selectedDriverIndex
    readonly property var currentEntry: (activeList && activeList.length > activeIndex) ? activeList[activeIndex] : null

    function stepStanding(delta) {
        if (!activeList || activeList.length <= 1) return;
        let nextIdx = (activeIndex + delta + activeList.length) % activeList.length;
        if (nextIdx === activeIndex) return;
        slideDirection = delta >= 0 ? 1 : -1;
        pendingIndex = nextIdx;
        cardSlideAnim.restart();
    }

    function toggleStandingsMode() {
        slideDirection = 1;
        modeFadeAnim.restart();
    }

    SequentialAnimation {
        id: cardSlideAnim

        ParallelAnimation {
            NumberAnimation {
                target: cardSlideContainer
                property: "xOffset"
                to: -root.slideDirection * 32
                duration: 110
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: cardSlideContainer
                property: "slideOpacity"
                to: 0.0
                duration: 110
                easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                if (root.showConstructors) {
                    root.selectedConstructorIndex = root.pendingIndex;
                } else {
                    root.selectedDriverIndex = root.pendingIndex;
                }
                cardSlideContainer.xOffset = root.slideDirection * 32;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: cardSlideContainer
                property: "xOffset"
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: cardSlideContainer
                property: "slideOpacity"
                to: 1.0
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: modeFadeAnim

        NumberAnimation {
            target: cardSlideContainer
            property: "slideOpacity"
            to: 0.0
            duration: 100
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                root.showConstructors = !root.showConstructors;
            }
        }
        NumberAnimation {
            target: cardSlideContainer
            property: "slideOpacity"
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
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
        id: f1Proc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "f1-data"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.nextRace) {
                        root.raceName = d.nextRace.name || root.raceName;
                        root.shortName = d.nextRace.shortName || root.shortName;
                        root.circuitName = d.nextRace.circuit || root.circuitName;
                        root.location = d.nextRace.location || root.location;
                        root.raceDate = d.nextRace.date || root.raceDate;
                        root.raceTime = d.nextRace.time || root.raceTime;
                        root.roundStr = d.nextRace.round || root.roundStr;
                        root.sessionLabel = d.nextRace.sessionLabel || root.sessionLabel;
                        root.sessionFullLabel = d.nextRace.sessionFullLabel || root.sessionFullLabel;
                        root.countdownStr = d.nextRace.countdown || root.countdownStr;
                        root.remainingSecs = d.nextRace.secondsRemaining !== undefined ? d.nextRace.secondsRemaining : root.remainingSecs;
                        root.circuitLength = d.nextRace.circuitLength || root.circuitLength;
                        root.laps = d.nextRace.laps || root.laps;
                    }
                    if (d.standings && d.standings.length > 0) {
                        root.standings = d.standings;
                        if (root.selectedDriverIndex >= d.standings.length) {
                            root.selectedDriverIndex = 0;
                        }
                    }
                    if (d.constructorStandings && d.constructorStandings.length > 0) {
                        root.constructorStandings = d.constructorStandings;
                        if (root.selectedConstructorIndex >= d.constructorStandings.length) {
                            root.selectedConstructorIndex = 0;
                        }
                    }
                } catch(e) {}
            }
        }
    }

    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    // Live 1-second countdown ticker
    Timer {
        interval: 1000
        running: root.isLive
        repeat: true
        onTriggered: {
            if (root.remainingSecs > 0) {
                root.remainingSecs -= 1;
                let days = Math.floor(root.remainingSecs / 86400);
                let hours = Math.floor((root.remainingSecs % 86400) / 3600);
                let mins = Math.floor((root.remainingSecs % 3600) / 60);
                let secs = root.remainingSecs % 60;
                let dPad = days < 10 ? "0" + days : days;
                let hPad = hours < 10 ? "0" + hours : hours;
                let mPad = mins < 10 ? "0" + mins : mins;
                let sPad = secs < 10 ? "0" + secs : secs;
                if (days > 0) {
                    root.countdownStr = dPad + "d " + hPad + "h " + mPad + "m " + sPad + "s";
                } else {
                    root.countdownStr = hPad + "h " + mPad + "m " + sPad + "s";
                }
            } else {
                root.countdownStr = "LIVE NOW";
            }
        }
    }

    // Periodic refresh every 5 minutes
    Timer {
        interval: 300000
        running: root.isLive
        repeat: true
        onTriggered: {
            if (root.isLive) f1Proc.running = true;
        }
    }

    // =========================================================================
    // FULL ACCENT BORDER (Formula 1 Racing Red)
    // =========================================================================
    Rectangle {
        id: fullAccentBorder
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.color: "#E10600"
        border.width: 1.5
        z: 10
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

        // 1. Header: F1 Logo Badge + GP Title + Round + Countdown Pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 22
                radius: 6
                color: "#E10600"

                Image {
                    anchors.centerIn: parent
                    source: root.f1WhitePng
                    width: 24
                    height: 13
                    sourceSize: Qt.size(48, 26)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    asynchronous: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.shortName
                    font.family: theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Black
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                }

                Text {
                    text: root.roundStr
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }
            }

            // Broadcast Timing HUD Countdown Pill (tucked cleanly toward top-right corner)
            Rectangle {
                Layout.preferredHeight: 23
                Layout.preferredWidth: countdownRow.implicitWidth + 16
                Layout.rightMargin: -5
                Layout.topMargin: -4
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                radius: 6
                color: root.countdownStr === "LIVE NOW"
                    ? Qt.rgba(225/255, 6/255, 0/255, 0.24)
                    : Qt.rgba(0.03, 0.04, 0.08, 0.55)
                border.color: root.countdownStr === "LIVE NOW"
                    ? "#E10600"
                    : Qt.rgba(225/255, 6/255, 0/255, 0.45)
                border.width: 1

                RowLayout {
                    id: countdownRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: "#FF3B30"
                        Layout.alignment: Qt.AlignVCenter

                        SequentialAnimation on opacity {
                            running: root.isLive
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.25; duration: 600 }
                            NumberAnimation { from: 0.25; to: 1.0; duration: 600 }
                        }
                    }

                    Text {
                        text: (root.sessionLabel ? root.sessionLabel + " • " : "") + root.countdownStr
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // 2. Slim Track Strip (Circuit distance + laps + location, NO Tires, NO FIA Formula 1)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            radius: 7
            color: Qt.rgba(0.03, 0.04, 0.07, 0.45)
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Rectangle {
                    width: 3
                    height: 12
                    radius: 1.5
                    color: "#E10600"
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "TRACK"
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.circuitLength + " • " + root.laps + " Laps"
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.raceDate + " • " + root.raceTime
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // 3. Standings Section (Toggle between Driver Standings & Constructor Standings)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // Subheader: Clickable Title + Clean Counter + Season
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Interactive Standings Mode Switcher (Drivers <-> Constructors)
                Rectangle {
                    id: standingsTogglePill
                    implicitWidth: modeLabel.implicitWidth + 14
                    implicitHeight: 20
                    radius: 5
                    color: modeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: modeMouse.containsMouse ? Qt.rgba(225/255, 6/255, 0/255, 0.65) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: root.showConstructors ? "CONSTRUCTOR STANDINGS" : "DRIVER STANDINGS"
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Black
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleStandingsMode()
                    }
                }

                Rectangle {
                    height: 17
                    width: entryCounterText.implicitWidth + 12
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1

                    Text {
                        id: entryCounterText
                        anchors.centerIn: parent
                        text: (root.activeIndex + 1) + " / " + Math.max(1, root.activeList.length)
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: theme.textMuted
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "2026 SEASON"
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: theme.textDim
                }
            }

            // Standings Card (No arrows; left click = prev, right click = next; smooth horizontal slide)
            Rectangle {
                id: driverCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 9
                readonly property color teamCol: (root.currentEntry && root.currentEntry.color) ? root.currentEntry.color : "#E10600"
                readonly property int posVal: root.currentEntry ? root.currentEntry.pos : 1

                color: Qt.rgba(0.03, 0.04, 0.07, 0.56)
                border.color: driverCardMouse.containsMouse && root.currentEntry
                    ? Qt.rgba(teamCol.r, teamCol.g, teamCol.b, 0.70)
                    : Qt.rgba(1, 1, 1, 0.11)
                border.width: 1
                clip: true

                Behavior on border.color { ColorAnimation { duration: 160 } }

                // Subtle team-color ambient wash inside card
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(driverCard.teamCol.r, driverCard.teamCol.g, driverCard.teamCol.b, 0.16) }
                        GradientStop { position: 0.45; color: Qt.rgba(driverCard.teamCol.r, driverCard.teamCol.g, driverCard.teamCol.b, 0.02) }
                        GradientStop { position: 1.0; color: Qt.rgba(driverCard.teamCol.r, driverCard.teamCol.g, driverCard.teamCol.b, 0.08) }
                    }
                }

                // Team Left Accent Bar
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3.5
                    color: driverCard.teamCol
                }

                // Sliding Entry Content
                Item {
                    id: cardSlideContainer
                    anchors.fill: parent
                    property real xOffset: 0
                    property real slideOpacity: 1.0
                    transform: Translate { x: cardSlideContainer.xOffset }
                    opacity: cardSlideContainer.slideOpacity

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 12
                        spacing: 11

                        // Official F1 Broadcast Timing Position Badge (White P1 -> Frosted Silver P2 -> Subtle Glass P3+)
                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            Layout.alignment: Qt.AlignVCenter
                            radius: 8
                            border.width: 1
                            color: {
                                if (driverCard.posVal === 1) return "#FFFFFF";
                                if (driverCard.posVal === 2) return Qt.rgba(1, 1, 1, 0.16);
                                if (driverCard.posVal === 3) return Qt.rgba(1, 1, 1, 0.09);
                                return Qt.rgba(1, 1, 1, 0.04);
                            }
                            border.color: {
                                if (driverCard.posVal === 1) return "#FFFFFF";
                                if (driverCard.posVal === 2) return Qt.rgba(1, 1, 1, 0.34);
                                if (driverCard.posVal === 3) return Qt.rgba(1, 1, 1, 0.18);
                                return Qt.rgba(1, 1, 1, 0.10);
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "P" + driverCard.posVal
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Black
                                color: driverCard.posVal === 1 ? "#111318" : (driverCard.posVal <= 3 ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.82))
                            }
                        }

                        // Large Official Constructor Crest Logo
                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            radius: 9
                            color: Qt.rgba(driverCard.teamCol.r, driverCard.teamCol.g, driverCard.teamCol.b, 0.14)
                            border.color: Qt.rgba(driverCard.teamCol.r, driverCard.teamCol.g, driverCard.teamCol.b, 0.42)
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 38
                                height: 38
                                sourceSize: Qt.size(96, 96)
                                source: Quickshell.shellPath("icons/f1-teams/" + ((root.currentEntry && root.currentEntry.teamKey) ? root.currentEntry.teamKey : "f1") + ".png")
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                smooth: true
                                asynchronous: true
                            }
                        }

                        // Center Identity (Driver Mode vs Constructor Mode)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    visible: !root.showConstructors
                                    Layout.preferredWidth: numTxt.implicitWidth + 10
                                    Layout.preferredHeight: 19
                                    radius: 5
                                    color: Qt.rgba(driverCard.teamCol.r, driverCard.teamCol.g, driverCard.teamCol.b, 0.18)
                                    border.color: Qt.rgba(driverCard.teamCol.r, driverCard.teamCol.g, driverCard.teamCol.b, 0.65)
                                    border.width: 1

                                    Text {
                                        id: numTxt
                                        anchors.centerIn: parent
                                        text: root.currentEntry ? ("#" + (root.currentEntry.number || "0")) : "#12"
                                        font.family: theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Black
                                        color: "#FFFFFF"
                                    }
                                }

                                Text {
                                    text: root.showConstructors
                                        ? (root.currentEntry ? root.currentEntry.team : "Mercedes-AMG Petronas")
                                        : (root.currentEntry ? root.currentEntry.fullName : "Andrea Kimi Antonelli")
                                    font.family: theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    visible: !root.showConstructors
                                    text: root.currentEntry ? root.currentEntry.code : "ANT"
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Black
                                    color: driverCard.teamCol
                                }

                                Text {
                                    text: root.showConstructors
                                        ? (root.currentEntry ? ((root.currentEntry.drivers || "") + (root.currentEntry.wins > 0 ? (" • " + root.currentEntry.wins + (root.currentEntry.wins === 1 ? " Win" : " Wins")) : "")) : "")
                                        : (root.currentEntry ? root.currentEntry.team : "Mercedes-AMG Petronas")
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Right Championship Points
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Text {
                                text: root.currentEntry ? root.currentEntry.pts : "390"
                                font.family: theme.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Black
                                color: "#FFFFFF"
                                anchors.baseline: ptsSuffix.baseline
                            }

                            Text {
                                id: ptsSuffix
                                text: "PTS"
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: driverCard.teamCol
                            }
                        }
                    }
                }

                // Half-card Left/Right Click + Drag Support (No arrows needed)
                MouseArea {
                    id: driverCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    property real startScreenX: 0
                    property real startScreenY: 0
                    property bool isDragging: false

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            f1Proc.running = true;
                            return;
                        }
                        if (mouse.button !== Qt.LeftButton) return;
                        let w = root.wrapper || root.findWrapper();
                        let target = (w && w.parent) ? w.parent : null;
                        if (target) {
                            let pt = driverCardMouse.mapToItem(target, mouse.x, mouse.y);
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
                            let pt = driverCardMouse.mapToItem(target, mouse.x, mouse.y);
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
                            if (mouse.x < driverCard.width * 0.5) {
                                root.stepStanding(-1);
                            } else {
                                root.stepStanding(1);
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
                f1Proc.running = true;
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
                Quickshell.execDetached(["xdg-open", "https://www.formula1.com/en/racing/2026.html"]);
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
