import QtQuick
import QtQuick3D

// 3D replica modeled after the user's adjustable single-fan black laptop cooling stand:
// - Horizontal bottom base frame with notched adjustment slots + rear kickstand bar
// - Steep tilted (~26 deg) perforated mesh deck with side cutout handles
// - 2 raised vertical ribs flanking a large central spinning turbine fan
// - 4 corner rubber pads + 2 front folding laptop stopper hooks
Node {
    id: root

    property bool baseOn: false
    property color accentColor: "#06b6d4"
    property bool isLive: true

    property real fanAngle: 0.0

    Timer {
        interval: 28
        repeat: true
        running: root.isLive && root.baseOn
        onTriggered: {
            root.fanAngle = (root.fanAngle + 15.0) % 360.0;
        }
    }

    // 1. Bottom Horizontal Adjustment Base Tray resting flat on desk
    Node {
        position: Qt.vector3d(0, -2.05, 0.25)

        // Left & Right Base Rails
        Model {
            source: "#Cube"
            position: Qt.vector3d(-4.4, 0, 0)
            scale: Qt.vector3d(0.009, 0.0026, 0.078)
            materials: PrincipledMaterial { baseColor: "#14161c"; roughness: 0.5; metalness: 0.25 }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(4.4, 0, 0)
            scale: Qt.vector3d(0.009, 0.0026, 0.078)
            materials: PrincipledMaterial { baseColor: "#14161c"; roughness: 0.5; metalness: 0.25 }
        }
        // Front & Rear Crossbars
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 0, 3.65)
            scale: Qt.vector3d(0.096, 0.0024, 0.007)
            materials: PrincipledMaterial { baseColor: "#14161c"; roughness: 0.5; metalness: 0.25 }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 0, -3.55)
            scale: Qt.vector3d(0.096, 0.0024, 0.007)
            materials: PrincipledMaterial { baseColor: "#14161c"; roughness: 0.5; metalness: 0.25 }
        }

        // Notched Height-Adjustment Teeth along Left & Right Rails
        Repeater3D {
            model: 5
            delegate: Node {
                required property int index
                readonly property real slotZ: -2.2 + index * 1.15
                Model {
                    source: "#Cube"
                    position: Qt.vector3d(-4.4, 0.18, slotZ)
                    scale: Qt.vector3d(0.006, 0.0018, 0.0035)
                    materials: PrincipledMaterial { baseColor: "#1b1e26"; roughness: 0.45 }
                }
                Model {
                    source: "#Cube"
                    position: Qt.vector3d(4.4, 0.18, slotZ)
                    scale: Qt.vector3d(0.006, 0.0018, 0.0035)
                    materials: PrincipledMaterial { baseColor: "#1b1e26"; roughness: 0.45 }
                }
            }
        }

        // Angled Wire/Bar Kickstand Prop supporting upper deck
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(-3.6, 1.45, -1.65)
            eulerRotation: Qt.vector3d(-32, 0, 0)
            scale: Qt.vector3d(0.0018, 0.036, 0.0018)
            materials: PrincipledMaterial { baseColor: "#334155"; metalness: 0.8; roughness: 0.25 }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(3.6, 1.45, -1.65)
            eulerRotation: Qt.vector3d(-32, 0, 0)
            scale: Qt.vector3d(0.0018, 0.036, 0.0018)
            materials: PrincipledMaterial { baseColor: "#334155"; metalness: 0.8; roughness: 0.25 }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, 2.75, -2.55)
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.0018, 0.074, 0.0018)
            materials: PrincipledMaterial { baseColor: "#334155"; metalness: 0.8; roughness: 0.25 }
        }
    }

    // 2. Steep Tilted Cooling Deck Assembly (~26 deg angle like the real stand)
    Node {
        position: Qt.vector3d(0, 0.05, 0)
        eulerRotation: Qt.vector3d(26, 0, 0)

        // Main Matte-Black Frame Backplate
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, -0.14, 0)
            scale: Qt.vector3d(0.124, 0.0032, 0.092)
            materials: PrincipledMaterial {
                baseColor: "#12141a"
                metalness: 0.25
                roughness: 0.48
            }
        }

        // Perforated Steel Mesh Top Panel (slightly recessed dark gunmetal)
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 0.04, 0)
            scale: Qt.vector3d(0.114, 0.0012, 0.084)
            materials: PrincipledMaterial {
                baseColor: "#191c24"
                metalness: 0.62
                roughness: 0.36
            }
        }

        // Side Ergonomic Grip Handle Bridges (Left & Right cutouts)
        Model {
            source: "#Cube"
            position: Qt.vector3d(-6.45, -0.04, 0)
            scale: Qt.vector3d(0.0045, 0.0034, 0.032)
            materials: PrincipledMaterial { baseColor: "#161920"; roughness: 0.45 }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(6.45, -0.04, 0)
            scale: Qt.vector3d(0.0045, 0.0034, 0.032)
            materials: PrincipledMaterial { baseColor: "#161920"; roughness: 0.45 }
        }

        // 2 Prominent Vertical Raised Air-Channel Ribs flanking the single fan
        Model {
            source: "#Cube"
            position: Qt.vector3d(-2.55, 0.14, -0.15)
            scale: Qt.vector3d(0.017, 0.0018, 0.048)
            materials: PrincipledMaterial {
                baseColor: "#161921"
                metalness: 0.35
                roughness: 0.40
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(2.55, 0.14, -0.15)
            scale: Qt.vector3d(0.017, 0.0018, 0.048)
            materials: PrincipledMaterial {
                baseColor: "#161921"
                metalness: 0.35
                roughness: 0.40
            }
        }

        // 4 Corner Non-Slip Rubber Pads
        Repeater3D {
            model: [
                {x: -3.5, z: -3.4}, {x: 3.5, z: -3.4},
                {x: -3.5, z: 3.3},  {x: 3.5, z: 3.3}
            ]
            delegate: Model {
                required property var modelData
                source: "#Cube"
                position: Qt.vector3d(modelData.x, 0.14, modelData.z)
                scale: Qt.vector3d(0.011, 0.0014, 0.0075)
                materials: PrincipledMaterial { baseColor: "#0c0d11"; roughness: 0.85 }
            }
        }

        // 2 Front Folding Laptop Stopper Hooks
        Model {
            source: "#Cube"
            position: Qt.vector3d(-3.1, 0.42, 4.48)
            scale: Qt.vector3d(0.011, 0.0076, 0.0028)
            materials: PrincipledMaterial { baseColor: "#181b22"; roughness: 0.45 }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(3.1, 0.42, 4.48)
            scale: Qt.vector3d(0.011, 0.0076, 0.0028)
            materials: PrincipledMaterial { baseColor: "#181b22"; roughness: 0.45 }
        }

        // Single Large Central Fan under the Mesh (14-blade curved turbine)
        Node {
            position: Qt.vector3d(0, -0.02, -0.1)

            // Recessed Fan Housing Ring
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(0, -0.08, 0)
                scale: Qt.vector3d(0.060, 0.0012, 0.060)
                materials: PrincipledMaterial {
                    baseColor: "#090b0f"
                    emissiveFactor: root.baseOn
                        ? Qt.vector3d(root.accentColor.r * 0.45, root.accentColor.g * 0.45, root.accentColor.b * 0.45)
                        : Qt.vector3d(0, 0, 0)
                }
            }

            // Spinning Single 14-Blade Central Rotor
            Node {
                eulerRotation: Qt.vector3d(0, root.fanAngle, 0)

                Model {
                    source: "#Cylinder"
                    position: Qt.vector3d(0, 0.02, 0)
                    scale: Qt.vector3d(0.016, 0.0022, 0.016)
                    materials: PrincipledMaterial { baseColor: "#222733"; metalness: 0.55; roughness: 0.30 }
                }

                Repeater3D {
                    model: 14
                    delegate: Node {
                        required property int index
                        eulerRotation: Qt.vector3d(0, index * (360.0 / 14.0), 0)
                        Model {
                            source: "#Cube"
                            position: Qt.vector3d(0, 0.02, 1.78)
                            eulerRotation: Qt.vector3d(0, 18, 26)
                            scale: Qt.vector3d(0.0046, 0.0009, 0.0235)
                            materials: PrincipledMaterial {
                                baseColor: root.baseOn ? root.accentColor : "#2b3240"
                                opacity: 0.78
                                alphaMode: PrincipledMaterial.Blend
                                emissiveFactor: root.baseOn
                                    ? Qt.vector3d(root.accentColor.r * 1.1, root.accentColor.g * 1.1, root.accentColor.b * 1.1)
                                    : Qt.vector3d(0, 0, 0)
                            }
                        }
                    }
                }
            }

            // Subtle Mesh Grille Cross-Bars over Central Fan
            Repeater3D {
                model: [-1.8, -0.9, 0.0, 0.9, 1.8]
                delegate: Model {
                    required property real modelData
                    source: "#Cube"
                    position: Qt.vector3d(0, 0.11, modelData - 0.1)
                    scale: Qt.vector3d(0.052, 0.0004, 0.0009)
                    materials: PrincipledMaterial { baseColor: "#1b1f28"; metalness: 0.65; roughness: 0.35 }
                }
            }
        }
    }
}
