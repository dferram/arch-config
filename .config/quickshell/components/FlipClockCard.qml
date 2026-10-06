import QtQuick

// Classic split flap: the old top half folds down, revealing the new bottom half.
Item {
    id: card
    property string value: ""
    property color accent: "#42a0bf"
    property bool outlined: false
    property string currentValue: ""
    property string outgoingValue: ""
    property real progress: 1
    property bool initialized: false
    readonly property bool turning: turn.running
    readonly property color edgeColor: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
    width: 620
    height: 820

    function updateValue() {
        if (!initialized || value === currentValue) return;
        turn.stop();
        outgoingValue = currentValue;
        currentValue = value;
        turn.restart();
    }
    onValueChanged: updateValue()
    Component.onCompleted: {
        currentValue = value;
        initialized = true;
    }

    // Both halves crop the same full-size face, keeping the digits aligned.
    component HalfFace: Item {
        id: face
        property string digits: ""
        property bool lower: false
        property color edgeColor: "transparent"
        property real edgeWidth: 0
        property real shade: 0
        clip: true

        Rectangle {
            y: face.lower ? -face.height : 0
            width: face.width
            height: face.height * 2
            radius: face.width * 46 / 620
            color: "#18191c"
            border.width: face.edgeWidth
            border.color: face.edgeColor
            Text {
                anchors.centerIn: parent
                text: face.digits
                color: "#e1e4e8"
                font.family: "Bebas Neue"
                font.pixelSize: parent.height * 680 / 820
            }
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "black"
                opacity: face.shade
            }
        }
    }

    HalfFace {
        width: card.width; height: card.height / 2
        digits: card.currentValue
        edgeWidth: card.outlined ? 6 : 0
        edgeColor: card.edgeColor
        shade: card.turning ? 0.18 * (1 - card.progress) : 0
    }
    HalfFace {
        y: card.height / 2
        width: card.width; height: card.height / 2
        lower: true
        digits: card.turning ? card.outgoingValue : card.currentValue
        edgeWidth: card.outlined ? 6 : 0
        edgeColor: card.edgeColor
    }

    // First half of the turn: old upper flap rotates toward the center seam.
    HalfFace {
        objectName: "outgoingTop"
        width: card.width; height: card.height / 2
        digits: card.outgoingValue
        visible: card.turning && card.progress < 0.5
        edgeWidth: card.outlined ? 6 : 0
        edgeColor: card.edgeColor
        shade: 0.28 * card.progress * 2
        layer.enabled: visible
        layer.smooth: true
        transform: Rotation {
            origin.x: card.width / 2
            origin.y: card.height / 2
            axis.x: 1; axis.y: 0; axis.z: 0
            distanceToPlane: card.height * 8
            angle: -180 * card.progress
        }
    }
    // Second half: the reverse side opens down onto the lower half of the card.
    HalfFace {
        objectName: "incomingBottom"
        y: card.height / 2
        width: card.width; height: card.height / 2
        lower: true
        digits: card.currentValue
        visible: card.turning && card.progress >= 0.5
        edgeWidth: card.outlined ? 6 : 0
        edgeColor: card.edgeColor
        shade: 0.28 * (1 - card.progress) * 2
        layer.enabled: visible
        layer.smooth: true
        transform: Rotation {
            origin.x: card.width / 2
            origin.y: 0
            axis.x: 1; axis.y: 0; axis.z: 0
            distanceToPlane: card.height * 8
            angle: 180 * (1 - card.progress)
        }
    }

    // Keep the original black horizontal division, with no calendar hardware.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 8 * card.height / 820
        color: "black"
        z: 2
    }
    SequentialAnimation {
        id: turn
        NumberAnimation {
            target: card; property: "progress"
            from: 0; to: 0.5
            duration: 260
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: card; property: "progress"
            from: 0.5; to: 1
            duration: 360
            easing.type: Easing.OutCubic
        }
    }
}
