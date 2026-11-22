import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 216
    implicitHeight: 208

    radius: 20
    color: theme.widgetGlass
    border.color: theme.borderSubtle
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
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    property var reposList: []
    property int dirtyCount: 0

    Process {
        id: gitProc
        command: ["python3", Quickshell.shellPath("scripts/dev-env-status.py"), "git"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    root.reposList = Array.isArray(d.repos) ? d.repos : [];
                    root.dirtyCount = d.dirtyCount || 0;
                } catch(e) {}
            }
        }
    }

    function refreshNow() {
        if (!gitProc.running) gitProc.running = true;
    }

    Component.onCompleted: refreshNow()

    Timer {
        interval: 8000
        repeat: true
        running: root.isLive
        onTriggered: root.refreshNow()
    }

    // Drag, right-click menu, and click-to-refresh MouseArea
    MouseArea {
        id: bgMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startScreenX: 0
        property real startScreenY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (root.wrapper) root.wrapper.menuOpen = !root.wrapper.menuOpen;
                return;
            }
            if (mouse.button !== Qt.LeftButton) return;
            if (root.wrapper && root.wrapper.menuOpen) root.wrapper.menuOpen = false;
            let canvasPt = mapToItem(root.wrapper ? root.wrapper.parent : root.parent, mouse.x, mouse.y);
            startScreenX = canvasPt.x;
            startScreenY = canvasPt.y;
            isDragging = false;
        }

        onPositionChanged: (mouse) => {
            if (!bgMouseArea.pressed || (mouse.buttons & Qt.LeftButton) === 0) {
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
            if (isDragging && root.wrapper) root.wrapper.updateDrag(dx, dy);
        }

        onReleased: {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
        }

        onCanceled: {
            if (isDragging) {
                isDragging = false;
                if (root.wrapper) root.wrapper.endDrag();
            }
        }

        onClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton || isDragging) return;
            root.refreshNow();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 13
        anchors.bottomMargin: 12
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 6

            Text {
                text: "󰊢"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: root.dirtyCount > 0 ? "#ff9f0a" : "#30d158"
            }

            Text {
                Layout.fillWidth: true
                text: "Git Repos"
                color: theme.text
                font.family: theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Text {
                text: root.dirtyCount > 0 ? (root.dirtyCount + " dirty") : "clean"
                color: root.dirtyCount > 0 ? "#ff9f0a" : "#30d158"
                font.family: theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }

        // Repos List
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.reposList
            spacing: 5
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: repoRow
                required property var modelData
                width: ListView.view.width
                height: 36
                radius: 9
                color: repoRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.045)
                border.width: 1
                border.color: repoRowMa.containsMouse ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.45) : Qt.rgba(1, 1, 1, 0.07)

                readonly property bool isDirty: (repoRow.modelData.dirty || 0) > 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    spacing: 6

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: repoRow.modelData.name || "repo"
                            elide: Text.ElideRight
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (repoRow.modelData.branch || "main") + (repoRow.modelData.ahead > 0 ? (" ↑" + repoRow.modelData.ahead) : "")
                            elide: Text.ElideRight
                            color: theme.textDim
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 8
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 17
                        Layout.preferredWidth: stTxt.implicitWidth + 10
                        radius: 6
                        color: repoRow.isDirty ? Qt.rgba(1.0, 0.62, 0.04, 0.16) : Qt.rgba(48/255, 209/255, 88/255, 0.14)
                        border.width: 1
                        border.color: repoRow.isDirty ? Qt.rgba(1.0, 0.62, 0.04, 0.40) : Qt.rgba(48/255, 209/255, 88/255, 0.35)

                        Text {
                            id: stTxt
                            anchors.centerIn: parent
                            text: repoRow.isDirty ? ("~" + repoRow.modelData.dirty) : "✓"
                            color: repoRow.isDirty ? "#ff9f0a" : "#30d158"
                            font.family: theme.fontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }
                }

                MouseArea {
                    id: repoRowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["kitty", "--directory", repoRow.modelData.path])
                }
            }
        }
    }
}
