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
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true
    property bool shuffle: true
    property int intervalSecs: 30
    property int lastActiveInterval: 30
    property string fitMode: "crop" // "crop" (PreserveAspectCrop) or "fit" (PreserveAspectFit)
    property string albumSearchText: ""
    property bool multiSelectMode: true
    property int activeTab: 0 // 0 = Albums, 1 = Playback
    readonly property bool isPaused: intervalSecs <= 0

    function currentPhotoRaw() {
        return (root.currentPhoto || "").replace(/^file:\/\//, "");
    }

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
            singleClickTimer.stop();
            if (!loadAlbumsListProc.running) loadAlbumsListProc.running = true;
            // Preserve current photo if already loaded instead of randomizing a new one
            if (root.currentPhotoRaw() === "" && !loadAlbumProc.running) {
                loadAlbumProc.running = true;
            }
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
        if (d.interval !== undefined) {
            root.intervalSecs = d.interval;
            if (d.interval > 0) root.lastActiveInterval = d.interval;
        }
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
        if (!toggleRecursiveProc.running) {
            toggleRecursiveProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-toggle-recursive", root.widgetId, root.currentPhotoRaw()];
            toggleRecursiveProc.running = true;
        }
    }

    function toggleShuffle() {
        if (!toggleShuffleProc.running) {
            toggleShuffleProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-toggle-shuffle", root.widgetId, root.currentPhotoRaw()];
            toggleShuffleProc.running = true;
        }
    }

    function setFit(mode) {
        root.fitMode = mode;
        setFitProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-set-fit", root.widgetId, mode, root.currentPhotoRaw()];
        setFitProc.running = true;
    }

    function setIntervalSec(sec) {
        if (sec > 0) root.lastActiveInterval = sec;
        root.intervalSecs = sec;
        setIntervalProc.command = ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "photos-set-interval", root.widgetId, sec.toString(), root.currentPhotoRaw()];
        setIntervalProc.running = true;
    }

    function togglePause() {
        if (root.isPaused) {
            root.setIntervalSec(root.lastActiveInterval > 0 ? root.lastActiveInterval : 30);
        } else {
            root.setIntervalSec(0);
        }
    }

    function setWidgetSize(cspan, rspan) {
        if (root.wrapper && root.wrapper.applyResize) {
            root.wrapper.applyResize(cspan, rspan);
        }
    }

    // Auto rotate every N seconds with subtle light animation (only when live and mounted)
    Timer {
        id: autoRotateTimer
        interval: Math.max(5000, root.intervalSecs * 1000)
        repeat: true
        running: root.isLive && root.totalPhotos > 1 && !root.selectorOpen && root.intervalSecs > 0
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
                sourceSize.width: 900
                sourceSize.height: 900
                autoTransform: true
                asynchronous: true
                cache: false
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
                sourceSize.width: 900
                sourceSize.height: 900
                autoTransform: true
                asynchronous: true
                cache: false
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
    // Unified Mouse Handler: Drag & Drop + Double-Click to Open Selector
    // =========================================================================
    Timer {
        id: singleClickTimer
        interval: 230
        repeat: false
        onTriggered: {
            if (!root.selectorOpen) root.nextPhoto();
        }
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
                    // Single click advances photo when not paused/opening menu
                    if (!root.selectorOpen) singleClickTimer.restart();
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
    // Apple Sonoma Quick Switcher & Customizer Sheet
    // =========================================================================
    Rectangle {
        id: selectorSheet
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(0.045, 0.048, 0.075, 0.92)
        border.color: Qt.rgba(255, 255, 255, 0.14)
        border.width: 1
        z: 10
        clip: true
        visible: opacity > 0.01
        opacity: root.selectorOpen ? 1.0 : 0.0
        scale: root.selectorOpen ? 1.0 : 0.96

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Specular top hairline highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(255, 255, 255, 0.16)
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 9

            // 1. Clean Header: Album Title + Quick Pause Pill + Close Button
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 8
                    color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.20)
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰄀"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: theme.blueLight != "" ? theme.blueLight : theme.blue
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: root.albumName + (root.photoSubfolder ? " • " + root.photoSubfolder : "")
                        color: "#ffffff"
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.totalPhotos > 0
                            ? ("Photo " + (root.currentIndex + 1) + " of " + root.totalPhotos + (root.isPaused ? " • Paused" : ""))
                            : "No photos selected"
                        color: root.isPaused ? "#ff9f0a" : theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }

                // Quick Pause / Play Toggle Pill right in header (never changes current photo!)
                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: hdrPauseRow.implicitWidth + 14
                    radius: 12
                    color: root.isPaused ? Qt.rgba(255, 159, 10, 0.24) : (hdrPauseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    border.color: root.isPaused ? "#ff9f0a" : Qt.rgba(255, 255, 255, 0.14)
                    border.width: 1

                    Row {
                        id: hdrPauseRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: root.isPaused ? "󰐊" : "󰏤"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: root.isPaused ? "#ff9f0a" : theme.textSub
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.isPaused ? "Resume" : "Pause"
                            color: root.isPaused ? "#ffffff" : theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: hdrPauseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePause()
                    }
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: closeHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(255, 255, 255, 0.10)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: closeHover.containsMouse ? "#ffffff" : theme.textDim
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

            // 2. Apple Sonoma Segmented Tab Control (Albums | Playback)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(255, 255, 255, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    Repeater {
                        model: [
                            { "idx": 0, "label": "Albums", "icon": "󰉋" },
                            { "idx": 1, "label": "Playback & Size", "icon": "󰒓" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isAct: root.activeTab === modelData.idx
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 6
                            color: isAct ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.34) : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: isAct ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.60) : "transparent"
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: modelData.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: isAct ? "#ffffff" : theme.textDim
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.label
                                    color: isAct ? "#ffffff" : theme.textSub
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: isAct ? Font.Bold : Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = modelData.idx
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 0: ALBUMS & SUBFOLDERS (Spacious, searchable pool)
            // =================================================================
            ColumnLayout {
                visible: root.activeTab === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // Search Bar + Quick Actions Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: filterInput.activeFocus ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 7
                            spacing: 6

                            Text {
                                text: "󰍉"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: theme.textDim
                            }

                            TextInput {
                                id: filterInput
                                Layout.fillWidth: true
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                selectByMouse: true
                                clip: true
                                onTextChanged: root.albumSearchText = text

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Search " + root.availableAlbums.length + " albums..."
                                    color: theme.textDim
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    visible: !filterInput.text && !filterInput.activeFocus
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
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

                    // Open current photo in Dolphin
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 8
                        color: dolphMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰝰"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: theme.textSub
                        }

                        MouseArea {
                            id: dolphMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openDolphin()
                        }
                    }
                }

                // Multi-Select & All Photos Toolbar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        implicitHeight: 22
                        implicitWidth: multiSelectRow.implicitWidth + 14
                        radius: 11
                        color: root.multiSelectMode ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: root.multiSelectMode ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : Qt.rgba(255, 255, 255, 0.10)
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

                    Rectangle {
                        id: allPhotosBtn
                        implicitHeight: 22
                        implicitWidth: allPhotosText.implicitWidth + 14
                        radius: 11
                        readonly property bool isAllPhotos: root.activeFolders.length === 1 && root.activeFolders[0].split("/").pop() === "Pictures"
                        color: allPhotosBtn.isAllPhotos ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: allPhotosBtn.isAllPhotos ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1

                        Text {
                            id: allPhotosText
                            anchors.centerIn: parent
                            text: "All Photos"
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: allPhotosBtn.isAllPhotos ? "#ffffff" : theme.textSub
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

                // Spacious Scrollable Album Chips Pool
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: albumFlow.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Flow {
                        id: albumFlow
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: root.getFilteredAlbums()
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelected: root.activeFolders.indexOf(modelData.path) !== -1
                                readonly property bool isSubfolder: modelData.depth > 1

                                height: 26
                                width: Math.min(chipRow.implicitWidth + 16, albumFlow.width)
                                radius: 13
                                color: isSelected
                                    ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.34)
                                    : (chipHover.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06))
                                border.color: isSelected
                                    ? (theme.blueLight != "" ? theme.blueLight : theme.blue)
                                    : (chipHover.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.09))
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: isSelected ? "#30d158" : (isSubfolder ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.7) : Qt.rgba(1, 1, 1, 0.25))
                                    }

                                    Text {
                                        text: modelData.name
                                        color: isSelected ? "#ffffff" : theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: isSelected ? Font.Bold : Font.Normal
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideMiddle
                                        width: Math.min(implicitWidth, albumFlow.width - 60)
                                    }

                                    Text {
                                        text: String(root.recursive ? modelData.totalCount : modelData.count)
                                        color: isSelected ? Qt.rgba(1, 1, 1, 0.80) : theme.textDim
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
                                    onDoubleClicked: root.setFolder(modelData.path)
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 1: PLAYBACK & SIZE SETTINGS
            // =================================================================
            Flickable {
                visible: root.activeTab === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: playbackCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: playbackCol
                    width: parent.width
                    spacing: 10

                    // Widget Size
                    Column {
                        width: parent.width
                        spacing: 5
                        Text {
                            text: "WIDGET SIZE"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: [
                                    { "label": "1×1 Small", "c": 1, "r": 1 },
                                    { "label": "2×1 Wide",  "c": 2, "r": 1 },
                                    { "label": "2×2 Large", "c": 2, "r": 2 }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: (parent.width - 12) / 3
                                    height: 28
                                    radius: 8
                                    readonly property bool isActive: (root.wrapper && Math.round(root.wrapper.colSpan) === modelData.c && Math.round(root.wrapper.rowSpan) === modelData.r)
                                    color: isActive ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.36) : (szHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                                    border.color: isActive ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : Qt.rgba(255, 255, 255, 0.10)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: isActive ? "#ffffff" : theme.textSub
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
                    }

                    // Playback Options
                    Column {
                        width: parent.width
                        spacing: 5
                        Text {
                            text: "DISPLAY & ORDER"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                        Row {
                            width: parent.width
                            spacing: 6

                            Rectangle {
                                width: (parent.width - 12) / 3
                                height: 28
                                radius: 8
                                color: root.recursive ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.32) : (recHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                                border.color: root.recursive ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : Qt.rgba(255, 255, 255, 0.10)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "󰉋"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: root.recursive ? "#ffffff" : theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.recursive ? "Subfolders" : "Top Only"; color: root.recursive ? "#ffffff" : theme.textSub; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: root.recursive ? Font.Bold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: recHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleRecursive() }
                            }

                            Rectangle {
                                width: (parent.width - 12) / 3
                                height: 28
                                radius: 8
                                color: root.shuffle ? Qt.rgba(0.95, 0.60, 0.10, 0.28) : (shufHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                                border.color: root.shuffle ? "#ff9f0a" : Qt.rgba(255, 255, 255, 0.10)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: root.shuffle ? "󰒟" : "󰑋"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: root.shuffle ? "#ff9f0a" : theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: root.shuffle ? "Shuffle" : "In Order"; color: root.shuffle ? "#ffffff" : theme.textSub; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: root.shuffle ? Font.Bold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: shufHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleShuffle() }
                            }

                            Rectangle {
                                id: fitBtn
                                width: (parent.width - 12) / 3
                                height: 28
                                radius: 8
                                readonly property bool isFit: root.fitMode === "fit"
                                color: fitBtn.isFit ? Qt.rgba(0.2, 0.8, 0.4, 0.28) : (fitHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                                border.color: fitBtn.isFit ? "#30d158" : Qt.rgba(255, 255, 255, 0.10)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: fitBtn.isFit ? "󰊓" : "󰹑"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: fitBtn.isFit ? "#30d158" : theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: fitBtn.isFit ? "Fit" : "Crop"; color: fitBtn.isFit ? "#ffffff" : theme.textSub; font.family: theme.fontFamily; font.pixelSize: 9; font.weight: fitBtn.isFit ? Font.Bold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: fitHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setFit(fitBtn.isFit ? "crop" : "fit") }
                            }
                        }
                    }

                    // Rotation Interval
                    Column {
                        width: parent.width
                        spacing: 5
                        Text {
                            text: "ROTATION"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: [
                                    { "label": "15s", "sec": 15 },
                                    { "label": "30s", "sec": 30 },
                                    { "label": "1m",  "sec": 60 },
                                    { "label": "5m",  "sec": 300 },
                                    { "label": "Pause", "sec": 0 }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: (parent.width - 24) / 5
                                    height: 26
                                    radius: 7
                                    readonly property bool isSelected: root.intervalSecs === modelData.sec
                                    readonly property bool isPauseBtn: modelData.sec === 0
                                    color: isSelected
                                        ? (isPauseBtn ? Qt.rgba(255, 159, 10, 0.28) : Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.36))
                                        : (intHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                                    border.color: isSelected
                                        ? (isPauseBtn ? "#ff9f0a" : (theme.blueLight != "" ? theme.blueLight : theme.blue))
                                        : Qt.rgba(255, 255, 255, 0.10)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: isSelected ? "#ffffff" : theme.textSub
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

                    // Current Photo Quick Bar
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: root.photoFilename || "No photo"
                                color: theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                                color: pPrevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                                Text { anchors.centerIn: parent; text: "󰒮"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#ffffff" }
                                MouseArea { id: pPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.prevPhoto() }
                            }

                            Rectangle {
                                Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12
                                color: pNextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                                Text { anchors.centerIn: parent; text: "󰒭"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#ffffff" }
                                MouseArea { id: pNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.nextPhoto() }
                            }
                        }
                    }
                }
            }
        }
    }
}
