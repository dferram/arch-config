import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 448
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
    readonly property string githubSvg: Quickshell.shellPath("icons/github.svg")
    property bool isLive: (parent && parent.isLive !== undefined) ? parent.isLive : true

    property string username: "dferram"
    property int activeTab: 0 // 0 = PRs, 1 = Notifications / Activity
    property bool hasToken: false
    property int openPrCount: 0
    property int unreadCount: 0
    property var prsList: []
    property var notifsList: []
    property bool isLoading: false

    function stateColor(st) {
        switch ((st || "").toLowerCase()) {
            case "open": return "#30d158";
            case "merged": return "#bf5af2";
            case "draft": return theme.textMuted;
            case "closed": return "#ff453a";
            default: return theme.blueLight;
        }
    }

    Process {
        id: actProc
        command: ["python3", Quickshell.shellPath("scripts/github-activity.py"), "get", root.username]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isLoading = false;
                let txt = text.trim();
                if (!txt || !txt.startsWith("{")) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.username) root.username = d.username;
                    root.hasToken = !!d.hasToken;
                    if (d.openPrCount !== undefined) root.openPrCount = d.openPrCount;
                    if (d.unreadCount !== undefined) root.unreadCount = d.unreadCount;
                    if (Array.isArray(d.prs)) root.prsList = d.prs;
                    if (Array.isArray(d.notifications)) root.notifsList = d.notifications;
                } catch(e) {}
            }
        }
        onExited: root.isLoading = false
    }

    function refresh(force) {
        if (actProc.running) return;
        root.isLoading = true;
        actProc.command = ["python3", Quickshell.shellPath("scripts/github-activity.py"), force ? "fetch" : "get", root.username];
        actProc.running = true;
    }

    Component.onCompleted: refresh(false)

    Timer {
        interval: 300000
        repeat: true
        running: root.isLive
        onTriggered: root.refresh(true)
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
            root.refresh(true);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 13
        anchors.bottomMargin: 12
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        // Header + Tab Switcher (PRs | Alerts)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                radius: 7
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1

                Image {
                    anchors.centerIn: parent
                    width: 15
                    height: 15
                    source: root.githubSvg
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/pulls"])
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "GitHub Inbox"
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }

                Text {
                    text: "@" + root.username + (root.isLoading ? " • syncing..." : "")
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                }
            }

            // Tab 0: Pull Requests
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: prTabTxt.implicitWidth + 16
                radius: 8
                color: root.activeTab === 0 ? Qt.rgba(48/255, 209/255, 88/255, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: root.activeTab === 0 ? Qt.rgba(48/255, 209/255, 88/255, 0.50) : Qt.rgba(1, 1, 1, 0.08)

                Text {
                    id: prTabTxt
                    anchors.centerIn: parent
                    text: "PRs (" + root.prsList.length + ")"
                    color: root.activeTab === 0 ? "#30d158" : theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = 0
                }
            }

            // Tab 1: Notifications / Activity
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: notifTabTxt.implicitWidth + 16
                radius: 8
                color: root.activeTab === 1 ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.20) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: root.activeTab === 1 ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.55) : Qt.rgba(1, 1, 1, 0.08)

                Text {
                    id: notifTabTxt
                    anchors.centerIn: parent
                    text: root.hasToken
                        ? ("Alerts (" + root.unreadCount + ")")
                        : ("Activity (" + root.notifsList.length + ")")
                    color: root.activeTab === 1 ? theme.blueLight : theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = 1
                }
            }
        }

        // Body List (PRs or Notifications/Activity)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // PRs List
            ListView {
                anchors.fill: parent
                visible: root.activeTab === 0 && root.prsList.length > 0
                model: root.prsList
                spacing: 5
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: prRow
                    required property var modelData
                    width: ListView.view.width
                    height: 40
                    radius: 9
                    color: prRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: prRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)

                    readonly property color badgeCol: root.stateColor(prRow.modelData.state)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Rectangle {
                            Layout.preferredHeight: 18
                            Layout.preferredWidth: stLabel.implicitWidth + 10
                            radius: 5
                            color: Qt.rgba(prRow.badgeCol.r, prRow.badgeCol.g, prRow.badgeCol.b, 0.16)
                            border.width: 1
                            border.color: Qt.rgba(prRow.badgeCol.r, prRow.badgeCol.g, prRow.badgeCol.b, 0.38)

                            Text {
                                id: stLabel
                                anchors.centerIn: parent
                                text: (prRow.modelData.state || "open").toUpperCase()
                                color: prRow.badgeCol
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: prRow.modelData.title || "Pull Request"
                                elide: Text.ElideRight
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (prRow.modelData.repo || "") + " #" + (prRow.modelData.number || 0)
                                elide: Text.ElideRight
                                color: theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                            }
                        }

                        Text {
                            text: prRow.modelData.ago || ""
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: prRowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", prRow.modelData.url || "https://github.com/pulls"])
                    }
                }
            }

            // PR Empty State
            Column {
                anchors.centerIn: parent
                spacing: 3
                visible: root.activeTab === 0 && root.prsList.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isLoading ? "Checking pull requests..." : "No active pull requests"
                    color: theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.hasToken ? "All PRs caught up" : "Public PRs • click for GitHub"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                }
            }

            // Notifications / Activity List
            ListView {
                anchors.fill: parent
                visible: root.activeTab === 1 && root.notifsList.length > 0
                model: root.notifsList
                spacing: 5
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: nfRow
                    required property var modelData
                    width: ListView.view.width
                    height: 40
                    radius: 9
                    color: nfRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: nfRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            radius: 4
                            color: nfRow.modelData.unread ? theme.blueLight : "#30d158"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: nfRow.modelData.title || ""
                                elide: Text.ElideRight
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (nfRow.modelData.repo || "") + " • " + (nfRow.modelData.kind || "Event")
                                elide: Text.ElideRight
                                color: theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 9
                            }
                        }

                        Text {
                            text: nfRow.modelData.ago || ""
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: nfRowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", nfRow.modelData.url || "https://github.com/notifications"])
                    }
                }
            }

            // Notifications Empty State
            Column {
                anchors.centerIn: parent
                spacing: 3
                visible: root.activeTab === 1 && root.notifsList.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isLoading ? "Syncing notifications..." : "Inbox zero"
                    color: theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.hasToken ? "No unread GitHub notifications" : "Optional: save PAT to ~/.local/share/desktop-widgets/github_token"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                }
            }
        }
    }
}
