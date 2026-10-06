import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root
    
    Theme { id: theme }
    
    required property var parentWindow
    property string activePopupId: ""
    signal togglePopup(string id)
    
    implicitWidth: pill.implicitWidth
    implicitHeight: 28
    
    // Minimal weather text for the bar
    property string weatherText: "..."
    
    // Popup state properties
    property string currentTemp: "--"
    property string currentDesc: "Loading..."
    property string currentHumidity: "--%"
    property string currentWind: "-- km/h"
    property string currentPrecip: "-- mm"
    property var hourlyData: []
    
    Process {
        id: weatherProc
        command: ["curl", "-s", "wttr.in/?format=j1"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (txt.length > 0 && txt.startsWith("{")) {
                    try {
                        let data = JSON.parse(txt);
                        let current = data.current_condition[0];
                        
                        root.currentTemp = current.temp_C;
                        root.currentDesc = current.weatherDesc[0].value;
                        root.currentHumidity = current.humidity + "%";
                        root.currentWind = current.windspeedKmph + " km/h";
                        root.currentPrecip = current.precipMM + " mm";
                        
                        root.weatherText = current.temp_C + "°C";
                        
                        // Parse today's hourly data
                        if (data.weather && data.weather.length > 0) {
                            let todayHourly = data.weather[0].hourly;
                            let hData = [];
                            for (let i = 0; i < todayHourly.length; i++) {
                                let h = todayHourly[i];
                                let timeStr = h.time;
                                if (timeStr === "0") timeStr = "12 a.m.";
                                else {
                                    let hour = parseInt(timeStr) / 100;
                                    let ampm = hour >= 12 ? "p.m." : "a.m.";
                                    let h12 = hour % 12;
                                    if (h12 === 0) h12 = 12;
                                    timeStr = h12 + " " + ampm;
                                }
                                hData.push({ time: timeStr, temp: parseInt(h.tempC) });
                            }
                            root.hourlyData = hData;
                        }
                    } catch(e) { }
                }
            }
        }
    }
    
    Timer {
        interval: 1800000 // 30 mins
        running: true
        repeat: true
        onTriggered: {
            weatherProc.running = false;
            weatherProc.running = true;
        }
    }
    
    BarPill {
        id: pill
        text: root.weatherText
        iconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23e2e8f0' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z'/></svg>"
        accentColor: theme.blue
        active: root.activePopupId === "weather"
        
        onClicked: {
            root.togglePopup("weather");
            if (root.activePopupId === "weather") {
                weatherProc.running = false;
                weatherProc.running = true;
            }
        }
    }

    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "weather"
        implicitWidth: 400
        implicitHeight: cardLayout.implicitHeight + 42
        color: "transparent"

        Rectangle {
            id: cardContainer
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
                Behavior on y { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            }

            Behavior on opacity { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
            Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 20

                // Header: Main Weather
                Row {
                    width: parent.width
                    spacing: 16
                    
                    // Big Icon
                    Item {
                        width: 64
                        height: 64
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Image {
                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            source: pill.iconSource
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                    // Main Info
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        
                        Row {
                            spacing: 4
                            Text {
                                text: root.currentTemp
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 42
                                font.weight: Font.Bold
                            }
                            Text {
                                text: "°C"
                                color: theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                                anchors.baseline: parent.bottom
                                anchors.baselineOffset: -6
                            }
                        }
                        
                        Text {
                            text: root.currentDesc
                            color: theme.blueLight
                            font.family: theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }
                }
                
                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.borderSubtle
                }
                
                // Details Grid
                Grid {
                    columns: 3
                    spacing: 20
                    width: parent.width
                    
                    Column {
                        spacing: 4
                        Text { text: "Humidity"; color: theme.textSub; font.pixelSize: 12; font.family: theme.fontFamily }
                        Text { text: root.currentHumidity; color: theme.text; font.pixelSize: 14; font.family: theme.fontFamily; font.weight: Font.DemiBold }
                    }
                    Column {
                        spacing: 4
                        Text { text: "Wind"; color: theme.textSub; font.pixelSize: 12; font.family: theme.fontFamily }
                        Text { text: root.currentWind; color: theme.text; font.pixelSize: 14; font.family: theme.fontFamily; font.weight: Font.DemiBold }
                    }
                    Column {
                        spacing: 4
                        Text { text: "Precipitation"; color: theme.textSub; font.pixelSize: 12; font.family: theme.fontFamily }
                        Text { text: root.currentPrecip; color: theme.text; font.pixelSize: 14; font.family: theme.fontFamily; font.weight: Font.DemiBold }
                    }
                }

                // Hourly Forecast Graph
                Item {
                    width: parent.width
                    height: 120
                    
                    Canvas {
                        id: graphCanvas
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 90
                        
                        property var model: root.hourlyData
                        
                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (!model || model.length === 0) return;
                            
                            let minT = 1000;
                            let maxT = -1000;
                            for(let i = 0; i < model.length; i++) {
                                let t = model[i].temp;
                                if(t < minT) minT = t;
                                if(t > maxT) maxT = t;
                            }
                            if(maxT === minT) { minT -= 5; maxT += 5; }
                            
                            let padding = 25;
                            let chartW = width - 20; 
                            let chartH = height - padding;
                            let stepX = chartW / Math.max(1, model.length - 1);
                            let offsetX = 10;
                            
                            // 1. Draw gradient fill
                            ctx.beginPath();
                            ctx.moveTo(offsetX, height);
                            for(let i = 0; i < model.length; i++) {
                                let x = offsetX + i * stepX;
                                let norm = (model[i].temp - minT) / (maxT - minT);
                                let y = padding + chartH - (norm * chartH);
                                ctx.lineTo(x, y);
                            }
                            ctx.lineTo(offsetX + width, height);
                            ctx.lineTo(offsetX, height);
                            ctx.closePath();
                            
                            let gradient = ctx.createLinearGradient(0, 0, 0, height);
                            gradient.addColorStop(0, "rgba(251, 191, 36, 0.35)"); // Yellow transparent
                            gradient.addColorStop(1, "rgba(251, 191, 36, 0.0)");
                            ctx.fillStyle = gradient;
                            ctx.fill();
                            
                            // 2. Draw line path
                            ctx.beginPath();
                            for(let i = 0; i < model.length; i++) {
                                let x = offsetX + i * stepX;
                                let norm = (model[i].temp - minT) / (maxT - minT);
                                let y = padding + chartH - (norm * chartH);
                                if(i === 0) ctx.moveTo(x, y);
                                else ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = "#fbbf24"; // Yellow
                            ctx.lineWidth = 2.5;
                            ctx.stroke();
                            
                            // 3. Draw text points
                            for(let i = 0; i < model.length; i++) {
                                let x = offsetX + i * stepX;
                                let norm = (model[i].temp - minT) / (maxT - minT);
                                let y = padding + chartH - (norm * chartH);
                                
                                ctx.fillStyle = "#ffffff";
                                ctx.font = "bold 13px sans-serif";
                                ctx.textAlign = "center";
                                ctx.fillText(model[i].temp + "°", x, y - 10);
                            }
                        }
                        
                        Connections {
                            target: root
                            function onHourlyDataChanged() { graphCanvas.requestPaint(); }
                        }
                    }
                    
                    // Time Labels Below Graph
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        
                        Repeater {
                            model: root.hourlyData
                            Item {
                                Layout.fillWidth: true
                                height: 20
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.time
                                    color: theme.textSub
                                    font.pixelSize: 11
                                    font.family: theme.fontFamily
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
