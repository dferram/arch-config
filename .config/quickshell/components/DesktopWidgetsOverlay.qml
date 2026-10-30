import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

PanelWindow {
    id: desktopWindow

    Theme { id: theme }

    // Position widget canvas on bottom layer (behind all normal windows, above wallpaper)
    WlrLayershell.layer: WlrLayer.Bottom
    property bool requestsKeyboardFocus: false
    WlrLayershell.keyboardFocus: requestsKeyboardFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: 0
        bottom: 0
        left: 0
        right: 0
    }

    // Monitor & Workspace Logic: widgets displayed on ALL workspaces
    property var modelData: null
    screen: modelData
    readonly property string screenName: (modelData && modelData.name) ? modelData.name : ""
    
    property bool enabled: true
    readonly property bool shouldBeVisible: enabled

    visible: shouldBeVisible || canvasItem.opacity > 0.01

    // =========================================================================
    // Responsive Desktop Grid System (6x4 Symmetric Apple Sonoma Grid)
    // Dynamically scales to any monitor resolution (1440x960, 1080p, 1440p, 4K)
    // =========================================================================
    readonly property int gridCols: 6
    readonly property int gridRows: 4
    readonly property real gridGap: 16
    readonly property real sideMargin: Math.max(24, Math.round(desktopWindow.width * 0.022))
    readonly property real topMargin: 56
    readonly property real bottomMargin: 24
    readonly property real cellWidth: Math.floor((desktopWindow.width - (sideMargin * 2) - ((gridCols - 1) * gridGap)) / gridCols)
    readonly property real cellHeight: Math.floor((desktopWindow.height - topMargin - bottomMargin - ((gridRows - 1) * gridGap)) / gridRows)
    readonly property real gridStartX: Math.round((desktopWindow.width - (gridCols * cellWidth + (gridCols - 1) * gridGap)) / 2)
    readonly property real gridStartY: topMargin

    // Global drag and grid state
    property bool isDraggingAny: false
    property int snapCol: -1
    property int snapRow: -1
    property bool snapValid: true
    property real snapWidth: cellWidth
    property real snapHeight: cellHeight
    property bool showGridGuide: false
    property bool showAddGallery: false

    // Collision Detection API: strictly prevents widgets from overlapping
    function isSlotAvailable(excludeKey, col, row, colSpan, rowSpan) {
        if (col < 0 || row < 0 || col + colSpan > gridCols || row + rowSpan > gridRows) {
            return false;
        }
        let m = gridMap;
        if (!m) return true;
        for (let k in m) {
            if (k === excludeKey) continue;
            let other = m[k];
            let oc = other.col || 0;
            let or = other.row || 0;
            let ow = other.colSpan || 1;
            let oh = other.rowSpan || 1;

            // AABB non-overlap test
            let noOverlap = (col + colSpan <= oc) || (oc + ow <= col) ||
                            (row + rowSpan <= or) || (or + oh <= row);
            if (!noOverlap) {
                return false;
            }
        }
        return true;
    }

    function findBestFitSlot(excludeKey, preferCol, preferRow, colSpan, rowSpan) {
        if (isSlotAvailable(excludeKey, preferCol, preferRow, colSpan, rowSpan)) {
            return { "col": preferCol, "row": preferRow, "valid": true };
        }
        // Search outwards for the closest free slot that fits without collision
        let bestDist = 999999;
        let bestCol = -1, bestRow = -1;
        for (let r = 0; r <= gridRows - rowSpan; r++) {
            for (let c = 0; c <= gridCols - colSpan; c++) {
                if (isSlotAvailable(excludeKey, c, r, colSpan, rowSpan)) {
                    let d = Math.hypot(c - preferCol, r - preferRow);
                    if (d < bestDist) {
                        bestDist = d;
                        bestCol = c;
                        bestRow = r;
                    }
                }
            }
        }
        if (bestCol >= 0 && bestRow >= 0) {
            return { "col": bestCol, "row": bestRow, "valid": true };
        }
        return { "col": preferCol, "row": preferRow, "valid": false };
    }

    // Grid coordinates map (loaded asynchronously from persistent store)
    property var gridMap: ({})
    property bool gridLoaded: false
    property bool hasPendingSave: false

    // Load saved grid positions
    Process {
        id: loadGridProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "grid-get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    if (d && typeof d === "object" && Object.keys(d).length > 0) {
                        desktopWindow.gridMap = d;
                        desktopWindow.gridLoaded = true;
                    }
                } catch(e) {}
            }
        }
    }

    // Save grid positions with queueing to prevent dropping concurrent saves
    Process {
        id: saveGridProc
        onExited: {
            if (desktopWindow.hasPendingSave) {
                desktopWindow.hasPendingSave = false;
                desktopWindow.savePositions();
            }
        }
    }

    function savePositions() {
        if (!desktopWindow.gridLoaded || !desktopWindow.gridMap || Object.keys(desktopWindow.gridMap).length === 0) {
            return;
        }
        if (saveGridProc.running) {
            desktopWindow.hasPendingSave = true;
            return;
        }
        let jsonStr = JSON.stringify(desktopWindow.gridMap);
        saveGridProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "grid-save", jsonStr];
        saveGridProc.running = true;
    }

    function reloadGrid() {
        loadGridProc.running = true;
    }

    property int reloadTick: (shell && shell.gridReloadTick !== undefined) ? shell.gridReloadTick : 0
    onReloadTickChanged: reloadGrid()

    Process {
        id: resetGridProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "grid-reset"]
        onExited: reloadGrid()
    }

    function addWidgetKey(key, type, defW, defH) {
        let m = Object.assign({}, desktopWindow.gridMap);
        let occupied = {};
        for (let k in m) {
            let item = m[k];
            let cw = item.colSpan || 1;
            let rw = item.rowSpan || 1;
            for (let c = item.col; c < item.col + cw; c++) {
                for (let r = item.row; r < item.row + rw; r++) {
                    occupied[c + "," + r] = true;
                }
            }
        }
        let foundCol = 0, foundRow = 0;
        let placed = false;
        for (let r = 0; r <= desktopWindow.gridRows - defH; r++) {
            for (let c = 0; c <= desktopWindow.gridCols - defW; c++) {
                let collision = false;
                for (let dc = 0; dc < defW; dc++) {
                    for (let dr = 0; dr < defH; dr++) {
                        if (occupied[(c + dc) + "," + (r + dr)]) {
                            collision = true;
                            break;
                        }
                    }
                    if (collision) break;
                }
                if (!collision) {
                    foundCol = c;
                    foundRow = r;
                    placed = true;
                    break;
                }
            }
            if (placed) break;
        }

        m[key] = {
            "col": foundCol,
            "row": foundRow,
            "colSpan": defW,
            "rowSpan": defH,
            "type": type
        };
        desktopWindow.gridMap = m;
        desktopWindow.savePositions();
        desktopWindow.showAddGallery = false;
    }

    // Main Desktop Widgets Canvas
    Item {
        id: canvasItem
        anchors.fill: parent

        opacity: desktopWindow.shouldBeVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        // =====================================================================
        // Apple Desktop Grid Overlay (Visible ONLY when dragging or in Edit Mode)
        // =====================================================================
        Item {
            id: gridOverlay
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: (desktopWindow.isDraggingAny || desktopWindow.showGridGuide) ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Grid Cells Matrix
            Repeater {
                model: desktopWindow.gridCols * desktopWindow.gridRows
                delegate: Rectangle {
                    id: cellRect
                    required property int index
                    readonly property int col: index % desktopWindow.gridCols
                    readonly property int row: Math.floor(index / desktopWindow.gridCols)

                    x: desktopWindow.gridStartX + col * (desktopWindow.cellWidth + desktopWindow.gridGap)
                    y: desktopWindow.gridStartY + row * (desktopWindow.cellHeight + desktopWindow.gridGap)
                    width: desktopWindow.cellWidth
                    height: desktopWindow.cellHeight
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.02)
                    border.color: Qt.rgba(255, 255, 255, 0.07)
                    border.width: 1

                    // Subtle dot pattern in center of cell
                    Rectangle {
                        anchors.centerIn: parent
                        width: 4
                        height: 4
                        radius: 2
                        color: Qt.rgba(255, 255, 255, 0.18)
                    }

                    // Coordinate guide label (visible in customize mode)
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 6
                        text: cellRect.col + "," + cellRect.row
                        color: Qt.rgba(255, 255, 255, 0.20)
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        visible: desktopWindow.showGridGuide
                    }
                }
            }

            // Snap Target Ghost Indicator
            Rectangle {
                id: snapGhost
                visible: desktopWindow.isDraggingAny && desktopWindow.snapCol >= 0 && desktopWindow.snapRow >= 0
                x: desktopWindow.gridStartX + desktopWindow.snapCol * (desktopWindow.cellWidth + desktopWindow.gridGap)
                y: desktopWindow.gridStartY + desktopWindow.snapRow * (desktopWindow.cellHeight + desktopWindow.gridGap)
                width: desktopWindow.snapWidth
                height: desktopWindow.snapHeight
                radius: 22
                color: desktopWindow.snapValid ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.16) : Qt.rgba(1, 0.2, 0.2, 0.22)
                border.color: desktopWindow.snapValid ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : "#ff453a"
                border.width: 2

                Behavior on x { NumberAnimation { duration: 90 } }
                Behavior on y { NumberAnimation { duration: 90 } }
                Behavior on width { NumberAnimation { duration: 90 } }
                Behavior on height { NumberAnimation { duration: 90 } }
            }
        }

        // =====================================================================
        // WIDGETS INSTANCES ON THE GRID
        // =====================================================================

        // 1. Clock Widget
        GridWidgetWrapper {
            id: itemClock
            overlay: desktopWindow
            widgetKey: "clock"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["clock"])
            DesktopClockWidget {
                anchors.fill: parent
            }
        }

        // 2. Battery Widget
        GridWidgetWrapper {
            id: itemBattery
            overlay: desktopWindow
            widgetKey: "battery"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["battery"])
            DesktopBatteryWidget {
                anchors.fill: parent
            }
        }

        // 3. Calendar Widget
        GridWidgetWrapper {
            id: itemCalendar
            overlay: desktopWindow
            widgetKey: "calendar"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["calendar"])
            DesktopCalendarWidget {
                anchors.fill: parent
            }
        }

        // 4. Live Weather Widget
        GridWidgetWrapper {
            id: itemWeather
            overlay: desktopWindow
            widgetKey: "weather"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["weather"])
            DesktopWeatherWidget {
                anchors.fill: parent
            }
        }

        // 5. System Resources Monitor (CPU, RAM, Temp)
        GridWidgetWrapper {
            id: itemResources
            overlay: desktopWindow
            widgetKey: "resources"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["resources"])
            DesktopResourcesWidget {
                anchors.fill: parent
            }
        }

        // Screen Time Tracker (Trabajo vs Ocio / Procrastinación)
        GridWidgetWrapper {
            id: itemScreenTime
            overlay: desktopWindow
            widgetKey: "screentime"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["screentime"])
            DesktopScreenTimeWidget {
                anchors.fill: parent
            }
        }

        // 6. Media Player (Now Playing)
        GridWidgetWrapper {
            id: itemMedia
            overlay: desktopWindow
            widgetKey: "media"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["media"])
            DesktopMediaWidget {
                anchors.fill: parent
            }
        }

        // 7. Reminders Widget
        GridWidgetWrapper {
            id: itemReminders
            overlay: desktopWindow
            widgetKey: "reminders"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["reminders"])
            DesktopRemindersWidget {
                anchors.fill: parent
            }
        }

        // 8. Notes Widget
        GridWidgetWrapper {
            id: itemNotes
            overlay: desktopWindow
            widgetKey: "notes"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["notes"])
            DesktopNotesWidget {
                anchors.fill: parent
            }
        }

        // 9. Photo Widget 1 (Pictures)
        GridWidgetWrapper {
            id: itemPhoto1
            overlay: desktopWindow
            widgetKey: "photo1"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["photo1"])
            DesktopPhotoWidget {
                anchors.fill: parent
                widgetId: "1"
            }
        }

        // 10. Photo Widget 2 (Pictures 2)
        GridWidgetWrapper {
            id: itemPhoto2
            overlay: desktopWindow
            widgetKey: "photo2"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["photo2"])
            DesktopPhotoWidget {
                anchors.fill: parent
                widgetId: "2"
            }
        }

        // 11. Photo Widget 3 (Wallpapers)
        GridWidgetWrapper {
            id: itemPhoto3
            overlay: desktopWindow
            widgetKey: "photo3"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["photo3"])
            DesktopPhotoWidget {
                anchors.fill: parent
                widgetId: "3"
            }
        }

        // 12. Photo Widget 4 (Additional Frame)
        GridWidgetWrapper {
            id: itemPhoto4
            overlay: desktopWindow
            widgetKey: "photo4"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["photo4"])
            DesktopPhotoWidget {
                anchors.fill: parent
                widgetId: "4"
            }
        }

        // 13. Photo Widget 5 (Additional Frame)
        GridWidgetWrapper {
            id: itemPhoto5
            overlay: desktopWindow
            widgetKey: "photo5"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["photo5"])
            DesktopPhotoWidget {
                anchors.fill: parent
                widgetId: "5"
            }
        }

        // 14. Formula 1 Motorsport Hub
        GridWidgetWrapper {
            id: itemF1
            overlay: desktopWindow
            widgetKey: "f1"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["f1"])
            DesktopF1Widget {
                anchors.fill: parent
            }
        }

        // 15. NBA Scoreboard Hub
        GridWidgetWrapper {
            id: itemNba
            overlay: desktopWindow
            widgetKey: "nba"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["nba"])
            DesktopNbaWidget {
                anchors.fill: parent
            }
        }

        // 16. GitHub Green Wall Hub
        GridWidgetWrapper {
            id: itemGithub
            overlay: desktopWindow
            widgetKey: "github"
            visible: !!(desktopWindow.gridMap && desktopWindow.gridMap["github"])
            DesktopGithubWidget {
                anchors.fill: parent
            }
        }

        // =====================================================================
        // APPLE SONOMA EDIT MODE CONTROLS OVERLAY (z: 1000 - Guaranteed Clickable)
        // =====================================================================
        Item {
            id: editControlsContainer
            anchors.fill: parent
            z: 1000
            visible: opacity > 0.01
            opacity: desktopWindow.showGridGuide ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Floating Bottom Control Bar
            Rectangle {
                id: editModeBar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                height: 42
                width: editBarRow.implicitWidth + 32
                radius: 21
                color: Qt.rgba(0.06, 0.06, 0.10, 0.96)
                border.color: theme.borderGlow
                border.width: 1
                z: 1000
                scale: desktopWindow.showGridGuide ? 1.0 : 0.92

                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Row {
                    id: editBarRow
                    anchors.centerIn: parent
                    spacing: 12

                    // Mode Badge
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle {
                            width: 7; height: 7; radius: 3.5; color: "#0a84ff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "EDIT MODE"
                            color: "#ffffff"
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle { width: 1; height: 16; color: Qt.rgba(255, 255, 255, 0.12); anchors.verticalCenter: parent.verticalCenter }

                    // Add Widget Button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: addTxt.implicitWidth + 24
                        radius: 14
                        color: desktopWindow.showAddGallery ? "#0a84ff" : (addHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08))
                        border.color: desktopWindow.showAddGallery ? "#ffffff" : Qt.rgba(255, 255, 255, 0.22)
                        border.width: 1

                        Row {
                            id: addTxt
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: desktopWindow.showAddGallery ? "󰅖" : "󰐕"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: desktopWindow.showAddGallery ? "#ffffff" : "#0a84ff"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: desktopWindow.showAddGallery ? "Close Gallery" : "Add Widget"
                                color: "#ffffff"
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: addHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: desktopWindow.showAddGallery = !desktopWindow.showAddGallery
                        }
                    }

                    // Reset Layout Button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: resetTxt.implicitWidth + 20
                        radius: 14
                        color: resetHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(255, 255, 255, 0.15)
                        border.width: 1

                        Row {
                            id: resetTxt
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰁨"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: theme.textSub
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Reset"
                                color: theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: resetHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: resetGridProc.running = true
                        }
                    }

                    // Done Button (Apple Blue)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        width: doneTxt.implicitWidth + 24
                        radius: 14
                        color: doneHover.containsMouse ? "#0071e3" : "#0a84ff"

                        Text {
                            id: doneTxt
                            anchors.centerIn: parent
                            text: "Done"
                            color: "#ffffff"
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: doneHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                desktopWindow.showAddGallery = false;
                                if (shell && shell.showGridGuide !== undefined) {
                                    shell.showGridGuide = false;
                                } else {
                                    desktopWindow.showGridGuide = false;
                                }
                            }
                        }
                    }
                }
            }

            // Apple Sonoma Add Widget Gallery Drawer
            Rectangle {
                id: addGallery
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: editModeBar.top
                anchors.bottomMargin: 14
                width: 680
                height: galleryCol.implicitHeight + 28
                radius: 18
                color: Qt.rgba(0.06, 0.06, 0.10, 0.98)
                border.color: theme.borderGlow
                border.width: 1
                z: 1001
                visible: opacity > 0.01
                opacity: (desktopWindow.showGridGuide && desktopWindow.showAddGallery) ? 1.0 : 0.0
                scale: (desktopWindow.showGridGuide && desktopWindow.showAddGallery) ? 1.0 : 0.92

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: (mouse) => mouse.accepted = true
                }

                Column {
                    id: galleryCol
                    anchors.centerIn: parent
                    width: parent.width - 28
                    spacing: 12

                    // Header
                    Item {
                        width: parent.width
                        height: 22

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DESKTOP WIDGET GALLERY • CLICK TO ADD OR REMOVE"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            radius: 11
                            color: closeGalHover.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: closeGalHover.containsMouse ? "#ffffff" : theme.textDim
                            }

                            MouseArea {
                                id: closeGalHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: desktopWindow.showAddGallery = false
                            }
                        }
                    }

                    // Widget Grid Cards
                    Grid {
                        columns: 4
                        spacing: 8
                        width: parent.width

                        Repeater {
                            model: [
                                { "key": "clock",     "name": "Clock",        "icon": "󰥔", "span": "1x1", "c": 1, "r": 1 },
                                { "key": "battery",   "name": "Battery",      "icon": "󱐋", "span": "1x1", "c": 1, "r": 1 },
                                { "key": "calendar",  "name": "Calendar",     "icon": "󰸗", "span": "1x1", "c": 1, "r": 1 },
                                { "key": "weather",   "name": "Weather",      "icon": "󰖐", "span": "1x1", "c": 1, "r": 1 },
                                { "key": "resources", "name": "Resources",    "icon": "󰘚", "span": "1x1", "c": 1, "r": 1 },
                                { "key": "screentime", "name": "Screen Time",  "icon": "󱑎", "span": "1x1", "c": 1, "r": 1 },
                                { "key": "media",     "name": "Now Playing",  "icon": "󰎈", "span": "2x1", "c": 2, "r": 1 },
                                { "key": "reminders", "name": "Reminders",    "icon": "󰄟", "span": "1x1", "c": 1, "r": 1 },
                                { "key": "notes",     "name": "Quick Notes",  "icon": "󰈔", "span": "2x1", "c": 2, "r": 1 },
                                { "key": "f1",        "name": "Formula 1",    "icon": "󰀝", "span": "2x1", "c": 2, "r": 1 },
                                { "key": "nba",       "name": "NBA Hub",      "icon": "󰊪", "span": "2x1", "c": 2, "r": 1 },
                                { "key": "github",    "name": "GitHub Wall",  "icon": "󰊤", "span": "2x1", "c": 2, "r": 1 },
                                { "key": "photo1",    "name": "Photos (1)",   "icon": "󰄀", "span": "2x2", "c": 2, "r": 2 },
                                { "key": "photo2",    "name": "Photos (2)",   "icon": "󰄀", "span": "2x2", "c": 2, "r": 2 },
                                { "key": "photo3",    "name": "Photos (3)",   "icon": "󰄀", "span": "2x2", "c": 2, "r": 2 },
                                { "key": "photo4",    "name": "Photos (4)",   "icon": "󰄀", "span": "2x2", "c": 2, "r": 2 },
                                { "key": "photo5",    "name": "Photos (5)",   "icon": "󰄀", "span": "2x2", "c": 2, "r": 2 }
                            ]

                            delegate: Rectangle {
                                width: (galleryCol.width - 24) / 4
                                height: 64
                                radius: 10
                                readonly property bool isAdded: !!(desktopWindow.gridMap && desktopWindow.gridMap[modelData.key])
                                color: isAdded ? (cardHover.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.18) : Qt.rgba(1, 1, 1, 0.05)) : (cardHover.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28) : Qt.rgba(1, 1, 1, 0.08))
                                border.color: isAdded ? (cardHover.containsMouse ? "#ff453a" : Qt.rgba(255, 255, 255, 0.12)) : (cardHover.containsMouse ? theme.blue : Qt.rgba(255, 255, 255, 0.18))
                                border.width: 1

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 6
                                        Text {
                                            text: modelData.icon
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            color: isAdded ? (cardHover.containsMouse ? "#ff453a" : theme.blueLight) : "#0a84ff"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.name
                                            color: isAdded ? (cardHover.containsMouse ? "#ffffff" : theme.text) : theme.text
                                            font.family: theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: isAdded ? (cardHover.containsMouse ? "󰅖 Remove Widget" : "󰄬 Active on Desktop") : ("󰐕 Add (" + modelData.span + ")")
                                        color: isAdded ? (cardHover.containsMouse ? "#ff453a" : theme.textDim) : theme.blueLight
                                        font.family: theme.fontFamily
                                        font.pixelSize: 9
                                        font.weight: cardHover.containsMouse ? Font.Bold : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: cardHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!isAdded) {
                                            desktopWindow.addWidgetKey(modelData.key, modelData.key, modelData.c, modelData.r);
                                        } else {
                                            let m = Object.assign({}, desktopWindow.gridMap);
                                            delete m[modelData.key];
                                            desktopWindow.gridMap = m;
                                            desktopWindow.savePositions();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
