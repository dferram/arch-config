import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
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
    readonly property color accent: lockMedia.hasTrack ? lockMedia.mediaAccentColor : theme.blue
    readonly property string artUrl: lockMedia.hasTrack ? lockMedia.artUrl : ""
    readonly property bool hasArt: artUrl !== ""

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
    onArtUrlChanged: {
        if (root.artUrl !== "") flipArt = !flipArt;
    }

    Item {
        id: backdrop
        anchors.fill: parent
        opacity: root.revealed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic } }

        // Blurred wallpaper base (shown only when no media is playing or no artwork)
        Image {
            id: wallImg
            anchors.fill: parent
            source: root.ctx.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 512
            sourceSize.height: 512
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wallImg
            visible: opacity > 0.01
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.15
            brightness: -0.15
            opacity: (!root.hasArt && wallImg.status === Image.Ready) ? 0.55 : 0.0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        }

        // Blurred album art A (crossfade layer)
        Image {
            id: bgArtA
            anchors.fill: parent
            source: !root.flipArt ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            sourceSize.height: 640
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
            saturation: 0.40
            brightness: -0.10
            opacity: (!root.flipArt && root.hasArt && bgArtA.status === Image.Ready) ? 0.65 : 0.0
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }

        // Blurred album art B (crossfade layer)
        Image {
            id: bgArtB
            anchors.fill: parent
            source: root.flipArt ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            sourceSize.height: 640
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
            saturation: 0.40
            brightness: -0.10
            opacity: (root.flipArt && root.hasArt && bgArtB.status === Image.Ready) ? 0.65 : 0.0
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
        }

        // Accent bloom rising from the bottom
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.70) }
                GradientStop { position: 1.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) }
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
                         : (root.height / 2 - height / 2 - (lockMedia.hasTrack ? 36 : 12) * root.baseScale)
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

    // ==========================================================================
    // MINI MEDIA PILL (idle clock state only: floating under the monumental flip clock)
    // ==========================================================================
    // MINI MEDIA PILL (idle flip-clock mode) — Apple Liquid Glass capsule
    // ==========================================================================
    Rectangle {
        id: miniMediaPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(28, root.height * 0.045)
        width: Math.min(460, root.width - 48)
        height: 60
        radius: 30
        color: "#e60d0e14"
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.16)

        opacity: (!root.revealed && lockMedia.hasTrack) ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // Liquid glass ambient refraction tint (accent color glow)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) }
                GradientStop { position: 0.50; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Top specular hairline (light reflection across curved glass edge)
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 60
            height: 1
            color: Qt.rgba(255, 255, 255, 0.28)
        }

        // Inset Progress Bar (cleanly inset inside straight pill section so it never overflows)
        Item {
            id: miniProgressTrack
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 68
            height: 3

            Rectangle {
                anchors.fill: parent
                radius: 1.5
                color: Qt.rgba(255, 255, 255, 0.12)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 1.5
                width: lockMedia.trackLength > 0
                    ? parent.width * Math.max(0, Math.min(1.0, lockMedia.currentPosition / lockMedia.trackLength))
                    : 0
                color: root.accent

                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            anchors.verticalCenterOffset: -3
            spacing: 12

            // Circular Album Artwork thumbnail / Platform Icon
            Item {
                id: miniThumbContainer
                width: 40
                height: 40
                anchors.verticalCenter: parent.verticalCenter

                // Perfect circle mask via OpacityMask
                Item {
                    id: miniThumbMasked
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: miniThumbContainer.width
                            height: miniThumbContainer.height
                            radius: miniThumbContainer.width / 2
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(255, 255, 255, 0.08)
                    }

                    Image {
                        id: miniThumb
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 80
                        sourceSize.height: 80
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !miniThumb.visible
                        text: "󰝚"
                        font.family: root.iconFont
                        font.pixelSize: 18
                        color: root.accent
                    }
                }

                // Specular circular ring around cover
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.24)
                }
            }

            // Track Title & Artist (Clicking reveals the full unlock panel)
            MouseArea {
                id: miniTrackMa
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: parent.width - miniThumbContainer.width - 12 - miniCtrlRow.width - 12
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.ctx.reveal();
                    input.forceActiveFocus();
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: lockMedia.trackTitle || "Media playing"
                        font.family: theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: lockMedia.trackArtist || (lockMedia.currentPlatform.toUpperCase())
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        color: theme.textDim
                        elide: Text.ElideRight
                    }
                }
            }

            // Mini Playback Controls
            Row {
                id: miniCtrlRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Previous Track
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: miniPrevMa.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: root.iconFont
                        font.pixelSize: 15
                        color: theme.textSub
                    }

                    MouseArea {
                        id: miniPrevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (lockMedia.activePlayer && lockMedia.activePlayer.canGoPrevious)
                                lockMedia.activePlayer.previous();
                            root.ctx.poke();
                        }
                    }
                }

                // Play / Pause Button
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: root.accent
                    anchors.verticalCenter: parent.verticalCenter
                    scale: miniPlayMa.pressed ? 0.90 : (miniPlayMa.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: lockMedia.isPlaying ? 0 : 1
                        text: lockMedia.isPlaying ? "󰏤" : "󰐊"
                        font.family: root.iconFont
                        font.pixelSize: 15
                        color: "#000000"
                    }

                    MouseArea {
                        id: miniPlayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (lockMedia.activePlayer)
                                lockMedia.activePlayer.togglePlaying();
                            root.ctx.poke();
                        }
                    }
                }

                // Next Track
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: miniNextMa.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: root.iconFont
                        font.pixelSize: 15
                        color: theme.textSub
                    }

                    MouseArea {
                        id: miniNextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (lockMedia.activePlayer && lockMedia.activePlayer.canGoNext)
                                lockMedia.activePlayer.next();
                            root.ctx.poke();
                        }
                    }
                }
            }
        }
    }

    // ==========================================================================
    // CONTROL PANEL
    // ==========================================================================
    Column {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.miniTop + root.miniHeight + 24 + slide
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
            readonly property real rowH: Math.max(330, lockMedia.implicitHeight)

            Item {
                width: 350
                height: parent.rowH
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
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰝚"
                            color: theme.textDim
                            font.family: root.iconFont
                            font.pixelSize: 32
                            opacity: 0.4
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Nothing playing"
                            color: theme.textDim
                            font.family: theme.fontFamily
                            font.pixelSize: 14
                        }
                    }
                }
            }


            LockCalendarCard {
                id: lockCalendar
                width: 280
                height: parent.rowH
                now: root.ctx.now
                reminders: root.ctx.reminders
                accent: root.accent
                active: root.revealed
            }
        }

        LockRemindersCard {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 646
            now: root.ctx.now
            reminders: root.ctx.reminders
            accent: root.accent
            active: root.revealed
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

                // Caps Lock indicator badge (clean icon-only)
                Rectangle {
                    id: capsBadge
                    anchors.right: fpIcon.visible ? fpIcon.left : parent.right
                    anchors.rightMargin: fpIcon.visible ? 8 : 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.ctx.capsLock
                    width: 26
                    height: 26
                    radius: 13
                    color: Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.22)
                    border.width: 1
                    border.color: theme.peach

                    Text {
                        anchors.centerIn: parent
                        text: "󰪛"
                        font.family: root.iconFont
                        font.pixelSize: 14
                        color: theme.peach
                    }
                }

                Text {
                    id: fpIcon
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
            if (event.key === Qt.Key_CapsLock) {
                root.ctx.toggleCapsLockTentative();
                root.ctx.poke();
                return;
            }
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
