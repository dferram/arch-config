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
    // Carbon Pit-Wall Smoked Broadcast Glass (deep neutral obsidian without muddy red/blue bleed)
    color: Qt.rgba(0.052, 0.058, 0.082, 0.80)
    border.color: Qt.rgba(1, 1, 1, 0.16)
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
    readonly property string f1WhitePng: Quickshell.shellPath("icons/f1-white.png")

    // Live F1 API state
    property string raceName: "Las Vegas Grand Prix"
    property string shortName: "Las Vegas GP"
    property string circuitName: "Las Vegas Strip Street Circuit"
    property string location: "Las Vegas, USA"
    property string raceDate: "Sunday, Nov 22"
    property string raceTime: "04:00 UTC"
    property string roundStr: "Round 21 / 24"
    property string sessionLabel: "RACE"
    property string sessionFullLabel: "Grand Prix Race"
    property string countdownStr: "LIVE NOW"
    property int remainingSecs: 0
    property string circuitLength: "5.8 km"
    property int laps: 53

    property bool showConstructors: false
    property int driverPage: 0
    property int constructorPage: 0
    property int pendingPage: 0
    property int slideDirection: 1

    property var standings: []
    property var constructorStandings: []

    readonly property var activeList: showConstructors ? constructorStandings : standings
    readonly property int pageSize: 3
    readonly property int totalPages: Math.max(1, Math.ceil((activeList ? activeList.length : 0) / pageSize))
    readonly property int activePage: Math.min(showConstructors ? constructorPage : driverPage, totalPages - 1)

    function entryAt(idx) {
        if (!activeList || idx < 0 || idx >= activeList.length) return null;
        return activeList[idx];
    }

    function pageRangeLabel() {
        if (!activeList || activeList.length === 0) return "0 / 0";
        let start = activePage * pageSize + 1;
        let end = Math.min(activeList.length, start + pageSize - 1);
        return start + "-" + end + " / " + activeList.length;
    }

    function stepPage(delta) {
        if (totalPages <= 1) return;
        let nextP = (activePage + delta + totalPages) % totalPages;
        if (nextP === activePage) return;
        slideDirection = delta >= 0 ? 1 : -1;
        pendingPage = nextP;
        towerSlideAnim.restart();
    }

    function toggleStandingsMode() {
        modeFadeAnim.restart();
    }

    SequentialAnimation {
        id: towerSlideAnim

        ParallelAnimation {
            NumberAnimation {
                target: towerSlideContainer
                property: "xOffset"
                to: -root.slideDirection * 28
                duration: 100
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: towerSlideContainer
                property: "slideOpacity"
                to: 0.0
                duration: 100
                easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                if (root.showConstructors) {
                    root.constructorPage = root.pendingPage;
                } else {
                    root.driverPage = root.pendingPage;
                }
                towerSlideContainer.xOffset = root.slideDirection * 28;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: towerSlideContainer
                property: "xOffset"
                to: 0
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: towerSlideContainer
                property: "slideOpacity"
                to: 1.0
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: modeFadeAnim

        NumberAnimation {
            target: towerSlideContainer
            property: "slideOpacity"
            to: 0.0
            duration: 90
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                root.showConstructors = !root.showConstructors;
            }
        }
        NumberAnimation {
            target: towerSlideContainer
            property: "slideOpacity"
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    // Smoked Obsidian Liquid Glass specular surface sheen
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        z: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.01) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.03) }
        }
    }

    // Surgical F1 Crimson Racing Stripe along top edge (Pit-Wall Broadcast signature)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2.5
        z: 9
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#E10600" }
            GradientStop { position: 0.55; color: Qt.rgba(225/255, 6/255, 0, 0.55) }
            GradientStop { position: 1.0; color: Qt.rgba(225/255, 6/255, 0, 0.08) }
        }
    }

    // Fetch live data process
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
                        trackCanvas.requestPaint();
                    }
                    if (d.standings && d.standings.length > 0) {
                        root.standings = d.standings;
                        if (root.driverPage >= Math.ceil(d.standings.length / root.pageSize)) {
                            root.driverPage = 0;
                        }
                    }
                    if (d.constructorStandings && d.constructorStandings.length > 0) {
                        root.constructorStandings = d.constructorStandings;
                        if (root.constructorPage >= Math.ceil(d.constructorStandings.length / root.pageSize)) {
                            root.constructorPage = 0;
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
    // MAIN CONTENT LAYOUT
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.bottomMargin: 10
        anchors.leftMargin: 13
        anchors.rightMargin: 13
        spacing: 7
        z: 2

        // 1. Broadcast Pit-Wall Header (Large F1 Emblem + GP Info + Track Silhouette + Status Pill)
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Large Official F1 Crest Badge
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 28
                radius: 6
                color: "#E10600"
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.centerIn: parent
                    source: root.f1WhitePng
                    width: 44
                    height: 20
                    sourceSize: Qt.size(96, 48)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    asynchronous: true
                }
            }

            // GP Title + Compact Track Telemetry Line
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: root.shortName
                        font.family: theme.fontFamily
                        font.pixelSize: 14
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

                // Telemetry line (distance, laps, start time — crisp tabular numbers)
                Text {
                    text: root.circuitLength + " • " + root.laps + " Laps • " + root.raceTime
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // Mini Circuit Track Outline Vector (Canvas)
            Canvas {
                id: trackCanvas
                Layout.preferredWidth: 34
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignVCenter
                antialiasing: true

                Component.onCompleted: requestPaint()

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    let gp = (root.shortName || "").toLowerCase();
                    let pts;
                    if (gp.includes("vegas")) {
                        pts = [[4,18],[12,18],[13,12],[18,12],[22,6],[30,6],[30,11],[23,13],[22,19],[7,20],[4,18]];
                    } else if (gp.includes("qatar") || gp.includes("lusail")) {
                        pts = [[5,18],[18,19],[28,15],[29,8],[22,5],[14,9],[11,6],[6,10],[5,18]];
                    } else if (gp.includes("abu")) {
                        pts = [[4,14],[11,5],[25,5],[30,10],[27,18],[17,17],[13,20],[6,19],[4,14]];
                    } else if (gp.includes("mexico")) {
                        pts = [[4,17],[22,17],[26,12],[29,12],[29,17],[24,20],[11,11],[7,12],[4,17]];
                    } else {
                        pts = [[4,17],[15,17],[20,7],[29,7],[28,16],[19,15],[12,20],[4,17]];
                    }

                    ctx.strokeStyle = "rgba(255, 255, 255, 0.50)";
                    ctx.lineWidth = 1.8;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    for (let i = 0; i < pts.length; i++) {
                        if (i === 0) ctx.moveTo(pts[i][0], pts[i][1]);
                        else ctx.lineTo(pts[i][0], pts[i][1]);
                    }
                    ctx.stroke();

                    // Red Start/Finish Line Marker
                    ctx.fillStyle = "#E10600";
                    ctx.beginPath();
                    ctx.arc(pts[0][0], pts[0][1], 2.2, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            // Top-Right Session Timing HUD Badge
            Rectangle {
                Layout.preferredHeight: 23
                Layout.preferredWidth: countdownRow.implicitWidth + 14
                Layout.rightMargin: -4
                Layout.topMargin: -3
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                radius: 6
                color: root.countdownStr === "LIVE NOW"
                    ? Qt.rgba(225/255, 6/255, 0, 0.24)
                    : Qt.rgba(0.02, 0.03, 0.06, 0.65)
                border.color: root.countdownStr === "LIVE NOW"
                    ? "#E10600"
                    : Qt.rgba(1, 1, 1, 0.16)
                border.width: 1

                RowLayout {
                    id: countdownRow
                    anchors.centerIn: parent
                    spacing: 5

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
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // 2. Standings Header Bar (Drivers <-> Constructors Toggle, Page Range, Season)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: standingsTogglePill
                implicitWidth: modeRow.implicitWidth + 14
                implicitHeight: 20
                radius: 5
                color: modeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                border.color: modeMouse.containsMouse ? Qt.rgba(225/255, 6/255, 0, 0.75) : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: root.showConstructors ? "CONSTRUCTOR STANDINGS" : "DRIVER STANDINGS"
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Black
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "⇄"
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
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
                height: 18
                width: pageText.implicitWidth + 12
                radius: 5
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1

                Text {
                    id: pageText
                    anchors.centerIn: parent
                    text: root.pageRangeLabel()
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: theme.textMuted
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "2026 SEASON"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: theme.textDim
            }
        }

        // 3. F1 Broadcast Timing Tower (3 Rows per page, Left/Right Click Slide)
        Rectangle {
            id: towerBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 9
            color: Qt.rgba(0.025, 0.028, 0.042, 0.64)
            border.color: Qt.rgba(1, 1, 1, 0.11)
            border.width: 1
            clip: true

            Item {
                id: towerSlideContainer
                anchors.fill: parent
                property real xOffset: 0
                property real slideOpacity: 1.0
                transform: Translate { x: towerSlideContainer.xOffset }
                opacity: towerSlideContainer.slideOpacity

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 3

                    Repeater {
                        model: root.pageSize

                        Rectangle {
                            id: timingRow
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6

                            readonly property var entry: root.entryAt(root.activePage * root.pageSize + index)
                            readonly property int posVal: entry ? entry.pos : (index + 1)
                            readonly property color teamCol: (entry && entry.color) ? entry.color : "#E10600"

                            visible: entry !== null
                            color: posVal === 1 ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02)
                            border.color: posVal === 1 ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 8
                                spacing: 8

                                // Option 1 Broadcast Position Pill (White P1 -> Silver P2 -> Subtle Glass P3+)
                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 22
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 5
                                    border.width: 1
                                    color: {
                                        if (timingRow.posVal === 1) return "#FFFFFF";
                                        if (timingRow.posVal === 2) return Qt.rgba(1, 1, 1, 0.16);
                                        if (timingRow.posVal === 3) return Qt.rgba(1, 1, 1, 0.09);
                                        return Qt.rgba(1, 1, 1, 0.04);
                                    }
                                    border.color: {
                                        if (timingRow.posVal === 1) return "#FFFFFF";
                                        if (timingRow.posVal === 2) return Qt.rgba(1, 1, 1, 0.34);
                                        if (timingRow.posVal === 3) return Qt.rgba(1, 1, 1, 0.18);
                                        return Qt.rgba(1, 1, 1, 0.08);
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "P" + timingRow.posVal
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        font.weight: Font.Black
                                        color: timingRow.posVal === 1 ? "#111318" : (timingRow.posVal <= 3 ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.80))
                                    }
                                }

                                // Team Color Telemetry Vertical Stripe
                                Rectangle {
                                    Layout.preferredWidth: 3
                                    Layout.preferredHeight: 20
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 1.5
                                    color: timingRow.teamCol
                                }

                                // Official Constructor Logo
                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 24
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 5
                                    color: Qt.rgba(timingRow.teamCol.r, timingRow.teamCol.g, timingRow.teamCol.b, 0.12)
                                    border.color: Qt.rgba(timingRow.teamCol.r, timingRow.teamCol.g, timingRow.teamCol.b, 0.30)
                                    border.width: 1

                                    Image {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 20
                                        sourceSize: Qt.size(64, 64)
                                        source: Quickshell.shellPath("icons/f1-teams/" + ((timingRow.entry && timingRow.entry.teamKey) ? timingRow.entry.teamKey : "f1") + ".png")
                                        fillMode: Image.PreserveAspectFit
                                        mipmap: true
                                        smooth: true
                                        asynchronous: true
                                    }
                                }

                                // Code (Drivers mode)
                                Text {
                                    visible: !root.showConstructors
                                    Layout.preferredWidth: 28
                                    text: timingRow.entry ? timingRow.entry.code : "ANT"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                    color: timingRow.teamCol
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Driver Name OR Constructor Team Name
                                Text {
                                    text: root.showConstructors
                                        ? (timingRow.entry ? timingRow.entry.team : "")
                                        : (timingRow.entry ? timingRow.entry.fullName : "")
                                    font.family: theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Driver Duo / Wins (Constructors) OR Number (Drivers)
                                Text {
                                    text: root.showConstructors
                                        ? (timingRow.entry ? (timingRow.entry.drivers || "") : "")
                                        : (timingRow.entry ? ("#" + (timingRow.entry.number || "0")) : "")
                                    font.family: root.showConstructors ? theme.fontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: theme.textDim
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: root.showConstructors ? 115 : 32
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Tabular Championship Points
                                Row {
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                    spacing: 3

                                    Text {
                                        text: timingRow.entry ? timingRow.entry.pts : "0"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: Font.Black
                                        color: "#FFFFFF"
                                        anchors.baseline: rowPtsLbl.baseline
                                    }

                                    Text {
                                        id: rowPtsLbl
                                        text: "PTS"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        color: timingRow.teamCol
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Left/Right half click pagination + drag support
            MouseArea {
                id: towerMouse
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
                        let pt = towerMouse.mapToItem(target, mouse.x, mouse.y);
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
                        let pt = towerMouse.mapToItem(target, mouse.x, mouse.y);
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
                        if (mouse.x < towerBox.width * 0.5) {
                            root.stepPage(-1);
                        } else {
                            root.stepPage(1);
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
