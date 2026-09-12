import QtQuick
import QtQuick.Layouts
import Quickshell
import "components"
import "theme"

ShellRoot {
    id: shell

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

                // Main Bar Background Container (Apple iPhone Liquid Glass Dynamic Island)
                Rectangle {
                    id: barContainer
                    anchors.fill: parent
                    radius: theme.radius
                    color: theme.bgGlass
                    border.color: theme.border
                    border.width: 1

                    // Click anywhere on empty bar to dismiss active popups
                    MouseArea {
                        anchors.fill: parent
                        z: 0
                        onClicked: barWindow.currentPopup = ""
                    }

                    // Content layer
                    Item {
                        anchors.fill: parent
                        z: 1

                        // Left Section: Accurate Arch Badge + Hyprland Workspaces + Spotify/Media Player
                        Row {
                            id: leftSection
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

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

                        // Center Section: Pure Clean Time & Date Clock (No icon)
                        Row {
                            id: centerSection
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter

                            ClockWidget {
                                parentWindow: barWindow
                                activePopupId: barWindow.currentPopup
                                onTogglePopup: (id) => barWindow.togglePopup(id)
                            }
                        }

                        // Right Section: System Resources, Volume, Bluetooth, Network, Display, Battery
                        Row {
                            id: rightSection
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

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
}
