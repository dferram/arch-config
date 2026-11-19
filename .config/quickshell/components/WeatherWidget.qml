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

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    // Weather state
    property string currentTemp: "--"
    property string feelsLike: "--"
    property string currentDesc: "Loading..."
    property string shortDesc: ""
    property string currentCity: "Local"
    property string currentHumidity: "--%"
    property string currentWind: "-- km/h"
    property string currentPrecip: "-- mm"
    property string currentUv: "--"
    property string highTemp: "--"
    property string lowTemp: "--"
    property string sunriseStr: ""
    property string sunsetStr: ""
    property string weatherKind: "cloudy"
    property bool isNightTime: {
        let h = new Date().getHours();
        return h < 6 || h >= 19;
    }
    property var hourlyData: []
    property var dailyForecast: []

    readonly property color weatherAccent: {
        if (weatherKind === "sunny" && !isNightTime) return "#fbbf24";
        if (weatherKind === "thunder") return "#f59e0b";
        if (weatherKind === "rain" || weatherKind === "snow") return "#38bdf8";
        if (isNightTime) return "#93c5fd";
        return theme.blueLight;
    }

    function classifyWeatherCode(codeStr, descStr) {
        let code = parseInt(codeStr, 10);
        let d = (descStr || "").toLowerCase();
        if ([200, 386, 389, 392, 395].indexOf(code) !== -1 || d.includes("thunder") || d.includes("storm")) return "thunder";
        if ([179, 182, 185, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 374, 377].indexOf(code) !== -1 || d.includes("snow") || d.includes("sleet") || d.includes("blizzard")) return "snow";
        if ([176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359].indexOf(code) !== -1 || d.includes("rain") || d.includes("shower") || d.includes("drizzle")) return "rain";
        if ([143, 248, 260].indexOf(code) !== -1 || d.includes("fog") || d.includes("mist") || d.includes("haze")) return "fog";
        if (code === 113 || d.includes("sunny") || d.includes("clear")) return "sunny";
        if (code === 116 || d.includes("partly")) return "partly";
        if ([119, 122].indexOf(code) !== -1 || d.includes("cloud") || d.includes("overcast")) return "cloudy";
        return "cloudy";
    }

    function shortLabelForKind(kind, night) {
        if (kind === "sunny") return night ? "Clear" : "Sunny";
        if (kind === "partly") return "Partly";
        if (kind === "cloudy") return "Cloudy";
        if (kind === "rain") return "Rain";
        if (kind === "thunder") return "Storm";
        if (kind === "fog") return "Mist";
        if (kind === "snow") return "Snow";
        return "";
    }

    function weatherSvgUri(kind, night) {
        let cloudFill = "%23e2e8f0";
        let cloudSoft = "%23cbd5e1";
        let cloudFront = "%23f1f5f9";
        let moonCol = "%2393c5fd";
        let sunCol = "%23fbbf24";
        let rainCol = "%2338bdf8";
        let snowCol = "%23bae6fd";

        if (kind === "sunny" && !night) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<circle cx='12' cy='12' r='4.6' fill='" + sunCol + "'/>" +
                   "<g stroke='" + sunCol + "' stroke-width='2' stroke-linecap='round'>" +
                   "<path d='M12 2.2v2.2'/><path d='M12 19.6v2.2'/><path d='M2.2 12h2.2'/><path d='M19.6 12h2.2'/>" +
                   "<path d='m5.1 5.1 1.6 1.6'/><path d='m17.3 17.3 1.6 1.6'/><path d='m18.9 5.1-1.6 1.6'/><path d='m6.7 17.3-1.6 1.6'/>" +
                   "</g></svg>";
        }
        if (kind === "sunny" && night) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M20.2 14.5A8.5 8.5 0 0 1 9.5 3.8a8.5 8.5 0 1 0 10.7 10.7Z' fill='" + moonCol + "'/>" +
                   "<circle cx='17.5' cy='6.5' r='1.1' fill='" + sunCol + "'/>" +
                   "</svg>";
        }
        if (kind === "partly" && !night) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<circle cx='9.2' cy='9.2' r='3.8' fill='" + sunCol + "'/>" +
                   "<g stroke='" + sunCol + "' stroke-width='1.8' stroke-linecap='round'>" +
                   "<path d='M9.2 2.4v1.6'/><path d='M2.4 9.2H4'/><path d='m4.4 4.4 1.2 1.2'/><path d='m14 4.4-1.2 1.2'/>" +
                   "</g>" +
                   "<path d='M17.2 19.2H8.5a4.2 4.2 0 0 1-.4-8.4 5.2 5.2 0 0 1 9.8 1.5 3.5 3.5 0 0 1-.7 6.9Z' fill='" + cloudFront + "'/>" +
                   "</svg>";
        }
        if (kind === "partly" && night) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M13.5 9.8A5 5 0 0 1 8 3.6a5 5 0 1 0 5.5 6.2Z' fill='" + moonCol + "'/>" +
                   "<path d='M17.5 19.2H8.8a4.2 4.2 0 0 1-.4-8.4 5.2 5.2 0 0 1 9.8 1.5 3.5 3.5 0 0 1-.7 6.9Z' fill='" + cloudFill + "'/>" +
                   "</svg>";
        }
        if (kind === "rain") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M17.5 15.2H7.2a4.1 4.1 0 0 1-.4-8.2 5.2 5.2 0 0 1 9.9 1.4 3.4 3.4 0 0 1 .8 6.8Z' fill='" + cloudSoft + "'/>" +
                   "<g stroke='" + rainCol + "' stroke-width='2' stroke-linecap='round'>" +
                   "<path d='M8.5 17.8 7.3 21'/><path d='M12.5 17.8 11.3 21'/><path d='M16.5 17.8 15.3 21'/>" +
                   "</g></svg>";
        }
        if (kind === "thunder") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M17.5 14.8H7.2a4.1 4.1 0 0 1-.4-8.2 5.2 5.2 0 0 1 9.9 1.4 3.4 3.4 0 0 1 .8 6.8Z' fill='" + cloudSoft + "'/>" +
                   "<path d='M13 13.5 9.8 18h3l-1 4 4.2-5.2h-3l1-3.3Z' fill='" + sunCol + "'/>" +
                   "</svg>";
        }
        if (kind === "snow") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M17.5 14.8H7.2a4.1 4.1 0 0 1-.4-8.2 5.2 5.2 0 0 1 9.9 1.4 3.4 3.4 0 0 1 .8 6.8Z' fill='" + cloudFill + "'/>" +
                   "<circle cx='8.5' cy='18.5' r='1.3' fill='" + snowCol + "'/><circle cx='12.5' cy='20' r='1.3' fill='" + snowCol + "'/><circle cx='16' cy='18.2' r='1.3' fill='" + snowCol + "'/>" +
                   "</svg>";
        }
        if (kind === "fog") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M17.2 13.5H7.2a3.8 3.8 0 0 1-.4-7.6 4.8 4.8 0 0 1 9.2 1.3 3.2 3.2 0 0 1 1.2 6.3Z' fill='" + cloudSoft + "'/>" +
                   "<g stroke='%2394a3b8' stroke-width='2' stroke-linecap='round'><path d='M5 17h14'/><path d='M7 20.5h10'/></g>" +
                   "</svg>";
        }
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
               "<path d='M17.5 18.2H7.2a4.2 4.2 0 0 1-.4-8.4 5.4 5.4 0 0 1 10.2 1.5 3.5 3.5 0 0 1 .5 6.9Z' fill='" + cloudFill + "'/>" +
               "</svg>";
    }

    readonly property string weatherIconUri: weatherSvgUri(weatherKind, isNightTime)

    // High-contrast monochrome stroke silhouette for the top bar
    readonly property string barSilhouetteUri: {
        let col = theme.urlColor(theme.blueLight);
        if (weatherKind === "sunny" && !isNightTime) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<circle cx='12' cy='12' r='4'/><path d='M12 2v2'/><path d='M12 20v2'/><path d='m4.93 4.93 1.41 1.41'/><path d='m17.66 17.66 1.41 1.41'/><path d='M2 12h2'/><path d='M20 12h2'/><path d='m6.34 17.66-1.41 1.41'/><path d='m19.07 4.93-1.41 1.41'/>" +
                   "</svg>";
        }
        if (weatherKind === "sunny" && isNightTime) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z'/>" +
                   "</svg>";
        }
        if (weatherKind === "partly" && !isNightTime) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M12 2v2'/><path d='m4.93 4.93 1.41 1.41'/><path d='M20 12h2'/><path d='m19.07 4.93-1.41 1.41'/><path d='M15.947 12.65a4 4 0 0 0-5.925-4.128'/><path d='M13 22H7a5 5 0 1 1 4.9-6H13a3 3 0 0 1 0 6Z'/>" +
                   "</svg>";
        }
        if (weatherKind === "partly" && isNightTime) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z'/><path d='M13 21H7a4 4 0 1 1 3.9-4.9H13a2.5 2.5 0 0 1 0 5Z'/>" +
                   "</svg>";
        }
        if (weatherKind === "rain") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242'/><path d='M16 14v6'/><path d='M8 14v6'/><path d='M12 16v6'/>" +
                   "</svg>";
        }
        if (weatherKind === "thunder") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M6 16.326A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 .5 8.973'/><path d='m13 12-3 5h4l-3 5'/>" +
                   "</svg>";
        }
        if (weatherKind === "snow") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242'/><path d='M8 15h.01'/><path d='M8 19h.01'/><path d='M12 17h.01'/><path d='M12 21h.01'/><path d='M16 15h.01'/><path d='M16 19h.01'/>" +
                   "</svg>";
        }
        if (weatherKind === "fog") {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
                   "<path d='M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242'/><path d='M16 17H7'/><path d='M17 21H9'/>" +
                   "</svg>";
        }
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2.0' stroke-linecap='round' stroke-linejoin='round'>" +
               "<path d='M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z'/>" +
               "</svg>";
    }

    function formatShortHour(timeVal) {
        let num = parseInt(timeVal, 10) || 0;
        let hr = Math.floor(num / 100);
        if (hr === 0) return "12a";
        if (hr === 12) return "12p";
        return hr > 12 ? ((hr - 12) + "p") : (hr + "a");
    }

    function formatDayLabel(dateStr, idx) {
        if (idx === 0) return "Today";
        if (idx === 1) return "Tomorrow";
        if (!dateStr) return "Day " + (idx + 1);
        let p = dateStr.split("-");
        if (p.length !== 3) return dateStr;
        let dt = new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10));
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return names[dt.getDay()] || dateStr;
    }

    Process {
        id: weatherProc
        command: ["curl", "-s", "--max-time", "6", "wttr.in/?format=j1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = text.trim();
                if (txt.length > 0 && txt.startsWith("{")) {
                    try {
                        let data = JSON.parse(txt);
                        if (data.current_condition && data.current_condition.length > 0) {
                            let current = data.current_condition[0];
                            root.currentTemp = current.temp_C || "--";
                            root.feelsLike = current.FeelsLikeC || root.currentTemp;
                            root.currentDesc = (current.weatherDesc && current.weatherDesc[0]) ? current.weatherDesc[0].value.trim() : "Clear";
                            root.currentHumidity = (current.humidity || "0") + "%";
                            root.currentWind = (current.windspeedKmph || "0") + " km/h";
                            root.currentPrecip = (current.precipMM || "0") + " mm";
                            root.currentUv = current.uvIndex || "0";

                            let kind = root.classifyWeatherCode(current.weatherCode, root.currentDesc);
                            root.weatherKind = kind;
                            root.shortDesc = root.shortLabelForKind(kind, root.isNightTime);
                        }

                        if (data.nearest_area && data.nearest_area.length > 0) {
                            let area = data.nearest_area[0];
                            let cName = (area.areaName && area.areaName[0]) ? area.areaName[0].value : "";
                            if (!cName && area.region && area.region[0]) cName = area.region[0].value;
                            if (cName) root.currentCity = cName;
                        }

                        if (data.weather && data.weather.length > 0) {
                            let today = data.weather[0];
                            root.highTemp = today.maxtempC || "--";
                            root.lowTemp = today.mintempC || "--";
                            if (today.astronomy && today.astronomy.length > 0) {
                                root.sunriseStr = today.astronomy[0].sunrise || "";
                                root.sunsetStr = today.astronomy[0].sunset || "";
                            }

                            let todayHourly = today.hourly || [];
                            let hData = [];
                            for (let i = 0; i < todayHourly.length; i++) {
                                let h = todayHourly[i];
                                hData.push({
                                    hourNum: Math.floor((parseInt(h.time, 10) || 0) / 100),
                                    time: root.formatShortHour(h.time),
                                    temp: parseInt(h.tempC, 10) || 0
                                });
                            }
                            root.hourlyData = hData;

                            let days = [];
                            let minAll = 999;
                            let maxAll = -999;
                            let count = Math.min(3, data.weather.length);
                            for (let d = 0; d < count; d++) {
                                let w = data.weather[d];
                                let lo = parseInt(w.mintempC, 10);
                                let hi = parseInt(w.maxtempC, 10);
                                if (!isNaN(lo) && lo < minAll) minAll = lo;
                                if (!isNaN(hi) && hi > maxAll) maxAll = hi;
                                let midSlot = (w.hourly && w.hourly.length > 4) ? w.hourly[4] : (w.hourly && w.hourly[0] ? w.hourly[0] : null);
                                let dDesc = midSlot && midSlot.weatherDesc && midSlot.weatherDesc[0] ? midSlot.weatherDesc[0].value : "";
                                let dCode = midSlot ? midSlot.weatherCode : "116";
                                days.push({
                                    label: root.formatDayLabel(w.date, d),
                                    low: isNaN(lo) ? 0 : lo,
                                    high: isNaN(hi) ? 0 : hi,
                                    kind: root.classifyWeatherCode(dCode, dDesc)
                                });
                            }
                            let span = Math.max(1, maxAll - minAll);
                            for (let d = 0; d < days.length; d++) {
                                days[d].startPct = (days[d].low - minAll) / span;
                                days[d].widthPct = Math.max(0.12, (days[d].high - days[d].low) / span);
                            }
                            root.dailyForecast = days;
                        }
                    } catch(e) {}
                }
            }
        }
    }

    Timer {
        interval: 1800000 // 30 mins
        running: true
        repeat: true
        onTriggered: {
            if (!weatherProc.running) weatherProc.running = true;
        }
    }

    BarPill {
        id: pill
        iconSource: root.barSilhouetteUri
        text: root.currentTemp !== "--" ? (root.currentTemp + "°") : "..."
        subText: ""
        accentColor: theme.blue
        active: root.activePopupId === "weather"
        customPadding: 10

        onClicked: {
            root.togglePopup("weather");
            if (root.activePopupId === "weather" && !weatherProc.running) {
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
        implicitWidth: 390
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

            // Subtle atmospheric glow at top
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 150
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(root.weatherAccent.r, root.weatherAccent.g, root.weatherAccent.b, 0.14) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 14

                // 1. Top Location Row
                Item {
                    width: parent.width
                    height: 22

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Image {
                            width: 13
                            height: 13
                            sourceSize: Qt.size(26, 26)
                            anchors.verticalCenter: parent.verticalCenter
                            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + theme.urlColor(root.weatherAccent) + "' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'><path d='M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z'/><circle cx='12' cy='10' r='3'/></svg>"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            text: root.currentCity
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // 2. Hero Temperature Block
                Item {
                    width: parent.width
                    height: 62

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        Image {
                            width: 56
                            height: 56
                            sourceSize: Qt.size(112, 112)
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.weatherIconUri
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.currentTemp + "°"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 42
                            font.weight: Font.Light
                        }
                    }
                }

                // 3. 4-Tile Metrics Strip
                Row {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: [
                            {
                                label: "HUMIDITY",
                                val: root.currentHumidity,
                                svg: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%2338bdf8' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'><path d='M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z'/></svg>"
                            },
                            {
                                label: "WIND",
                                val: root.currentWind,
                                svg: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%2334d399' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'><path d='M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2'/><path d='M9.6 4.6A2 2 0 1 1 11 8H2'/><path d='M12.6 19.4A2 2 0 1 0 14 16H2'/></svg>"
                            },
                            {
                                label: "UV INDEX",
                                val: root.currentUv,
                                svg: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23fbbf24' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='4'/><path d='M12 2v2'/><path d='M12 20v2'/><path d='m4.93 4.93 1.41 1.41'/><path d='m17.66 17.66 1.41 1.41'/><path d='M2 12h2'/><path d='M20 12h2'/><path d='m6.34 17.66-1.41 1.41'/><path d='m19.07 4.93-1.41 1.41'/></svg>"
                            },
                            {
                                label: "PRECIP",
                                val: root.currentPrecip,
                                svg: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%2360a5fa' stroke-width='2.1' stroke-linecap='round' stroke-linejoin='round'><path d='M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242'/><path d='M16 14v6'/><path d='M8 14v6'/><path d='M12 16v6'/></svg>"
                            }
                        ]

                        Rectangle {
                            width: (parent.width - 24) / 4
                            height: 52
                            radius: 10
                            color: theme.surface
                            border.color: theme.borderSubtle
                            border.width: 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    Image {
                                        width: 11
                                        height: 11
                                        sourceSize: Qt.size(22, 22)
                                        source: modelData.svg
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.label
                                        color: theme.textDim
                                        font.family: theme.fontFamily
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.val
                                    color: theme.text
                                    font.family: theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // 4. Smooth Bezier Hourly Temperature Curve
                Rectangle {
                    width: parent.width
                    height: 124
                    radius: 10
                    color: theme.surface
                    border.color: theme.borderSubtle
                    border.width: 1

                    Canvas {
                        id: graphCanvas
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 8
                        height: 88

                        property var model: root.hourlyData
                        property color accent: root.weatherAccent

                        onPaint: {
                            let ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (!model || model.length < 2) return;

                            let minT = 1000;
                            let maxT = -1000;
                            for (let i = 0; i < model.length; i++) {
                                if (model[i].temp < minT) minT = model[i].temp;
                                if (model[i].temp > maxT) maxT = model[i].temp;
                            }
                            if (maxT === minT) { minT -= 3; maxT += 3; }

                            let padTop = 22;
                            let padBot = 10;
                            let offsetX = 18;
                            let chartW = width - (offsetX * 2);
                            let chartH = height - padTop - padBot;
                            let stepX = chartW / (model.length - 1);

                            let pts = [];
                            for (let i = 0; i < model.length; i++) {
                                let x = offsetX + i * stepX;
                                let norm = (model[i].temp - minT) / (maxT - minT);
                                let y = padTop + chartH - (norm * chartH);
                                pts.push({ x: x, y: y, temp: model[i].temp, hourNum: model[i].hourNum });
                            }

                            // Smooth curve helper
                            function traceCurve() {
                                ctx.moveTo(pts[0].x, pts[0].y);
                                for (let i = 0; i < pts.length - 1; i++) {
                                    let mx = (pts[i].x + pts[i + 1].x) / 2;
                                    let my = (pts[i].y + pts[i + 1].y) / 2;
                                    ctx.quadraticCurveTo(pts[i].x, pts[i].y, mx, my);
                                }
                                let last = pts[pts.length - 1];
                                ctx.lineTo(last.x, last.y);
                            }

                            // Area fill
                            ctx.beginPath();
                            traceCurve();
                            ctx.lineTo(pts[pts.length - 1].x, height);
                            ctx.lineTo(pts[0].x, height);
                            ctx.closePath();
                            let grad = ctx.createLinearGradient(0, 0, 0, height);
                            grad.addColorStop(0, Qt.rgba(accent.r, accent.g, accent.b, 0.30));
                            grad.addColorStop(1, Qt.rgba(accent.r, accent.g, accent.b, 0.0));
                            ctx.fillStyle = grad;
                            ctx.fill();

                            // Stroke curve
                            ctx.beginPath();
                            traceCurve();
                            ctx.strokeStyle = accent;
                            ctx.lineWidth = 2.2;
                            ctx.stroke();

                            // Highlight closest hour node + temp labels
                            let nowH = new Date().getHours();
                            let bestIdx = 0;
                            let bestDiff = 99;
                            for (let i = 0; i < pts.length; i++) {
                                let diff = Math.abs(pts[i].hourNum - nowH);
                                if (diff < bestDiff) { bestDiff = diff; bestIdx = i; }
                            }

                            for (let i = 0; i < pts.length; i++) {
                                let p = pts[i];
                                if (i === bestIdx) {
                                    ctx.beginPath();
                                    ctx.arc(p.x, p.y, 4.2, 0, Math.PI * 2);
                                    ctx.fillStyle = "#ffffff";
                                    ctx.fill();
                                    ctx.lineWidth = 2;
                                    ctx.strokeStyle = accent;
                                    ctx.stroke();
                                } else {
                                    ctx.beginPath();
                                    ctx.arc(p.x, p.y, 2.0, 0, Math.PI * 2);
                                    ctx.fillStyle = accent;
                                    ctx.fill();
                                }

                                ctx.fillStyle = (i === bestIdx) ? "#ffffff" : "#cbd5e1";
                                ctx.font = (i === bestIdx) ? "bold 11px sans-serif" : "600 10px sans-serif";
                                ctx.textAlign = "center";
                                ctx.fillText(p.temp + "°", p.x, p.y - 9);
                            }
                        }

                        Connections {
                            target: root
                            function onHourlyDataChanged() { graphCanvas.requestPaint(); }
                            function onWeatherAccentChanged() { graphCanvas.requestPaint(); }
                        }
                    }

                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6

                        Repeater {
                            model: root.hourlyData
                            Item {
                                Layout.fillWidth: true
                                height: 16
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.time
                                    color: theme.textMuted
                                    font.pixelSize: 10
                                    font.family: theme.fontFamily
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }

                // 5. 3-Day Forecast Card (Apple Weather range bar style)
                Rectangle {
                    visible: root.dailyForecast.length > 0
                    width: parent.width
                    implicitHeight: forecastCol.implicitHeight + 12
                    radius: 10
                    color: theme.surface
                    border.color: theme.borderSubtle
                    border.width: 1

                    Column {
                        id: forecastCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        Repeater {
                            model: root.dailyForecast

                            Item {
                                width: forecastCol.width
                                height: 22

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 72
                                    text: modelData.label
                                    color: index === 0 ? theme.text : theme.textSub
                                    font.family: theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: index === 0 ? Font.Bold : Font.Medium
                                }

                                Image {
                                    x: 78
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    sourceSize: Qt.size(32, 32)
                                    source: root.weatherSvgUri(modelData.kind, false)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        width: 24
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.low + "°"
                                        color: theme.textMuted
                                        font.family: theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Temperature span bar
                                    Rectangle {
                                        width: 108
                                        height: 5
                                        radius: 2.5
                                        color: theme.surfaceActive
                                        anchors.verticalCenter: parent.verticalCenter
                                        clip: true

                                        Rectangle {
                                            x: Math.round(parent.width * modelData.startPct)
                                            width: Math.max(8, Math.round(parent.width * modelData.widthPct))
                                            height: parent.height
                                            radius: 2.5
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0.0; color: "#38bdf8" }
                                                GradientStop { position: 1.0; color: "#fbbf24" }
                                            }
                                        }
                                    }

                                    Text {
                                        width: 24
                                        horizontalAlignment: Text.AlignLeft
                                        text: modelData.high + "°"
                                        color: theme.text
                                        font.family: theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
