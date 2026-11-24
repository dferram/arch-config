import QtQuick
import QtQuick3D
import "../theme"

// High-detail interactive 3D replica of the wired Terport TR69N
// (69-key ISO-ES layout, smoked translucent pudding keycaps, 18 Full-RGB modes)
Item {
    id: root
    Theme { id: theme }

    property bool ledOn: true
    property string ledMode: "rainbow"
    property color ledColor: "#bf4148"
    property bool multiColor: true
    property real ledBrightness: 0.90
    property real ledSpeed: 1.0
    property bool connected: false
    property bool isLive: true

    // Smooth interpolated LED state for fluid color/brightness/on-off transitions
    property color smoothLedColor: root.ledColor
    Behavior on smoothLedColor { ColorAnimation { duration: 320; easing.type: Easing.InOutCubic } }

    property real smoothBrightness: (root.ledOn && root.ledMode !== "off") ? root.ledBrightness : 0.0
    Behavior on smoothBrightness { NumberAnimation { duration: 280; easing.type: Easing.InOutQuad } }

    property real yawAngle: -4
    property real tiltAngle: 26
    property real zoomFactor: 0.94
    property real phase: 0.0

    Behavior on zoomFactor {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    readonly property bool isAnimated: root.isLive && root.ledOn && root.ledMode !== "static" && root.ledMode !== "wasd_gaming" && root.ledMode !== "off"

    function resetCamera() {
        yawAngle = -4;
        tiltAngle = 26;
        zoomFactor = 0.94;
    }

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
        if (root.smoothBrightness <= 0.005) return Qt.rgba(0.06, 0.07, 0.09, 1.0);
        let nx = k.nx, nz = k.nz;
        let baseCol = root.smoothLedColor;
        let baseH = colorToHue(baseCol);
        let p = root.phase;

        switch (root.ledMode) {
            case "rainbow":
                return root.multiColor ? hsvToColor(nx * 0.85 + nz * 0.25 - p, 0.94, 1.0) : baseCol;
            case "horizontal_wave":
                return root.multiColor ? hsvToColor(nx - p, 0.92, 1.0) : baseCol;
            case "vertical_wave":
                return root.multiColor ? hsvToColor(nz - p, 0.92, 1.0) : baseCol;
            case "color_cycle":
                return root.multiColor ? hsvToColor(p, 0.92, 1.0) : baseCol;
            case "breathing_cycle":
                return root.multiColor ? hsvToColor(p * 0.5, 0.92, 1.0) : baseCol;
            case "col_scan":
            case "wide_sweep":
                return root.multiColor ? hsvToColor(nx * 0.6 + nz * 0.3 - p, 0.92, 1.0) : baseCol;
            case "pinwheel": {
                let ang = (Math.atan2(nz - 0.5, nx - 0.5) / 6.28318 + 1.0) % 1.0;
                return root.multiColor ? hsvToColor(ang - p, 0.92, 1.0) : baseCol;
            }
            case "reactive_cluster":
            case "inverted_reactive":
                return root.multiColor ? hsvToColor(nx * 0.65 + nz * 0.2 + p * 0.35, 0.92, 1.0) : baseCol;
            case "gradient":
                return root.multiColor
                    ? hsvToColor(nx * 0.45 + Math.sin(p * 6.28318) * 0.2, 0.90, 1.0)
                    : hsvToColor(baseH + 0.14 * Math.sin(nx * 3.14159 + p * 6.28318), 0.88, 1.0);
            case "sine_wave":
                return root.multiColor
                    ? hsvToColor(nx * 0.7 + p, 0.92, 1.0)
                    : baseCol;
            case "ripple": {
                let dist = Math.hypot(nx - 0.5, nz - 0.5);
                return root.multiColor ? hsvToColor(dist * 1.4 - p * 1.5, 0.92, 1.0) : baseCol;
            }
            case "center_split": {
                let d = Math.abs(nx - 0.5) * 2.0;
                return root.multiColor ? hsvToColor(d * 0.8 - p, 0.92, 1.0) : baseCol;
            }
            case "radar": {
                let ang = (Math.atan2(nz - 0.5, nx - 0.5) / 6.28318 + 1.0) % 1.0;
                return root.multiColor ? hsvToColor(ang - p, 0.92, 1.0) : baseCol;
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
                return baseCol;
            }
            case "wasd_gaming":
                return k.isGame ? (root.multiColor ? "#ff2d3b" : baseCol) : Qt.rgba(0.14, 0.16, 0.22, 1.0);
            case "breathing":
            case "static":
            default:
                return root.multiColor ? hsvToColor(nx * 0.65 + nz * 0.15, 0.90, 1.0) : baseCol;
        }
    }

    function keyLedIntensity(k) {
        if (root.smoothBrightness <= 0.005) return 0.0;
        let dim = root.connected ? 1.0 : 0.82;
        let b = root.smoothBrightness * dim;
        let nx = k.nx, nz = k.nz, p = root.phase;

        switch (root.ledMode) {
            case "rainbow":
            case "horizontal_wave": {
                if (root.multiColor) return b;
                let w = 0.5 + 0.5 * Math.sin((nx - p) * 6.28318);
                return b * (0.14 + 0.86 * w);
            }
            case "vertical_wave": {
                if (root.multiColor) return b;
                let w = 0.5 + 0.5 * Math.sin((nz - p) * 6.28318);
                return b * (0.14 + 0.86 * w);
            }
            case "breathing":
            case "breathing_cycle": {
                let pulse = 0.14 + 0.86 * (0.5 + 0.5 * Math.sin(p * 6.28318));
                return b * pulse;
            }
            case "col_scan": {
                let colSeed = hash01(k.col, 17.0);
                let head = (p * 1.65 + colSeed * 1.45) % 1.45;
                let dy = head - nz;
                let glow = (dy >= 0 && dy < 0.44) ? (1.0 - dy / 0.44) : 0.06;
                return b * glow;
            }
            case "pinwheel": {
                let ang = (Math.atan2(nz - 0.5, nx - 0.5) / 6.28318 + 1.0) % 1.0;
                let wave = 0.5 + 0.5 * Math.sin((ang - p) * 6.28318);
                return root.multiColor ? b : b * (0.48 + 0.52 * wave);
            }
            case "wide_sweep": {
                let center = 0.5 + 0.42 * Math.sin(p * 6.28318);
                let dist = Math.abs(nx - center);
                let band = dist < 0.22 ? 1.0 : (dist < 0.34 ? (1.0 - (dist - 0.22) / 0.12) : 0.08);
                return b * Math.max(0.08, band);
            }
            case "reactive_cluster": {
                let tSlot = Math.floor(p * 12.0);
                let sub = (p * 12.0) - tSlot;
                let targetX = 0.12 + hash01(tSlot, 7.0) * 0.76;
                let targetZ = 0.15 + hash01(tSlot, 29.0) * 0.70;
                let d = Math.hypot(nx - targetX, (nz - targetZ) * 0.65);
                let glow = d < 0.24 ? (1.0 - d / 0.24) * (1.0 - sub * 0.85) : 0.06;
                return b * Math.max(0.06, glow);
            }
            case "inverted_reactive": {
                let tSlot = Math.floor(p * 14.0);
                let sub = (p * 14.0) - tSlot;
                let targetRow = Math.floor(hash01(tSlot, 29.0) * 5.0);
                let targetCol = Math.floor(hash01(tSlot, 7.0) * 14.0);
                let isHit = (k.row === targetRow && k.col === targetCol);
                return b * (isHit ? (0.06 + 0.94 * sub) : 1.0);
            }
            case "ripple": {
                let dist = Math.hypot(nx - 0.5, nz - 0.5);
                let wave = 0.15 + 0.85 * Math.pow(0.5 + 0.5 * Math.sin(dist * 14.0 - p * 12.566), 2);
                return b * wave;
            }
            case "sine_wave": {
                let targetZ = 0.5 + 0.42 * Math.sin(nx * 9.5 - p * 6.28318);
                let d = Math.abs(nz - targetZ);
                return b * Math.max(0.08, 1.0 - d * 3.8);
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
                let tSlot = Math.floor(p * 16.0);
                let sub = (p * 16.0) - tSlot;
                let targetRow = Math.floor(hash01(tSlot, 29.0) * 5.0);
                let targetCol = Math.floor(hash01(tSlot, 7.0) * 14.0);
                let isHit = (k.row === targetRow && k.col === targetCol);
                return b * (isHit ? Math.max(0.08, 1.0 - sub) : 0.06);
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
        interval: 75
        repeat: true
        running: root.isAnimated
        onTriggered: {
            root.phase = (root.phase + 0.022 * root.ledSpeed) % 1.0;
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
                    "label": sp.l || "",
                    "sub": sp.s || "",
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
        // Row 0: Esc(X), 1..0, ', ¿, Bksp(2u), Supr
        addRow(0, [
            {w:1, l:"✕", esc:true, game:true},
            {w:1, l:"1", s:"F1"}, {w:1, l:"2", s:"F2"}, {w:1, l:"3", s:"F3"},
            {w:1, l:"4", s:"F4"}, {w:1, l:"5", s:"F5"}, {w:1, l:"6", s:"F6"},
            {w:1, l:"7", s:"F7"}, {w:1, l:"8", s:"F8"}, {w:1, l:"9", s:"F9"},
            {w:1, l:"0", s:"F10"}, {w:1, l:"'", s:"F11"}, {w:1, l:"¿", s:"F12"},
            {w:2, l:"←"}, {w:1, l:"Supr"}
        ]);
        // Row 1: Tab(1.5), Q..P, `, +, EnterTop(1.5), RePág(1)
        addRow(1, [
            {w:1.5, l:"Tab"},
            {w:1, l:"Q"}, {w:1, l:"W", game:true}, {w:1, l:"E"}, {w:1, l:"R"},
            {w:1, l:"T"}, {w:1, l:"Y"}, {w:1, l:"U"}, {w:1, l:"I"},
            {w:1, l:"O"}, {w:1, l:"P"}, {w:1, l:"`", s:"Ini"}, {w:1, l:"+", s:"Fin"},
            {w:1.5, l:"↵", enterTop:true}, {w:1, l:"RePág"}
        ]);
        // Row 2: Bloq Mayús(1.75), A..Ñ, ´, }, EnterBot(1.25), AvPág(1)
        addRow(2, [
            {w:1.75, l:"Bloq"},
            {w:1, l:"A", game:true}, {w:1, l:"S", game:true}, {w:1, l:"D", game:true},
            {w:1, l:"F"}, {w:1, l:"G"}, {w:1, l:"H"}, {w:1, l:"J"},
            {w:1, l:"K"}, {w:1, l:"L"}, {w:1, l:"Ñ", s:"Imp"}, {w:1, l:"´", s:"Ins"},
            {w:1, l:"}"}, {w:1.25, l:"", enterBot:true}, {w:1, l:"AvPág"}
        ]);
        // Row 3: Mayús(1.25), <>, Z..M, ,, ., -, Mayús(1.75), ▲, Fin
        addRow(3, [
            {w:1.25, l:"Mayús"}, {w:1, l:"<>"},
            {w:1, l:"Z"}, {w:1, l:"X"}, {w:1, l:"C"}, {w:1, l:"V"},
            {w:1, l:"B"}, {w:1, l:"N"}, {w:1, l:"M"},
            {w:1, l:","}, {w:1, l:"."}, {w:1, l:"-"},
            {w:1.75, l:"Mayús"}, {w:1, l:"▲", game:true}, {w:1, l:"Fin"}
        ]);
        // Row 4: Ctrl, Win, Alt, Space(6.25), AltGr, Fn, Menu, ◀, ▼, ▶
        addRow(4, [
            {w:1.25, l:"Ctrl"}, {w:1.25, l:"⊞"}, {w:1.25, l:"Alt"},
            {w:6.25, l:"TERPORT          —          TR69N", space:true},
            {w:1, l:"AltGr"}, {w:1, l:"Fn"}, {w:1, l:"▤"},
            {w:1, l:"◀", game:true}, {w:1, l:"▼", game:true}, {w:1, l:"▶", game:true}
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
            antialiasingQuality: SceneEnvironment.Medium
        }

        PerspectiveCamera {
            id: cam
            position: Qt.vector3d(0, 8.8 * root.zoomFactor, 12.2 * root.zoomFactor)
            eulerRotation: Qt.vector3d(-35.8, 0, 0)
            fieldOfView: 34
            clipNear: 0.5
            clipFar: 120
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-52, 26, 0)
            brightness: 1.55
            color: "#f8fafc"
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-22, -145, 0)
            brightness: 0.72
            color: "#94a3b8"
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-15, 165, 0)
            brightness: 0.42
            color: "#7dd3fc"
        }

        PointLight {
            position: Qt.vector3d(0, 4.2, 2.2)
            brightness: root.smoothBrightness > 0.005 ? (2.35 * root.smoothBrightness) : 0.25
            color: (root.multiColor && root.smoothBrightness > 0.005)
                ? root.hsvToColor(0.5 - root.phase, 0.85, 1.0)
                : (root.smoothBrightness > 0.005 ? root.smoothLedColor : "#334155")
            linearFade: 0.08
        }

        Node {
            id: kbRig
            position: Qt.vector3d(0, 0.12, 0)
            // Subtle natural keyboard typing wedge tilt (+5 deg forward slope) + orbit
            eulerRotation: Qt.vector3d(root.tiltAngle + 5, root.yawAngle, 0)

            Behavior on eulerRotation {
                enabled: !orbitMa.pressed
                Vector3dAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            // Ultra-Slim Smoked Polycarbonate Lower Base (Terport TR69N)
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.44, 0)
                scale: Qt.vector3d(0.165, 0.0056, 0.0535)
                materials: PrincipledMaterial {
                    baseColor: "#141210"
                    metalness: 0.25
                    roughness: 0.14
                    clearcoatAmount: 0.85
                    clearcoatRoughnessAmount: 0.08
                    specularAmount: 0.95
                }
            }

            // Frosted Smoked Acrylic Perimeter Underglow Strip
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.26, 0)
                scale: Qt.vector3d(0.1662, 0.0014, 0.0546)
                materials: PrincipledMaterial {
                    baseColor: "#26211c"
                    opacity: 0.72
                    alphaMode: PrincipledMaterial.Blend
                    emissiveFactor: root.smoothBrightness > 0.005
                        ? Qt.vector3d(
                            root.keyLedColor(root.keyLayout[34]).r * root.smoothBrightness * 0.35,
                            root.keyLedColor(root.keyLayout[34]).g * root.smoothBrightness * 0.35,
                            root.keyLedColor(root.keyLayout[34]).b * root.smoothBrightness * 0.35)
                        : Qt.vector3d(0, 0, 0)
                    roughness: 0.12
                }
            }

            // Inner Dark PCB / Switch Plate
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.10, 0)
                scale: Qt.vector3d(0.162, 0.0016, 0.0515)
                materials: PrincipledMaterial {
                    baseColor: "#0e0d0c"
                    metalness: 0.20
                    roughness: 0.24
                    emissiveFactor: root.smoothBrightness > 0.005
                        ? Qt.vector3d(
                            root.keyLedColor(root.keyLayout[34]).r * root.smoothBrightness * 0.32,
                            root.keyLedColor(root.keyLayout[34]).g * root.smoothBrightness * 0.32,
                            root.keyLedColor(root.keyLayout[34]).b * root.smoothBrightness * 0.32)
                        : Qt.vector3d(0, 0, 0)
                }
            }

            // Razor-Thin Glossy Smoked Acrylic Bezel Walls (lower profile so keycaps rise boldly above)
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.14, 2.66)
                scale: Qt.vector3d(0.166, 0.0064, 0.0018)
                materials: PrincipledMaterial { baseColor: "#1d1b18"; metalness: 0.28; roughness: 0.12; clearcoatAmount: 0.85; clearcoatRoughnessAmount: 0.08 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(0, -0.14, -2.66)
                scale: Qt.vector3d(0.166, 0.0064, 0.0018)
                materials: PrincipledMaterial { baseColor: "#1d1b18"; metalness: 0.28; roughness: 0.12; clearcoatAmount: 0.85; clearcoatRoughnessAmount: 0.08 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(-8.26, -0.14, 0)
                scale: Qt.vector3d(0.0018, 0.0064, 0.0548)
                materials: PrincipledMaterial { baseColor: "#1d1b18"; metalness: 0.28; roughness: 0.12; clearcoatAmount: 0.85; clearcoatRoughnessAmount: 0.08 }
            }
            Model {
                source: "#Cube"
                position: Qt.vector3d(8.26, -0.14, 0)
                scale: Qt.vector3d(0.0018, 0.0064, 0.0548)
                materials: PrincipledMaterial { baseColor: "#1d1b18"; metalness: 0.28; roughness: 0.12; clearcoatAmount: 0.85; clearcoatRoughnessAmount: 0.08 }
            }

            // 69 Crystal-Smoked Translucent Polycarbonate Keycaps + Visible '+' Cross-Stems
            Repeater3D {
                model: root.keyLayout
                delegate: Node {
                    required property var modelData
                    readonly property real u: 1.01
                    property color kCol: root.keyLedColor(modelData)
                    property real kInt: root.keyLedIntensity(modelData)
                    readonly property real yBase: 0.14 + modelData.rowHeightBias

                    Behavior on kCol { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on kInt { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

                    position: Qt.vector3d(modelData.cx * u, yBase, modelData.cz * u)

                    // 1. Bright PCB LED hotspot underneath switch
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, -0.14, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0056, 0.0014, modelData.d * u * 0.0056)
                        materials: PrincipledMaterial {
                            baseColor: kCol
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 3.1, kCol.g * kInt * 3.1, kCol.b * kInt * 3.1)
                            roughness: 0.25
                        }
                    }

                    // 2. Signature visible '+' mechanical switch cross-stem inside smoked keycap
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, 0.18, 0)
                        scale: Qt.vector3d(0.0034, 0.0048, 0.0010)
                        materials: PrincipledMaterial {
                            baseColor: "#2d2823"
                            roughness: 0.45
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.45, kCol.g * kInt * 0.45, kCol.b * kInt * 0.45)
                        }
                    }
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, 0.18, 0)
                        scale: Qt.vector3d(0.0010, 0.0048, 0.0034)
                        materials: PrincipledMaterial {
                            baseColor: "#2d2823"
                            roughness: 0.45
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.45, kCol.g * kInt * 0.45, kCol.b * kInt * 0.45)
                        }
                    }

                    // 3. Tall glossy smoked-glass lower skirt (OEM mechanical keycap base)
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, 0.09, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0091, 0.0044, modelData.d * u * 0.0091)
                        materials: PrincipledMaterial {
                            baseColor: "#2a231d"
                            opacity: 0.46
                            alphaMode: PrincipledMaterial.Blend
                            roughness: 0.08
                            specularAmount: 1.0
                            clearcoatAmount: 0.92
                            clearcoatRoughnessAmount: 0.06
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.65, kCol.g * kInt * 0.65, kCol.b * kInt * 0.65)
                        }
                    }

                    // 4. Mid tapered OEM wall for realistic 3D sculpted volume
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, 0.33, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0082, 0.0024, modelData.d * u * 0.0082)
                        materials: PrincipledMaterial {
                            baseColor: "#28221c"
                            opacity: 0.54
                            alphaMode: PrincipledMaterial.Blend
                            roughness: 0.08
                            specularAmount: 1.0
                            clearcoatAmount: 0.94
                            clearcoatRoughnessAmount: 0.06
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.46, kCol.g * kInt * 0.46, kCol.b * kInt * 0.46)
                        }
                    }

                    // 5. Sculpted glossy smoked polycarbonate top crown
                    Model {
                        source: "#Cube"
                        position: Qt.vector3d(0, 0.48, 0)
                        scale: Qt.vector3d(modelData.w * u * 0.0072, 0.0014, modelData.d * u * 0.0072)
                        materials: PrincipledMaterial {
                            baseColor: "#241f1a"
                            opacity: 0.62
                            alphaMode: PrincipledMaterial.Blend
                            roughness: 0.07
                            specularAmount: 1.0
                            clearcoatAmount: 0.95
                            clearcoatRoughnessAmount: 0.05
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.34, kCol.g * kInt * 0.34, kCol.b * kInt * 0.34)
                        }
                    }

                    // 6. Seamless ISO Enter bridge block connecting Row 1 & Row 2
                    Model {
                        visible: modelData.isEnterTop
                        source: "#Cube"
                        position: Qt.vector3d(0.125 * u, 0.24, 0.50 * u)
                        scale: Qt.vector3d(1.25 * u * 0.0076, 0.0062, 0.90 * u * 0.0076)
                        materials: PrincipledMaterial {
                            baseColor: "#26211c"
                            opacity: 0.56
                            alphaMode: PrincipledMaterial.Blend
                            roughness: 0.08
                            clearcoatAmount: 0.92
                            clearcoatRoughnessAmount: 0.06
                            emissiveFactor: Qt.vector3d(kCol.r * kInt * 0.36, kCol.g * kInt * 0.36, kCol.b * kInt * 0.36)
                        }
                    }
                }
            }

            // Single Crisp 2D Spanish ISO-ES Legend Overlay Sheet right on top of the sculpted keycaps
            Node {
                position: Qt.vector3d(0, 0.72, 0)
                eulerRotation: Qt.vector3d(-90, 0, 0)
                scale: Qt.vector3d(0.01616, 0.01616, 0.01616)

                Item {
                    width: 1000
                    height: 312.5
                    x: -width / 2
                    y: -height / 2

                    Repeater {
                        model: root.keyLayout
                        delegate: Item {
                            required property var modelData
                            readonly property real cellPx: 62.5
                            x: (modelData.cx + 8.0 - modelData.w / 2) * cellPx
                            y: (modelData.cz + 2.5 - modelData.d / 2) * cellPx
                            width: modelData.w * cellPx
                            height: modelData.d * cellPx

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: modelData.isSpace ? 20 : (modelData.isEsc ? 12 : 9)
                                anchors.leftMargin: modelData.isSpace ? 0 : 10
                                anchors.rightMargin: modelData.isSpace ? 0 : 10
                                horizontalAlignment: modelData.isSpace || modelData.isEsc ? Text.AlignHCenter : Text.AlignLeft
                                text: modelData.label
                                color: "#f8fafc"
                                font.family: theme.fontFamily
                                font.pixelSize: modelData.isEsc ? 26 : (modelData.isSpace ? 13 : (modelData.label.length > 2 ? 11 : 17))
                                font.weight: modelData.isEsc || modelData.isSpace ? Font.Bold : Font.DemiBold
                                opacity: 0.94
                            }

                            Text {
                                visible: modelData.sub !== ""
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.bottomMargin: 9
                                anchors.rightMargin: 10
                                text: modelData.sub
                                color: "#f5c542"
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                opacity: 0.88
                            }
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
        onWheel: (wheel) => {
            let step = wheel.angleDelta.y > 0 ? -0.08 : 0.08;
            root.zoomFactor = Math.max(0.60, Math.min(1.65, root.zoomFactor + step));
            wheel.accepted = true;
        }
        onDoubleClicked: root.resetCamera()
    }
}
