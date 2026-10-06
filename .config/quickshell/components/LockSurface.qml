import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../theme"

// ==============================================================================
// LOCK SURFACE — per-monitor lock UI
//  · Idle:     monumental OLED flip clock (same look as the old hyprlock)
//  · Revealed: clock shrinks to the top, control panel rises (media, status, auth)
// Reveal on click or on any key press; Esc / 20 s idle returns to the clock.
// ==============================================================================
Item {
    id: root
    required property LockContext ctx

    Theme { id: theme }

    readonly property string iconFont: "GeistMono Nerd Font Propo"
    readonly property color glass: "#d90f0f14"
    readonly property color glassHover: "#e61a1a21"
    readonly property bool revealed: ctx.revealed
    readonly property color accent: lockMedia.hasTrack ? lockMedia.mediaAccentColor : "#42a0bf"
    readonly property string artUrl: lockMedia.hasTrack ? lockMedia.artUrl : ""

    // Smooth, slightly springy curve shared by every reveal transition
    readonly property int revealDuration: 620

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // ==========================================================================
    // BACKGROUND (revealed only): blurred album art + accent glow on OLED black
    // ==========================================================================
    property bool flipArt: false
    onArtUrlChanged: flipArt = !flipArt

    Item {
        id: backdrop
        anchors.fill: parent
        opacity: root.revealed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic } }

        Image {
            id: bgArtA
            anchors.fill: parent
            source: !root.flipArt ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 256
            sourceSize.height: 256
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bgArtA
            visible: opacity > 0.01
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.25
            opacity: !root.flipArt && root.artUrl !== "" && bgArtA.status === Image.Ready ? 0.30 : 0.0
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }

        Image {
            id: bgArtB
            anchors.fill: parent
            source: root.flipArt ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 256
            sourceSize.height: 256
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bgArtB
            visible: opacity > 0.01
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.25
            opacity: root.flipArt && root.artUrl !== "" && bgArtB.status === Image.Ready ? 0.30 : 0.0
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }

        // Accent bloom rising from the bottom
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.80) }
                GradientStop { position: 1.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16) }
            }
        }
    }

    // Media controls and agent scrolling also keep the panel awake.
    TapHandler {
        acceptedButtons: Qt.AllButtons
        onPressedChanged: if (pressed) root.ctx.poke()
    }

    // Click anywhere: reveal / keep alive
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            root.ctx.reveal();
            input.forceActiveFocus();
        }
    }

    // ==========================================================================
    // FLIP CLOCK — authored at 1308x820 (hyprlock geometry) and scaled
    // ==========================================================================
    readonly property real baseScale: Math.min(1, (height * 0.86) / 820, (width * 0.92) / 1308)
    readonly property real miniHeight: Math.min(150, height * 0.16)
    readonly property real miniScale: miniHeight / 820
    readonly property real miniTop: Math.max(28, height * 0.05)

    Item {
        id: flipClock
        width: 1308
        height: 820
        x: (root.width - width) / 2
        y: root.revealed ? (root.miniTop + root.miniHeight / 2 - height / 2)
                         : (root.height / 2 - height / 2 - 12 * root.baseScale)
        scale: root.revealed ? root.miniScale : root.baseScale
        transformOrigin: Item.Center

        Behavior on y { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutExpo } }
        Behavior on scale { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutExpo } }

        // Keep each card alive across clock ticks so only changed values flip.
        FlipClockCard {
            id: hourCard
            value: Qt.formatDateTime(root.ctx.now, "h")
            accent: root.accent
            outlined: root.revealed
        }
        FlipClockCard {
            id: minuteCard
            x: 688
            value: Qt.formatDateTime(root.ctx.now, "mm")
            accent: root.accent
            outlined: root.revealed
        }

        // AM / PM
        Text {
            x: 310 - 245 - width / 2
            y: 410 - 360 - height / 2
            text: Qt.formatDateTime(root.ctx.now, "AP")
            color: "#91969e"
            font.family: "Bebas Neue"
            font.pixelSize: 90
            opacity: root.revealed ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
    }

    // Date under the mini clock
    Text {
        id: dateLabel
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.miniTop + root.miniHeight + 12
        text: {
            let s = Qt.locale("en_US").toString(root.ctx.now, "dddd, MMMM d");
            return s.charAt(0).toUpperCase() + s.slice(1) + "  ·  " + Qt.formatDateTime(root.ctx.now, "h:mm AP");
        }
        color: theme.textMuted
        font.family: theme.fontFamily
        font.pixelSize: 15
        font.weight: Font.Medium
        font.letterSpacing: 0.4
        opacity: root.revealed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }

    // ==========================================================================
    // CONTROL PANEL
    // ==========================================================================
    Column {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: dateLabel.y + dateLabel.height + 24 + slide
        scale: Math.min(1, (root.width - 40) / 646, (root.height - y - 24) / Math.max(1, implicitHeight))
        transformOrigin: Item.Top
        spacing: 24

        property real slide: root.revealed ? 0 : 40
        Behavior on slide { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutExpo } }
        opacity: root.revealed ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        // The bar's media card, including its live CAVA spectrum and artwork palette.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Item {
                width: 350
                height: lockMedia.hasTrack ? lockMedia.implicitHeight : 180
                MediaWidget {
                    id: lockMedia
                    anchors.fill: parent
                    parentWindow: null
                    embedded: true
                    embeddedActive: root.revealed
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !lockMedia.hasTrack
                    radius: 16
                    color: root.glass
                    border.width: 1
                    border.color: theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "Nothing playing"
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 14
                    }
                }
            }

            LockAgentCard {
                width: 280
                height: lockMedia.hasTrack ? lockMedia.implicitHeight : 180
                agents: root.ctx.agents
                available: root.ctx.agentsAvailable
                accent: root.accent
            }
        }

        // ---------------- AUTH ----------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ctx.userName
                color: theme.textSub
                font.family: theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            // Password pill
            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 46
                radius: 23
                color: root.glass
                border.width: 1
                border.color: root.ctx.authFailed ? theme.red
                              : input.text.length > 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.8)
                              : theme.border
                Behavior on border.color { ColorAnimation { duration: 200 } }

                transform: Translate { id: shakeT; x: 0 }
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 50 }
                    NumberAnimation { target: shakeT; property: "x"; to: 10; duration: 70 }
                    NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 60 }
                    NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
                }
                Connections {
                    target: root.ctx
                    function onFailCountChanged() { if (root.ctx.failCount > 0) shakeAnim.restart(); }
                    function onPasswordChanged() { if (input.text !== root.ctx.password) input.text = root.ctx.password; }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    font.family: root.iconFont
                    font.pixelSize: 16
                    color: theme.textDim
                }

                Text {
                    anchors.centerIn: parent
                    visible: input.text.length === 0
                    text: root.ctx.authBusy ? "Verifying…" : "Password"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 14
                }

                // Password dots (pop-in)
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Repeater {
                        model: Math.min(input.text.length, 18)
                        delegate: Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            color: theme.text
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.ctx.fingerprintAvailable
                    text: "󰈷"
                    font.family: root.iconFont
                    font.pixelSize: 18
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85)
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ctx.statusText !== "" ? root.ctx.statusText
                      : root.ctx.fingerprintAvailable ? "Press Enter to unlock  ·  or use your fingerprint"
                      : "Press Enter to unlock"
                color: root.ctx.authFailed ? theme.red : theme.textDim
                font.family: theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    // Keep keyboard input outside the panel, which is hidden in clock mode.
    TextInput {
        id: input
        width: 1
        height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        readOnly: root.ctx.authBusy
        cursorVisible: false
        onTextChanged: {
            if (root.ctx.password !== text) root.ctx.password = text;
            if (text.length > 0) {
                root.ctx.authFailed = false;
                root.ctx.statusText = "";
            }
        }
        onAccepted: {
            if (!root.ctx.revealed) root.ctx.reveal();
            else root.ctx.submit();
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.ctx.hide();
                event.accepted = true;
                return;
            }
            // Bare modifiers (e.g. releasing Super from Super+L) must not reveal
            const mods = [Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Meta, Qt.Key_Shift, Qt.Key_Control,
                          Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_NumLock, Qt.Key_unknown];
            if (mods.indexOf(event.key) !== -1) return;
            if (!root.ctx.revealed) root.ctx.reveal();
            root.ctx.poke();
        }
    }

    function fmtTime(us) {
        // MPRIS position/length are in seconds (Quickshell converts)
        let s = Math.max(0, Math.floor(us));
        let m = Math.floor(s / 60);
        let r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    Component.onCompleted: input.forceActiveFocus()
}
