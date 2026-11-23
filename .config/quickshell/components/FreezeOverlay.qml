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
    WlrLayershell.namespace: "quickshell:freeze"
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
        source: (win.active && win.screen && win.screen.name && win.token !== "")
            ? ("file:///tmp/.shot_freeze_" + win.token + "_" + win.screen.name + ".ppm")
            : ""
    }
}
