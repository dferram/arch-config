import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
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

    function getResolvedArtUrl(url) {
        if (!url) return "";
        if (url.startsWith("https://i.scdn.co/image/")) {
            let id = url.substring(url.lastIndexOf("/") + 1).split("?")[0];
            if (id) return "file:///home/ferram/.cache/spotify-covers/" + id + ".jpg";
        }
        return url;
    }

    function getPastelWaveColor(col) {
        if (!col) return Qt.rgba(0.85, 0.82, 0.95, 0.95);
        let r = col.r, g = col.g, b = col.b;
        let max = Math.max(r, g, b);
        let min = Math.min(r, g, b);
        let d = max - min;
        let h = 0;
        if (d > 0.001) {
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
            else if (max === g) h = ((b - r) / d + 2) / 6;
            else h = ((r - g) / d + 4) / 6;
        }
        // Material You Tone 80/85 mapping: soft, luminous, aesthetic pastel
        let s = 0.38;
        let v = 0.94;
        let i = Math.floor(h * 6);
        let f = h * 6 - i;
        let p = v * (1 - s);
        let q = v * (1 - f * s);
        let t = v * (1 - (1 - f) * s);
        let mod = i % 6;
        let ro = [v, q, p, p, t, v][mod];
        let go = [t, v, v, q, p, p][mod];
        let bo = [p, p, t, v, v, q][mod];
        return Qt.rgba(ro, go, bo, 0.96);
    }
    property color waveColor: getPastelWaveColor(root.accent)
    Behavior on waveColor { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }

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
        opacity: root.revealed ? 1.0 : (root.hasArt ? 0.75 : 0.0)
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
            source: !root.flipArt ? root.getResolvedArtUrl(root.artUrl) : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            sourceSize.height: 640
            asynchronous: true
            visible: false

            onStatusChanged: {
                if (status === Image.Error && source.toString().indexOf(".cache/spotify-covers") !== -1) {
                    source = !root.flipArt ? root.artUrl : "";
                }
            }
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
            source: root.flipArt ? root.getResolvedArtUrl(root.artUrl) : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            sourceSize.height: 640
            asynchronous: true
            visible: false

            onStatusChanged: {
                if (status === Image.Error && source.toString().indexOf(".cache/spotify-covers") !== -1) {
                    source = root.flipArt ? root.artUrl : "";
                }
            }
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
                         : (root.height / 2 - height / 2 - (lockMedia.hasTrack ? 16 : 8) * root.baseScale)
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
    // TOP-RIGHT SYSTEM STATUS PILL (CPU, Wi-Fi, Battery)
    // Only visible when revealed (hidden in clean clock view)
    // ==========================================================================
    Rectangle {
        id: topStatusPill
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.max(18, Math.round(root.height * 0.024))
        anchors.rightMargin: Math.max(20, Math.round(root.width * 0.020))
        height: 34
        width: statusRow.implicitWidth + 24
        radius: 17
        clip: true
        color: statusPillMa.containsMouse ? root.glassHover : theme.popupBg
        border.width: 1
        border.color: statusPillMa.containsMouse ? theme.borderGlow : theme.border
        z: 30

        opacity: root.revealed ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        transform: Translate {
            y: root.revealed ? 0 : -10
            Behavior on y { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutExpo } }
        }

        scale: statusPillMa.pressed ? 0.96 : (statusPillMa.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Telemetry properties
        property int cpuPct: 0
        property bool wifiConnected: false
        property string wifiSsid: "Disconnected"
        property int wifiSignal: 0
        property int batteryFallbackPercent: 100
        property string batteryFallbackStatus: "Discharging"

        property int batteryPct: {
            if (UPower.displayDevice && UPower.displayDevice.ready && UPower.displayDevice.percentage > 0) {
                return Math.round(UPower.displayDevice.percentage * 100);
            }
            return batteryFallbackPercent;
        }

        property bool isCharging: {
            if (UPower.displayDevice && UPower.displayDevice.ready) {
                let s = UPower.displayDevice.state;
                return s === 1 || s === 4 || s === 5 || (!UPower.onBattery && batteryPct < 100);
            }
            return batteryFallbackStatus.toLowerCase().indexOf("charging") !== -1;
        }

        property color cpuColor: {
            if (cpuPct > 80) return theme.red;
            if (cpuPct > 55) return theme.peach;
            return theme.cyan;
        }

        property color wifiColor: wifiConnected ? theme.blue : theme.textMuted

        property color batteryColor: {
            if (batteryPct <= 15 && !isCharging) return theme.red;
            if (isCharging) return theme.green;
            return theme.blue;
        }

        // SVG Icons
        property string cpuIconUri: {
            let col = theme.urlColor(cpuColor);
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<rect x='4' y='4' width='16' height='16' rx='2.5'/>" +
                   "<rect x='9' y='9' width='6' height='6' rx='1' fill='" + col + "' stroke='none'/>" +
                   "<path d='M9 1v3 M15 1v3 M9 20v3 M15 20v3 M20 9h3 M20 15h3 M1 9h3 M1 15h3'/>" +
                   "</svg>";
        }

        property string wifiIconUri: {
            let col = theme.urlColor(wifiColor);
            if (!wifiConnected) {
                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'>" +
                       "<line x1='2' y1='2' x2='22' y2='22'/>" +
                       "<path d='M12 20h.01'/>" +
                       "<path d='M8.5 16.4a5 5 0 0 1 7 0'/>" +
                       "<path d='M4.9 12.8a10 10 0 0 1 3.2 -2.1'/>" +
                       "<path d='M14.5 11.5a10 10 0 0 1 4.6 1.3'/>" +
                       "<path d='M1.5 8.5a15 15 0 0 1 4.2 -2.6'/>" +
                       "<path d='M10.7 5a15 15 0 0 1 11.8 3.5'/>" +
                       "</svg>";
            }
            let outerOp = wifiSignal >= 70 ? "1" : "0.25";
            let midOp = wifiSignal >= 35 ? "1" : "0.25";
            let dotOp = "1";
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M1.5 8.5a15 15 0 0 1 21 0' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round' stroke-opacity='" + outerOp + "'/>" +
                   "<path d='M5 12.5a10 10 0 0 1 14 0' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round' stroke-opacity='" + midOp + "'/>" +
                   "<path d='M8.5 16.5a5 5 0 0 1 7 0' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round' stroke-opacity='" + dotOp + "'/>" +
                   "<circle cx='12' cy='20' r='1.3' fill='" + col + "' fill-opacity='" + dotOp + "'/>" +
                   "</svg>";
        }

        property string batteryIconUri: {
            let col = theme.urlColor(batteryColor);
            let fillW = Math.max(1.8, Math.min(12.0, (batteryPct / 100.0) * 12.0));
            let nub = "<path d='M19 10.2 h1.2 c0.6 0 1.0 0.4 1.0 1.0 v1.6 c0 0.6 -0.4 1.0 -1.0 1.0 H19' fill='" + col + "'/>";
            if (isCharging) {
                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                       "<rect x='2.5' y='6.5' width='16' height='11' rx='2.5' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/>" + nub +
                       "<path d='M11.5 7 L8 12 h3.5 L9.5 17 L14 11.5 h-3 z' fill='" + col + "'/></svg>";
            } else {
                return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                       "<rect x='2.5' y='6.5' width='16' height='11' rx='2.5' stroke='" + col + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/>" + nub +
                       "<rect x='4.5' y='8.5' width='12' height='7' rx='1.2' fill='" + col + "' fill-opacity='0.16'/>" +
                       "<rect x='4.5' y='8.5' width='" + fillW + "' height='7' rx='1.2' fill='" + col + "'/></svg>";
            }
        }

        // Processes & Timers
        Process {
            id: cpuTelemetryProc
            command: ["/home/ferram/.local/bin/hypr-resources"]
            running: true
            stdout: StdioCollector {
                onTextChanged: {
                    let txt = text.trim();
                    if (!txt) return;
                    try {
                        let d = JSON.parse(txt);
                        topStatusPill.cpuPct = d.cpu || 0;
                    } catch(e) {}
                }
            }
        }

        Process {
            id: wifiTelemetryProc
            command: ["python3", Quickshell.shellPath("scripts/wifi-details.py")]
            running: true
            stdout: StdioCollector {
                onTextChanged: {
                    let txt = text.trim();
                    if (!txt) return;
                    try {
                        let d = JSON.parse(txt);
                        topStatusPill.wifiConnected = d.connected || false;
                        topStatusPill.wifiSsid = d.ssid || "Disconnected";
                        topStatusPill.wifiSignal = d.signal || 0;
                    } catch(e) {}
                }
            }
        }

        Process {
            id: batteryFallbackProc
            command: ["python3", Quickshell.shellPath("scripts/battery-details.py")]
            running: true
            stdout: StdioCollector {
                onTextChanged: {
                    let txt = text.trim();
                    if (!txt) return;
                    try {
                        let d = JSON.parse(txt);
                        if (d.capacity !== undefined && d.capacity > 0)
                            topStatusPill.batteryFallbackPercent = d.capacity;
                        if (d.status)
                            topStatusPill.batteryFallbackStatus = d.status;
                    } catch(e) {}
                }
            }
        }

        Connections {
            target: root
            function onRevealedChanged() {
                if (root.revealed) {
                    if (!cpuTelemetryProc.running) cpuTelemetryProc.running = true;
                    if (!wifiTelemetryProc.running) wifiTelemetryProc.running = true;
                    if (!batteryFallbackProc.running) batteryFallbackProc.running = true;
                }
            }
        }

        Timer {
            interval: 3000
            running: root.revealed
            repeat: true
            onTriggered: {
                if (!cpuTelemetryProc.running) cpuTelemetryProc.running = true;
            }
        }

        Timer {
            interval: 6000
            running: root.revealed
            repeat: true
            onTriggered: {
                if (!wifiTelemetryProc.running) wifiTelemetryProc.running = true;
                if (!batteryFallbackProc.running) batteryFallbackProc.running = true;
            }
        }

        // Top specular hairline (Apple liquid glass hallmark)
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: Qt.rgba(255, 255, 255, 0.22) }
                GradientStop { position: 0.75; color: Qt.rgba(255, 255, 255, 0.22) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Content Row
        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 12

            // 1. CPU
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Image {
                    width: 15
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter
                    source: topStatusPill.cpuIconUri
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: topStatusPill.cpuPct + "%"
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            // Separator 1
            Rectangle {
                width: 1
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                color: theme.borderSubtle
            }

            // 2. Wi-Fi
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Image {
                    width: 15
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter
                    source: topStatusPill.wifiIconUri
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: topStatusPill.wifiConnected ? topStatusPill.wifiSsid : "Sin Wi-Fi"
                    color: topStatusPill.wifiConnected ? theme.text : theme.textMuted
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, 110)
                }
            }

            // Separator 2
            Rectangle {
                width: 1
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                color: theme.borderSubtle
            }

            // 3. Battery
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Image {
                    width: 15
                    height: 15
                    anchors.verticalCenter: parent.verticalCenter
                    source: topStatusPill.batteryIconUri
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: topStatusPill.batteryPct + "%"
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        MouseArea {
            id: statusPillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onClicked: root.ctx.poke()
        }
    }

    // ==========================================================================
    // POWER ACTIONS — Restart & Shutdown (Bottom right corner, revealed only, icon-only)
    // ==========================================================================
    Process {
        id: powerProc
    }

    Row {
        id: powerActionsRow
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: Math.max(18, Math.round(root.height * 0.024))
        anchors.rightMargin: Math.max(20, Math.round(root.width * 0.020))
        spacing: 10
        z: 30

        opacity: root.revealed ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        transform: Translate {
            y: root.revealed ? 0 : 10
            Behavior on y { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutExpo } }
        }

        // Restart button (Icon-only, dark liquid glass)
        Rectangle {
            id: rebootBtn
            width: 38
            height: 38
            radius: 19
            clip: true
            color: rebootConfirmTimer.running
                ? Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.22)
                : (rebootMa.containsMouse ? root.glassHover : theme.popupBg)
            border.width: 1
            border.color: rebootConfirmTimer.running
                ? theme.peach
                : (rebootMa.containsMouse ? theme.borderGlow : theme.border)

            scale: rebootMa.pressed ? 0.92 : (rebootMa.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Specular top hairline
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.3; color: Qt.rgba(255, 255, 255, 0.25) }
                    GradientStop { position: 0.7; color: Qt.rgba(255, 255, 255, 0.25) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Timer {
                id: rebootConfirmTimer
                interval: 3000
                onTriggered: {}
            }

            Image {
                anchors.centerIn: parent
                width: 17
                height: 17
                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(rebootConfirmTimer.running ? theme.peach : theme.blue) + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><polyline points='23 4 23 10 17 10'/><path d='M20.49 15a9 9 0 1 1-2.12-9.36L23 10'/></svg>"
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                id: rebootMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onClicked: {
                    root.ctx.poke();
                    if (rebootConfirmTimer.running) {
                        powerProc.command = ["systemctl", "reboot"];
                        powerProc.running = true;
                    } else {
                        rebootConfirmTimer.restart();
                        shutdownConfirmTimer.stop();
                    }
                }
            }
        }

        // Shutdown button (Icon-only, dark liquid glass)
        Rectangle {
            id: shutdownBtn
            width: 38
            height: 38
            radius: 19
            clip: true
            color: shutdownConfirmTimer.running
                ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.22)
                : (shutdownMa.containsMouse ? root.glassHover : theme.popupBg)
            border.width: 1
            border.color: shutdownConfirmTimer.running
                ? theme.red
                : (shutdownMa.containsMouse ? theme.borderGlow : theme.border)

            scale: shutdownMa.pressed ? 0.92 : (shutdownMa.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Specular top hairline
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.3; color: Qt.rgba(255, 255, 255, 0.25) }
                    GradientStop { position: 0.7; color: Qt.rgba(255, 255, 255, 0.25) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Timer {
                id: shutdownConfirmTimer
                interval: 3000
                onTriggered: {}
            }

            Image {
                anchors.centerIn: parent
                width: 17
                height: 17
                source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(shutdownConfirmTimer.running ? theme.red : theme.red) + "' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><path d='M18.36 6.64a9 9 0 1 1-12.73 0'/><line x1='12' y1='2' x2='12' y2='12'/></svg>"
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                id: shutdownMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                onClicked: {
                    root.ctx.poke();
                    if (shutdownConfirmTimer.running) {
                        powerProc.command = ["systemctl", "poweroff"];
                        powerProc.running = true;
                    } else {
                        shutdownConfirmTimer.restart();
                        rebootConfirmTimer.stop();
                    }
                }
            }
        }
    }

    // ==========================================================================
    // MINI MEDIA PILL (idle flip-clock mode) — Dark Obsidian Liquid Glass capsule
    // ==========================================================================
    Rectangle {
        id: miniMediaPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(16, Math.round(root.height * 0.022))
        width: Math.min(360, root.width - 40)
        height: 50
        radius: 25
        color: Qt.rgba(0.04, 0.04, 0.06, 0.88)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.10)

        opacity: (!root.revealed && lockMedia.hasTrack) ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // 1. Subtle album artwork background (dimmed / tenue, Android style)
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: miniMediaPill.width
                    height: miniMediaPill.height
                    radius: miniMediaPill.radius
                }
            }

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 360
                sourceSize.height: 120
                asynchronous: true
                visible: root.hasArt && status === Image.Ready
                opacity: 0.12

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(4, 5, 8, 0.80)
                }
            }
        }

        // 2. Liquid glass ambient refraction tint (soft subtle accent glow)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12) }
                GradientStop { position: 0.40; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.02) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // 3. Top specular hairline (light reflection across curved dark glass edge)
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 48
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: Qt.rgba(255, 255, 255, 0.14) }
                GradientStop { position: 0.75; color: Qt.rgba(255, 255, 255, 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // 4. Inset Progress Bar (matching top bar MediaWidget, cleanly inset within the pill)
        Item {
            id: miniProgressTrack
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            height: 3
            visible: lockMedia.trackLength > 0

            // Unplayed track trough
            Rectangle {
                id: miniProgressTrough
                anchors.fill: parent
                radius: 1.5
                color: Qt.rgba(255, 255, 255, 0.08)
            }

            // Played track fill (matching top bar MediaWidget styling and mediaAccentColor)
            Rectangle {
                id: miniProgressFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 1.5
                width: {
                    if (lockMedia.trackLength <= 0) return 0;
                    let cur = lockMedia.currentPosition;
                    let pct = Math.max(0, Math.min(1.0, cur / lockMedia.trackLength));
                    return Math.round(parent.width * pct);
                }
                color: root.accent

                Behavior on width {
                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                }
            }

            // Click & drag to seek
            MouseArea {
                id: seekMa
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -6
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                preventStealing: true

                function handleSeek(mouseX) {
                    let r = Math.max(0, Math.min(1.0, mouseX / miniProgressTrack.width));
                    lockMedia.seekToRatio(r);
                    root.ctx.poke();
                }

                onClicked: mouse => handleSeek(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed) handleSeek(mouse.x);
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            anchors.verticalCenterOffset: -4
            spacing: 10

            // Circular Album Artwork thumbnail / Platform Icon
            Item {
                id: miniThumbContainer
                width: 30
                height: 30
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
                        color: Qt.rgba(0, 0, 0, 0.40)
                    }

                    Image {
                        id: miniThumb
                        anchors.fill: parent
                        source: root.getResolvedArtUrl(root.artUrl)
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 64
                        sourceSize.height: 64
                        asynchronous: true
                        visible: status === Image.Ready

                        onStatusChanged: {
                            if (status === Image.Error && source.toString().indexOf(".cache/spotify-covers") !== -1) {
                                source = root.artUrl;
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !miniThumb.visible
                        text: "󰝚"
                        font.family: root.iconFont
                        font.pixelSize: 15
                        color: root.accent
                    }
                }

                // Specular circular ring around cover
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                }
            }

            // Track Title & Artist (Clicking reveals the full unlock panel)
            MouseArea {
                id: miniTrackMa
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: Math.max(60, miniMediaPill.width - miniThumbContainer.width - miniCtrlRow.width - 48)
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.ctx.reveal();
                    input.forceActiveFocus();
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: lockMedia.trackTitle || "Media playing"
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Qt.rgba(255, 255, 255, 0.88)
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: lockMedia.trackArtist || (lockMedia.currentPlatform.toUpperCase())
                        font.family: theme.fontFamily
                        font.pixelSize: 10
                        color: Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.75)
                        elide: Text.ElideRight
                    }
                }
            }

            // Mini Playback Controls
            Row {
                id: miniCtrlRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Previous Track
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: miniPrevMa.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: root.iconFont
                        font.pixelSize: 13
                        color: miniPrevMa.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.70)
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

                // Play / Pause Button (Dark liquid glass pill, soft white icon)
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: miniPlayMa.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                    border.width: 1
                    border.color: miniPlayMa.containsMouse ? root.waveColor : Qt.rgba(255, 255, 255, 0.08)
                    anchors.verticalCenter: parent.verticalCenter
                    scale: miniPlayMa.pressed ? 0.92 : (miniPlayMa.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: lockMedia.isPlaying ? 0 : 1
                        text: lockMedia.isPlaying ? "󰏤" : "󰐊"
                        font.family: root.iconFont
                        font.pixelSize: 13
                        color: "#ffffff"
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
                    width: 26
                    height: 26
                    radius: 13
                    color: miniNextMa.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: root.iconFont
                        font.pixelSize: 13
                        color: miniNextMa.containsMouse ? "#ffffff" : Qt.rgba(255, 255, 255, 0.70)
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
        scale: Math.min(1, (root.width - 40) / Math.max(646, cardsRow.implicitWidth), (root.height - y - 24) / Math.max(1, implicitHeight))
        transformOrigin: Item.Top
        spacing: 24

        property real slide: root.revealed ? 0 : 40
        Behavior on slide { NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutExpo } }
        opacity: root.revealed ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        // The bar's media card, calendar, and NSQK Mosca countdown card
        Row {
            id: cardsRow
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
                    color: Qt.rgba(0.04, 0.04, 0.06, 0.88)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.10)
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

            LockDoomsdayCountdownCard {
                id: doomsdayCountdown
                width: 280
                height: parent.rowH
                reminders: root.ctx.reminders
                accent: "#10b981"
                active: root.revealed
            }

            LockEventCountdownCard {
                id: eventCountdown
                width: 310
                height: parent.rowH
                reminders: root.ctx.reminders
                accent: root.accent
                active: root.revealed
            }
        }

        LockRemindersCard {
            anchors.horizontalCenter: parent.horizontalCenter
            width: cardsRow.implicitWidth
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
            if (text.length > 0) root.ctx.resetQuickUnlock();
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
            if (event.isAutoRepeat) return;

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.ctx.tryQuickUnlock()) {
                    event.accepted = true;
                    return;
                }
                if (!root.ctx.revealed) {
                    root.ctx.reveal();
                    event.accepted = true;
                    return;
                }
                if (root.ctx.password.length === 0) {
                    event.accepted = true;
                    return;
                }
            } else {
                root.ctx.resetQuickUnlock();
            }

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
