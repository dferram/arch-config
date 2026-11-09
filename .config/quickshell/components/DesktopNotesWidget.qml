import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 345
    implicitHeight: 165
    width: implicitWidth
    height: implicitHeight

    radius: 20
    // Apple Sonoma Translucent Obsidian Glass
    color: Qt.rgba(0.06, 0.06, 0.09, 0.55)
    border.color: Qt.rgba(255, 255, 255, 0.10)
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
    readonly property var overlay: (root.parent && root.parent.parent && root.parent.parent.overlay) ? root.parent.parent.overlay : desktopWindow
    property string noteTitle: "Quick Notes"
    property string noteContent: ""
    property string lastUpdated: ""
    property bool isHovered: hoverHandler.hovered

    // Read initial notes from backend helper
    Process {
        id: readNotesProc
        command: ["python3", Quickshell.shellPath("scripts/desktop-widgets-helper.py"), "notes-get"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.title) root.noteTitle = d.title;
                    if (d.content !== undefined) {
                        root.noteContent = d.content;
                        if (contentArea.text !== d.content) {
                            contentArea.text = d.content;
                        }
                    }
                    if (d.updated_at) root.lastUpdated = d.updated_at;
                } catch(e) {}
            }
        }
    }

    // Save notes with debounced timer
    Process {
        id: saveNotesProc
    }

    Timer {
        id: saveDebounce
        interval: 1000
        repeat: false
        onTriggered: {
            saveNotesProc.command = [
                "python3",
                Quickshell.shellPath("scripts/desktop-widgets-helper.py"),
                "notes-save",
                titleInput.text.trim() || "Quick Notes",
                contentArea.text
            ];
            saveNotesProc.running = true;
            root.lastUpdated = "Saved just now";
        }
    }

    // Process to copy to clipboard
    Process { id: copyProc }

    Column {
        anchors.fill: parent
        anchors.margins: 13
        spacing: 6

        // Apple Notes Header Strip (Yellow Tab)
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Yellow Notes Folder Pill
                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: theme.yellow != "" ? theme.yellow : "#ffd60a"

                    Text {
                        anchors.centerIn: parent
                        text: "󰠮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: "#000000"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
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
                            if (!pressed || (mouse.buttons & Qt.LeftButton) === 0) {
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
                                if (root.wrapper) root.wrapper.startDrag(mouse.x, mouse.y);
                            }
                            if (isDragging && root.wrapper) {
                                root.wrapper.updateDrag(dx, dy);
                            }
                        }
                        onReleased: {
                            if (isDragging && root.wrapper) {
                                isDragging = false;
                                root.wrapper.endDrag();
                            }
                        }
                        onCanceled: {
                            if (isDragging && root.wrapper) {
                                isDragging = false;
                                root.wrapper.endDrag();
                            }
                        }
                    }
                }

                TextInput {
                    id: titleInput
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.width - 150
                    text: root.noteTitle
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    selectByMouse: true
                    activeFocusOnPress: true
                    onTextEdited: saveDebounce.restart()
                    onActiveFocusChanged: {
                        if (root.overlay && root.overlay.requestsKeyboardFocus !== undefined) {
                            root.overlay.requestsKeyboardFocus = (titleInput.activeFocus || contentArea.activeFocus);
                        }
                    }
                    Keys.onEscapePressed: {
                        titleInput.focus = false;
                        if (root.overlay) root.overlay.requestsKeyboardFocus = false;
                    }
                }
            }

            // Quick actions shown on hover
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                opacity: root.isHovered ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Copy button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 5
                    color: copyHover.containsMouse ? theme.surfaceActive : theme.surface
                    border.color: theme.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰆏"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: theme.textSub
                    }

                    MouseArea {
                        id: copyHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            copyProc.command = ["wl-copy", contentArea.text];
                            copyProc.running = true;
                            root.lastUpdated = "Copied to clipboard!";
                        }
                    }
                }

                // Clear button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 5
                    color: clearHover.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.2) : theme.surface
                    border.color: theme.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰃢"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: clearHover.containsMouse ? "#ff453a" : theme.textSub
                    }

                    MouseArea {
                        id: clearHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            contentArea.text = "";
                            saveDebounce.restart();
                        }
                    }
                }
            }
        }

        // Lined / Ruled note content container
        Rectangle {
            width: parent.width
            height: parent.height - 54
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(255, 255, 255, 0.06)
            border.width: 1
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: width
                contentHeight: contentArea.implicitHeight
                clip: true

                TextArea.flickable: TextArea {
                    id: contentArea
                    width: flick.width
                    wrapMode: TextEdit.Wrap
                    color: theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Normal
                    padding: 0
                    selectByMouse: true
                    activeFocusOnPress: true
                    placeholderText: "Type a quick note here..."
                    placeholderTextColor: theme.textDim
                    background: null

                    onTextChanged: {
                        if (text !== root.noteContent) {
                            saveDebounce.restart();
                        }
                    }
                    onActiveFocusChanged: {
                        if (root.overlay && root.overlay.requestsKeyboardFocus !== undefined) {
                            root.overlay.requestsKeyboardFocus = (titleInput.activeFocus || contentArea.activeFocus);
                        }
                    }
                    Keys.onEscapePressed: {
                        contentArea.focus = false;
                        if (root.overlay) root.overlay.requestsKeyboardFocus = false;
                    }
                }
            }
        }

        // Footer: Timestamp in English
        Row {
            width: parent.width
            spacing: 4

            Text {
                text: "󰄟 " + (root.lastUpdated || "Saved automatically")
                color: theme.textDim
                font.family: theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Medium
            }
        }
    }

    HoverHandler {
        id: hoverHandler
    }
}
