import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    required property var modelData
    property bool active: false
    property bool grabInput: false
    property string token: ""

    screen: modelData
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:freeze"
    WlrLayershell.keyboardFocus: (active && grabInput) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        visible: win.active && !win.grabInput
        cache: false
        asynchronous: false
        smooth: false
        fillMode: Image.Stretch
        source: (win.active && !win.grabInput && win.screen && win.screen.name && win.token !== "")
            ? ("file:///tmp/.shot_freeze_" + win.token + "_" + win.screen.name + ".ppm")
            : ""
    }

    MouseArea {
        anchors.fill: parent
        enabled: win.active && win.grabInput
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onPressed: (mouse) => { mouse.accepted = true }
        onWheel: (wheel) => { wheel.accepted = true }
    }
}
