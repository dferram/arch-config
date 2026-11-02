import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root
    Theme { id: theme }

    required property string widgetId

    implicitWidth: 216
    implicitHeight: 207

    readonly property real radius: 20

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null

    property string albumName: "Photos"
    property string currentPhoto: ""
    property string photoSubfolder: ""
    property string photoFilename: ""
    property int totalPhotos: 0
    property int currentIndex: 0
    property string mode: "folders"
    property var activeFolders: []
    property string folderPath: ""
    property bool isHovered: false
    property bool selectorOpen: false
    property var availableAlbums: []

    // Customization & Usability Options
    property bool recursive: true
    property bool shuffle: true
    property int intervalSecs: 30
    property string fitMode: "crop" // "crop" (PreserveAspectCrop) or "fit" (PreserveAspectFit)
    property string albumSearchText: ""
    property bool multiSelectMode: true

    function getFilteredAlbums() {
        let list = root.availableAlbums || [];
        let q = root.albumSearchText.trim().toLowerCase();
        if (!q) return list;
        return list.filter(a => {
            let n = (a.name || "").toLowerCase();
            let s = (a.shortName || "").toLowerCase();
            return n.indexOf(q) !== -1 || s.indexOf(q) !== -1;
        });
    }

    // Smooth Crossfade State
    property string activePhoto: ""
    property bool useImageA: true

    onSelectorOpenChanged: {
        if (root.selectorOpen) {
            if (!loadAlbumsListProc.running) loadAlbumsListProc.running = true;
            if (!loadAlbumProc.running) loadAlbumProc.running = true;
        }
    }

    function applyWidgetState(d) {
        if (!d || typeof d !== "object") return;
        if (d.album_name !== undefined) root.albumName = d.album_name;
        if (d.current_photo !== undefined) {
            let p = d.current_photo;
            root.currentPhoto = p ? "file://" + p : "";
        }
        if (d.total !== undefined) root.totalPhotos = d.total;
        if (d.current_index !== undefined) root.currentIndex = d.current_index;
        if (d.mode !== undefined) root.mode = d.mode;
        if (d.folders !== undefined) root.activeFolders = d.folders;
        if (d.folder !== undefined) root.folderPath = d.folder;
        if (d.recursive !== undefined) root.recursive = d.recursive;
        if (d.shuffle !== undefined) root.shuffle = d.shuffle;
        if (d.interval !== undefined) root.intervalSecs = d.interval;
        if (d.fit_mode !== undefined) root.fitMode = d.fit_mode;
        if (d.photo_subfolder !== undefined) root.photoSubfolder = d.photo_subfolder;
        if (d.photo_filename !== undefined) root.photoFilename = d.photo_filename;
    }

    onCurrentPhotoChanged: {
        let p = root.currentPhoto;
        if (!p) {
            root.activePhoto = "";
            imgA.source = "";
            imgB.source = "";
            return;
        }
        if (!root.activePhoto) {
            root.activePhoto = p;
            imgA.source = p;
            root.useImageA = true;
            return;
        }
        if (p === root.activePhoto) return;

        root.activePhoto = p;
        if (root.useImageA) {
            imgB.source = p;
            root.useImageA = false;
        } else {
            imgA.source = p;
            root.useImageA = true;
        }
    }

    // Read album state
    Process {
        id: loadAlbumProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-get", root.widgetId]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Read albums list for quick selection
    Process {
        id: loadAlbumsListProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "albums-list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let list = JSON.parse(txt);
                    if (Array.isArray(list)) root.availableAlbums = list;
                } catch(e) {}
            }
        }
    }

    // Dedicated process for choosing album folder
    Process {
        id: pickAlbumProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-pick-album", root.widgetId]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
        onExited: (code, status) => {
            loadAlbumsListProc.running = true;
        }
    }

    // Dedicated process for picking multiple photos
    Process {
        id: pickFilesProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-pick-files", root.widgetId]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for opening Dolphin
    Process {
        id: dolphinProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-open-dolphin", root.widgetId]
    }

    // Dedicated process for next photo
    Process {
        id: nextPhotoProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-next", root.widgetId]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for prev photo
    Process {
        id: prevPhotoProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-prev", root.widgetId]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for setting album folder directly
    Process {
        id: setFolderProc
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for toggling album in multi-selection
    Process {
        id: toggleAlbumProc
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for toggling recursive mode
    Process {
        id: toggleRecursiveProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-toggle-recursive", root.widgetId]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for toggling shuffle mode
    Process {
        id: toggleShuffleProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-toggle-shuffle", root.widgetId]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for fit mode
    Process {
        id: setFitProc
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    // Dedicated process for interval
    Process {
        id: setIntervalProc
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    root.applyWidgetState(d);
                } catch(e) {}
            }
        }
    }

    function openAlbumPicker() {
        if (!pickAlbumProc.running) pickAlbumProc.running = true;
    }

    function openFilesPicker() {
        if (!pickFilesProc.running) pickFilesProc.running = true;
    }

    function openDolphin() {
        if (!dolphinProc.running) dolphinProc.running = true;
    }

    function nextPhoto() {
        if (!nextPhotoProc.running) {
            let cur = (root.currentPhoto || "").replace(/^file:\/\//, "");
            nextPhotoProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-next", root.widgetId, cur];
            nextPhotoProc.running = true;
        }
    }

    function prevPhoto() {
        if (!prevPhotoProc.running) {
            let cur = (root.currentPhoto || "").replace(/^file:\/\//, "");
            prevPhotoProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-prev", root.widgetId, cur];
            prevPhotoProc.running = true;
        }
    }

    function setFolder(fPath) {
        setFolderProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-set-folder", root.widgetId, fPath];
        setFolderProc.running = true;
    }

    function toggleAlbum(fPath) {
        toggleAlbumProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-toggle-album", root.widgetId, fPath];
        toggleAlbumProc.running = true;
    }

    function toggleRecursive() {
        if (!toggleRecursiveProc.running) toggleRecursiveProc.running = true;
    }

    function toggleShuffle() {
        if (!toggleShuffleProc.running) toggleShuffleProc.running = true;
    }

    function setFit(mode) {
        root.fitMode = mode;
        setFitProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-set-fit", root.widgetId, mode];
        setFitProc.running = true;
    }

    function setIntervalSec(sec) {
        root.intervalSecs = sec;
        setIntervalProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-set-interval", root.widgetId, sec.toString()];
        setIntervalProc.running = true;
    }

    function setWidgetSize(cspan, rspan) {
        if (root.wrapper && root.wrapper.applyResize) {
            root.wrapper.applyResize(cspan, rspan);
        }
    }

    // Auto rotate every N seconds with subtle light animation
    Timer {
        id: autoRotateTimer
        interval: Math.max(5000, root.intervalSecs * 1000)
        repeat: true
        running: root.visible && (root.parent ? root.parent.visible : true) && root.totalPhotos > 1 && !root.selectorOpen && root.intervalSecs > 0
        onTriggered: root.nextPhoto()
    }

    // =========================================================================
    // Photo Display with OpacityMask (Exact rounded corners matching all widgets)
    // =========================================================================
    Item {
        id: photoContainer
        anchors.fill: parent

        // Main photo display container with clean rounded corner layer mask
        Item {
            id: photoSourceItem
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: photoSourceItem.width
                    height: photoSourceItem.height
                    radius: root.radius
                }
            }

            // Obsidian translucent base tint
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.06, 0.06, 0.09, 0.85)
            }

            // Main sharp photo display (Crop or Fit according to root.fitMode)
            Image {
                id: imgA
                anchors.fill: parent
                fillMode: root.fitMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
                autoTransform: true
                asynchronous: true
                cache: true
                opacity: (root.useImageA && status === Image.Ready) ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 650; easing.type: Easing.InOutQuad }
                }
            }

            Image {
                id: imgB
                anchors.fill: parent
                fillMode: root.fitMode === "fit" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
                autoTransform: true
                asynchronous: true
                cache: true
                opacity: (!root.useImageA && status === Image.Ready) ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 650; easing.type: Easing.InOutQuad }
                }
            }
        }

        // Apple Liquid Glass Border Overlay
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.color: Qt.rgba(255, 255, 255, 0.10)
            border.width: 1
        }
    }

    // Empty state placeholder
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: root.currentPhoto === "" || (imgA.status === Image.Error && imgB.status === Image.Error)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰄀"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 32
            color: theme.textDim
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Click to choose albums"
            color: theme.textMuted
            font.family: theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    // =========================================================================
    // Unified Mouse Handler: Drag & Drop + Click to Open Selector
    // =========================================================================
    Timer {
        id: singleClickTimer
        interval: 220
        repeat: false
        onTriggered: root.nextPhoto()
    }

    MouseArea {
        id: photoMouseArea
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 2

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (mouse.button !== Qt.LeftButton) return;
            let targetParent = (root.wrapper && root.wrapper.parent) ? root.wrapper.parent : root.parent;
            let pt = mapToItem(targetParent, mouse.x, mouse.y);
            startScreenX = pt.x;
            startScreenY = pt.y;
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!photoMouseArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
                if (isDragging) {
                    isDragging = false;
                    if (root.wrapper) root.wrapper.endDrag();
                }
                return;
            }

            let targetParent = (root.wrapper && root.wrapper.parent) ? root.wrapper.parent : root.parent;
            let pt = mapToItem(targetParent, mouse.x, mouse.y);
            let dx = pt.x - startScreenX;
            let dy = pt.y - startScreenY;

            if (!isDragging && Math.hypot(dx, dy) > 4) {
                isDragging = true;
                if (root.wrapper) {
                    root.wrapper.startDrag(mouse.x, mouse.y);
                }
            }
            if (isDragging && root.wrapper) {
                root.wrapper.updateDrag(dx, dy);
            }
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                singleClickTimer.stop();
                root.selectorOpen = !root.selectorOpen;
            }
        }

        onReleased: (mouse) => {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) {
                    root.wrapper.endDrag();
                }
            } else {
                if (mouse.button === Qt.RightButton) {
                    if (root.wrapper && root.wrapper.toggleMenu) {
                        root.wrapper.toggleMenu();
                    }
                } else if (mouse.button === Qt.LeftButton) {
                    // Single click advances photo without opening menu
                    singleClickTimer.restart();
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

    // =========================================================================
    // Apple Sonoma Quick Switcher & Customizer Sheet (Appears on click)
    // =========================================================================
    Rectangle {
        id: selectorSheet
        anchors.fill: parent
        anchors.margins: 6
        radius: root.radius - 2
        color: Qt.rgba(0.05, 0.05, 0.09, 0.96)
        border.color: theme.borderGlow
        border.width: 1
        z: 10
        visible: opacity > 0.01
        opacity: root.selectorOpen ? 1.0 : 0.0
        scale: root.selectorOpen ? 1.0 : 0.94

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => mouse.accepted = true
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 10
            contentWidth: width
            contentHeight: sheetContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: sheetContent
                width: parent.width
                spacing: 7

                // Header with Album Info, Current Subfolder and Close Button
                Item {
                    width: parent.width
                    height: 22

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        width: parent.width - 26

                        Text {
                            text: "󰄀"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: theme.blueLight != "" ? theme.blueLight : theme.blue
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.albumName + (root.photoSubfolder ? " › " + root.photoSubfolder : "") + (root.totalPhotos > 0 ? " (" + (root.currentIndex + 1) + "/" + root.totalPhotos + ")" : "")
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            width: parent.width - 24
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: closeHover.containsMouse ? theme.surfaceActive : theme.surface

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: theme.textDim
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectorOpen = false
                        }
                    }
                }

                // Widget Size Selector Buttons (Small 1x1, Wide 2x1, Large 2x2)
                Text {
                    text: "WIDGET SIZE"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                }

                Row {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            { "label": "1x1 Small", "c": 1, "r": 1 },
                            { "label": "2x1 Wide",  "c": 2, "r": 1 },
                            { "label": "2x2 Large", "c": 2, "r": 2 }
                        ]
                        delegate: Rectangle {
                            width: (parent.width - 10) / 3
                            height: 24
                            radius: 7
                            readonly property bool isActive: (root.wrapper && Math.round(root.wrapper.colSpan) === modelData.c && Math.round(root.wrapper.rowSpan) === modelData.r)
                            color: isActive ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.40) : (szHover.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08))
                            border.color: isActive ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.borderSubtle
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: isActive ? (theme.blueLight != "" ? theme.blueLight : "#ffffff") : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: isActive ? Font.Bold : Font.Normal
                            }

                            MouseArea {
                                id: szHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setWidgetSize(modelData.c, modelData.r)
                            }
                        }
                    }
                }

                // Personalization & Playback Settings Section
                Text {
                    text: "CUSTOMIZATION & PLAYBACK"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                }

                // Row of 3 primary toggle pills: Subfolders, Shuffle, Fit Mode
                Row {
                    width: parent.width
                    spacing: 5

                    // Subfolders (Recursion Toggle: All nested folders vs Main folder only)
                    Rectangle {
                        width: (parent.width - 10) / 3
                        height: 26
                        radius: 7
                        color: root.recursive ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.35) : (recHover.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08))
                        border.color: root.recursive ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.borderSubtle
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰉋"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: root.recursive ? (theme.blueLight != "" ? theme.blueLight : "#ffffff") : theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.recursive ? "Subfolders: ON" : "Subfolders: OFF"
                                color: root.recursive ? "#ffffff" : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                font.weight: root.recursive ? Font.Bold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: recHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleRecursive()
                        }
                    }

                    // Shuffle / Order Toggle
                    Rectangle {
                        width: (parent.width - 10) / 3
                        height: 26
                        radius: 7
                        color: root.shuffle ? Qt.rgba(0.95, 0.60, 0.10, 0.30) : (shufHover.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08))
                        border.color: root.shuffle ? "#ff9f0a" : theme.borderSubtle
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: root.shuffle ? "󰒟" : "󰑋"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: root.shuffle ? "#ff9f0a" : theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: root.shuffle ? "Shuffle" : "Sequential"
                                color: root.shuffle ? "#ffffff" : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                font.weight: root.shuffle ? Font.Bold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: shufHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleShuffle()
                        }
                    }

                    // Fit vs Crop Mode
                    Rectangle {
                        id: fitBtn
                        width: (parent.width - 10) / 3
                        height: 26
                        radius: 7
                        readonly property bool isFit: root.fitMode === "fit"
                        color: fitBtn.isFit ? Qt.rgba(0.2, 0.8, 0.4, 0.30) : (fitHover.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08))
                        border.color: fitBtn.isFit ? "#30d158" : theme.borderSubtle
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: fitBtn.isFit ? "󰊓" : "󰹑"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: fitBtn.isFit ? "#30d158" : theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: fitBtn.isFit ? "Fit (Whole)" : "Fill (Crop)"
                                color: fitBtn.isFit ? "#ffffff" : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                font.weight: fitBtn.isFit ? Font.Bold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: fitHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setFit(fitBtn.isFit ? "crop" : "fit")
                        }
                    }
                }

                // Rotation Interval Selection
                Row {
                    width: parent.width
                    height: 22
                    spacing: 4

                    Text {
                        text: "ROTATION:"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                        width: 54
                    }

                    Row {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: [
                                { "label": "15s", "sec": 15 },
                                { "label": "30s", "sec": 30 },
                                { "label": "1m",  "sec": 60 },
                                { "label": "5m",  "sec": 300 },
                                { "label": "󰏤 Pause", "sec": 0 }
                            ]
                            delegate: Rectangle {
                                width: Math.max(34, intLabel.implicitWidth + 10)
                                height: 20
                                radius: 5
                                readonly property bool isSelected: root.intervalSecs === modelData.sec
                                color: isSelected ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.40) : (intHover.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08))
                                border.color: isSelected ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.borderSubtle
                                border.width: 1

                                Text {
                                    id: intLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: isSelected ? (theme.blueLight != "" ? theme.blueLight : "#ffffff") : theme.textSub
                                    font.family: theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: isSelected ? Font.Bold : Font.Normal
                                }

                                MouseArea {
                                    id: intHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setIntervalSec(modelData.sec)
                                }
                            }
                        }
                    }
                }

                // Subtitle and Search for Albums and Nested Folders
                Item {
                    width: parent.width
                    height: 18

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ALBUMS & SUBFOLDERS"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.getFilteredAlbums().length + " available"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                    }
                }

                // Sleek Search Filter Input Box
                Rectangle {
                    width: parent.width
                    height: 26
                    radius: 7
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: filterInput.activeFocus ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.borderSubtle
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: theme.textDim
                        }

                        TextInput {
                            id: filterInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            selectByMouse: true
                            onTextChanged: root.albumSearchText = text

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Search albums or subfolders..."
                                color: theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                visible: !filterInput.text && !filterInput.activeFocus
                            }
                        }

                        // Clear search text button
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            radius: 8
                            color: clrHover.containsMouse ? theme.surfaceActive : "transparent"
                            visible: filterInput.text.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: theme.textDim
                            }

                            MouseArea {
                                id: clrHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    filterInput.text = "";
                                    root.albumSearchText = "";
                                }
                            }
                        }
                    }
                }

                // Multi-Album Control Toolbar
                RowLayout {
                    width: parent.width
                    spacing: 8

                    // Multi-Select toggle pill
                    Rectangle {
                        implicitHeight: 22
                        implicitWidth: multiSelectRow.implicitWidth + 14
                        radius: 11
                        color: root.multiSelectMode ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: root.multiSelectMode ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.borderSubtle
                        border.width: 1

                        Row {
                            id: multiSelectRow
                            anchors.centerIn: parent
                            spacing: 5
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: root.multiSelectMode ? "#30d158" : theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Multi-Select"
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: root.multiSelectMode ? "#ffffff" : theme.textDim
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.multiSelectMode = !root.multiSelectMode
                        }
                    }

                    // Quick "All Photos" button
                    Rectangle {
                        implicitHeight: 22
                        implicitWidth: allPhotosText.implicitWidth + 14
                        radius: 11
                        color: (root.activeFolders.length === 1 && root.activeFolders[0].indexOf("Pictures") !== -1 && root.activeFolders[0].split("/").pop() === "Pictures") ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: theme.borderSubtle
                        border.width: 1

                        Text {
                            id: allPhotosText
                            anchors.centerIn: parent
                            text: "All Photos"
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: theme.text
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setFolder(Quickshell.env("HOME") + "/Pictures")
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.activeFolders.length + " selected"
                        color: theme.blueLight != "" ? theme.blueLight : theme.blue
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    text: root.multiSelectMode ? "Click any album to toggle it into your pool • Double-click for solo" : "Click an album to display only that album"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Normal
                }

                Flow {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: root.getFilteredAlbums()
                        delegate: Rectangle {
                            readonly property bool isSelected: root.activeFolders.indexOf(modelData.path) !== -1
                            readonly property bool isSubfolder: modelData.depth > 1

                            height: 24
                            width: Math.min(chipRow.implicitWidth + 14, parent.width)
                            radius: 12
                            color: isSelected ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.35) : (chipHover.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08))
                            border.color: isSelected ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.borderSubtle
                            border.width: 1

                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: isSelected ? "✓" : (isSubfolder ? "↳" : "○")
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    color: isSelected ? (theme.blueLight != "" ? theme.blueLight : "#ffffff") : (isSubfolder ? theme.blue : theme.textDim)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.name
                                    color: isSelected ? (theme.blueLight != "" ? theme.blueLight : "#ffffff") : theme.text
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: isSelected ? Font.Bold : Font.Normal
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideMiddle
                                    width: Math.min(implicitWidth, root.width - 50)
                                }

                                Text {
                                    text: "(" + (root.recursive ? modelData.totalCount : modelData.count) + ")"
                                    color: isSelected ? Qt.rgba(1, 1, 1, 0.75) : theme.textDim
                                    font.family: theme.fontFamily
                                    font.pixelSize: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: chipHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (root.multiSelectMode || (mouse.modifiers & Qt.ControlModifier)) {
                                        root.toggleAlbum(modelData.path);
                                    } else {
                                        root.setFolder(modelData.path);
                                    }
                                }
                                onDoubleClicked: {
                                    root.setFolder(modelData.path);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
