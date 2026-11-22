import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var modelData
    property bool active: false
    property string token: ""

    screen: modelData
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: active

    Image {
        id: freezeImg
        anchors.fill: parent
        cache: false
        asynchronous: false
        smooth: false
        fillMode: Image.Stretch
        source: (win.active && win.screen && win.screen.name)
            ? ("file:///tmp/.shot_freeze_" + win.screen.name + ".png?t=" + win.token)
            : ""
    }
}
