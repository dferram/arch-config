import QtQuick

// ==============================================================================
// FALLING DIGITS COMPONENT
// Renders numeric countdown values with a cinematic vertical falling animation.
// Each digit that changes drops downwards (outgoing falls down & fades out,
// incoming drops in from above & fades in with natural deceleration).
// Digits that remain unchanged stay completely static and steady.
// ==============================================================================
Row {
    id: root

    property var value: "00"
    property string fontFamily: ""
    property int pixelSize: 22
    property int fontWeight: Font.Bold
    property bool fontItalic: false
    property real letterSpacing: 0
    property color textColor: "#ffffff"
    property int animationDuration: 280

    readonly property string textVal: "" + (value !== undefined && value !== null ? value : "")
    spacing: 0

    component FallingDigit: Item {
        id: digitRoot

        property string char: ""
        property string displayChar: char
        property string outgoingChar: ""
        property bool initialized: false

        property string fontFamily: ""
        property int pixelSize: 28
        property int fontWeight: Font.Bold
        property bool fontItalic: false
        property real letterSpacing: 0
        property color textColor: "#ffffff"
        property int animationDuration: 280

        implicitWidth: Math.max(measurer.implicitWidth, incomingText.implicitWidth)
        implicitHeight: Math.ceil(measurer.implicitHeight)
        clip: true

        Text {
            id: measurer
            visible: false
            text: "0"
            font.family: digitRoot.fontFamily
            font.pixelSize: digitRoot.pixelSize
            font.weight: digitRoot.fontWeight
            font.italic: digitRoot.fontItalic
            font.letterSpacing: digitRoot.letterSpacing
            font.features: { "tnum": 1 }
        }

        Text {
            id: outgoingText
            anchors.horizontalCenter: parent.horizontalCenter
            text: digitRoot.outgoingChar
            font.family: digitRoot.fontFamily
            font.pixelSize: digitRoot.pixelSize
            font.weight: digitRoot.fontWeight
            font.italic: digitRoot.fontItalic
            font.letterSpacing: digitRoot.letterSpacing
            font.features: { "tnum": 1 }
            color: digitRoot.textColor
            y: 0
            opacity: 0
        }

        Text {
            id: incomingText
            anchors.horizontalCenter: parent.horizontalCenter
            text: digitRoot.displayChar
            font.family: digitRoot.fontFamily
            font.pixelSize: digitRoot.pixelSize
            font.weight: digitRoot.fontWeight
            font.italic: digitRoot.fontItalic
            font.letterSpacing: digitRoot.letterSpacing
            font.features: { "tnum": 1 }
            color: digitRoot.textColor
            y: 0
            opacity: 1
        }

        ParallelAnimation {
            id: fallAnim
            NumberAnimation {
                target: outgoingText
                property: "y"
                from: 0
                to: Math.ceil(digitRoot.height * 1.1)
                duration: digitRoot.animationDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: outgoingText
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: digitRoot.animationDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: incomingText
                property: "y"
                from: -Math.ceil(digitRoot.height * 1.1)
                to: 0
                duration: digitRoot.animationDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: incomingText
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: digitRoot.animationDuration
                easing.type: Easing.OutCubic
            }
            onFinished: {
                outgoingText.opacity = 0;
                digitRoot.outgoingChar = "";
                incomingText.y = 0;
                incomingText.opacity = 1;
            }
        }

        function setChar(newChar) {
            if (!initialized) {
                displayChar = newChar;
                initialized = true;
                return;
            }
            if (newChar === displayChar) return;

            fallAnim.stop();
            outgoingChar = displayChar;
            displayChar = newChar;
            outgoingText.y = 0;
            outgoingText.opacity = 1;
            incomingText.y = -Math.ceil(digitRoot.height * 1.1);
            incomingText.opacity = 0;
            fallAnim.restart();
        }

        onCharChanged: setChar(char)
        Component.onCompleted: {
            displayChar = char;
            initialized = true;
        }
    }

    Repeater {
        model: root.textVal.length
        FallingDigit {
            char: root.textVal.charAt(index)
            fontFamily: root.fontFamily
            pixelSize: root.pixelSize
            fontWeight: root.fontWeight
            fontItalic: root.fontItalic
            letterSpacing: root.letterSpacing
            textColor: root.textColor
            animationDuration: root.animationDuration
        }
    }
}
