import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    Theme { id: theme }

    required property var parentWindow
    property string activePopupId: ""
    signal togglePopup(string id)

    implicitHeight: pill.implicitHeight
    implicitWidth: pill.implicitWidth

    // Official Arch Linux accurate SVG scaled to match standard icon size
    property string archSvgUri: {
        let col = theme.urlColor(theme.blue);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.74) translate(-11.5, -12)'><path d='M11.39.605C10.376 3.092 9.764 4.72 8.635 7.132c.693.734 1.543 1.589 2.923 2.554-1.484-.61-2.496-1.224-3.252-1.86C6.86 10.842 4.596 15.138 0 23.395c3.612-2.085 6.412-3.37 9.021-3.862a6.61 6.61 0 01-.171-1.547l.003-.115c.058-2.315 1.261-4.095 2.687-3.973 1.426.12 2.534 2.096 2.478 4.409a6.52 6.52 0 01-.146 1.243c2.58.505 5.352 1.787 8.914 3.844-.702-1.293-1.33-2.459-1.929-3.57-.943-.73-1.926-1.682-3.933-2.713 1.38.359 2.367.772 3.137 1.234-6.09-11.334-6.582-12.84-8.67-17.74z' fill='" + col + "'/></g></svg>";
    }

    // Telemetry state
    property string kernelVer: "Linux"
    property string uptimeStr: "Online"
    property string pkgsCount: "pacman"
    property string cpuModel: "Intel Ultra"
    property string ramInfo: "RAM"
    property string hostName: "ferram@ferram"
    property string hwModel: "HUAWEI MateBook 14"
    property string wmName: "Hyprland Wayland"

    Process {
        id: sysInfoProc
        command: ["/home/ferram/.local/bin/hypr-telemetry"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let d = JSON.parse(txt);
                    if (d.kernel) root.kernelVer = d.kernel;
                    if (d.uptime) root.uptimeStr = d.uptime;
                    if (d.pkgs) root.pkgsCount = d.pkgs;
                    if (d.cpu) root.cpuModel = d.cpu;
                    if (d.ram) root.ramInfo = d.ram;
                    if (d.host) root.hwModel = d.host;
                    if (d.user) root.hostName = d.user;
                    if (d.wm) root.wmName = d.wm;
                } catch(e) {}
            }
        }
    }

    BarPill {
        id: pill
        iconSource: root.archSvgUri
        text: "Arch"
        accentColor: theme.blue
        active: root.activePopupId === "host"
        pulsingIcon: root.activePopupId === "host"

        onClicked: {
            if (root.activePopupId !== "host") {
                sysInfoProc.running = true;
            }
            root.togglePopup("host");
        }
    }

    // Clean Obsidian Frosted Glass Popover
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "host"
        implicitWidth: 320
        implicitHeight: cardContent.implicitHeight + 20
        color: "transparent"

        Rectangle {
            id: mainCard
            anchors.fill: parent
            anchors.topMargin: 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge
            clip: true

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.95
            transformOrigin: Item.Top
            transform: Translate {
                y: popup.visible ? 0 : -8
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

            Column {
                id: cardContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 12

                // 1. Sleek Minimalist Geometric Arc Banner
                Rectangle {
                    id: heroBanner
                    width: parent.width
                    height: 125
                    color: Qt.rgba(0, 0, 0, 0.35)
                    clip: true

                    Canvas {
                        id: animCanvas
                        anchors.fill: parent

                        property real angle1: 0
                        property real angle2: 0
                        property real pulse: 0

                        onPaint: {
                            let ctx = getContext("2d");
                            let w = width;
                            let h = height;
                            let cx = w / 2;
                            let cy = h / 2;

                            ctx.clearRect(0, 0, w, h);

                            // Soft radial ambient glow (breathing Arc Reactor core)
                            let pScale = 0.85 + 0.15 * Math.sin(pulse);
                            let grad = ctx.createRadialGradient(cx, cy, 6, cx, cy, 54 * pScale);
                            grad.addColorStop(0, Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.26).toString());
                            grad.addColorStop(0.6, Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.07).toString());
                            grad.addColorStop(1, "transparent");
                            ctx.fillStyle = grad;
                            ctx.beginPath();
                            ctx.arc(cx, cy, 54 * pScale, 0, Math.PI * 2);
                            ctx.fill();

                            // Precision Outer Ring (r = 46, slow rotation)
                            ctx.save();
                            ctx.translate(cx, cy);
                            ctx.rotate(angle1);
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.12)";
                            ctx.lineWidth = 1;
                            // 4 subtle segmented arcs
                            for (let i = 0; i < 4; i++) {
                                let a = i * (Math.PI / 2);
                                ctx.beginPath();
                                ctx.arc(0, 0, 46, a + 0.15, a + (Math.PI / 2) - 0.15);
                                ctx.stroke();
                            }
                            // Single sleek orbit node
                            ctx.fillStyle = theme.blueLight.toString();
                            ctx.beginPath();
                            ctx.arc(46, 0, 2, 0, Math.PI * 2);
                            ctx.fill();
                            ctx.restore();

                            // Precision Inner Ring (r = 34, counter-rotation)
                            ctx.save();
                            ctx.translate(cx, cy);
                            ctx.rotate(angle2);
                            ctx.strokeStyle = Qt.rgba(theme.blueLight.r, theme.blueLight.g, theme.blueLight.b, 0.40).toString();
                            ctx.lineWidth = 1;
                            // 3 subtle arcs
                            for (let j = 0; j < 3; j++) {
                                let a = j * (Math.PI * 2 / 3);
                                ctx.beginPath();
                                ctx.arc(0, 0, 34, a + 0.2, a + (Math.PI * 2 / 3) - 0.4);
                                ctx.stroke();
                            }
                            ctx.restore();

                            // 4 cardinal micro tick marks (r = 52)
                            ctx.strokeStyle = "rgba(255, 255, 255, 0.20)";
                            ctx.lineWidth = 1;
                            let ticks = [0, Math.PI / 2, Math.PI, Math.PI * 1.5];
                            for (let k = 0; k < ticks.length; k++) {
                                let t = ticks[k];
                                ctx.beginPath();
                                ctx.moveTo(cx + Math.cos(t) * 49, cy + Math.sin(t) * 49);
                                ctx.lineTo(cx + Math.cos(t) * 53, cy + Math.sin(t) * 53);
                                ctx.stroke();
                            }
                        }

                        Timer {
                            id: animTimer
                            interval: 33
                            running: popup.visible
                            repeat: true
                            onTriggered: {
                                animCanvas.angle1 += 0.008;
                                animCanvas.angle2 -= 0.014;
                                animCanvas.pulse += 0.05;
                                animCanvas.requestPaint();
                            }
                        }
                    }

                    // Center Medallion: Frosted glass circle holding Arch logo
                    Rectangle {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        radius: 22
                        color: Qt.rgba(0, 0, 0, 0.55)
                        border.color: theme.border
                        border.width: 1

                        Image {
                            source: root.archSvgUri
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true

                            SequentialAnimation on scale {
                                running: popup.visible
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 1.06; duration: 1600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.06; to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    // Bottom divider line
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: theme.borderSubtle
                    }
                }

                // 2. Clean Host Header
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 2

                    Text {
                        text: "Arch Linux"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root.hwModel + " • " + root.hostName
                        color: theme.textMuted
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                // 3. Telemetry 2x2 Clean Frosted Glass Cards
                Grid {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    columns: 2
                    spacing: 8

                    // Card 3: Kernel
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 48
                        radius: theme.radiusSmall
                        color: theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 2

                            Text {
                                text: "KERNEL"
                                color: theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.kernelVer
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Card 4: Uptime
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 48
                        radius: theme.radiusSmall
                        color: theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 2

                            Text {
                                text: "UPTIME"
                                color: theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.uptimeStr
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Card 5: Packages
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 48
                        radius: theme.radiusSmall
                        color: theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 2

                            Text {
                                text: "PACKAGES"
                                color: theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.pkgsCount
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // Card 6: Compositor
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 48
                        radius: theme.radiusSmall
                        color: theme.surface
                        border.color: theme.borderSubtle
                        border.width: 1

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 2

                            Text {
                                text: "COMPOSITOR"
                                color: theme.textDim
                                font.family: theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                            Text {
                                text: root.wmName
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }



                // Clean bottom margin
                Item {
                    width: parent.width
                    height: 8
                }
            }
        }
    }
}
