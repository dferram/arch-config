import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 216
    implicitHeight: 207

    radius: 20
    // Obsidian Translucent Glass
    color: Qt.rgba(0.06, 0.06, 0.09, 0.55)
    border.color: Qt.rgba(255, 255, 255, 0.10)
    border.width: 1
    clip: true

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null

    property string currentTemp: "--"
    property string currentDesc: "Loading..."
    property string currentCity: "Local Weather"
    property string currentHumidity: "--%"
    property string currentWind: "-- km/h"
    property string weatherIcon: "󰖐"

    function mapWeatherIcon(desc) {
        let d = (desc || "").toLowerCase();
        if (d.includes("sunny") || d.includes("clear")) return "󰖙";
        if (d.includes("partly cloudy")) return "󰖕";
        if (d.includes("cloud") || d.includes("overcast")) return "󰖐";
        if (d.includes("rain") || d.includes("shower") || d.includes("drizzle")) return "󰖖";
        if (d.includes("thunder") || d.includes("storm")) return "󰖓";
        if (d.includes("snow") || d.includes("flurr") || d.includes("ice")) return "󰙾";
        if (d.includes("fog") || d.includes("mist") || d.includes("haze")) return "󰖑";
        return "󰖐";
    }

    Process {
        id: weatherProc
        command: ["curl", "-s", "--max-time", "4", "wttr.in/?format=j1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (txt.length > 0 && txt.startsWith("{")) {
                    try {
                        let data = JSON.parse(txt);
                        if (data.current_condition && data.current_condition.length > 0) {
                            let cur = data.current_condition[0];
                            root.currentTemp = cur.temp_C ? (cur.temp_C + "°") : "--°";
                            let dStr = (cur.weatherDesc && cur.weatherDesc[0]) ? cur.weatherDesc[0].value.trim() : "Clear";
                            root.currentDesc = dStr;
                            root.weatherIcon = root.mapWeatherIcon(dStr);
                            root.currentHumidity = (cur.humidity || "0") + "%";
                            root.currentWind = (cur.windspeedKmph || "0") + " km/h";
                        }
                        if (data.nearest_area && data.nearest_area.length > 0) {
                            let area = data.nearest_area[0];
                            let cName = (area.areaName && area.areaName[0]) ? area.areaName[0].value : "";
                            if (!cName && area.region && area.region[0]) cName = area.region[0].value;
                            if (cName) root.currentCity = cName;
                        }
                    } catch(e) {}
                }
            }
        }
    }

    // Refresh every 20 minutes
    Timer {
        interval: 1200000
        repeat: true
        running: true
        onTriggered: {
            if (!weatherProc.running) weatherProc.running = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        // Top Header: City & Weather Icon
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: "󰖐"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: theme.blueLight != "" ? theme.blueLight : theme.blue
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.currentCity
                    color: theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: root.width - 70
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 10
                color: refreshHover.containsMouse ? theme.surfaceActive : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: weatherProc.running ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.textDim
                    rotation: weatherProc.running ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 400 } }
                }

                MouseArea {
                    id: refreshHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!weatherProc.running) weatherProc.running = true;
                    }
                }
            }
        }

        // Center: Giant Hero Weather Condition Display
        Item {
            width: parent.width
            height: parent.height - 74

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.weatherIcon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 42
                    color: theme.blueLight != "" ? theme.blueLight : theme.blue
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.currentTemp
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pixelSize: 28
                    font.weight: Font.Bold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.currentDesc
                    color: theme.textSub
                    font.family: theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: root.width - 28
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Bottom Stats Bar: Humidity & Wind
        Rectangle {
            width: parent.width
            height: 24
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(255, 255, 255, 0.07)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 12

                Row {
                    spacing: 4
                    Text {
                        text: "󰖌"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: "#38bdf8"
                    }
                    Text {
                        text: root.currentHumidity
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Medium
                    }
                }

                Rectangle {
                    width: 1; height: 10
                    color: Qt.rgba(255, 255, 255, 0.15)
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    spacing: 4
                    Text {
                        text: "󰖝"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: "#a0db6a"
                    }
                    Text {
                        text: root.currentWind
                        color: theme.textDim
                        font.family: theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
