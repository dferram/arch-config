import QtQuick
import "../theme"

Item {
    id: wrapper

    Theme { id: theme }

    required property var overlay
    required property string widgetKey
    default property alias content: innerContainer.children

    readonly property bool isLive: wrapper.visible && !!(overlay && overlay.shouldBeVisible)

    readonly property var pos: (overlay && overlay.gridMap && overlay.gridMap[widgetKey]) ? overlay.gridMap[widgetKey] : { "col": 0, "row": 0, "colSpan": 1, "rowSpan": 1 }
    property int targetCol: (pos && pos.col !== undefined) ? pos.col : 0
    property int targetRow: (pos && pos.row !== undefined) ? pos.row : 0
    property int colSpan: (pos && pos.colSpan !== undefined) ? pos.colSpan : 1
    property int rowSpan: (pos && pos.rowSpan !== undefined) ? pos.rowSpan : 1
    property int widgetWorkspace: (pos && pos.workspace !== undefined) ? pos.workspace : 1

    readonly property bool isMounted: !!(overlay && overlay.gridMap && overlay.gridMap[widgetKey])
    readonly property bool isCurrentWorkspace: (widgetWorkspace === (overlay ? overlay.currentWorkspaceId : 1))
    readonly property bool shouldBeActive: isMounted && isCurrentWorkspace

    visible: isMounted && (opacity > 0.001)

    function moveToWorkspace(targetWs) {
        if (!overlay) return;
        let ws = parseInt(targetWs);
        if (isNaN(ws) || ws < 1) return;
        let m = Object.assign({}, overlay.gridMap);
        let best = overlay.findBestFitSlot ? overlay.findBestFitSlot(wrapper.widgetKey, targetCol, targetRow, colSpan, rowSpan, ws) : { "col": targetCol, "row": targetRow, "valid": true };
        m[wrapper.widgetKey] = {
            "col": best.col,
            "row": best.row,
            "colSpan": wrapper.colSpan,
            "rowSpan": wrapper.rowSpan,
            "type": wrapper.widgetKey,
            "workspace": ws
        };
        overlay.gridMap = m;
        wrapper.targetCol = best.col;
        wrapper.targetRow = best.row;
        overlay.savePositions();
        wrapper.menuOpen = false;
    }

    onPosChanged: {
        if (!pos) return;
        if (pos.col !== undefined) targetCol = pos.col;
        if (pos.row !== undefined) targetRow = pos.row;
        if (pos.colSpan !== undefined && !resizing) colSpan = pos.colSpan;
        if (pos.rowSpan !== undefined && !resizing) rowSpan = pos.rowSpan;
    }

    // Dynamic Sizing State
    property bool resizing: false
    property int previewColSpan: colSpan
    property int previewRowSpan: rowSpan

    readonly property real currentSpanW: resizing ? previewColSpan : colSpan
    readonly property real currentSpanH: resizing ? previewRowSpan : rowSpan

    readonly property real gridX: overlay ? (overlay.gridStartX + targetCol * (overlay.cellWidth + overlay.gridGap)) : 0
    readonly property real gridY: overlay ? (overlay.gridStartY + targetRow * (overlay.cellHeight + overlay.gridGap)) : 0
    readonly property real widgetW: overlay ? (currentSpanW * overlay.cellWidth + (currentSpanW - 1) * overlay.gridGap) : 216
    readonly property real widgetH: overlay ? (currentSpanH * overlay.cellHeight + (currentSpanH - 1) * overlay.gridGap) : 207

    width: widgetW
    height: widgetH

    // Smooth resize animations
    Behavior on width {
        enabled: !wrapper.resizing && (!overlay || overlay.gridLoaded)
        NumberAnimation { duration: 240; easing.type: Easing.OutBack }
    }
    Behavior on height {
        enabled: !wrapper.resizing && (!overlay || overlay.gridLoaded)
        NumberAnimation { duration: 240; easing.type: Easing.OutBack }
    }

    // Declarative Binding with drag offset (PRESERVES BINDING FOREVER - NEVER BREAKS!)
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    x: gridX + dragOffsetX
    y: gridY + dragOffsetY

    property bool dragging: false
    property real pressMouseX: 0
    property real pressMouseY: 0

    // Smooth snap animation when not dragging
    Behavior on x {
        enabled: !wrapper.dragging && (!overlay || overlay.gridLoaded)
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !wrapper.dragging && (!overlay || overlay.gridLoaded)
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // Elevation, scale and subtle opacity feedback when dragging
    scale: dragging ? 1.04 : 1.0
    opacity: dragging ? 0.90 : (shouldBeActive ? 1.0 : 0.0)
    z: (dragging || resizing || menuOpen) ? 200 : 1

    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // Hover handler for mouse detection across child items
    HoverHandler {
        id: wrapperHover
    }

    // Sizing API with collision check
    function applyResize(newCols, newRows) {
        let maxCols = overlay ? overlay.gridCols : 6;
        let maxRows = overlay ? overlay.gridRows : 4;
        let c = Math.max(1, Math.min(maxCols - targetCol, newCols));
        let r = Math.max(1, Math.min(maxRows - targetRow, newRows));

        // Prevent expanding over another widget
        if (overlay && overlay.isSlotAvailable) {
            while (c > 1 && !overlay.isSlotAvailable(wrapper.widgetKey, targetCol, targetRow, c, r, wrapper.widgetWorkspace)) {
                c--;
            }
            while (r > 1 && !overlay.isSlotAvailable(wrapper.widgetKey, targetCol, targetRow, c, r, wrapper.widgetWorkspace)) {
                r--;
            }
            if (!overlay.isSlotAvailable(wrapper.widgetKey, targetCol, targetRow, c, r, wrapper.widgetWorkspace)) {
                c = wrapper.colSpan;
                r = wrapper.rowSpan;
            }
        }

        wrapper.colSpan = c;
        wrapper.rowSpan = r;
        wrapper.previewColSpan = c;
        wrapper.previewRowSpan = r;

        if (overlay) {
            let m = Object.assign({}, overlay.gridMap);
            if (!m[wrapper.widgetKey]) {
                m[wrapper.widgetKey] = { "type": wrapper.widgetKey };
            }
            m[wrapper.widgetKey].col = targetCol;
            m[wrapper.widgetKey].row = targetRow;
            m[wrapper.widgetKey].colSpan = c;
            m[wrapper.widgetKey].rowSpan = r;
            m[wrapper.widgetKey].type = wrapper.widgetKey;
            m[wrapper.widgetKey].workspace = wrapper.widgetWorkspace;
            overlay.gridMap = m;
            overlay.savePositions();
        }
    }

    // Public drag API for widgets
    function startDrag(mouseX, mouseY) {
        if (wrapper.menuOpen) wrapper.menuOpen = false;
        wrapper.dragging = true;
        wrapper.pressMouseX = mouseX;
        wrapper.pressMouseY = mouseY;
        wrapper.dragOffsetX = 0;
        wrapper.dragOffsetY = 0;
        if (overlay) {
            overlay.isDraggingAny = true;
            overlay.snapValid = true;
            overlay.snapWidth = wrapper.width;
            overlay.snapHeight = wrapper.height;
            overlay.snapCol = wrapper.targetCol;
            overlay.snapRow = wrapper.targetRow;
        }
    }

    function updateDrag(totalDeltaX, totalDeltaY) {
        if (!wrapper.dragging || !overlay) return;
        wrapper.dragOffsetX = totalDeltaX;
        wrapper.dragOffsetY = totalDeltaY;

        // Calculate nearest snap cell
        let currentAbsX = wrapper.gridX + totalDeltaX;
        let currentAbsY = wrapper.gridY + totalDeltaY;
        let c = Math.round((currentAbsX - overlay.gridStartX) / (overlay.cellWidth + overlay.gridGap));
        let r = Math.round((currentAbsY - overlay.gridStartY) / (overlay.cellHeight + overlay.gridGap));
        c = Math.max(0, Math.min(overlay.gridCols - Math.ceil(wrapper.colSpan), c));
        r = Math.max(0, Math.min(overlay.gridRows - Math.ceil(wrapper.rowSpan), r));

        // Smart Snap: check collisions and find nearest free slot
        if (overlay.findBestFitSlot) {
            let res = overlay.findBestFitSlot(wrapper.widgetKey, c, r, wrapper.colSpan, wrapper.rowSpan, wrapper.widgetWorkspace);
            overlay.snapCol = res.col;
            overlay.snapRow = res.row;
            overlay.snapValid = res.valid;
        } else {
            overlay.snapCol = c;
            overlay.snapRow = r;
            overlay.snapValid = true;
        }
    }

    function endDrag() {
        if (!wrapper.dragging) return;
        wrapper.dragging = false;

        // Strictly prevent overlapping: only move if valid and non-colliding
        let isValid = overlay && (overlay.snapValid !== false) && overlay.snapCol >= 0 && overlay.snapRow >= 0;
        let c = isValid ? overlay.snapCol : wrapper.targetCol;
        let r = isValid ? overlay.snapRow : wrapper.targetRow;

        wrapper.dragOffsetX = 0;
        wrapper.dragOffsetY = 0;

        if (overlay) {
            overlay.isDraggingAny = false;
            let m = Object.assign({}, overlay.gridMap);
            m[wrapper.widgetKey] = {
                "col": c,
                "row": r,
                "colSpan": wrapper.colSpan,
                "rowSpan": wrapper.rowSpan,
                "type": wrapper.widgetKey,
                "workspace": wrapper.widgetWorkspace
            };
            overlay.gridMap = m;
            wrapper.targetCol = c;
            wrapper.targetRow = r;
            overlay.savePositions();
        }
    }

    // Base MouseArea for widgets without interactive sub-elements (Clock, Battery, Calendar, Reminders)
    MouseArea {
        id: baseDragArea
        anchors.fill: parent
        z: 0
        hoverEnabled: true
        cursorShape: wrapper.dragging ? Qt.ClosedHandCursor : (containsMouse ? Qt.OpenHandCursor : Qt.ArrowCursor)
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                wrapper.menuOpen = !wrapper.menuOpen;
                return;
            }
            if (mouse.button !== Qt.LeftButton) return;
            if (wrapper.menuOpen) wrapper.menuOpen = false;

            let canvasPt = mapToItem(wrapper.parent, mouse.x, mouse.y);
            startScreenX = canvasPt.x;
            startScreenY = canvasPt.y;
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!baseDragArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                if (isDragging) {
                    isDragging = false;
                    wrapper.endDrag();
                }
                return;
            }
            let canvasPt = mapToItem(wrapper.parent, mouse.x, mouse.y);
            let dx = canvasPt.x - startScreenX;
            let dy = canvasPt.y - startScreenY;

            if (!isDragging && Math.hypot(dx, dy) > 4) {
                isDragging = true;
                wrapper.startDrag(mouse.x, mouse.y);
            }
            if (isDragging) {
                wrapper.updateDrag(dx, dy);
            }
        }

        onReleased: {
            if (isDragging) {
                isDragging = false;
                wrapper.endDrag();
            }
        }

        onCanceled: {
            if (isDragging) {
                isDragging = false;
                wrapper.endDrag();
            }
        }
    }

    // Container for the actual widget
    Item {
        id: innerContainer
        anchors.fill: parent
        z: 1
        readonly property bool isLive: wrapper.isLive
        readonly property var wrapperRef: wrapper
        function startDrag(mx, my) { wrapper.startDrag(mx, my); }
        function updateDrag(dx, dy) { wrapper.updateDrag(dx, dy); }
        function endDrag() { wrapper.endDrag(); }
    }

    // Active Dragging Glow & Border (Sonoma style subtle accent halo)
    Rectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"
        border.color: (wrapper.dragging || wrapper.resizing) ? (theme.blueLight != "" ? theme.blueLight : "#0a84ff") : (overlay && overlay.showGridGuide ? Qt.rgba(0.2, 0.6, 1.0, 0.35) : "transparent")
        border.width: (wrapper.dragging || wrapper.resizing) ? 2 : 1
        z: 50
        visible: wrapper.dragging || wrapper.resizing || (overlay && overlay.showGridGuide)
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // =========================================================================
    // Android / Apple Interactive Bottom-Right Corner Resize Handle
    // =========================================================================
    Item {
        id: resizeHandleContainer
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 36
        height: 36
        z: 60

        // Handle is ONLY visible and active when grid edit mode is on
        visible: !!(overlay && overlay.showGridGuide)
        enabled: !!(overlay && overlay.showGridGuide)
        opacity: (overlay && overlay.showGridGuide) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // Apple Sonoma Glass Handle Pill
        Rectangle {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 7
            width: 22
            height: 22
            radius: 8
            color: resizeMouseArea.containsMouse ? (theme.blueLight != "" ? theme.blueLight : "#0a84ff") : Qt.rgba(0.08, 0.08, 0.14, 0.85)
            border.color: resizeMouseArea.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.30)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "󰧈"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#ffffff"
            }
        }

        MouseArea {
            id: resizeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            acceptedButtons: Qt.LeftButton

            property real startMouseX: 0
            property real startMouseY: 0
            property real origWidth: 0
            property real origHeight: 0

            onPressed: (mouse) => {
                if (mouse.button !== Qt.LeftButton) return;
                wrapper.resizing = true;
                startMouseX = mouse.x;
                startMouseY = mouse.y;
                origWidth = wrapper.width;
                origHeight = wrapper.height;
                wrapper.previewColSpan = wrapper.colSpan;
                wrapper.previewRowSpan = wrapper.rowSpan;
                if (overlay) {
                    overlay.isDraggingAny = true;
                    overlay.snapCol = wrapper.targetCol;
                    overlay.snapRow = wrapper.targetRow;
                    overlay.snapWidth = wrapper.width;
                    overlay.snapHeight = wrapper.height;
                    overlay.snapValid = true;
                }
            }

            onPositionChanged: (mouse) => {
                if (!wrapper.resizing || !overlay) return;
                let currentTotalW = origWidth + (mouse.x - startMouseX);
                let currentTotalH = origHeight + (mouse.y - startMouseY);

                let stepW = overlay.cellWidth + overlay.gridGap;
                let stepH = overlay.cellHeight + overlay.gridGap;

                let cols = Math.round((currentTotalW + overlay.gridGap / 2) / stepW);
                let rows = Math.round((currentTotalH + overlay.gridGap / 2) / stepH);

                cols = Math.max(1, Math.min(overlay.gridCols - wrapper.targetCol, cols));
                rows = Math.max(1, Math.min(overlay.gridRows - wrapper.targetRow, rows));

                // Only perform layout updates when column or row span actually changes (smooth performance)
                if (cols !== wrapper.previewColSpan || rows !== wrapper.previewRowSpan) {
                    wrapper.previewColSpan = cols;
                    wrapper.previewRowSpan = rows;

                    overlay.snapCol = wrapper.targetCol;
                    overlay.snapRow = wrapper.targetRow;
                    overlay.snapValid = overlay.isSlotAvailable ? overlay.isSlotAvailable(wrapper.widgetKey, wrapper.targetCol, wrapper.targetRow, cols, rows, wrapper.widgetWorkspace) : true;
                    overlay.snapWidth = cols * overlay.cellWidth + (cols - 1) * overlay.gridGap;
                    overlay.snapHeight = rows * overlay.cellHeight + (rows - 1) * overlay.gridGap;
                }
            }

            onReleased: {
                if (!wrapper.resizing) return;
                wrapper.resizing = false;
                if (overlay) overlay.isDraggingAny = false;
                wrapper.applyResize(wrapper.previewColSpan, wrapper.previewRowSpan);
            }

            onCanceled: {
                if (!wrapper.resizing) return;
                wrapper.resizing = false;
                if (overlay) overlay.isDraggingAny = false;
            }
        }
    }

    // =========================================================================
    // Apple Sonoma Delete Badge (Visible ONLY when in Edit Mode)
    // =========================================================================
    Rectangle {
        id: deleteBadge
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: -7
        width: 22
        height: 22
        radius: 11
        color: delHover.containsMouse ? "#d70015" : "#ff453a"
        border.color: "#ffffff"
        border.width: 1.5
        z: 75
        visible: opacity > 0.01
        opacity: (overlay && overlay.showGridGuide) ? 1.0 : 0.0
        scale: (overlay && overlay.showGridGuide) ? 1.0 : 0.5

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: "#ffffff"
        }

        MouseArea {
            id: delHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (overlay) {
                    let m = Object.assign({}, overlay.gridMap);
                    delete m[wrapper.widgetKey];
                    overlay.gridMap = m;
                    overlay.savePositions();
                }
            }
        }
    }

    // =========================================================================
    // macOS Sonoma Liquid Glass Right-Click Context Menu
    // =========================================================================
    property bool menuOpen: false

    function toggleMenu() {
        wrapper.menuOpen = !wrapper.menuOpen;
    }
    function closeMenu() {
        wrapper.menuOpen = false;
    }

    Rectangle {
        id: contextMenu
        z: 80
        anchors.centerIn: parent
        width: 180
        height: menuCol.implicitHeight + 20
        radius: 14
        color: Qt.rgba(0.06, 0.06, 0.10, 0.96)
        border.color: theme.borderGlow
        border.width: 1
        visible: opacity > 0.01
        opacity: wrapper.menuOpen ? 1.0 : 0.0
        scale: wrapper.menuOpen ? 1.0 : 0.90

        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => mouse.accepted = true
        }

        Column {
            id: menuCol
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 5

            // Header: Widget Title
            Row {
                width: parent.width
                spacing: 6
                Item { width: 2; height: 1 }
                Text {
                    text: wrapper.widgetKey.toUpperCase() + " SIZE"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                }
            }

            // Size Options: 1x1, 2x1, 2x2, 3x2
            Repeater {
                model: [
                    { "label": "1 × 1  Small", "c": 1, "r": 1 },
                    { "label": "2 × 1  Wide",  "c": 2, "r": 1 },
                    { "label": "2 × 2  Large", "c": 2, "r": 2 },
                    { "label": "3 × 2  X-Large", "c": 3, "r": 2 }
                ]
                delegate: Rectangle {
                    width: parent.width
                    height: 26
                    radius: 7
                    readonly property bool isActive: wrapper.colSpan === modelData.c && wrapper.rowSpan === modelData.r
                    color: optHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : (isActive ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25) : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: isActive ? "󰄵" : "󰩨"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: isActive ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.textDim
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: isActive ? "#ffffff" : theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: isActive ? Font.Bold : Font.Normal
                        }
                    }

                    MouseArea {
                        id: optHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wrapper.menuOpen = false;
                            wrapper.applyResize(modelData.c, modelData.r);
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            // Header: Workspace Selection
            Row {
                width: parent.width
                spacing: 6
                Item { width: 2; height: 1 }
                Text {
                    text: "WORKSPACE"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                }
            }

            // Workspace buttons row (1, 2, 3, 4, 5)
            Row {
                width: parent.width
                spacing: 4

                Repeater {
                    model: [1, 2, 3, 4, 5]
                    delegate: Rectangle {
                        width: Math.floor((menuCol.width - 16) / 5)
                        height: 26
                        radius: 6
                        readonly property bool isCurrentWs: wrapper.widgetWorkspace === modelData
                        color: wsHover.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : (isCurrentWs ? (theme.blueLight != "" ? theme.blueLight : "#0a84ff") : Qt.rgba(1, 1, 1, 0.06))
                        border.color: isCurrentWs ? "#ffffff" : Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.toString()
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: isCurrentWs ? Font.Bold : Font.Normal
                            color: isCurrentWs ? "#ffffff" : theme.text
                        }

                        MouseArea {
                            id: wsHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wrapper.moveToWorkspace(modelData);
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            // Close button
            Rectangle {
                width: parent.width
                height: 24
                radius: 6
                color: closeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: theme.textDim
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Close"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wrapper.menuOpen = false
                }
            }
        }
    }
}
