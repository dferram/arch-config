import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "components"
import "theme"

ShellRoot {
    id: shell

    // Central OSD Event Broker for smooth cross-component synchronization
    QtObject {
        id: osdService
        property string osdType: "volume"
        property int level: 50
        property bool isMuted: false
        property string customText: ""
        signal triggered()

        function show(type, val, muted, text) {
            osdType = type;
            level = Math.max(0, Math.min(100, val !== undefined ? val : 50));
            isMuted = !!muted;
            customText = text || "";
            triggered();
        }
    }
    // Desktop Notification Daemon with Dynamic App Colors & Moving LED Border
    NotificationOverlay {
        osdService: osdService
    }

    // Top-Center Dynamic Island Liquid Glass OSD for Volume & Brightness
    OsdOverlay {
        osdService: osdService
    }

    // Lock screen: OLED flip clock -> control panel on click / typing (Super+L)
    LockScreen {}

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData
                screen: modelData

                // Layer shell anchors
                anchors {
                    top: true
                    left: true
                    right: true
                }

                // Margins for modern floating bar
                margins {
                    top: 6
                    left: 12
                    right: 12
                }

                // Bar height
                implicitHeight: 38

                // Window background is transparent for rounded floating effect
                color: "transparent"

                // Accept keyboard focus when clock popup with text input is open
                focusable: currentPopup === "clock"

                // Shared active popup state for this bar
                property string currentPopup: ""

                function togglePopup(id) {
                    if (currentPopup === id) {
                        currentPopup = "";
                    } else {
                        currentPopup = id;
                    }
                }

                Theme { id: theme }

                // Background click area to dismiss active popups
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    onClicked: barWindow.currentPopup = ""
                }

                // Left Island: Arch Badge + Workspaces + Media
                Rectangle {
                    id: leftIsland
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: leftSection.implicitWidth + 16
                    radius: theme.radius
                    color: theme.bgGlass
                    border.color: theme.border
                    border.width: 1

                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    Row {
                        id: leftSection
                        anchors.centerIn: parent
                        spacing: 10

                        HostBadge {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        // Subtle vertical separator
                        Rectangle {
                            width: 1
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            color: theme.borderSubtle
                        }

                        WorkspacesWidget {
                            anchors.verticalCenter: parent.verticalCenter
                            targetScreen: barWindow.screen ? barWindow.screen : modelData
                        }

                        MediaWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                    }
                }

                // Center Island: Clock
                Rectangle {
                    id: centerIsland
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: centerSection.implicitWidth + 24
                    radius: theme.radius
                    color: theme.bgGlass
                    border.color: theme.border
                    border.width: 1

                    Row {
                        id: centerSection
                        anchors.centerIn: parent
                        spacing: 14

                        WeatherWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                        ClockWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                    }
                }

                // Right Island: System Widgets
                Rectangle {
                    id: rightIsland
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    width: rightSection.implicitWidth + 24
                    radius: theme.radius
                    color: theme.bgGlass
                    border.color: theme.border
                    border.width: 1

                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    Row {
                        id: rightSection
                        anchors.centerIn: parent
                        spacing: 14

                        
                        SysResourceWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        BluetoothWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        WifiWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        DisplayWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }

                        BatteryWidget {
                            parentWindow: barWindow
                            activePopupId: barWindow.currentPopup
                            onTogglePopup: (id) => barWindow.togglePopup(id)
                        }
                    }
                }
            }
        }
    }
}
