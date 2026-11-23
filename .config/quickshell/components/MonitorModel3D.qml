import QtQuick
import QtQuick3D

// Stylized realistic 3D Monitor supporting both of the user's real monitors:
// - "mark":    MARK M20 / Gaming Naceb (wide swept V-legs + cylindrical neck)
// - "samsung": Samsung Essential S3 (flat rectangular base plate + straight neck)
Node {
    id: root

    property bool connected: false
    property color accentColor: "#bf4148"
    property string monitorStyle: "mark" // "mark" | "samsung"

    // Main Ultra-Slim Rear Panel Housing
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 0.70, -0.15)
        scale: Qt.vector3d(0.130, 0.074, 0.0020)
        materials: PrincipledMaterial {
            baseColor: "#14161c"
            metalness: 0.25
            roughness: 0.42
        }
    }

    // Tapered Rear Electronics / VESA Spine
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 0.20, -0.34)
        scale: Qt.vector3d(0.064, 0.042, 0.0028)
        materials: PrincipledMaterial {
            baseColor: "#181b23"
            metalness: 0.30
            roughness: 0.40
        }
    }

    // Uniform Slim Matte-Black Bezels (Top, Left, Right)
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 4.35, 0.0)
        scale: Qt.vector3d(0.130, 0.0020, 0.0018)
        materials: PrincipledMaterial { baseColor: "#101217"; metalness: 0.20; roughness: 0.42 }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(-6.40, 0.70, 0.0)
        scale: Qt.vector3d(0.0020, 0.074, 0.0018)
        materials: PrincipledMaterial { baseColor: "#101217"; metalness: 0.20; roughness: 0.42 }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(6.40, 0.70, 0.0)
        scale: Qt.vector3d(0.0020, 0.074, 0.0018)
        materials: PrincipledMaterial { baseColor: "#101217"; metalness: 0.20; roughness: 0.42 }
    }

    // Slim Bottom Chin + Centered Brand Badge Bar
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, -2.98, 0.01)
        scale: Qt.vector3d(0.130, 0.0034, 0.0020)
        materials: PrincipledMaterial { baseColor: "#12141a"; metalness: 0.25; roughness: 0.38 }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, -2.98, 0.115)
        scale: Qt.vector3d(0.010, 0.0008, 0.0003)
        materials: PrincipledMaterial { baseColor: "#94a3b8"; metalness: 0.65; roughness: 0.25 }
    }

    // Active / Standby IPS Screen
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 0.73, -0.02)
        scale: Qt.vector3d(0.126, 0.0705, 0.0006)
        materials: PrincipledMaterial {
            baseColor: root.connected ? "#0f172a" : "#07090d"
            roughness: root.connected ? 0.14 : 0.24
            specularAmount: 0.88
            emissiveFactor: root.connected
                ? Qt.vector3d(0.09 + root.accentColor.r * 0.38, 0.12 + root.accentColor.g * 0.38, 0.20 + root.accentColor.b * 0.38)
                : Qt.vector3d(0.012, 0.014, 0.018)
        }
    }

    // Mock Desktop Top Bar & Glass Windows when Connected
    Model {
        visible: root.connected
        source: "#Cube"
        position: Qt.vector3d(0, 3.96, 0.02)
        scale: Qt.vector3d(0.116, 0.0022, 0.0003)
        materials: PrincipledMaterial {
            baseColor: "#1e293b"
            opacity: 0.75
            alphaMode: PrincipledMaterial.Blend
            emissiveFactor: Qt.vector3d(root.accentColor.r * 0.45, root.accentColor.g * 0.45, root.accentColor.b * 0.45)
        }
    }
    Model {
        visible: root.connected
        source: "#Cube"
        position: Qt.vector3d(-2.2, 0.60, 0.02)
        scale: Qt.vector3d(0.064, 0.048, 0.0003)
        materials: PrincipledMaterial {
            baseColor: "#1e293b"
            opacity: 0.56
            alphaMode: PrincipledMaterial.Blend
            emissiveFactor: Qt.vector3d(root.accentColor.r * 0.36, root.accentColor.g * 0.36, root.accentColor.b * 0.36)
        }
    }
    Model {
        visible: root.connected
        source: "#Cube"
        position: Qt.vector3d(2.8, 0.40, 0.02)
        scale: Qt.vector3d(0.040, 0.046, 0.0003)
        materials: PrincipledMaterial {
            baseColor: "#0f172a"
            opacity: 0.65
            alphaMode: PrincipledMaterial.Blend
            emissiveFactor: Qt.vector3d(0.10, 0.26, 0.40)
        }
    }

    // Bottom-right Power Status LED
    Model {
        source: "#Sphere"
        position: Qt.vector3d(5.2, -2.98, 0.12)
        scale: Qt.vector3d(0.0010, 0.0010, 0.0010)
        materials: PrincipledMaterial {
            baseColor: root.connected ? "#30d158" : "#ff9f0a"
            emissiveFactor: root.connected ? Qt.vector3d(0.3, 1.5, 0.6) : Qt.vector3d(0.45, 0.25, 0.02)
        }
    }

    // =========================================================================
    // STAND VARIANT A: MARK M20 / GAMING NACEB (Cylindrical neck + wide swept V-legs)
    // =========================================================================
    Node {
        visible: root.monitorStyle !== "samsung"

        // Cylindrical Central Neck Column
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, -3.52, -0.35)
            scale: Qt.vector3d(0.0056, 0.0155, 0.0056)
            materials: PrincipledMaterial {
                baseColor: "#1d2028"
                metalness: 0.45
                roughness: 0.34
            }
        }

        // Tapered Center Joint Hub
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, -4.16, -0.35)
            scale: Qt.vector3d(0.0095, 0.0032, 0.0095)
            materials: PrincipledMaterial { baseColor: "#191c23"; metalness: 0.45; roughness: 0.35 }
        }

        // Left Swept V-Leg (wide open angle like Gaming Naceb photo)
        Model {
            source: "#Cube"
            position: Qt.vector3d(-2.25, -4.38, 0.22)
            eulerRotation: Qt.vector3d(4, 15, -4)
            scale: Qt.vector3d(0.048, 0.0024, 0.0064)
            materials: PrincipledMaterial { baseColor: "#1a1d24"; metalness: 0.50; roughness: 0.34 }
        }
        // Right Swept V-Leg
        Model {
            source: "#Cube"
            position: Qt.vector3d(2.25, -4.38, 0.22)
            eulerRotation: Qt.vector3d(4, -15, 4)
            scale: Qt.vector3d(0.048, 0.0024, 0.0064)
            materials: PrincipledMaterial { baseColor: "#1a1d24"; metalness: 0.50; roughness: 0.34 }
        }
        // Rear Short Stabilizer Spur
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, -4.35, -0.95)
            eulerRotation: Qt.vector3d(-5, 0, 0)
            scale: Qt.vector3d(0.0072, 0.0024, 0.015)
            materials: PrincipledMaterial { baseColor: "#1a1d24"; metalness: 0.50; roughness: 0.34 }
        }
    }

    // =========================================================================
    // STAND VARIANT B: SAMSUNG ESSENTIAL (Straight rectangular neck + flat square base)
    // =========================================================================
    Node {
        visible: root.monitorStyle === "samsung"

        // Straight Rectangular Neck Stem
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, -3.55, -0.36)
            scale: Qt.vector3d(0.0115, 0.0165, 0.0044)
            materials: PrincipledMaterial {
                baseColor: "#171920"
                metalness: 0.28
                roughness: 0.42
            }
        }

        // Sleek Flat Rectangular Matte-Black Base Plate
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, -4.34, -0.15)
            scale: Qt.vector3d(0.048, 0.0024, 0.036)
            materials: PrincipledMaterial {
                baseColor: "#15171d"
                metalness: 0.22
                roughness: 0.44
                specularAmount: 0.5
            }
        }
    }
}
