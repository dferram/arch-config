import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"

Row {
    id: root

    Theme { id: theme }

    spacing: 5
    height: 28

    // Target screen passed from shell.qml
    property var targetScreen: null

    // Monitor name (e.g. "eDP-1" or "HDMI-A-1")
    property string screenName: {
        if (targetScreen && targetScreen.name) return targetScreen.name;
        return "";
    }

    // Determine if this screen is the primary laptop display
    property bool isPrimaryScreen: {
        if (screenName !== "") {
            return screenName.indexOf("eDP") !== -1;
        }
        return true;
    }

    // Model of workspaces: 1-5 for primary screen, 6-10 for secondary / external screen
    property var workspacesModel: isPrimaryScreen ? [1, 2, 3, 4, 5] : [6, 7, 8, 9, 10]

    // Query Hyprland monitor for this screen
    property var hyprMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    property var monitorActiveWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
    property bool isMonitorFocused: hyprMonitor ? hyprMonitor.focused : false

    // Active workspace ID on this monitor
    property int activeWorkspaceId: {
        if (monitorActiveWorkspace && monitorActiveWorkspace.id !== undefined && monitorActiveWorkspace.id > 0) {
            return monitorActiveWorkspace.id;
        }
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id !== undefined) {
            let fid = Hyprland.focusedWorkspace.id;
            if (root.workspacesModel.indexOf(fid) !== -1) {
                return fid;
            }
        }
        return isPrimaryScreen ? 1 : 6;
    }

    Repeater {
        model: root.workspacesModel

        Rectangle {
            id: wsPill
            width: 28
            height: 28
            radius: theme.radiusSmall
            anchors.verticalCenter: parent.verticalCenter

            property int wsId: modelData
            property bool isCurrent: root.activeWorkspaceId === wsId
            property bool isFocused: isCurrent && (root.isMonitorFocused || (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId))

            color: {
                if (isFocused) return theme.blue;
                if (isCurrent) return Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.35);
                if (wsMouse.containsMouse) return Qt.rgba(255, 255, 255, 0.14);
                return Qt.rgba(255, 255, 255, 0.06);
            }

            border.color: {
                if (isFocused) return theme.blueLight;
                if (isCurrent) return theme.blue;
                if (wsMouse.containsMouse) return Qt.rgba(255, 255, 255, 0.24);
                return Qt.rgba(255, 255, 255, 0.10);
            }
            border.width: 1

            Behavior on color { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }
            Behavior on border.color { ColorAnimation { duration: 260; easing.type: Easing.OutQuad } }

            scale: wsMouse.pressed ? 0.96 : (wsMouse.containsMouse ? 1.03 : 1.0)
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: wsPill.wsId
                color: {
                    if (wsPill.isFocused) return "#ffffff";
                    if (wsPill.isCurrent) return theme.blueLight;
                    if (wsMouse.containsMouse) return theme.text;
                    return theme.textMuted;
                }
                font.family: theme.fontFamily
                font.pixelSize: 11
                font.weight: wsPill.isCurrent ? Font.Bold : Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Hyprland.dispatch("workspace " + wsPill.wsId);
                }
            }
        }
    }
}
