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
    readonly property string f1WhiteSvg: Quickshell.shellPath("icons/f1-white-tight.svg")

    // Live F1 API state
    property string raceName: "Las Vegas Grand Prix"
    property string shortName: "Las Vegas GP"
    property string circuitId: "vegas"
    property var trackPoints: []
    property string circuitName: "Las Vegas Strip Street Circuit"
    property string location: "Las Vegas, USA"
    property string raceDate: "Sunday, Nov 22"
    property string raceTime: "04:00 UTC"
    property string roundStr: "Round 21 / 24"
    property string sessionLabel: "RACE"
    property string sessionFullLabel: "Grand Prix Race"
    property int currentLap: 0
    property bool isRaceLive: false
    property string countdownStr: "LIVE NOW"
    property int remainingSecs: 0
    property string circuitLength: "6.201 km"
    property int laps: 50

    // 0: Driver Standings, 1: Constructor Standings, 2: Race Positions, 3: Qualifying
    property int viewMode: 0
    property var pageIndices: [0, 0, 0, 0]
    property int pendingPage: 0
    property int slideDirection: 1

    property var standings: []
    property var constructorStandings: []
    property var raceStandings: []
    property var qualifying: []

    readonly property var activeList: {
        if (viewMode === 1) return constructorStandings;
        if (viewMode === 2) return raceStandings;
        if (viewMode === 3) return qualifying;
        return standings;
    }
    readonly property int pageSize: 3
    readonly property int totalPages: Math.max(1, Math.ceil((activeList ? activeList.length : 0) / pageSize))
    readonly property int activePage: Math.min(pageIndices[viewMode] || 0, totalPages - 1)

    function viewModeTitle() {
        if (viewMode === 1) return "CONSTRUCTOR STANDINGS";
        if (viewMode === 2) return isRaceLive ? "LIVE TIMING" : "RACE CLASSIFICATION";
        if (viewMode === 3) return "QUALIFYING";
        return "DRIVER STANDINGS";
    }

    function entryAt(idx) {
        if (!activeList || idx < 0 || idx >= activeList.length) return null;
        return activeList[idx];
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

    function setViewMode(targetMode) {
        if (targetMode === viewMode) return;
        modeFadeAnim.targetMode = targetMode;
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
                let copy = root.pageIndices.slice();
                copy[root.viewMode] = root.pendingPage;
                root.pageIndices = copy;
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
        property int targetMode: -1

        NumberAnimation {
            target: towerSlideContainer
            property: "slideOpacity"
            to: 0.0
            duration: 90
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                if (modeFadeAnim.targetMode >= 0) {
                    root.viewMode = modeFadeAnim.targetMode;
                    modeFadeAnim.targetMode = -1;
                } else {
                    // Cycle: Driver Standings -> Constructor Standings -> Race Positions -> Qualifying
                    for (let step = 1; step <= 4; step++) {
                        let cand = (root.viewMode + step) % 4;
                        let listForCand = cand === 1 ? root.constructorStandings : (cand === 2 ? root.raceStandings : (cand === 3 ? root.qualifying : root.standings));
                        if (listForCand && listForCand.length > 0) {
                            root.viewMode = cand;
                            break;
                        }
                    }
                }
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
                        root.circuitId = d.nextRace.circuitId || root.circuitId;
                        if (d.nextRace.trackPoints && d.nextRace.trackPoints.length > 0) {
                            root.trackPoints = d.nextRace.trackPoints;
                        }
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
                        root.currentLap = d.nextRace.currentLap !== undefined ? d.nextRace.currentLap : root.currentLap;
                        root.isRaceLive = !!d.nextRace.isRaceLive;
                        trackCanvas.requestPaint();
                    }
                    if (d.standings && d.standings.length > 0) {
                        root.standings = d.standings;
                    }
                    if (d.constructorStandings && d.constructorStandings.length > 0) {
                        root.constructorStandings = d.constructorStandings;
                    }
                    if (d.raceStandings && d.raceStandings.length > 0) {
                        root.raceStandings = d.raceStandings;
                    }
                    if (d.qualifying && d.qualifying.length > 0) {
                        root.qualifying = d.qualifying;
                    }
                } catch(e) {}
            }
        }
    }

    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    // Live 1-second countdown ticker (preserves live LAP counter when race is underway)
    Timer {
        interval: 1000
        running: root.isLive && !root.isRaceLive
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
            } else if (!root.isRaceLive) {
                root.countdownStr = "LIVE NOW";
            }
        }
    }

    // Periodic refresh: 30s during live race, 5m otherwise
    Timer {
        interval: root.isRaceLive ? 30000 : 300000
        running: root.isLive
        repeat: true
        onTriggered: {
            if (root.isLive && !f1Proc.running) f1Proc.running = true;
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

            // Large Official F1 Crest Badge (tight SVG fills badge boldly)
            Rectangle {
                Layout.preferredWidth: 66
                Layout.preferredHeight: 30
                radius: 6
                color: "#E10600"
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.centerIn: parent
                    source: root.f1WhiteSvg
                    width: 54
                    height: 16
                    sourceSize: Qt.size(108, 32)
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
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

            // Official GPS Circuit Track Outline Vector + Animated Racing Car Telemetry Dot
            Canvas {
                id: trackCanvas
                Layout.preferredWidth: 42
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter
                antialiasing: true
                visible: root.trackPoints && root.trackPoints.length > 2

                property real lapProgress: 0.0
                onLapProgressChanged: requestPaint()

                NumberAnimation {
                    target: trackCanvas
                    property: "lapProgress"
                    from: 0.0
                    to: 1.0
                    duration: 6500
                    easing.type: Easing.Linear
                    loops: Animation.Infinite
                    running: root.isLive && trackCanvas.visible
                }

                Connections {
                    target: root
                    function onTrackPointsChanged() { trackCanvas.requestPaint(); }
                }
                Component.onCompleted: requestPaint()

                function pointOnClosedLoop(pts, tNorm, pad, drawW, drawH) {
                    let n = pts.length;
                    let cum = [0.0];
                    let total = 0.0;
                    for (let i = 0; i < n; i++) {
                        let p0 = pts[i];
                        let p1 = pts[(i + 1) % n];
                        let seg = Math.hypot((p1[0] - p0[0]) * drawW, (p1[1] - p0[1]) * drawH);
                        total += seg;
                        cum.push(total);
                    }
                    if (total <= 0.001) {
                        return { x: pad + pts[0][0] * drawW, y: pad + pts[0][1] * drawH };
                    }
                    let wrapped = ((tNorm % 1.0) + 1.0) % 1.0;
                    let target = wrapped * total;
                    for (let i = 0; i < n; i++) {
                        if (target <= cum[i + 1]) {
                            let segLen = cum[i + 1] - cum[i];
                            let frac = segLen > 0.0001 ? (target - cum[i]) / segLen : 0.0;
                            let a = pts[i];
                            let b = pts[(i + 1) % n];
                            return {
                                x: pad + (a[0] + (b[0] - a[0]) * frac) * drawW,
                                y: pad + (a[1] + (b[1] - a[1]) * frac) * drawH
                            };
                        }
                    }
                    return { x: pad + pts[0][0] * drawW, y: pad + pts[0][1] * drawH };
                }

                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    let pts = root.trackPoints;
                    if (!pts || pts.length < 3) return;

                    let pad = 4.0;
                    let drawW = width - pad * 2;
                    let drawH = height - pad * 2;

                    // Circuit asphalt trace
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.45)";
                    ctx.lineWidth = 1.6;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    for (let i = 0; i < pts.length; i++) {
                        let px = pad + pts[i][0] * drawW;
                        let py = pad + pts[i][1] * drawH;
                        if (i === 0) ctx.moveTo(px, py);
                        else ctx.lineTo(px, py);
                    }
                    ctx.closePath();
                    ctx.stroke();

                    // Smooth continuous crimson light trail following the exact circuit path
                    let trailSteps = 14;
                    let trailSpan = 0.16;
                    let trailPts = [];
                    for (let s = 0; s <= trailSteps; s++) {
                        let tSample = trackCanvas.lapProgress - (1.0 - s / trailSteps) * trailSpan;
                        trailPts.push(pointOnClosedLoop(pts, tSample, pad, drawW, drawH));
                    }

                    // Soft outer ambient red light glow
                    for (let s = 0; s < trailSteps; s++) {
                        let ratio = (s + 1) / trailSteps;
                        ctx.strokeStyle = "rgba(225, 6, 0, " + (0.20 * ratio * ratio) + ")";
                        ctx.lineWidth = 1.5 + 3.2 * ratio;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(trailPts[s].x, trailPts[s].y);
                        ctx.lineTo(trailPts[s + 1].x, trailPts[s + 1].y);
                        ctx.stroke();
                    }

                    // Crisp inner crimson light core
                    for (let s = 0; s < trailSteps; s++) {
                        let ratio = (s + 1) / trailSteps;
                        ctx.strokeStyle = "rgba(255, 59, 48, " + (0.75 * ratio * ratio) + ")";
                        ctx.lineWidth = 0.8 + 1.1 * ratio;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(trailPts[s].x, trailPts[s].y);
                        ctx.lineTo(trailPts[s + 1].x, trailPts[s + 1].y);
                        ctx.stroke();
                    }

                    // Active F1 Telemetry Marker with soft red halo
                    let cur = trailPts[trailSteps];
                    ctx.fillStyle = "rgba(225, 6, 0, 0.28)";
                    ctx.beginPath();
                    ctx.arc(cur.x, cur.y, 4.4, 0, Math.PI * 2);
                    ctx.fill();

                    ctx.fillStyle = "#E10600";
                    ctx.beginPath();
                    ctx.arc(cur.x, cur.y, 2.5, 0, Math.PI * 2);
                    ctx.fill();

                    ctx.fillStyle = "#FFFFFF";
                    ctx.beginPath();
                    ctx.arc(cur.x, cur.y, 1.0, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            // Top-Right Session Timing HUD Badge (shows LIVE + lap count when race is underway)
            Rectangle {
                Layout.preferredHeight: 23
                Layout.preferredWidth: countdownRow.implicitWidth + 14
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                radius: 6
                color: (root.isRaceLive || root.countdownStr === "LIVE NOW")
                    ? Qt.rgba(225/255, 6/255, 0, 0.24)
                    : Qt.rgba(0.02, 0.03, 0.06, 0.65)
                border.color: (root.isRaceLive || root.countdownStr === "LIVE NOW")
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
                        text: (root.isRaceLive || root.countdownStr === "LIVE NOW")
                            ? ("LIVE • " + (root.countdownStr === "LIVE NOW" ? "NOW" : root.countdownStr))
                            : ((root.sessionLabel ? root.sessionLabel + " • " : "") + root.countdownStr)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // 2. Standings Header Bar (4 Modes: Drivers, Constructors, Race Positions, Qualifying)
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
                        text: root.viewModeTitle()
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

                                // Code (Drivers, Race & Qualifying modes)
                                Text {
                                    visible: root.viewMode !== 1
                                    Layout.preferredWidth: 28
                                    text: (timingRow.entry && timingRow.entry.code) ? timingRow.entry.code : ""
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                    color: timingRow.teamCol
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Driver Name OR Constructor Team Name
                                Text {
                                    text: root.viewMode === 1
                                        ? ((timingRow.entry && timingRow.entry.team) ? timingRow.entry.team : "")
                                        : ((timingRow.entry && timingRow.entry.fullName) ? timingRow.entry.fullName : "")
                                    font.family: theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Driver Duo (Constructors) OR Car Number (Drivers / Race / Quali)
                                Text {
                                    text: root.viewMode === 1
                                        ? ((timingRow.entry && timingRow.entry.drivers) ? timingRow.entry.drivers : "")
                                        : ((timingRow.entry && timingRow.entry.number) ? ("#" + timingRow.entry.number) : "")
                                    font.family: root.viewMode === 1 ? theme.fontFamily : "JetBrainsMono Nerd Font"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: theme.textDim
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: root.viewMode === 1 ? 115 : 32
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Tabular Right Metric (Points | Race Status | Qualy Lap Time)
                                Row {
                                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                    spacing: 4

                                    Text {
                                        text: {
                                            if (!timingRow.entry) return "";
                                            if (root.viewMode === 2 || root.viewMode === 3) {
                                                return timingRow.entry.metric ? timingRow.entry.metric : "";
                                            }
                                            return timingRow.entry.pts !== undefined ? String(timingRow.entry.pts) : "0";
                                        }
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: (root.viewMode === 3) ? 11 : 12
                                        font.weight: Font.Black
                                        color: "#FFFFFF"
                                        anchors.baseline: rowPtsLbl.baseline
                                    }

                                    Text {
                                        id: rowPtsLbl
                                        text: {
                                            if (!timingRow.entry) return "";
                                            if (root.viewMode === 2 || root.viewMode === 3) {
                                                return timingRow.entry.unit ? timingRow.entry.unit : "";
                                            }
                                            return "PTS";
                                        }
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
