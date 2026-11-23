import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

// Realistic sculpted 3D HP 150/200 matte-black mouse
// True rounded-front/rear superellipse footprint + inward-angled glossy side walls
// + smooth matte top deck + flush scroll-wheel recess + ribbed scroll wheel.
Node {
    id: root

    property bool connected: false

    function topHeightAt(x, z, rFrac) {
        // z in [-2.75 .. +2.75], normalize s in [-1 .. +1]
        let s = Math.max(-1.0, Math.min(1.0, z / 2.75));
        // Ridge profile along Z: front lip ~0.26, rises smoothly to peak ~1.24 at s=0.18, rear lip ~0.34
        let arch = 0.30 + 0.94 * Math.pow(Math.max(0.0, Math.cos(s * Math.PI * 0.44 - 0.12)), 1.35);
        // Smooth cross-sectional crown from shoulder edge (rFrac=1) to centerline (rFrac=0)
        let edgeLip = 0.24 + 0.10 * (s + 1.0) * 0.5;
        let crown = edgeLip + (arch - edgeLip) * Math.pow(Math.max(0.0, 1.0 - rFrac * rFrac), 0.52);

        // Subtle scroll wheel well carved cleanly in front center
        let dx = x / 0.22;
        let dz = (z + 1.36) / 0.44;
        let well = Math.exp(-(dx * dx * dx * dx + dz * dz * dz * dz));
        crown -= 0.22 * well;

        // Hairline button split groove ahead of scroll wheel
        if (z < -1.80 && Math.abs(x) < 0.032) {
            crown -= 0.025 * (1.0 - Math.abs(x) / 0.032);
        }
        return crown;
    }

    function footprintRadiusAt(phi) {
        let cx = Math.sin(phi);
        let cz = -Math.cos(phi);
        let halfW = 1.54 + 0.14 * cz - 0.06 * Math.exp(-Math.pow((cz + 0.18) / 0.35, 2));
        let halfL = 2.75;
        let rNorm = Math.pow(Math.pow(Math.abs(cx), 2.55) + Math.pow(Math.abs(cz), 2.85), -1.0 / 2.70);
        return { x: cx * rNorm * halfW, z: cz * rNorm * halfL };
    }

    function buildScrollBezel(geom) {
        // Flush glossy-black tapered scroll-wheel island hugging the exact top shell curvature
        const nZ = 28;
        const nX = 12;
        const zStart = -2.18;
        const zEnd = -0.46;

        let pts = [];
        let idx = [];
        let normAcc = [];

        for (let i = 0; i <= nZ; i++) {
            let fz = i / nZ; // 0 = front, 1 = rear rounded tip
            let z = zStart + fz * (zEnd - zStart);
            // Wide rounded pill around scroll wheel, tapering cleanly toward rear point
            let envFront = Math.pow(Math.sin(Math.min(1.0, fz / 0.18) * Math.PI * 0.5), 0.55);
            let envRear = Math.pow(Math.sin(Math.min(1.0, (1.0 - fz) / 0.36) * Math.PI * 0.5), 0.60);
            let halfW = Math.max(0.015, 0.32 * envFront * envRear);

            for (let j = 0; j <= nX; j++) {
                let fx = (j / nX) * 2.0 - 1.0; // -1..+1
                let x = fx * halfW;
                // Approximate rFrac using local shell half-width (~1.42)
                let rFrac = Math.min(0.95, Math.hypot(x / 1.42, z / 2.75));
                let y = topHeightAt(x, z, rFrac) + 0.008 * (1.0 - 0.5 * fx * fx);
                pts.push(Qt.vector3d(x, y, z));
                normAcc.push(Qt.vector3d(0, 0, 0));
            }
        }

        let stride = nX + 1;
        for (let i = 0; i < nZ; i++) {
            for (let j = 0; j < nX; j++) {
                let a = i * stride + j;
                let b = (i + 1) * stride + j;
                let c = (i + 1) * stride + (j + 1);
                let d = i * stride + (j + 1);
                idx.push(a, b, c, a, c, d);
                let va = pts[a], vb = pts[b], vc = pts[c], vd = pts[d];
                let n1 = vb.minus(va).crossProduct(vc.minus(va));
                let n2 = vc.minus(va).crossProduct(vd.minus(va));
                normAcc[a] = normAcc[a].plus(n1).plus(n2);
                normAcc[b] = normAcc[b].plus(n1);
                normAcc[c] = normAcc[c].plus(n1).plus(n2);
                normAcc[d] = normAcc[d].plus(n2);
            }
        }

        let finalNormals = [];
        for (let k = 0; k < normAcc.length; k++) {
            let n = normAcc[k];
            let len = Math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
            finalNormals.push(len > 0.00001 ? Qt.vector3d(n.x / len, n.y / len, n.z / len) : Qt.vector3d(0, 1, 0));
        }
        geom.primitiveMode = ProceduralMesh.Triangles;
        geom.positions = pts;
        geom.normals = finalNormals;
        geom.indexes = idx;
        geom.updateGeometry();
    }

    // Builds the full closed mouse body with crisp undercut side walls and smooth top arch
    function buildMouseBody(geom, part) {
        const nPhi = 72;
        const nRing = 20;

        let pts = [];
        let idx = [];
        let normAcc = [];

        if (part === "top") {
            // Smooth matte top shell from center (rFrac=0) out to shoulder bevel (rFrac=1)
            for (let r = 0; r <= nRing; r++) {
                let rFrac = r / nRing;
                for (let a = 0; a <= nPhi; a++) {
                    let phi = (a / nPhi) * Math.PI * 2.0;
                    let fp = footprintRadiusAt(phi);
                    let px = fp.x * rFrac;
                    let pz = fp.z * rFrac;
                    let py = topHeightAt(px, pz, rFrac);
                    pts.push(Qt.vector3d(px, py, pz));
                    normAcc.push(Qt.vector3d(0, 0, 0));
                }
            }
            let stride = nPhi + 1;
            for (let r = 0; r < nRing; r++) {
                for (let a = 0; a < nPhi; a++) {
                    let i0 = r * stride + a;
                    let i1 = (r + 1) * stride + a;
                    let i2 = (r + 1) * stride + (a + 1);
                    let i3 = r * stride + (a + 1);
                    // Winding for +Y outward normal
                    idx.push(i0, i3, i2, i0, i2, i1);
                    let v0 = pts[i0], v1 = pts[i1], v2 = pts[i2], v3 = pts[i3];
                    let n1 = v3.minus(v0).crossProduct(v2.minus(v0));
                    let n2 = v2.minus(v0).crossProduct(v1.minus(v0));
                    normAcc[i0] = normAcc[i0].plus(n1).plus(n2);
                    normAcc[i3] = normAcc[i3].plus(n1);
                    normAcc[i2] = normAcc[i2].plus(n1).plus(n2);
                    normAcc[i1] = normAcc[i1].plus(n2);
                }
            }
        } else {
            // Glossy undercut side wall from shoulder (rFrac=1, y=edgeLip) down to desk base (scale=0.80, y=0)
            const nWall = 6;
            for (let w = 0; w <= nWall; w++) {
                let f = w / nWall; // 0 = shoulder top, 1 = bottom desk edge
                let inset = 1.0 - 0.20 * Math.pow(f, 0.85); // Real mouse inward undercut!
                for (let a = 0; a <= nPhi; a++) {
                    let phi = (a / nPhi) * Math.PI * 2.0;
                    let fp = footprintRadiusAt(phi);
                    let topY = topHeightAt(fp.x, fp.z, 1.0);
                    let py = topY * (1.0 - f);
                    pts.push(Qt.vector3d(fp.x * inset, py, fp.z * inset));
                    normAcc.push(Qt.vector3d(0, 0, 0));
                }
            }
            let stride = nPhi + 1;
            for (let w = 0; w < nWall; w++) {
                for (let a = 0; a < nPhi; a++) {
                    let i0 = w * stride + a;
                    let i1 = (w + 1) * stride + a;
                    let i2 = (w + 1) * stride + (a + 1);
                    let i3 = w * stride + (a + 1);
                    idx.push(i0, i3, i2, i0, i2, i1);
                    let v0 = pts[i0], v1 = pts[i1], v2 = pts[i2], v3 = pts[i3];
                    let n1 = v3.minus(v0).crossProduct(v2.minus(v0));
                    let n2 = v2.minus(v0).crossProduct(v1.minus(v0));
                    normAcc[i0] = normAcc[i0].plus(n1).plus(n2);
                    normAcc[i3] = normAcc[i3].plus(n1);
                    normAcc[i2] = normAcc[i2].plus(n1).plus(n2);
                    normAcc[i1] = normAcc[i1].plus(n2);
                }
            }
            // Flat closed bottom plate at y=0
            let centerIdx = pts.length;
            pts.push(Qt.vector3d(0, 0, 0));
            normAcc.push(Qt.vector3d(0, -1, 0));
            let baseStart = nWall * stride;
            for (let a = 0; a < nPhi; a++) {
                idx.push(centerIdx, baseStart + a, baseStart + a + 1);
            }
        }

        let finalNormals = [];
        for (let k = 0; k < normAcc.length; k++) {
            let n = normAcc[k];
            let len = Math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
            finalNormals.push(len > 0.00001 ? Qt.vector3d(n.x / len, n.y / len, n.z / len) : Qt.vector3d(0, 1, 0));
        }

        geom.primitiveMode = ProceduralMesh.Triangles;
        geom.positions = pts;
        geom.normals = finalNormals;
        geom.indexes = idx;
        geom.updateGeometry();
    }

    // 1. Matte Charcoal-Black Sculpted Top Shell (HP 150 texture)
    Model {
        geometry: ProceduralMesh {
            id: topShellGeom
            Component.onCompleted: root.buildMouseBody(topShellGeom, "top")
        }
        materials: PrincipledMaterial {
            baseColor: "#22252d"
            metalness: 0.06
            roughness: 0.50
            specularAmount: 0.45
        }
    }

    // 2. Glossy Black Undercut Side Skirts + Flat Desk Base
    Model {
        geometry: ProceduralMesh {
            id: sideSkirtGeom
            Component.onCompleted: root.buildMouseBody(sideSkirtGeom, "wall")
        }
        materials: PrincipledMaterial {
            baseColor: "#0e1015"
            metalness: 0.15
            roughness: 0.16
            specularAmount: 0.88
        }
    }

    // 3. Flush Glossy-Black Tapered Center Scroll Housing (conforms 100% to top shell)
    Model {
        geometry: ProceduralMesh {
            id: scrollBezelGeom
            Component.onCompleted: root.buildScrollBezel(scrollBezelGeom)
        }
        materials: PrincipledMaterial {
            baseColor: "#0a0b0f"
            metalness: 0.16
            roughness: 0.14
            specularAmount: 0.92
        }
    }

    // 4. All-Black Ribbed Scroll Wheel seated inside the flush housing
    Node {
        position: Qt.vector3d(0, 0.72, -1.36)

        Model {
            source: "#Cylinder"
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.0042, 0.0016, 0.0042)
            materials: PrincipledMaterial {
                baseColor: "#14171d"
                roughness: 0.76
                metalness: 0.05
            }
        }

        Repeater3D {
            model: 16
            delegate: Node {
                required property int index
                eulerRotation: Qt.vector3d(index * 22.5, 0, 0)
                Model {
                    source: "#Cube"
                    position: Qt.vector3d(0, 0.21, 0)
                    scale: Qt.vector3d(0.0014, 0.00024, 0.00038)
                    materials: PrincipledMaterial { baseColor: "#262b35"; roughness: 0.65 }
                }
            }
        }
    }

    // 5. Optical Sensor Window Underneath when Connected
    Model {
        source: "#Cylinder"
        position: Qt.vector3d(0, -0.004, 0.05)
        scale: Qt.vector3d(0.0042, 0.0002, 0.0042)
        materials: PrincipledMaterial {
            baseColor: root.connected ? "#ef4444" : "#0b0c10"
            emissiveFactor: root.connected ? Qt.vector3d(1.0, 0.10, 0.10) : Qt.vector3d(0, 0, 0)
        }
    }
}
