import QtQuick
import QtQuick3D
import "../theme"

// High-detail interactive 3D replica of the wired Terport TR69N
// (69-key ISO-ES layout, smoked translucent pudding keycaps, 18 Full-RGB modes)
Item {
    id: root
    Theme { id: theme }

    property string activeDevice: "keyboard" // "keyboard" | "monitor" | "mouse" | "base"
    property bool monitorConnected: false
    property string monitorStyle: "mark" // "mark" | "samsung"
    property bool mouseConnected: false
    property bool baseOn: false

    property bool ledOn: true
    property string ledMode: "rainbow"
    property color ledColor: "#bf4148"
    property bool multiColor: true
    property real ledBrightness: 0.90
    property real ledSpeed: 1.0
    property bool connected: false
    property bool isLive: true

    property real yawAngle: -14
    property real tiltAngle: 18
    property real phase: 0.0

    readonly property bool isAnimated: root.isLive && root.activeDevice === "keyboard" && root.ledOn && root.ledMode !== "static" && root.ledMode !== "wasd_gaming" && root.ledMode !== "off"

    function resetCamera() {
        if (activeDevice === "monitor") {
            yawAngle = -16;
            tiltAngle = 6;
        } else if (activeDevice === "mouse") {
            yawAngle = -36;
            tiltAngle = 22;
        } else if (activeDevice === "base") {
            yawAngle = -28;
            tiltAngle = 12;
        } else {
            yawAngle = -14;
            tiltAngle = 18;
        }
    }

    onActiveDeviceChanged: resetCamera()

    function hsvToColor(h, s, v) {
        let hue = ((h % 1.0) + 1.0) % 1.0;
        let i = Math.floor(hue * 6);
        let f = hue * 6 - i;
        let p = v * (1 - s);
        let q = v * (1 - f * s);
        let t = v * (1 - (1 - f) * s);
        let r = 0, g = 0, b = 0;
        switch (i % 6) {
            case 0: r = v; g = t; b = p; break;
            case 1: r = q; g = v; b = p; break;
            case 2: r = p; g = v; b = t; break;
            case 3: r = p; g = q; b = v; break;
            case 4: r = t; g = p; b = v; break;
            case 5: r = v; g = p; b = q; break;
        }
        return Qt.rgba(r, g, b, 1.0);
    }

    function colorToHue(col) {
        let r = col.r, g = col.g, b = col.b;
        let mx = Math.max(r, g, b), mn = Math.min(r, g, b);
        let d = mx - mn;
        if (d < 0.001) return 0.0;
        let h = 0.0;
        if (mx === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        else if (mx === g) h = ((b - r) / d + 2) / 6;
        else h = ((r - g) / d + 4) / 6;
        return h;
    }

    function hash01(a, b) {
        let x = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    function effectiveColor(hueOffset) {
        if (root.multiColor) return hsvToColor(hueOffset, 0.92, 1.0);
        return root.ledColor;
    }

    function keyLedColor(k) {
        if (!root.ledOn || root.ledMode === "off") return Qt.rgba(0.06, 0.07, 0.09, 1.0);
        let nx = k.nx, nz = k.nz;
        let baseH = colorToHue(root.ledColor);
        let p = root.phase;

        switch (root.ledMode) {
            case "rainbow":
                return hsvToColor(nx * 0.85 + nz * 0.25 - p, 0.94, 1.0);
            case "horizontal_wave":
                return hsvToColor(nx - p, 0.92, 1.0);
            case "vertical_wave":
                return hsvToColor(nz - p, 0.92, 1.0);
            case "color_cycle":
                return hsvToColor(p, 0.92, 1.0);
            case "gradient":
                return root.multiColor
                    ? hsvToColor(nx * 0.45 + Math.sin(p * 6.28318) * 0.2, 0.90, 1.0)
                    : hsvToColor(baseH + 0.14 * Math.sin(nx * 3.14159 + p * 6.28318), 0.88, 1.0);
            case "sine_wave":
                return root.multiColor
                    ? hsvToColor(nx * 0.7 + p, 0.92, 1.0)
                    : root.ledColor;
            case "ripple": {
                let dist = Math.hypot(nx - 0.5, nz - 0.5);
                return root.multiColor ? hsvToColor(dist * 1.4 - p * 1.5, 0.92, 1.0) : root.ledColor;
            }
            case "center_split": {
                let d = Math.abs(nx - 0.5) * 2.0;
                return root.multiColor ? hsvToColor(d * 0.8 - p, 0.92, 1.0) : root.ledColor;
            }
            case "radar": {
                let ang = (Math.atan2(nz - 0.5, nx - 0.5) / 6.28318 + 1.0) % 1.0;
                return root.multiColor ? hsvToColor(ang - p, 0.92, 1.0) : root.ledColor;
            }
            case "raindrop":
            case "starlight":
            case "marquee":
            case "collision":
            case "reactive_typing":
            case "crosshair": {
                if (root.multiColor) {
                    let h = (hash01(k.row, k.col) * 0.75 + p * 0.5 + nx * 0.25) % 1.0;
                    return hsvToColor(h, 0.92, 1.0);
                }
                return root.ledColor;
            }
            case "wasd_gaming":
                return k.isGame ? (root.multiColor ? "#ff2d3b" : root.ledColor) : Qt.rgba(0.14, 0.16, 0.22, 1.0);
            case "breathing":
            case "static":
            default:
                return root.multiColor ? hsvToColor(nx * 0.65 + nz * 0.15, 0.90, 1.0) : root.ledColor;
        }
    }

    function keyLedIntensity(k) {
        if (!root.ledOn || root.ledMode === "off") return 0.0;
        let dim = root.connected ? 1.0 : 0.82;
        let b = root.ledBrightness * dim;
        let nx = k.nx, nz = k.nz, p = root.phase;

        switch (root.ledMode) {
            case "breathing": {
                let pulse = 0.14 + 0.86 * (0.5 + 0.5 * Math.sin(p * 6.28318));
                return b * pulse;
            }
            case "ripple": {
                let dist = Math.hypot(nx - 0.5, nz - 0.5);
                let wave = 0.15 + 0.85 * Math.pow(0.5 + 0.5 * Math.sin(dist * 14.0 - p * 12.566), 2);
                return b * wave;
            }
            case "sine_wave": {
                let targetZ = 0.5 + 0.36 * Math.sin(nx * 8.0 - p * 6.28318);
                let d = Math.abs(nz - targetZ);
                return b * Math.max(0.14, 1.0 - d * 3.1);
            }
            case "marquee": {
                let idx = (k.row % 2 === 0) ? (k.row * 16 + k.col) : (k.row * 16 + (15 - k.col));
                let head = (p * 75.0) % 75.0;
                let dist = (head - idx + 75.0) % 75.0;
                return b * (dist < 14 ? (1.0 - dist / 14.0) : 0.10);
            }
            case "raindrop": {
                let colSeed = hash01(k.col, 13.0);
                let dropY = (p * (1.4 + colSeed) + colSeed) % 1.4;
                let dy = dropY - nz;
                let glow = (dy >= 0 && dy < 0.45) ? (1.0 - dy / 0.45) : 0.08;
                return b * glow;
            }
            case "starlight": {
                let seed = hash01(k.col, k.row);
                let tw = Math.pow(0.5 + 0.5 * Math.sin((p * 2.0 + seed * 6.28318) * 6.28318), 4);
                return b * (0.10 + 0.90 * tw);
            }
            case "center_split": {
                let d = Math.abs(nx - 0.5) * 2.0;
                let w = 0.5 + 0.5 * Math.sin(d * 6.28318 - p * 6.28318);
                return b * (0.18 + 0.82 * w);
            }
            case "collision": {
                let beamA = (p * 1.3) % 1.0;
                let beamB = 1.0 - beamA;
                let da = Math.abs(nx - beamA);
                let db = Math.abs(nx - beamB);
                let hit = Math.max(Math.max(0, 1.0 - da * 7.0), Math.max(0, 1.0 - db * 7.0));
                return b * Math.max(0.10, hit);
            }
            case "radar": {
                let ang = (Math.atan2(nz - 0.5, nx - 0.5) / 6.28318 + 1.0) % 1.0;
                let diff = (p - ang + 1.0) % 1.0;
                return b * (diff < 0.25 ? (1.0 - diff * 3.6) : 0.12);
            }
            case "reactive_typing": {
                let tSlot = Math.floor(p * 18.0);
                let activeSeed = hash01(tSlot, 7.0);
                let sub = (p * 18.0) - tSlot;
                let targetX = activeSeed;
                let targetZ = hash01(tSlot, 29.0);
                let d = Math.hypot(nx - targetX, (nz - targetZ) * 0.6);
                let burst = d < 0.18 ? (1.0 - sub) : 0.08;
                return b * Math.max(0.08, burst);
            }
            case "crosshair": {
                let cx = 0.5 + 0.45 * Math.sin(p * 6.28318);
                let cz = 0.5 + 0.42 * Math.cos(p * 6.28318 * 2.0);
                let dx = Math.abs(nx - cx);
                let dz = Math.abs(nz - cz);
                let hit = Math.max(dx < 0.07 ? 1.0 : 0.0, dz < 0.13 ? 1.0 : 0.0);
                return b * Math.max(0.10, hit);
            }
            case "wasd_gaming":
                return k.isGame ? b * 1.15 : b * 0.12;
            default:
                return b;
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: root.isAnimated
        onTriggered: {
            root.phase = (root.phase + 0.012 * root.ledSpeed) % 1.0;
        }
    }

    // Exact 69-key ISO-ES physical layout matching the Terport TR69N
    readonly property var keyLayout: {
        let keys = [];
        function addRow(rowIdx, specs) {
            let cur = 0;
            for (let i = 0; i < specs.length; i++) {
                let sp = specs[i];
                let w = sp.w;
                let d = sp.d || 1.0;
                let cz = (rowIdx + 0.5 - 2.5) + (sp.dz || 0);
                keys.push({
                    "cx": cur + w / 2 - 8.0,
                    "cz": cz,
                    "w": w,
                    "d": d,
                    "row": rowIdx,
                    "col": i,
                    "nx": (cur + w / 2) / 16.0,
                    "nz": (rowIdx + 0.5) / 5.0,
                    "isSpace": !!sp.space,
                    "isEsc": !!sp.esc,
                    "isGame": !!sp.game,
                    "isEnterTop": !!sp.enterTop,
                    "isEnterBot": !!sp.enterBot,
                    "rowHeightBias": (4 - rowIdx) * 0.025
                });
                cur += w;
            }
        }
        // Row 0: Esc, 1..0, ', ¿, Bksp(2u), Supr
        addRow(0, [
            {w:1, esc:true, game:true}, {w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:2},{w:1}
        ]);
        // Row 1: Tab(1.5), Q, W, E, R, T, Y, U, I, O, P, `, +, EnterTop(1.5), RePag(1)
        addRow(1, [
            {w:1.5}, {w:1},{w:1, game:true},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1.5, enterTop:true},{w:1}
        ]);
        // Row 2: BloqMayus(1.75), A, S, D, F, G, H, J, K, L, Ñ, ´, }, EnterBot(1.25), AvPag(1)
        addRow(2, [
            {w:1.75}, {w:1, game:true},{w:1, game:true},{w:1, game:true},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1.25, enterBot:true},{w:1}
        ]);
        // Row 3: ShiftL(1.25), <>, Z..M(7), ,, ., -, ShiftR(1.75), Up(1), End(1)
        addRow(3, [
            {w:1.25}, {w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1},{w:1.75},{w:1, game:true},{w:1}
        ]);
        // Row 4: Ctrl(1.25), Win(1.25), Alt(1.25), Space(6.25), AltGr(1), Fn(1), Menu(1), Left(1), Down(1), Right(1)
        addRow(4, [
            {w:1.25},{w:1.25},{w:1.25},{w:6.25, space:true},{w:1},{w:1},{w:1},{w:1, game:true},{w:1, game:true},{w:1, game:true}
        ]);
        return keys;
    }

    View3D {
        id: view3d
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "transparent"
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        PerspectiveCamera {
            id: cam
            position: {
                if (root.activeDevice === "monitor") return Qt.vector3d(0, 1.8, 21.8);
                if (root.activeDevice === "mouse") return Qt.vector3d(0, 4.2, 10.6);
                if (root.activeDevice === "base") return Qt.vector3d(0, 5.6, 19.2);
                return Qt.vector3d(0, 9.6, 21.0);
            }
            eulerRotation: {
                if (root.activeDevice === "monitor") return Qt.vector3d(-4.5, 0, 0);
                if (root.activeDevice === "mouse") return Qt.vector3d(-21, 0, 0);
                if (root.activeDevice === "base") return Qt.vector3d(-16, 0, 0);
                return Qt.vector3d(-24.5, 0, 0);
            }
            fieldOfView: 35
            clipNear: 0.5
            clipFar: 120
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-50, 28, 0)
            brightness: 1.45
            color: "#f1f5f9"
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-20, -145, 0)
            brightness: 0.65
            color: "#94a3b8"
        }

        PointLight {
            position: Qt.vector3d(0, 4.2, 2.2)
            brightness: {
                if (root.activeDevice === "base") return root.baseOn ? 1.8 : 0.35;
                if (root.activeDevice === "monitor") return root.monitorConnected ? 1.4 : 0.35;
                if (root.activeDevice === "mouse") return root.mouseConnected ? 1.8 : 1.15;
                return (root.ledOn && root.ledMode !== "off") ? (2.2 * root.ledBrightness) : 0.25;
            }
            color: {
                if (root.activeDevice === "base") return root.baseOn ? "#22d3ee" : "#334155";
                if (root.activeDevice === "monitor") return root.ledColor;
                if (root.activeDevice === "mouse") return "#cbd5e1";
                return (root.ledMode === "rainbow" || root.ledMode === "color_cycle")
                    ? root.hsvToColor(0.5 - root.phase, 0.85, 1.0)
                    : ((root.ledOn && root.ledMode !== "off") ? root.ledColor : "#334155");
            }
            linearFade: 0.08
        }

        // Orbitable Monitor 3D Node
        Node {
            visible: root.activeDevice === "monitor"
            position: Qt.vector3d(0, 0.08, 0)
            eulerRotation: Qt.vector3d(root.tiltAngle, root.yawAngle, 0)
            Behavior on eulerRotation {
                enabled: !orbitMa.pressed
                Vector3dAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            MonitorModel3D {
                connected: root.monitorConnected
                accentColor: root.ledColor
                monitorStyle: root.monitorStyle
            }
        }

        // Orbitable Mouse 3D Node
        Node {
            visible: root.activeDevice === "mouse"
            position: Qt.vector3d(0, -0.51, 0)
            eulerRotation: Qt.vector3d(root.tiltAngle, root.yawAngle, 0)
            Behavior on eulerRotation {
                enabled: !orbitMa.pressed
                Vector3dAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            MouseModel3D {
                connected: root.mouseConnected
            }
        }

        // Orbitable Cooling Base 3D Node
        Node {
            visible: root.activeDevice === "base"
            position: Qt.vector3d(0, 0.10, 0)
            eulerRotation: Qt.vector3d(root.tiltAngle, root.yawAngle, 0)
            Behavior on eulerRotation {
                enabled: !orbitMa.pressed
                Vector3dAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            CoolingBaseModel3D {
                baseOn: root.baseOn
                accentColor: "#06b6d4"
                isLive: root.isLive && root.activeDevice === "base"
            }
        }

        Node {
            id: kbRig
            visible: root.activeDevice === "keyboard"
            position: Qt.vector3d(0, -0.05, 0)
            // Subtle natural keyboard typing wedge tilt (+5 deg forward slope) + orbit
            eulerRotation: Qt.vector3d(root.tiltAngle + 5, root.yawAngle, 0)

            Behavior on eulerRotation {
                enabled: !orbitMa.pressed
                Vector3dAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            // Main Dark Smoked Translucent Case Lower Body
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.46, 0)
                scale: Qt.vector3d(0.172, 0.0078, 0.059)
                materials: PrincipledMaterial {
                    baseColor: "#101218"
                    metalness: 0.42
                    roughness: 0.36
                    specularAmount: 0.8
                }
            }

            // Glossy Smoked Acrylic Side Underglow Strip
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.34, 0)
                scale: Qt.vector3d(0.1725, 0.0014, 0.0595)
                materials: PrincipledMaterial {
                    baseColor: "#1b1f29"
                    opacity: 0.70
                    alphaMode: PrincipledMaterial.Blend
                    emissiveFactor: (root.ledOn && root.ledMode !== "off")
                        ? Qt.vector3d(
                            root.keyLedColor(root.keyLayout[34]).r * root.ledBrightness * 0.22,
                            root.keyLedColor(root.keyLayout[34]).g * root.ledBrightness * 0.22,
                            root.keyLedColor(root.keyLayout[34]).b * root.ledBrightness * 0.22)
                        : Qt.vector3d(0, 0, 0)
                    roughness: 0.2
                }
            }

            // Inner LED Switch Plate / Reflector Deck
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.10, 0)
                scale: Qt.vector3d(0.163, 0.0018, 0.052)
                materials: PrincipledMaterial {
                    baseColor: "#0a0c12"
                    metalness: 0.3
                    roughness: 0.22
                    emissiveFactor: (root.ledOn && root.ledMode !== "off")
                        ? Qt.vector3d(
                            root.keyLedColor(root.keyLayout[34]).r * root.ledBrightness * 0.30,
                            root.keyLedColor(root.keyLayout[34]).g * root.ledBrightness * 0.30,
                            root.keyLedColor(root.keyLayout[34]).b * root.ledBrightness * 0.30)
                        : Qt.vector3d(0, 0, 0)
                }
            }

            // Outer Bezel Walls (Front, Back, Left, Right)
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.05, 2.79)
                scale: Qt.vector3d(0.172, 0.0096, 0.0032)
                materials: PrincipledMaterial { baseColor: "#161922"; metalness: 0.50; roughness: 0.30 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.05, -2.79)
                scale: Qt.vector3d(0.172, 0.0096, 0.0032)
                materials: PrincipledMaterial { baseColor: "#161922"; metalness: 0.50; roughness: 0.30 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(-8.44, -0.05, 0)
                scale: Qt.vector3d(0.0032, 0.0096, 0.059)
                materials: PrincipledMaterial { baseColor: "#161922"; metalness: 0.50; roughness: 0.30 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(8.44, -0.05, 0)
                scale: Qt.vector3d(0.0032, 0.0096, 0.059)
                materials: PrincipledMaterial { baseColor: "#161922"; metalness: 0.50; roughness: 0.30 }
            }

            // Top-Left USB-C Housing + Wired Cable (like physical TR69N)
            Model {
                source: "#Cube"
                position: Qt.vector3d(-7.15, -0.22, -3.22)
                scale: Qt.vector3d(0.0090, 0.0052, 0.0085)
                materials: PrincipledMaterial {
                    baseColor: root.connected ? "#2a3345" : "#171a22"
                    metalness: 0.65
                    roughness: 0.28
                    emissiveFactor: root.connected ? Qt.vector3d(0.06, 0.32, 0.16) : Qt.vector3d(0, 0, 0)
                }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(-7.15, -0.24, -4.45)
                scale: Qt.vector3d(0.0024, 0.0024, 0.022)
                materials: PrincipledMaterial {
                    baseColor: root.connected ? "#384457" : "#15171c"
                    roughness: 0.6
                }
            }

            // 69 Sculpted Translucent Smoked Keycaps + Inner Stem LED Diffusers
            Repeater3D {
                model: root.keyLayout
                delegate: Node {
                    required property var modelData
                    readonly property real u: 1.01
                    readonly property color kCol: root.keyLedColor(modelData)
                    readonly property real kInt: root.keyLedIntensity(modelData)
                    readonly property real yBase: 0.14 + modelData.rowHeightBias

                    position: Qt.vector3d(modelData.cx * u, yBase, modelData.cz * u)

                    // 1. Bright PCB LED hotspot right underneath keycap
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, -0.14, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0058, 0.0014, modelData.d * u * 0.0058)
                        materials: PrincipledMaterial {
                            baseColor: kCol
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 2.8, kCol.g * kInt * 2.8, kCol.b * kInt * 2.8)
                            roughness: 0.3
                        }
                    }

                    // 2. Inner cross-stem / diffuser pillar visible through translucent keycap walls
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, 0.01, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0038, 0.0030, modelData.d * u * 0.0038)
                        materials: PrincipledMaterial {
                            baseColor: kCol
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 1.9, kCol.g * kInt * 1.9, kCol.b * kInt * 1.9)
                            roughness: 0.35
                        }
                    }

                    // 3. Smoked translucent lower keycap skirt (wider base)
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, -0.02, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0090, 0.0024, modelData.d * u * 0.0090)
                        materials: PrincipledMaterial {
                            baseColor: "#14171f"
                            opacity: 0.60
                            alphaMode: PrincipledMaterial.Blend
                            roughness: 0.18
                            specularAmount: 0.90
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.52, kCol.g * kInt * 0.52, kCol.b * kInt * 0.52)
                        }
                    }

                    // 4. Tapered upper keycap crown (narrower top surface, darker smoked tint)
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, 0.14, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0074, 0.0022, modelData.d * u * 0.0074)
                        materials: PrincipledMaterial {
                            baseColor: modelData.isEsc ? "#242834" : "#181b23"
                            opacity: 0.84
                            alphaMode: PrincipledMaterial.Blend
                            roughness: 0.24
                            specularAmount: 0.85
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.28, kCol.g * kInt * 0.28, kCol.b * kInt * 0.28)
                        }
                    }

                    // 5. Keycap glowing legend bar (replicates shine-through legends & Esc X / Terport Spacebar)
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(
                            modelData.isSpace ? 0 : (-modelData.w * u * 0.14),
                            0.255,
                            modelData.isSpace ? 0.08 : -0.14
                        )
                        scale: modelData.isSpace
                            ? Qt.vector3d(0.024, 0.0004, 0.0014)
                            : (modelData.isEsc ? Qt.vector3d(0.0036, 0.0005, 0.0036) : Qt.vector3d(0.0022, 0.0004, 0.0012))
                        materials: PrincipledMaterial {
                            baseColor: modelData.isEsc ? "#f8fafc" : "#cbd5e1"
                            emissiveFactor: modelData.isEsc
                                ? Qt.vector3d(0.55 + kCol.r * kInt * 0.5, 0.55 + kCol.g * kInt * 0.5, 0.58 + kCol.b * kInt * 0.5)
                                : Qt.vector3d(0.18 + kCol.r * kInt * 0.75, 0.18 + kCol.g * kInt * 0.75, 0.20 + kCol.b * kInt * 0.75)
                            roughness: 0.2
                        }
                    }

                    // 6. Seamless ISO Enter bridge block connecting Row 1 & Row 2
                    Model {
                        visible: modelData.isEnterTop
                        source: "#Cube"
                        position: Qt.vector3d(0.125 * u, 0.06, 0.50 * u)
                        scale: Qt.vector3d(1.25 * u * 0.0074, 0.0038, 0.90 * u * 0.0074)
                        materials: PrincipledMaterial {
                            baseColor: "#181b23"
                            opacity: 0.80
                            alphaMode: PrincipledMaterial.Blend
                            roughness: 0.24
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.32, kCol.g * kInt * 0.32, kCol.b * kInt * 0.32)
                        }
                    }
                }
            }
        }
    }

    // Orbit Drag + Double-Click to Reset Camera
    MouseArea {
        id: orbitMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton
        property real lastX: 0
        property real lastY: 0

        onPressed: (mouse) => {
            lastX = mouse.x;
            lastY = mouse.y;
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return;
            let dx = mouse.x - lastX;
            let dy = mouse.y - lastY;
            lastX = mouse.x;
            lastY = mouse.y;
            root.yawAngle = Math.max(-55, Math.min(55, root.yawAngle + dx * 0.45));
            root.tiltAngle = Math.max(-16, Math.min(48, root.tiltAngle + dy * 0.35));
        }
        onDoubleClicked: root.resetCamera()
    }
}
