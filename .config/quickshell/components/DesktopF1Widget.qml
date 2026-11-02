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
    readonly property string f1WhitePng: Quickshell.shellPath("icons/f1-white.png")
    readonly property string f1Png: Quickshell.shellPath("icons/f1.png")

    // State properties (dynamically populated from live ESPN/Jolpica F1 API)
    property string raceName: "Mexico City Grand Prix"
    property string shortName: "Mexico City GP"
    property string circuitName: "Autodromo Hermanos Rodriguez"
    property string location: "Mexico City, Mexico"
    property string raceDate: "Friday, Oct 30"
    property string raceTime: "18:30 UTC"
    property string roundStr: "Round 21 / 25"
    property string sessionLabel: "FP1"
    property string sessionFullLabel: "Práctica 1"
    property string countdownStr: "02h 30m 00s"
    property int remainingSecs: 9000
    property string circuitLength: "4.304 km"
    property int laps: 71

    property var compounds: [
        {"code": "C3", "compound": "Hard", "color": "#FFFFFF", "label": "HARD"},
        {"code": "C4", "compound": "Medium", "color": "#FFD700", "label": "MED"},
        {"code": "C5", "compound": "Soft", "color": "#E10600", "label": "SOFT"}
    ]

    property int selectedDriverIndex: 0
    property var standings: []

    readonly property var currentDriver: (standings && standings.length > selectedDriverIndex) ? standings[selectedDriverIndex] : null

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
                } catch(e) {}
            }
        }
    }

    // Auto rotate drivers disabled per user preference (driver stays static)
    Timer {
        id: autoRotateTimer
        interval: 12000
        running: false
        repeat: true
        onTriggered: {
            if (root.standings && root.standings.length > 1) {
                root.selectedDriverIndex = (root.selectedDriverIndex + 1) % root.standings.length;
            }
        }
    }

    function prevDriver() {
        if (root.standings && root.standings.length > 0) {
            root.selectedDriverIndex = (root.selectedDriverIndex - 1 + root.standings.length) % root.standings.length;
        }
    }

    function nextDriver() {
        if (root.standings && root.standings.length > 0) {
            root.selectedDriverIndex = (root.selectedDriverIndex + 1) % root.standings.length;
        }
    }

    // Live 1-second countdown ticker (only ticks when widget is visible)
    Timer {
        interval: 1000
        running: root.visible
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

    // Periodic refresh
    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: f1Proc.running = true
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
        border.width: 2
        z: 10
    }

    // =========================================================================
    // MAIN CONTENT LAYOUT
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 15
        anchors.bottomMargin: 14
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        // 1. Header: F1 Logo Badge + Race Details + Countdown Pill
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // F1 Official Logo Emblem Badge
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 22
                radius: 5
                color: "#E10600"

                Image {
                    anchors.centerIn: parent
                    source: root.f1WhitePng
                    width: 26
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }

            // Grand Prix Name & Round Subtitle (NO circuit silhouette outline)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: root.shortName
                        font.family: theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Black
                        color: "#FFFFFF"
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 4
                        radius: 2
                        color: "#E10600"
                    }

                    Text {
                        text: root.roundStr
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: theme.textDim
                    }
                }

                Text {
                    text: root.circuitName + " • " + root.raceTime
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.65)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // High-Tech F1 Broadcast Timing HUD Countdown
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: countdownRow.implicitWidth + 16
                radius: 6
                color: Qt.rgba(0.08, 0.08, 0.12, 0.90)
                border.color: Qt.rgba(225, 6, 0, 0.45)
                border.width: 1

                RowLayout {
                    id: countdownRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 6
                        radius: 3
                        color: "#E10600"
                        Layout.alignment: Qt.AlignVCenter

                        SequentialAnimation on opacity {
                            running: root.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.25; duration: 600 }
                            NumberAnimation { from: 0.25; to: 1.0; duration: 600 }
                        }
                    }

                    Text {
                        id: countdownText
                        text: (root.sessionLabel ? root.sessionLabel + " • " : "") + root.countdownStr
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Black
                        color: "#FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // 2. Track & Compounds Bar (Clean & Minimalist • NO Lap record)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(255, 255, 255, 0.08)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 12

                // Track Distance & Laps
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    Rectangle {
                        width: 3
                        height: 14
                        radius: 1.5
                        color: "#E10600"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "TRACK"
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.circuitLength + " (" + root.laps + " L)"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: 1
                    height: 16
                    color: Qt.rgba(255, 255, 255, 0.10)
                    Layout.alignment: Qt.AlignVCenter
                }

                // Pirelli Tyre Compounds
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    Text {
                        text: "TIRES"
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: root.compounds
                            Rectangle {
                                width: 17
                                height: 17
                                radius: 8.5
                                color: "transparent"
                                border.color: modelData.color
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.code
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 8
                                    font.weight: Font.Black
                                    color: modelData.color
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Season Badge
                Rectangle {
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: seasonText.implicitWidth + 12
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(255, 255, 255, 0.10)
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: seasonText
                        anchors.centerIn: parent
                        text: "FIA FORMULA 1"
                        font.family: theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.Black
                        color: theme.textDim
                    }
                }
            }
        }

        // 3. Driver Standings with Lateral Navigation Arrows (NBA Style)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 5

            // Subheader with Title & Interactive Lateral Arrows
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "DRIVER STANDINGS"
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Black
                    color: "#FFFFFF"
                }

                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 4
                    radius: 2
                    color: "#E10600"
                }

                // Interactive Driver Switcher (< 1 of 23 >)
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
                            onClicked: root.prevDriver()
                        }
                    }

                    Text {
                        text: (root.selectedDriverIndex + 1) + " of " + Math.max(1, root.standings.length)
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
                            onClicked: root.nextDriver()
                        }
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

            // Driver Data Card (spacious, aesthetic, dark obsidian)
            Rectangle {
                id: driverCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: driverCardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.035)
                border.color: driverCardHover.containsMouse
                    ? (root.currentDriver ? root.currentDriver.color : "#E10600")
                    : Qt.rgba(255, 255, 255, 0.08)
                border.width: 1
                clip: true

                // Driver Constructor Team Left Stripe
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3.5
                    color: root.currentDriver ? root.currentDriver.color : "#E10600"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10

                    // Left Side Lateral Arrow on the Card
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 28
                        radius: 4
                        color: cardPrevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: cardPrevMouse.containsMouse ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.45)
                        }

                        MouseArea {
                            id: cardPrevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevDriver()
                        }
                    }

                    // Position Badge (P1 gold/red, P2 silver, P3 bronze)
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 6
                        color: {
                            if (!root.currentDriver) return Qt.rgba(1, 1, 1, 0.08);
                            if (root.currentDriver.pos === 1) return "#E10600";
                            if (root.currentDriver.pos === 2) return Qt.rgba(192, 192, 192, 0.25);
                            if (root.currentDriver.pos === 3) return Qt.rgba(205, 127, 50, 0.25);
                            return Qt.rgba(1, 1, 1, 0.08);
                        }
                        border.color: {
                            if (!root.currentDriver) return Qt.rgba(255, 255, 255, 0.12);
                            if (root.currentDriver.pos === 1) return "transparent";
                            if (root.currentDriver.pos === 2) return Qt.rgba(192, 192, 192, 0.45);
                            if (root.currentDriver.pos === 3) return Qt.rgba(205, 127, 50, 0.45);
                            return Qt.rgba(255, 255, 255, 0.12);
                        }
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.currentDriver ? ("P" + root.currentDriver.pos) : "P1"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Black
                            color: "#FFFFFF"
                        }
                    }

                    // Driver Permanent Racing Number
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 22
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: root.currentDriver ? root.currentDriver.color : "#E10600"
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.currentDriver ? ("#" + (root.currentDriver.number || "0")) : "#1"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Black
                            color: "#FFFFFF"
                        }
                    }

                    // Driver Full Name & Team Details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            spacing: 6
                            Text {
                                text: root.currentDriver ? root.currentDriver.fullName : "Kimi Antonelli"
                                font.family: theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.currentDriver ? ("• " + root.currentDriver.code) : "• ANT"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.currentDriver ? root.currentDriver.color : "#27F4D2"
                            }
                        }

                        RowLayout {
                            spacing: 5
                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: root.currentDriver ? root.currentDriver.color : "#27F4D2"
                            }
                            Text {
                                text: root.currentDriver ? root.currentDriver.team : "Mercedes-AMG Petronas"
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                color: theme.textDim
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Championship Points
                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            text: root.currentDriver ? (root.currentDriver.pts + " PTS") : "365 PTS"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                            font.weight: Font.Black
                            color: root.currentDriver ? root.currentDriver.color : "#27F4D2"
                            anchors.right: parent.right
                        }
                        Text {
                            text: "CHAMPIONSHIP"
                            font.family: theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: theme.textDim
                            anchors.right: parent.right
                        }
                    }

                    // Constructor Crest Logo
                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(255, 255, 255, 0.10)
                            border.width: 1

                            Image {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                source: Quickshell.shellPath("icons/f1-teams/" + ((root.currentDriver && root.currentDriver.teamKey) ? root.currentDriver.teamKey : "f1") + ".png")
                                fillMode: Image.PreserveAspectFit
                                opacity: 0.95
                                cache: false
                                asynchronous: true
                            }
                        }
                    }

                    // Right Side Lateral Arrow on the Card
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 28
                        radius: 4
                        color: cardNextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "›"
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: cardNextMouse.containsMouse ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.45)
                        }

                        MouseArea {
                            id: cardNextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextDriver()
                        }
                    }
                }

                MouseArea {
                    id: driverCardHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                    onClicked: root.nextDriver()
                }
            }
        }
    }

    // Drag / Interaction MouseArea (Apple Sonoma smooth dragging)
    MouseArea {
        id: bgDragArea
        anchors.fill: parent
        z: -2
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
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
                Quickshell.execDetached(["xdg-open", "https://www.formula1.com/en/racing/2026.html"]);
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
