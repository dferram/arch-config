import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"

PanelWindow {
    id: notifWindow

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    anchors {
        top: true
        right: true
    }
    margins {
        top: 48
        right: 14
    }

    implicitWidth: 330
    implicitHeight: Math.max(1, notifCol.childrenRect.height + 8)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: notifModel.count > 0

    Theme { id: theme }

    ListModel {
        id: notifModel
    }

    property var notifMap: ({})
    property var osdService: null
    property bool isDndOn: false

    function getNotif(id) {
        return notifMap[id] || null;
    }

    function removeNotifEntry(id) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).notifId === id) {
                notifModel.remove(i);
                break;
            }
        }
        delete notifMap[id];
    }

    function dismissNotif(id) {
        let raw = notifMap[id];
        removeNotifEntry(id);
        if (raw) {
            try { raw.dismiss(); } catch(e) {}
        }
    }

    function remoteCloseNotif(id) {
        for (let i = 0; i < notifCol.children.length; i++) {
            let item = notifCol.children[i];
            if (item && item.notifId === id && item.dismissCard) {
                item.dismissCard();
                return;
            }
        }
        removeNotifEntry(id);
    }

    Process {
        id: dndStatusProc
        command: ["/home/ferram/.local/bin/hypr-dnd", "status"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let lines = text.trim().split("\n");
                if (lines.length > 0) {
                    let last = lines[lines.length - 1].trim();
                    notifWindow.isDndOn = (last === "on");
                }
            }
        }
    }

    Process {
        id: f1SoundProc
        command: ["pw-play", "/home/ferram/.local/share/sounds/f1.oga"]
    }

    property real lastF1SoundTime: 0

    function playF1Sound() {
        let now = Date.now();
        if (now - lastF1SoundTime < 2500) return;
        lastF1SoundTime = now;
        f1SoundProc.running = false;
        f1SoundProc.running = true;
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            if (!dndStatusProc.running) dndStatusProc.running = true;
        }
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        extraHints: [
            "x-kde-origin-name",
            "origin",
            "desktop-entry",
            "x-origin",
            "x-canonical-app-name",
            "category",
            "x-category",
            "urgency"
        ]

        onNotification: (notif) => {
            notif.tracked = true;
            let incomingApp = (notif.appName || "").toLowerCase();
            let incomingSum = (notif.summary || "").toLowerCase();

            // Intercept volume, brightness, mic, night light & caps lock for dedicated OSD HUD
            let isWarning = incomingApp.includes("hearing") || incomingSum.includes("warning") || incomingSum.includes("safety");
            let isVolume = !isWarning && (incomingApp.includes("volume") || incomingSum.includes("volume"));
            let isBrightness = incomingApp.includes("bright") || incomingSum.includes("brightness") || incomingSum.includes("brillo");
            let isMic = incomingApp.includes("micro") || incomingSum.includes("microphone") || incomingSum.includes("micrófono");
            let isNight = incomingApp.includes("night") || incomingSum.includes("night light") || incomingSum.includes("luz nocturna") || incomingSum.includes("luz cálida");
            let isCaps = incomingApp.includes("caps") || incomingSum.includes("mayús") || incomingSum.includes("caps lock");

            if (isVolume || isBrightness || isMic || isNight || isCaps) {
                let val = 50;
                let isMuted = false;
                let osdType = "volume";
                let text = "";

                if (isVolume) {
                    osdType = "volume";
                    if (notif.hints && notif.hints.value !== undefined) {
                        val = parseInt(notif.hints.value);
                    } else {
                        let m = incomingSum.match(/(\d+)%/);
                        if (m) val = parseInt(m[1]);
                    }
                    isMuted = incomingSum.includes("mute") || (notif.hints && (notif.hints.muted === true || notif.hints.muted === "true"));
                } else if (isBrightness) {
                    osdType = "brightness";
                    if (notif.hints && notif.hints.value !== undefined) {
                        val = parseInt(notif.hints.value);
                    } else {
                        let m = incomingSum.match(/(\d+)%/);
                        if (m) val = parseInt(m[1]);
                    }
                } else if (isMic) {
                    osdType = "mic";
                    isMuted = incomingSum.includes("mute") || (notif.hints && (notif.hints.muted === true || notif.hints.muted === "true"));
                    val = isMuted ? 0 : 100;
                    text = isMuted ? "MUTED" : "ACTIVE";
                } else if (isNight) {
                    osdType = "nightmode";
                    let active = incomingSum.includes("enabled") || incomingSum.includes("activad") || incomingSum.includes(" on") || (notif.body && notif.body.includes("enabled"));
                    if (incomingSum.includes("disabled") || incomingSum.includes("desactivad") || incomingSum.includes(" off")) active = false;
                    isMuted = !active;
                    val = active ? 100 : 0;
                    text = active ? "ON" : "OFF";
                } else if (isCaps) {
                    osdType = "capslock";
                    let active = incomingSum.includes(" on") || incomingSum.includes("enabled") || incomingSum.includes("activad") || (notif.hints && (notif.hints.active === true || notif.hints.active === "true"));
                    if (incomingSum.includes(" off") || incomingSum.includes("disabled") || incomingSum.includes("desactivad")) active = false;
                    isMuted = !active;
                    val = active ? 100 : 0;
                    text = active ? "ON" : "OFF";
                }

                if (notifWindow.osdService) {
                    notifWindow.osdService.show(osdType, val, isMuted, text);
                }

                try { notif.dismiss(); } catch(e) {}
                return;
            }

            // Sync DND state directly if notification comes from hypr-dnd
            let isDndFeedback = incomingApp.includes("disturb") || incomingApp.includes("molestar") ||
                                incomingSum.includes("disturb") || incomingSum.includes("molestar") ||
                                incomingApp.includes("dnd");
            if (isDndFeedback) {
                let isAct = incomingSum.includes("enable") || incomingSum.includes("activad") || (notif.hints && (notif.hints.active === true || notif.hints.active === "true"));
                if (incomingSum.includes("disable") || incomingSum.includes("desactivad")) isAct = false;
                notifWindow.isDndOn = isAct;
            }

            let notifBody = (notif.body || "").toLowerCase();
            let notifDesktop = (notif.desktopEntry || "").toLowerCase();
            let notifHintsStr = "";
            try { if (notif.hints) notifHintsStr = JSON.stringify(notif.hints).toLowerCase(); } catch(e) {}

            let isWhatsAppAlert = incomingApp.includes("whatsapp") || incomingSum.includes("whatsapp") ||
                                  notifBody.includes("whatsapp") || notifDesktop.includes("whatsapp") ||
                                  notifHintsStr.includes("whatsapp") || notifHintsStr.includes("web.whatsapp.com") ||
                                  incomingApp.includes("whatsdesk") || incomingApp.includes("whatsie") ||
                                  incomingApp.includes("zapzap") || incomingApp.includes("walc");

            // If Do Not Disturb is active, suppress non-essential notifications (e.g. social media, media, browsers)
            if (notifWindow.isDndOn && !isDndFeedback) {
                let isSystemAlert = (notif.urgency === 2) ||
                    incomingApp.includes("bater") || incomingSum.includes("bater") || incomingApp.includes("battery") ||
                    incomingApp.includes("system") || incomingApp.includes("power") || incomingApp.includes("bluetooth") ||
                    incomingApp.includes("wifi") || incomingApp.includes("network") || incomingApp.includes("pipewire") ||
                    incomingApp.includes("wireplumber") || incomingApp.includes("headphone") || incomingApp.includes("hearing") ||
                    incomingApp.includes("display") || incomingApp.includes("pantalla");

                let isDevOrAgentAlert = incomingApp.includes("antigravity") || incomingApp.includes("code") ||
                    incomingApp.includes("devin") || incomingApp.includes("claude") ||
                    incomingSum.includes("antigravity") || incomingSum.includes("agente") || incomingSum.includes("agent");

                let isCalendarOrF1Alert = incomingApp.includes("remind") || incomingSum.includes("remind") ||
                    incomingApp.includes("calendar") || incomingSum.includes("calendar") ||
                    incomingApp.includes("formula") || incomingApp.includes("f1") || incomingSum.includes("f1") ||
                    incomingSum.includes("grand prix") || (notif.hints && (String(notif.hints.category || "") === "F1" || String(notif.hints["x-category"] || "") === "F1"));

                let isCommunicationAlert = isWhatsAppAlert;

                if (!isSystemAlert && !isDevOrAgentAlert && !isCalendarOrF1Alert && !isCommunicationAlert) {
                    try { notif.dismiss(); } catch(e) {}
                    return;
                }
            }

            let notifCat = "";
            if (notif.hints) {
                if (notif.hints.category) notifCat = String(notif.hints.category).toLowerCase();
                else if (notif.hints["category"]) notifCat = String(notif.hints["category"]).toLowerCase();
                else if (notif.hints["x-category"]) notifCat = String(notif.hints["x-category"]).toLowerCase();
            }
            let isF1Notif = incomingApp.includes("f1") || incomingSum.includes("f1") || notifBody.includes("f1") ||
                            incomingApp.includes("formula 1") || incomingSum.includes("formula 1") || notifBody.includes("formula 1") ||
                            incomingSum.includes("grand prix") || notifBody.includes("grand prix") || notifCat.includes("f1");

            if (isF1Notif) {
                notifWindow.playF1Sound();
            }

            // Connect closed signal safely
            try {
                notif.closed.connect(() => {
                    notifWindow.remoteCloseNotif(notif.id);
                });
            } catch(e) {}

            let notifId = notif.id;
            let appName = notif.appName || "";
            let summary = notif.summary || "";
            let bodyText = notif.body || "";
            let urgency = (notif.urgency !== undefined ? notif.urgency : 1);
            let appIcon = notif.appIcon || "";
            let desktopEntry = notif.desktopEntry || "";
            let expireTimeout = notif.expireTimeout || 0;
            let notifImage = (notif.image && notif.image !== "") ? String(notif.image) : "";
            let hints = notif.hints || {};
            let actions = notif.actions || [];

            let incomingAppLower = appName.toLowerCase();
            let incomingSumLower = summary.toLowerCase();
            let isSingleton = incomingAppLower.includes("bater") || incomingAppLower.includes("battery");

            // Cache raw notif object
            notifWindow.notifMap[notifId] = notif;

            // Check if there is an existing duplicate in notifModel
            let duplicateIndex = -1;
            for (let i = 0; i < notifModel.count; i++) {
                let entry = notifModel.get(i);
                if (!entry) continue;

                let entryAppLower = (entry.appName || "").toLowerCase();
                let entrySumLower = (entry.summary || "").toLowerCase();

                let isDup = (entry.notifId === notifId) ||
                    (incomingSumLower.length > 0 && incomingSumLower === entrySumLower && incomingAppLower === entryAppLower) ||
                    ((incomingAppLower.includes("hearing") || incomingSumLower.includes("headphone")) &&
                     (entryAppLower.includes("hearing") || entrySumLower.includes("headphone")));

                let matchSingleton = isSingleton && (
                    (incomingAppLower.includes("volume") && (entryAppLower.includes("volume") || entrySumLower.includes("volume"))) ||
                    (incomingAppLower.includes("bright") && (entryAppLower.includes("bright") || entrySumLower.includes("bright"))) ||
                    ((incomingAppLower.includes("bater") || incomingAppLower.includes("battery")) && (entryAppLower.includes("bater") || entryAppLower.includes("battery")))
                );

                if (isDup || matchSingleton) {
                    duplicateIndex = i;
                    break;
                }
            }

            if (duplicateIndex !== -1) {
                let oldId = notifModel.get(duplicateIndex).notifId;
                if (oldId !== notifId && notifWindow.notifMap[oldId]) {
                    try { notifWindow.notifMap[oldId].dismiss(); } catch(e) {}
                    delete notifWindow.notifMap[oldId];
                }
                notifModel.remove(duplicateIndex);
            }

            // Cap model count to 4 (remove oldest if >= 4)
            while (notifModel.count >= 4) {
                let lastIndex = notifModel.count - 1;
                let lastId = notifModel.get(lastIndex).notifId;
                let oldRaw = notifWindow.notifMap[lastId];
                notifModel.remove(lastIndex);
                if (oldRaw) {
                    try { oldRaw.dismiss(); } catch(e) {}
                    delete notifWindow.notifMap[lastId];
                }
            }

            // Prepare safe serializable metadata for styling
            let metaContextStr = (appName + " " + summary + " " + bodyText).toLowerCase();
            if (appIcon) metaContextStr += " " + appIcon.toLowerCase();
            if (desktopEntry) metaContextStr += " " + desktopEntry.toLowerCase();
            let hintCategory = "";
            if (hints) {
                try {
                    if (hints.category) hintCategory = String(hints.category);
                    else if (hints["category"]) hintCategory = String(hints["category"]);
                    else if (hints["x-category"]) hintCategory = String(hints["x-category"]);
                } catch(e) {}
                try {
                    for (let k in hints) {
                        if (k === "image-data" || k === "image_data" || k === "icon_data") continue;
                        metaContextStr += " " + k + ":" + String(hints[k]).toLowerCase();
                    }
                } catch(e) {}
                try { metaContextStr += " " + JSON.stringify(hints).toLowerCase(); } catch(e) {}
            }
            if (actions) {
                try {
                    for (let i = 0; i < actions.length; i++) {
                        let act = actions[i];
                        if (act) metaContextStr += " " + (act.identifier || "").toLowerCase() + " " + (act.text || "").toLowerCase();
                    }
                } catch(e) {}
            }

            // Insert new notification at top
            notifModel.insert(0, {
                notifId: notifId,
                appName: appName,
                summary: summary,
                bodyText: bodyText,
                urgency: urgency,
                appIcon: appIcon,
                desktopEntry: desktopEntry,
                expireTimeout: expireTimeout,
                notifImage: notifImage,
                hintCategory: hintCategory,
                metaContext: metaContextStr,
                timeStr: Qt.formatTime(new Date(), "HH:mm")
            });
        }
    }

    Column {
        id: notifCol
        width: parent.width
        spacing: 8

        Repeater {
            model: notifModel

            delegate: Item {
                id: card
                required property int notifId
                required property string appName
                required property string summary
                required property string bodyText
                required property int urgency
                required property string appIcon
                required property string desktopEntry
                required property int expireTimeout
                required property string notifImage
                required property string hintCategory
                required property string metaContext
                required property string timeStr

                width: notifCol.width
                implicitHeight: Math.max(68, contentRow.implicitHeight + 20)
                height: implicitHeight

                opacity: 0.0
                scale: 0.95
                transform: Translate { id: cardSlide; x: 24 }

                Component.onCompleted: {
                    notifEntrance.start();
                }

                Component.onDestruction: {
                    cardDismissAnim.stop();
                    notifEntrance.stop();
                }

                function dismissCard() {
                    if (cardDismissAnim.running) return;
                    expireTimer.stop();
                    cardDismissAnim.start();
                }

                ParallelAnimation {
                    id: notifEntrance
                    NumberAnimation { target: card; property: "opacity"; from: 0.0; to: 1.0; duration: 500; easing.type: Easing.OutCubic }
                    NumberAnimation { target: card; property: "scale"; from: 0.95; to: 1.0; duration: 500; easing.type: Easing.OutCubic }
                    NumberAnimation { target: cardSlide; property: "x"; from: 24; to: 0; duration: 500; easing.type: Easing.OutCubic }
                }

                ParallelAnimation {
                    id: cardDismissAnim
                    NumberAnimation { target: card; property: "opacity"; to: 0.0; duration: 250; easing.type: Easing.InCubic }
                    NumberAnimation { target: cardSlide; property: "x"; to: 28; duration: 250; easing.type: Easing.InCubic }
                    NumberAnimation { target: card; property: "scale"; to: 0.95; duration: 250; easing.type: Easing.InCubic }
                    onFinished: {
                        notifWindow.dismissNotif(card.notifId);
                    }
                }

                readonly property bool isWhatsApp: {
                    let ctx = (metaContext || "").toLowerCase();
                    return ctx.includes("whatsapp") ||
                           ctx.includes("web.whatsapp.com") ||
                           ctx.includes("whatsdesk") ||
                           ctx.includes("whatsie") ||
                           ctx.includes("zapzap") ||
                           ctx.includes("walc");
                }
                readonly property bool isInstagram: metaContext.includes("instagram") || metaContext.includes("instagram.com")

                // Dynamic Color Resolution based on sender
                property var palette: {
                    let lowerApp = (appName || "").toLowerCase();
                    let lowerSum = (summary || "").toLowerCase();
                    let lowerBody = (bodyText || "").toLowerCase();
                    let appIconName = (card.appIcon || "").toLowerCase();
                    let lowerIcon = appIconName;
                    let ctx = (card.metaContext || "").toLowerCase();

                    // Do Not Disturb / No Molestar (Focus Purple / Violet)
                    if (lowerApp.includes("disturb") || lowerApp.includes("molestar") || lowerApp.includes("dnd") ||
                        lowerSum.includes("disturb") || lowerSum.includes("molestar") || lowerSum.includes("dnd") ||
                        lowerIcon.includes("dnd")) {
                        let isOff = lowerSum.includes("disable") || lowerSum.includes("desactivad") || lowerBody.includes("all") || lowerBody.includes("todas");
                        return {
                            primary: isOff ? "#94a3b8" : "#a855f7",
                            secondary: isOff ? "#64748b" : "#7c3aed",
                            accent: isOff ? "#cbd5e1" : "#c084fc",
                            label: isOff ? "NO MOLESTAR: DESACTIVADO" : "NO MOLESTAR: ACTIVADO",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Night Light / Sunset Mode (Warm Amber / Gold)
                    if (lowerApp.includes("night") || lowerSum.includes("night") ||
                        lowerSum.includes("warm color") || appIconName.includes("weather-clear-night") ||
                        appIconName.includes("night-light") || lowerApp.includes("sunset")) {
                        return {
                            primary: "#f59e0b",    // Warm Amber
                            secondary: "#fbbf24",  // Amber Light
                            accent: "#d97706",     // Amber Deep
                            label: "NIGHT LIGHT",
                            isAntigravity: false,
                            isNightLight: true
                        };
                    }

                    // Power / AC Charging
                    if ((lowerApp.includes("power") || lowerApp.includes("bater") || lowerApp.includes("battery")) &&
                        (lowerSum.includes("ac power") || lowerSum.includes("charging") || lowerSum.includes("cargando") || lowerIcon.includes("charging"))) {
                        return {
                            primary: "#30d158",    // Apple Emerald
                            secondary: "#28b84d",  // Deep Emerald
                            accent: "#34d399",     // Mint Glow
                            label: "POWER",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Battery alert (Red LED beam for low/critical, amber for status)
                    if (lowerApp.includes("bater") || lowerApp.includes("battery") ||
                        lowerSum.includes("bater") || lowerSum.includes("battery") ||
                        lowerIcon.includes("battery") ||
                        (lowerApp.includes("power") && (lowerSum.includes("battery") || lowerSum.includes("power saver")))) {
                        let isCritical = lowerSum.includes("critical") || lowerSum.includes("crític") ||
                                         lowerSum.includes("5%") || lowerIcon.includes("empty") || card.urgency === 2;
                        let isLow = lowerSum.includes("low") || lowerSum.includes("baja") ||
                                    lowerSum.includes("10%") || lowerSum.includes("15%") || lowerIcon.includes("caution");
                        return {
                            primary: isCritical ? "#ff3b30" : (isLow ? "#ff9f0a" : "#ff9f0a"),
                            secondary: isCritical ? "#e22b31" : "#ea580c",
                            accent: isCritical ? "#ff787d" : "#fb923c",
                            label: isCritical ? "CRITICAL BATTERY" : (isLow ? "LOW BATTERY" : "BATTERY"),
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Hearing Protection, Ear Safety & Headphone Connection (Amber glow)
                    if (lowerApp.includes("hearing") || lowerSum.includes("hearing") || lowerSum.includes("high volume") ||
                        lowerApp.includes("headphone") || lowerSum.includes("headphone") || lowerApp.includes("audífono") || lowerSum.includes("audifono")) {
                        return {
                            primary: "#f59e0b",    // Amber warning
                            secondary: "#d97706",  // Deep amber
                            accent: "#fbbf24",     // Amber glow
                            label: (lowerSum.includes("connected") || lowerApp.includes("headphone")) ? "HEADPHONES" : "HEARING SAFETY",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Volume & Brightness (Neutral Apple Glass)
                    if (lowerApp.includes("volume") || lowerApp.includes("volumen")) {
                        return {
                            primary: "#ffffff",
                            secondary: "#e2e8f0",
                            accent: "#94a3b8",
                            label: "VOLUME",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    if (lowerApp.includes("bright") || lowerApp.includes("brillo")) {
                        return {
                            primary: "#ffffff",
                            secondary: "#fef08a",
                            accent: "#cbd5e1",
                            label: "BRIGHTNESS",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // --- 1. AI Coding Agents & LLMs ---
                    // Devin (Pure Specular White & Platinum / Clean Obsidian Glass)
                    if (lowerApp.includes("devin") || ctx.includes("devin")) {
                        return {
                            primary: "#ffffff",    // Specular White
                            secondary: "#e2e8f0",  // Crisp Platinum
                            accent: "#94a3b8",     // Slate Glow
                            label: "DEVIN",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Antigravity IDE (Cosmic Cyan / Electric Blue / Cosmic Indigo)
                    if (lowerApp.includes("antigravity") || ctx.includes("antigravity")) {
                        return {
                            primary: "#38bdf8",    // Electric Cyan
                            secondary: "#3b82f6",  // Antigravity Blue
                            accent: "#818cf8",     // Cosmic Indigo
                            label: "ANTIGRAVITY IDE",
                            isAntigravity: true,
                            isNightLight: false
                        };
                    }

                    // ChatGPT / OpenAI Codex (OpenAI Emerald Teal)
                    if (lowerApp.includes("chatgpt") || ctx.includes("chatgpt") || lowerApp.includes("codex") || ctx.includes("codex") || ctx.includes("openai")) {
                        return {
                            primary: "#10a37f",    // OpenAI Emerald
                            secondary: "#1a7f64",  // Deep Teal
                            accent: "#2dd4bf",     // Mint Glow
                            label: ctx.includes("codex") ? "OPENAI CODEX" : "CHATGPT",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Anthropic Claude (Claude Warm Terracotta)
                    if (lowerApp.includes("claude") || ctx.includes("claude") || ctx.includes("anthropic")) {
                        return {
                            primary: "#da7756",    // Claude Terracotta
                            secondary: "#c15f3e",  // Deep Rust
                            accent: "#f4a261",     // Warm Amber Glow
                            label: "CLAUDE",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Gemini (Gemini Sparkle Blue / Lilac)
                    if (lowerApp.includes("gemini") || ctx.includes("gemini") || ctx.includes("bard")) {
                        return {
                            primary: "#4e82ee",    // Sparkle Blue
                            secondary: "#9b72cf",  // Celestial Lilac
                            accent: "#ba9efc",     // Violet Glow
                            label: "GEMINI",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // DeepSeek (Cobalt Electric Blue)
                    if (lowerApp.includes("deepseek") || ctx.includes("deepseek")) {
                        return {
                            primary: "#0066ff",    // DeepSeek Blue
                            secondary: "#004ecc",  // Deep Navy
                            accent: "#60a5fa",     // Sky Glow
                            label: "DEEPSEEK",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // GitHub Copilot (Electric Lilac / Indigo)
                    if (lowerApp.includes("copilot") || ctx.includes("copilot")) {
                        return {
                            primary: "#6e40c9",    // Copilot Indigo
                            secondary: "#552da3",  // Deep Purple
                            accent: "#a371f7",     // Neon Glow
                            label: "GITHUB COPILOT",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Ollama (Pure Monochrome / Silver)
                    if (lowerApp.includes("ollama") || ctx.includes("ollama")) {
                        return {
                            primary: "#ffffff",    // Crisp White
                            secondary: "#cbd5e1",  // Slate Silver
                            accent: "#94a3b8",     // Soft Glow
                            label: "OLLAMA",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // --- 2. Custom Affiliations & Themes ---
                    // Formula 1 (Official F1 Racing Red & Speed Crimson)
                    if (ctx.includes("formula 1") || ctx.includes("formula1") || ctx.includes("grand prix") ||
                        ctx.includes("f1 tv") || ctx.includes("f1tv") ||
                        /(?:^|[\s\-_/|(\[])f1(?:$|[\s\-_/|)\].:])/i.test(ctx)) {
                        return {
                            primary: "#E10600",    // Official Formula 1 Racing Red
                            secondary: "#b80500",  // Deep Crimson
                            accent: "#ff3b30",     // Speed Carmine Glow
                            label: "FORMULA 1",
                            isAntigravity: false,
                            isNightLight: false,
                            isF1: true
                        };
                    }

                    // Spider-Man (Marvel Vibrant Red & Electric Blue)
                    if (ctx.includes("spider-man") || ctx.includes("spiderman") || ctx.includes("spider man") ||
                        ctx.includes("spider_man") || ctx.includes("hombre araña") || ctx.includes("peter parker") ||
                        ctx.includes("miles morales") || ctx.includes("spider-verse") || ctx.includes("spiderverse")) {
                        return {
                            primary: "#e23636",    // Spidey Crimson
                            secondary: "#0266c8",  // Web Electric Blue
                            accent: "#38bdf8",     // Neon Blue Glow
                            label: "SPIDER-MAN",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Colgate-Palmolive (Electric Blue matching logo)
                    if (ctx.includes("colgate") || ctx.includes("colpal")) {
                        return {
                            primary: "#0067fe",    // Colgate Blue
                            secondary: "#0052fe",  // Deep Blue
                            accent: "#60a5fa",     // Soft Blue Glow
                            label: "COLGATE-PALMOLIVE",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Troyanos UAQ (UAQ Royal Blue & Gold)
                    if (ctx.includes("troyanos") || ctx.includes("uaq")) {
                        return {
                            primary: "#0072ce",    // UAQ Royal Blue
                            secondary: "#002b49",  // Deep Navy
                            accent: "#f2a900",     // Troyanos Gold
                            label: "TROYANOS UAQ",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // --- 3. Social & Messaging ---
                    // WhatsApp (Vibrant Emerald Green)
                    if (card.isWhatsApp) {
                        return {
                            primary: "#25D366",    // WhatsApp Emerald Green
                            secondary: "#128C7E",  // Deep Teal Green
                            accent: "#34D399",     // Mint Glow
                            label: "WHATSAPP",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Instagram (Vibrant Rose/Magenta)
                    if (card.isInstagram) {
                        return {
                            primary: "#E1306C",    // Instagram Electric Rose
                            secondary: "#C13584",  // Instagram Royal Purple
                            accent: "#F77737",     // Instagram Warm Amber
                            label: "INSTAGRAM",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Discord / Vesktop (Blurple)
                    if (lowerApp.includes("discord") || lowerApp.includes("vesktop") || ctx.includes("discord")) {
                        return {
                            primary: "#5865f2",    // Discord Blurple
                            secondary: "#7289da",  // Soft Lilac
                            accent: "#818cf8",     // Indigo Glow
                            label: "DISCORD",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Telegram (Electric Cyan-Blue)
                    if (lowerApp.includes("telegram") || ctx.includes("telegram")) {
                        return {
                            primary: "#229ed9",    // Telegram Blue
                            secondary: "#0088cc",  // Deep Cyan
                            accent: "#38bdf8",     // Sky Glow
                            label: "TELEGRAM",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Slack (Aubergine & Emerald)
                    if (lowerApp.includes("slack") || ctx.includes("slack")) {
                        return {
                            primary: "#e01e5a",    // Slack Rose
                            secondary: "#ecb22e",  // Slack Gold
                            accent: "#2eb67d",     // Slack Green
                            label: "SLACK",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // LinkedIn (Corporate Electric Blue)
                    if (lowerApp.includes("linkedin") || ctx.includes("linkedin")) {
                        return {
                            primary: "#0a66c2",    // LinkedIn Blue
                            secondary: "#004182",  // Deep Navy
                            accent: "#38bdf8",     // Sky Glow
                            label: "LINKEDIN",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Reddit (Vibrant Reddit Orange)
                    if (lowerApp.includes("reddit") || ctx.includes("reddit")) {
                        return {
                            primary: "#ff4500",    // Reddit Orange
                            secondary: "#e03d00",  // Deep Amber-Red
                            accent: "#ff784e",     // Coral Glow
                            label: "REDDIT",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Twitter / X (Pure Monochrome Platinum)
                    if (lowerApp.includes("twitter") || ctx.includes("twitter") || ctx.includes("x.com") || lowerApp === "x") {
                        return {
                            primary: "#ffffff",    // White
                            secondary: "#cbd5e1",  // Slate Silver
                            accent: "#94a3b8",     // Slate Glow
                            label: "X / TWITTER",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Twitch (Twitch Purple)
                    if (lowerApp.includes("twitch") || ctx.includes("twitch")) {
                        return {
                            primary: "#9146ff",    // Twitch Electric Purple
                            secondary: "#772ce8",  // Deep Violet
                            accent: "#a970ff",     // Neon Glow
                            label: "TWITCH",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // --- 4. Google Workspace Ecosystem ---
                    // Gmail (Google Mail Red)
                    if (lowerApp.includes("gmail") || ctx.includes("gmail") || ctx.includes("mail.google")) {
                        return {
                            primary: "#ea4335",    // Gmail Red
                            secondary: "#c5221f",  // Deep Crimson
                            accent: "#f87171",     // Coral Glow
                            label: "GMAIL",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Meet (Google Meet Green)
                    if (lowerApp.includes("meet") || ctx.includes("google meet") || ctx.includes("meet.google")) {
                        return {
                            primary: "#00ac47",    // Meet Green
                            secondary: "#00832d",  // Deep Jade
                            accent: "#34d399",     // Mint Glow
                            label: "GOOGLE MEET",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Classroom (Classroom Chalk Green)
                    if (lowerApp.includes("classroom") || ctx.includes("classroom") || ctx.includes("google classroom")) {
                        return {
                            primary: "#0f9d58",    // Classroom Green
                            secondary: "#137333",  // Forest Green
                            accent: "#f4b400",     // Warm Gold
                            label: "GOOGLE CLASSROOM",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Docs (Docs Royal Blue)
                    if (ctx.includes("google docs") || ctx.includes("docs.google") || ctx.includes("documentos de google")) {
                        return {
                            primary: "#4285f4",    // Google Blue
                            secondary: "#1a73e8",  // Royal Blue
                            accent: "#93c5fd",     // Sky Glow
                            label: "GOOGLE DOCS",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Sheets (Sheets Emerald)
                    if (ctx.includes("google sheets") || ctx.includes("sheets.google") || ctx.includes("hojas de cálculo") || ctx.includes("hoja de cálculo")) {
                        return {
                            primary: "#0f9d58",    // Sheets Emerald
                            secondary: "#1e8e3e",  // Deep Green
                            accent: "#6ee7b7",     // Mint Glow
                            label: "GOOGLE SHEETS",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Slides (Slides Sun Yellow)
                    if (ctx.includes("google slides") || ctx.includes("slides.google") || ctx.includes("presentaciones de google")) {
                        return {
                            primary: "#f4b400",    // Slides Yellow
                            secondary: "#f9ab00",  // Deep Gold
                            accent: "#fde047",     // Bright Sun
                            label: "GOOGLE SLIDES",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Drive (Drive Trifold Tricolor)
                    if (ctx.includes("google drive") || ctx.includes("drive.google") || ctx.includes("mi unidad") || ctx.includes("my drive")) {
                        return {
                            primary: "#0f9d58",    // Drive Green
                            secondary: "#4285f4",  // Drive Blue
                            accent: "#f4b400",     // Drive Yellow
                            label: "GOOGLE DRIVE",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Keep (Keep Amber)
                    if (ctx.includes("google keep") || ctx.includes("keep.google")) {
                        return {
                            primary: "#fbbc04",    // Keep Amber
                            secondary: "#f9ab00",  // Deep Gold
                            accent: "#fde047",     // Sun Glow
                            label: "GOOGLE KEEP",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Forms (Forms Purple)
                    if (ctx.includes("google forms") || ctx.includes("forms.google") || ctx.includes("formularios de google")) {
                        return {
                            primary: "#7248b9",    // Forms Purple
                            secondary: "#5e35b1",  // Deep Violet
                            accent: "#c084fc",     // Lilac Glow
                            label: "GOOGLE FORMS",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // --- 5. Media & Streaming ---
                    // Spotify (Balanced Green)
                    if (lowerApp.includes("spotify") || ctx.includes("spotify")) {
                        return {
                            primary: "#1db954",    // Spotify Green
                            secondary: "#168a3e",  // Dark Green
                            accent: "#10b981",     // Emerald Glow
                            label: "SPOTIFY",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // YouTube / YouTube Music (YouTube Red)
                    if (lowerApp.includes("youtube") || ctx.includes("youtube") || ctx.includes("youtu.be")) {
                        return {
                            primary: "#ff0000",    // YouTube Red
                            secondary: "#cc0000",  // Deep Crimson
                            accent: "#ff4d4d",     // Red Glow
                            label: "YOUTUBE",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // SoundCloud (SoundCloud Sunset Orange)
                    if (lowerApp.includes("soundcloud") || ctx.includes("soundcloud")) {
                        return {
                            primary: "#ff5500",    // SoundCloud Orange
                            secondary: "#e04b00",  // Deep Sunset
                            accent: "#ff884d",     // Warm Glow
                            label: "SOUNDCLOUD",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Netflix (Netflix Cinema Red)
                    if (lowerApp.includes("netflix") || ctx.includes("netflix")) {
                        return {
                            primary: "#e50914",    // Netflix Red
                            secondary: "#b20710",  // Dark Ruby
                            accent: "#ff3b30",     // Electric Red
                            label: "NETFLIX",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Disney+ (Disney Deep Royal Blue)
                    if (ctx.includes("disney+") || ctx.includes("disneyplus") || ctx.includes("disney plus")) {
                        return {
                            primary: "#113ccf",    // Disney Royal Blue
                            secondary: "#002796",  // Deep Space Navy
                            accent: "#38bdf8",     // Ice Glow
                            label: "DISNEY+",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // HBO Max / Max (Max Royal Purple & Neon Blue)
                    if (ctx.includes("hbo max") || ctx.includes("hbomax") || ctx.includes("max.com") || lowerApp.includes("hbo")) {
                        return {
                            primary: "#5822b4",    // Max Violet
                            secondary: "#002be7",  // Electric Blue
                            accent: "#a855f7",     // Purple Sheen
                            label: "MAX",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Prime Video (Amazon Sky Blue)
                    if (ctx.includes("prime video") || ctx.includes("amazon prime") || ctx.includes("primevideo")) {
                        return {
                            primary: "#00a8e1",    // Prime Blue
                            secondary: "#0073a8",  // Ocean Blue
                            accent: "#38bdf8",     // Cyan Glow
                            label: "PRIME VIDEO",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Stremio (Stremio Purple)
                    if (lowerApp.includes("stremio") || ctx.includes("stremio")) {
                        return {
                            primary: "#6a38b3",    // Stremio Purple
                            secondary: "#502390",  // Deep Violet
                            accent: "#a855f7",     // Lilac Glow
                            label: "STREMIO",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // --- 6. Developer & System Tools ---
                    // GitHub (Pearl White & Sky Blue)
                    if ((lowerApp.includes("github") || ctx.includes("github") || ctx.includes("github.com")) && !ctx.includes("copilot")) {
                        return {
                            primary: "#f0f6fc",    // Pearl White
                            secondary: "#8b949e",  // Slate Silver
                            accent: "#58a6ff",     // GitHub Blue
                            label: "GITHUB",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Git / Lazygit (Git Flame Orange)
                    if (lowerApp.includes("lazygit") || ctx.includes("lazygit") || (lowerApp === "git" || ctx.includes("git commit") || ctx.includes("git push"))) {
                        return {
                            primary: "#f05032",    // Git Orange
                            secondary: "#d83e20",  // Deep Burnt
                            accent: "#fb923c",     // Amber Glow
                            label: "GIT",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Docker / Containers / Podman / Lazydocker (Docker Cyan-Blue)
                    if (lowerApp.includes("docker") || ctx.includes("docker") || ctx.includes("lazydocker") || ctx.includes("podman") || ctx.includes("container")) {
                        return {
                            primary: "#2496ed",    // Docker Blue
                            secondary: "#0db7ed",  // Ocean Cyan
                            accent: "#38bdf8",     // Sky Glow
                            label: "DOCKER",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Node.js (Node Emerald)
                    if (ctx.includes("node.js") || ctx.includes("nodejs") || ctx.includes(" npm") || ctx.includes("npm ") || ctx.includes("bun ") || ctx.includes("vite")) {
                        return {
                            primary: "#339933",    // Node Green
                            secondary: "#267326",  // Deep Green
                            accent: "#4ade80",     // Mint Glow
                            label: "NODE.JS",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // PostgreSQL / pgAdmin / DBeaver / psql (Postgres Blue)
                    if (lowerApp.includes("postgres") || lowerApp.includes("pgadmin") || ctx.includes("postgres") || ctx.includes("pgadmin") || ctx.includes("psql") || ctx.includes("dbeaver")) {
                        return {
                            primary: "#336791",    // Postgres Blue
                            secondary: "#244b6b",  // Navy
                            accent: "#38bdf8",     // Cyan Glow
                            label: "POSTGRESQL",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Swagger / OpenAPI (Swagger Lime-Green)
                    if (lowerApp.includes("swagger") || ctx.includes("swagger") || ctx.includes("openapi") || ctx.includes("api-docs")) {
                        return {
                            primary: "#85ea2d",    // Swagger Lime
                            secondary: "#49cc90",  // Mint Green
                            accent: "#a3e635",     // Lime Glow
                            label: "SWAGGER API",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Kitty Terminal / Terminal (Terminal Warm Amber-Orange)
                    if (lowerApp === "kitty" || lowerApp.includes("terminal") || ctx.includes("kitty") || ctx.includes("alacritty")) {
                        return {
                            primary: "#f97316",    // Warm Orange
                            secondary: "#ea580c",  // Burnt Amber
                            accent: "#fb923c",     // Soft Glow
                            label: "KITTY TERMINAL",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // VS Code (Code Electric Blue)
                    if (lowerApp.includes("code") || lowerApp.includes("vscode") || ctx.includes("vscode")) {
                        return {
                            primary: "#007acc",    // VS Code Blue
                            secondary: "#0098ff",  // Electric Blue
                            accent: "#38bdf8",     // Sky Glow
                            label: "VS CODE",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // LeetCode (LeetCode Amber-Gold)
                    if (lowerApp.includes("leetcode") || ctx.includes("leetcode")) {
                        return {
                            primary: "#ffa116",    // LeetCode Amber
                            secondary: "#ea8c00",  // Deep Gold
                            accent: "#fbbf24",     // Warm Glow
                            label: "LEETCODE",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Notion (Notion Obsidian White)
                    if (lowerApp.includes("notion") || ctx.includes("notion")) {
                        return {
                            primary: "#ffffff",    // Crisp White
                            secondary: "#e2e8f0",  // Light Slate
                            accent: "#64748b",     // Slate Glass
                            label: "NOTION",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // FileZilla (FileZilla Burgundy-Red)
                    if (lowerApp.includes("filezilla") || ctx.includes("filezilla")) {
                        return {
                            primary: "#ba0000",    // Burgundy
                            secondary: "#8b0000",  // Dark Wine
                            accent: "#ef5350",     // Red Sheen
                            label: "FILEZILLA",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Dolphin / File Manager (KDE Blue)
                    if (lowerApp.includes("dolphin") || lowerApp.includes("thunar") || lowerApp.includes("nautilus") || ctx.includes("dolphin")) {
                        return {
                            primary: "#1d99f3",    // KDE Blue
                            secondary: "#0d6efd",  // Electric Blue
                            accent: "#60a5fa",     // Soft Sky
                            label: "FILES",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // EasyEffects / Audio DSP (Audio Violet)
                    if (lowerApp.includes("easyeffects") || lowerApp.includes("pavucontrol") || ctx.includes("easyeffects")) {
                        return {
                            primary: "#7c3aed",    // Audio Violet
                            secondary: "#6d28d9",  // Deep Purple
                            accent: "#a78bfa",     // Glow Lilac
                            label: "EASYEFFECTS",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Firefox / Zen (Warm Flame)
                    if (lowerApp.includes("firefox") || lowerApp.includes("zen")) {
                        return {
                            primary: "#ff7139",    // Firefox Orange
                            secondary: "#ff3b30",  // Coral Red
                            accent: "#a855f7",     // Violet Flame
                            label: "BROWSER",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Chromium (Cyan & Blue shades)
                    if (lowerApp.includes("chromium") || ctx.includes("chromium")) {
                        return {
                            primary: "#1767d1",    // Chromium Blue
                            secondary: "#679ef5",  // Sky Cyan
                            accent: "#afccf9",     // Ice Glow
                            label: "CHROMIUM",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Chrome (Google Blue)
                    if (lowerApp.includes("chrome") || ctx.includes("chrome")) {
                        return {
                            primary: "#4285f4",    // Google Blue
                            secondary: "#ea4335",  // Google Red
                            accent: "#fbbc05",     // Google Yellow
                            label: "CHROME",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Calendar / Reminders (Category-driven LED beam & border)
                    if (lowerApp.includes("remind") || lowerApp.includes("recordatorio") || lowerApp.includes("calendar") ||
                        lowerSum.includes("reminder") || lowerSum.includes("recordatorio") || lowerSum.includes("calendar")) {

                        let hintCat = card.hintCategory || "";
                        let fullTxt = (hintCat + " " + lowerSum + " " + (card.bodyText || "").toLowerCase());

                        // Sara (Romantic Rose / Pink)
                        if (fullTxt.includes("sara")) {
                            return {
                                primary: "#ff2d55",
                                secondary: "#e11d48",
                                accent: "#f43f5e",
                                label: "REMINDERS • SARA",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Marvel / Doomsday (Doctor Doom Emerald Green)
                        if (fullTxt.includes("marvel") || fullTxt.includes("doomsday")) {
                            return {
                                primary: "#10b981",
                                secondary: "#059669",
                                accent: "#34d399",
                                label: "REMINDERS • MARVEL",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Formula 1 (Official F1 Racing Red)
                        if (fullTxt.includes("f1") || fullTxt.includes("formula 1") || fullTxt.includes("formula1") || fullTxt.includes("grand prix")) {
                            return {
                                primary: "#E10600",
                                secondary: "#b80500",
                                accent: "#ff3b30",
                                label: "REMINDERS • F1",
                                isAntigravity: false,
                                isNightLight: false,
                                isF1: true
                            };
                        }

                        // Colgate-Palmolive (Electric Blue)
                        if (fullTxt.includes("colgate")) {
                            return {
                                primary: "#0067fe",
                                secondary: "#0052fe",
                                accent: "#60a5fa",
                                label: "REMINDERS • COLGATE",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Personal (Orange)
                        if (fullTxt.includes("personal")) {
                            return {
                                primary: "#f97316",
                                secondary: "#ea580c",
                                accent: "#fb923c",
                                label: "REMINDERS • PERSONAL",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Projects (Green)
                        if (fullTxt.includes("project")) {
                            return {
                                primary: "#10b981",
                                secondary: "#059669",
                                accent: "#34d399",
                                label: "REMINDERS • PROJECTS",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Free Lance (Electric Cyan)
                        if (fullTxt.includes("free lance") || fullTxt.includes("free-lance") || fullTxt.includes("freelance")) {
                            return {
                                primary: "#06b6d4",
                                secondary: "#0891b2",
                                accent: "#22d3ee",
                                label: "REMINDERS • FREE LANCE",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // School (Purple)
                        if (fullTxt.includes("school") || fullTxt.includes("escuela") || fullTxt.includes("troyanos")) {
                            return {
                                primary: "#a855f7",
                                secondary: "#9333ea",
                                accent: "#c084fc",
                                label: "REMINDERS • SCHOOL",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // General / All Reminders (Turquoise / Purple)
                        return {
                            primary: "#06b6d4",
                            secondary: "#3b82f6",
                            accent: "#a855f7",
                            label: "REMINDERS",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Hyprland / Arch Linux (Official Arch Cyan)
                    if (lowerApp.includes("hypr") || lowerApp.includes("arch") || lowerSum.includes("hypr") || lowerSum.includes("arch") || ctx.includes("hypr") || ctx.includes("arch")) {
                        return {
                            primary: "#1793d1",    // Arch Cyan
                            secondary: "#0f6c9c",  // Deep Arch Blue
                            accent: "#38bdf8",     // Sky Blue Glow
                            label: lowerApp.includes("hypr") ? "HYPRLAND" : "ARCH LINUX",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // System / Power / Critical alerts (Red LED beam)
                    if (lowerApp.includes("system") || lowerApp.includes("sistema") ||
                        lowerApp.includes("power") || lowerApp.includes("hypr-battery") || card.urgency === 2) {
                        return {
                            primary: "#ff3b30",    // Apple Coral Red
                            secondary: "#e22b31",  // Deep Carmine
                            accent: "#ff787d",     // Red glow
                            label: (appName && appName.length > 0) ? appName.toUpperCase() : "SYSTEM",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Default (Dynamic Wallpaper Accent)
                    return {
                        primary: theme.blue,
                        secondary: theme.blueLight,
                        accent: theme.blueDeep,
                        label: (appName || "NOTIFICATION").toUpperCase(),
                        isAntigravity: false,
                        isNightLight: false
                    };
                }

                // Icon Resolution (High quality vector & brand assets)
                property string resolvedIcon: {
                    let rawIcon = card.appIcon || "";
                    let lowerIcon = rawIcon.toLowerCase();
                    let lowerApp = (appName || "").toLowerCase();
                    let lowerSum = (card.summary || "").toLowerCase();
                    let lowerBody = (card.bodyText || "").toLowerCase();
                    let ctx = (card.metaContext || "").toLowerCase();

                    // Do Not Disturb / No Molestar official SVG icons
                    if (lowerApp.includes("disturb") || lowerApp.includes("molestar") || lowerApp.includes("dnd") ||
                        lowerSum.includes("disturb") || lowerSum.includes("molestar") || lowerSum.includes("dnd") ||
                        lowerIcon.includes("dnd")) {
                        let isOff = lowerSum.includes("disable") || lowerSum.includes("desactivad") || lowerBody.includes("all") || lowerBody.includes("todas");
                        return isOff ? "file:///home/ferram/.local/share/icons/dnd-off.svg" : "file:///home/ferram/.local/share/icons/dnd-on.svg";
                    }

                    if (palette.isAntigravity) {
                        return "/usr/share/pixmaps/antigravity.png";
                    }
                    let desktopEntry = (card.desktopEntry || "").toLowerCase();

                    // Devin official desktop logo
                    if (lowerApp.includes("devin") || desktopEntry.includes("devin") || lowerIcon.includes("devin") || ctx.includes("devin")) {
                        return "file:///usr/share/pixmaps/devin-desktop.png";
                    }

                    // ChatGPT / OpenAI Codex
                    if (lowerApp.includes("chatgpt") || ctx.includes("chatgpt") || lowerApp.includes("codex") || ctx.includes("codex") || ctx.includes("openai")) {
                        return "file:///home/ferram/.local/share/icons/chatgpt.svg";
                    }

                    // Claude
                    if (lowerApp.includes("claude") || ctx.includes("claude") || ctx.includes("anthropic")) {
                        return "file:///home/ferram/.local/share/icons/claude.svg";
                    }

                    // Gemini
                    if (lowerApp.includes("gemini") || ctx.includes("gemini") || ctx.includes("bard")) {
                        return "file:///home/ferram/.local/share/icons/gemini.svg";
                    }

                    // DeepSeek
                    if (lowerApp.includes("deepseek") || ctx.includes("deepseek")) {
                        return "file:///home/ferram/.local/share/icons/deepseek.svg";
                    }

                    // Copilot
                    if (lowerApp.includes("copilot") || ctx.includes("copilot")) {
                        return "file:///home/ferram/.local/share/icons/copilot.svg";
                    }

                    // Ollama
                    if (lowerApp.includes("ollama") || ctx.includes("ollama")) {
                        return "file:///home/ferram/.local/share/icons/ollama.svg";
                    }

                    // Formula 1 official SVG icon
                    if (ctx.includes("formula 1") || ctx.includes("formula1") || ctx.includes("grand prix") ||
                        ctx.includes("f1 tv") || ctx.includes("f1tv") ||
                        /(?:^|[\s\-_/|(\[])f1(?:$|[\s\-_/|)\].:])/i.test(ctx)) {
                        return "file:///home/ferram/.local/share/icons/f1.svg";
                    }

                    // Spider-Man
                    if (ctx.includes("spider-man") || ctx.includes("spiderman") || ctx.includes("spider man") ||
                        ctx.includes("spider_man") || ctx.includes("hombre araña") || ctx.includes("peter parker") ||
                        ctx.includes("miles morales") || ctx.includes("spider-verse") || ctx.includes("spiderverse")) {
                        return "file:///home/ferram/.local/share/icons/spiderman.png";
                    }

                    // Colgate-Palmolive
                    if (ctx.includes("colgate") || ctx.includes("colpal")) {
                        return "file:///home/ferram/.local/share/icons/cp.svg";
                    }

                    // Troyanos UAQ
                    if (ctx.includes("troyanos") || ctx.includes("uaq")) {
                        return "file:///home/ferram/.local/share/icons/troyanos.svg";
                    }

                    // Kitty Terminal
                    if (lowerApp === "kitty" || desktopEntry === "kitty" ||
                        lowerIcon === "kitty" || /(?:^|\/)kitty\.(?:svg|png)$/.test(lowerIcon)) {
                        return "file:///home/ferram/.local/share/icons/kitty.svg";
                    }

                    // Do Not Disturb / No Molestar official SVG icons
                    if (lowerApp.includes("disturb") || lowerApp.includes("molestar") ||
                        lowerSum.includes("disturb") || lowerSum.includes("molestar") ||
                        lowerIcon.includes("dnd") || lowerApp.includes("dnd")) {
                        let isOff = lowerSum.includes("disable") || lowerSum.includes("desactivad") || lowerBody.includes("all") || lowerBody.includes("todas");
                        return isOff ? "file:///home/ferram/.local/share/icons/dnd-off.svg" : "file:///home/ferram/.local/share/icons/dnd-on.svg";
                    }

                    // WhatsApp official SVG icon
                    if (card.isWhatsApp) {
                        return "file:///home/ferram/.local/share/icons/whatsapp.svg";
                    }

                    // Instagram official SVG icon
                    if (card.isInstagram) {
                        return "file:///home/ferram/.local/share/icons/instagram.svg";
                    }

                    // GitHub official SVG icon
                    if ((lowerApp.includes("github") || ctx.includes("github") || ctx.includes("github.com")) && !ctx.includes("copilot")) {
                        return "file:///home/ferram/.local/share/icons/github.svg";
                    }

                    // Git official SVG icon
                    if (lowerApp.includes("lazygit") || ctx.includes("lazygit") || (lowerApp === "git" || ctx.includes("git commit") || ctx.includes("git push"))) {
                        return "file:///home/ferram/.local/share/icons/git.svg";
                    }

                    // Docker official SVG icon
                    if (lowerApp.includes("docker") || ctx.includes("docker") || ctx.includes("lazydocker") || ctx.includes("podman") || ctx.includes("container")) {
                        return "file:///home/ferram/.local/share/icons/docker.svg";
                    }

                    // Node.js official SVG icon
                    if (ctx.includes("node.js") || ctx.includes("nodejs") || ctx.includes(" npm") || ctx.includes("npm ") || ctx.includes("bun ") || ctx.includes("vite")) {
                        return "file:///home/ferram/.local/share/icons/node.svg";
                    }

                    // PostgreSQL / pgAdmin official SVG icon
                    if (lowerApp.includes("postgres") || lowerApp.includes("pgadmin") || ctx.includes("postgres") || ctx.includes("pgadmin") || ctx.includes("psql") || ctx.includes("dbeaver")) {
                        return "file:///home/ferram/.local/share/icons/postgresql.svg";
                    }

                    // Swagger official SVG icon
                    if (lowerApp.includes("swagger") || ctx.includes("swagger") || ctx.includes("openapi") || ctx.includes("api-docs")) {
                        return "file:///home/ferram/.local/share/icons/swagger.svg";
                    }

                    // LeetCode official SVG icon
                    if (lowerApp.includes("leetcode") || ctx.includes("leetcode")) {
                        return "file:///home/ferram/.local/share/icons/leetcode.svg";
                    }

                    // Notion official SVG icon
                    if (lowerApp.includes("notion") || ctx.includes("notion")) {
                        return "file:///home/ferram/.local/share/icons/notion.svg";
                    }

                    // LinkedIn official SVG icon
                    if (lowerApp.includes("linkedin") || lowerSum.includes("linkedin") || ctx.includes("linkedin")) {
                        return "file:///home/ferram/.local/share/icons/linkedin.svg";
                    }

                    // Spotify official SVG icon
                    if (lowerApp.includes("spotify") || lowerIcon.includes("spotify") || ctx.includes("spotify")) {
                        return "file:///home/ferram/.local/share/icons/spotify.svg";
                    }

                    // YouTube official SVG icon
                    if (lowerApp.includes("youtube") || ctx.includes("youtube") || ctx.includes("youtu.be")) {
                        return "file:///home/ferram/.local/share/icons/youtube.svg";
                    }

                    // SoundCloud official SVG icon
                    if (lowerApp.includes("soundcloud") || ctx.includes("soundcloud")) {
                        return "file:///home/ferram/.local/share/icons/soundcloud.svg";
                    }

                    // Netflix official SVG icon
                    if (lowerApp.includes("netflix") || ctx.includes("netflix")) {
                        return "file:///home/ferram/.local/share/icons/netflix.svg";
                    }

                    // Disney+ official SVG icon
                    if (ctx.includes("disney+") || ctx.includes("disneyplus") || ctx.includes("disney plus")) {
                        return "file:///home/ferram/.local/share/icons/disney.svg";
                    }

                    // HBO Max official SVG icon
                    if (ctx.includes("hbo max") || ctx.includes("hbomax") || ctx.includes("max.com") || lowerApp.includes("hbo")) {
                        return "file:///home/ferram/.local/share/icons/hbo.svg";
                    }

                    // Prime Video official SVG icon
                    if (ctx.includes("prime video") || ctx.includes("amazon prime") || ctx.includes("primevideo")) {
                        return "file:///home/ferram/.local/share/icons/prime.svg";
                    }

                    // Stremio official SVG icon
                    if (lowerApp.includes("stremio") || ctx.includes("stremio")) {
                        return "file:///home/ferram/.local/share/icons/stremio.svg";
                    }

                    // Reddit official SVG icon
                    if (lowerApp.includes("reddit") || ctx.includes("reddit")) {
                        return "file:///home/ferram/.local/share/icons/reddit.svg";
                    }

                    // Twitter / X official SVG icon
                    if (lowerApp.includes("twitter") || ctx.includes("twitter") || ctx.includes("x.com") || lowerApp === "x") {
                        return "file:///home/ferram/.local/share/icons/x.svg";
                    }

                    // Twitch official SVG icon
                    if (lowerApp.includes("twitch") || ctx.includes("twitch")) {
                        return "file:///home/ferram/.local/share/icons/twitch.svg";
                    }

                    // Discord / Vesktop official SVG icon
                    if (lowerApp.includes("discord") || lowerApp.includes("vesktop") || lowerIcon.includes("discord") || ctx.includes("discord")) {
                        return "file:///home/ferram/.local/share/icons/discord.svg";
                    }

                    // Telegram official SVG icon
                    if (lowerApp.includes("telegram") || lowerIcon.includes("telegram") || ctx.includes("telegram")) {
                        return "file:///home/ferram/.local/share/icons/telegram.svg";
                    }

                    // Google Classroom official SVG icon
                    if (lowerApp.includes("classroom") || lowerSum.includes("classroom") || ctx.includes("classroom")) {
                        return "file:///home/ferram/.local/share/icons/classroom.svg";
                    }

                    // Google Meet official SVG icon
                    if (lowerApp.includes("meet") || lowerSum.includes("google meet") || ctx.includes("meet")) {
                        return "file:///home/ferram/.local/share/icons/meet.svg";
                    }

                    // Google Docs official SVG icon
                    if (ctx.includes("google docs") || ctx.includes("docs.google") || ctx.includes("documentos de google")) {
                        return "file:///home/ferram/.local/share/icons/docs.svg";
                    }

                    // Google Sheets official SVG icon
                    if (ctx.includes("google sheets") || ctx.includes("sheets.google") || ctx.includes("hojas de cálculo") || ctx.includes("hoja de cálculo")) {
                        return "file:///home/ferram/.local/share/icons/sheets.svg";
                    }

                    // Google Slides official SVG icon
                    if (ctx.includes("google slides") || ctx.includes("slides.google") || ctx.includes("presentaciones de google")) {
                        return "file:///home/ferram/.local/share/icons/slides.svg";
                    }

                    // Google Drive official SVG icon
                    if (ctx.includes("google drive") || ctx.includes("drive.google") || ctx.includes("mi unidad") || ctx.includes("my drive")) {
                        return "file:///home/ferram/.local/share/icons/drive.svg";
                    }

                    // Google Keep official SVG icon
                    if (ctx.includes("google keep") || ctx.includes("keep.google")) {
                        return "file:///home/ferram/.local/share/icons/keep.svg";
                    }

                    // Google Forms official SVG icon
                    if (ctx.includes("google forms") || ctx.includes("forms.google") || ctx.includes("formularios de google")) {
                        return "file:///home/ferram/.local/share/icons/forms.svg";
                    }

                    // Gmail official SVG icon
                    if (lowerApp.includes("gmail") || ctx.includes("gmail") || ctx.includes("mail.google")) {
                        return "file:///home/ferram/.local/share/icons/gmail.svg";
                    }

                    // Chromium official SVG icon (monochromatic blue)
                    if (lowerApp.includes("chromium") || lowerIcon.includes("chromium") || ctx.includes("chromium")) {
                        return "file:///home/ferram/.local/share/icons/chromium.svg";
                    }

                    // Google Chrome official SVG icon
                    if (lowerApp.includes("chrome") || lowerIcon.includes("chrome") || ctx.includes("chrome")) {
                        return "file:///home/ferram/.local/share/icons/chrome.svg";
                    }

                    // Hyprland / Arch Linux official SVG logo
                    if (lowerApp.includes("hypr") || lowerApp.includes("arch") || lowerSum.includes("hypr") || lowerSum.includes("arch") || ctx.includes("hypr") || ctx.includes("arch")) {
                        return "file:///home/ferram/.local/share/icons/arch.svg";
                    }

                    // Hearing Safety / Headphone Connected vector icon
                    if (lowerApp.includes("hearing") || lowerSum.includes("hearing") || lowerSum.includes("high volume") ||
                        lowerApp.includes("headphone") || lowerSum.includes("headphone") || lowerIcon.includes("headphone") ||
                        lowerSum.includes("audífono") || lowerSum.includes("audifono")) {
                        return "file:///home/ferram/.local/share/icons/headphones.svg";
                    }

                    // Calendar / Reminders custom 3D SVG icon
                    if (lowerApp.includes("remind") || lowerApp.includes("recordatorio") || lowerApp.includes("calendar")) {
                        if (ctx.includes("sara")) return "file:///home/ferram/.local/share/icons/heart.svg";
                        if (ctx.includes("marvel") || ctx.includes("doomsday")) return "file:///home/ferram/.local/share/icons/marvel.svg";
                        return "file:///home/ferram/.local/share/icons/calendar-3d.svg";
                    }

                    // FileZilla icon
                    if (lowerApp.includes("filezilla") || ctx.includes("filezilla")) {
                        return "file:///usr/share/icons/hicolor/scalable/apps/filezilla.svg";
                    }

                    // Night Light crisp SVG Moon
                    if (palette.isNightLight || lowerIcon.includes("weather-clear-night") || lowerIcon.includes("night-light")) {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z' fill='%23f59e0b'/></svg>";
                    }

                    // Display Brightness / Sun icon
                    if (lowerIcon.includes("display-brightness") || lowerIcon.includes("brightness") || lowerApp.includes("brightness")) {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23ffffff' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='4'/><line x1='12' y1='2' x2='12' y2='4'/><line x1='12' y1='20' x2='12' y2='22'/><line x1='4.93' y1='4.93' x2='6.34' y2='6.34'/><line x1='17.66' y1='17.66' x2='19.07' y2='19.07'/><line x1='2' y1='12' x2='4' y2='12'/><line x1='20' y1='12' x2='22' y2='12'/><line x1='4.93' y1='19.07' x2='6.34' y2='17.66'/><line x1='17.66' y1='6.34' x2='19.07' y2='4.93'/></svg>";
                    }

                    // Volume icon
                    if (lowerApp.includes("volume") || lowerIcon.includes("audio-volume")) {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23ffffff' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><polygon points='11 5 6 9 2 9 2 15 6 15 11 19 11 5'/><path d='M15.54 8.46a5 5 0 0 1 0 7.07'/><path d='M19.07 4.93a10 10 0 0 1 0 14.14'/></svg>";
                    }

                    // Battery & Power official vector SVG icons
                    if (lowerApp.includes("bater") || lowerApp.includes("battery") ||
                        lowerSum.includes("bater") || lowerSum.includes("battery") ||
                        lowerIcon.includes("battery") ||
                        (lowerApp.includes("power") && (lowerSum.includes("power") || lowerSum.includes("battery")))) {
                        if (lowerIcon.includes("charging") || lowerSum.includes("charging") || lowerSum.includes("ac power") || lowerSum.includes("conectad")) {
                            return "file:///home/ferram/.local/share/icons/battery-charging.svg";
                        }
                        if (lowerIcon.includes("caution") || lowerIcon.includes("empty") || lowerIcon.includes("warning") ||
                            lowerSum.includes("critical") || lowerSum.includes("crític") || lowerSum.includes("low") ||
                            lowerSum.includes("baja") || lowerSum.includes("warning") || card.urgency === 2) {
                            return "file:///home/ferram/.local/share/icons/battery-warning.svg";
                        }
                        return "file:///home/ferram/.local/share/icons/battery.svg";
                    }

                    if (card.notifImage && card.notifImage !== "") {
                        return card.notifImage;
                    }

                    if (rawIcon !== "") {
                        if (rawIcon.startsWith("/") || rawIcon.startsWith("file://") || rawIcon.startsWith("data:")) {
                            return rawIcon;
                        }
                        let qPath = Quickshell.iconPath(rawIcon, true);
                        if (qPath) return qPath;
                    }

                    // Pure vector logo fallback: Arch Linux official logo (never empty, never letters)
                    return "file:///home/ferram/.local/share/icons/arch.svg";
                }

                // Auto-dismiss timer (pauses on hover)
                Timer {
                    id: expireTimer
                    interval: {
                        let lowerApp = card.appName.toLowerCase();
                        if (lowerApp.includes("volume") || lowerApp.includes("bright")) return 1400;
                        let customTimeout = card.expireTimeout > 0 ? card.expireTimeout : 6500;
                        return Math.max(5000, customTimeout);
                    }
                    running: true
                    onTriggered: card.dismissCard()
                }

                // 1. Moving LED Border Beam Layer (Perimeter-Uniform Velocity, Infinite Continuous Loop)
                Item {
                    id: borderBeamLayer
                    anchors.fill: parent
                    opacity: 1.0

                    property real beamProgress: 0.0

                    function calcPerimeterAngle(p) {
                        let w = Math.max(1, borderBeamLayer.width);
                        let h = Math.max(1, borderBeamLayer.height);
                        let perimeter = 2 * (w + h);
                        let hw = w / 2;
                        let hh = h / 2;
                        let frac = p % 1.0;
                        if (frac < 0) frac += 1.0;
                        let dist = frac * perimeter;
                        let x = 0;
                        let y = 0;

                        if (dist < hh) {
                            x = hw;
                            y = dist;
                        } else if (dist < hh + w) {
                            x = hw - (dist - hh);
                            y = hh;
                        } else if (dist < hh + w + h) {
                            x = -hw;
                            y = hh - (dist - (hh + w));
                        } else if (dist < hh + 2 * w + h) {
                            x = -hw + (dist - (hh + w + h));
                            y = -hh;
                        } else {
                            x = hw;
                            y = -hh + (dist - (hh + 2 * w + h));
                        }

                        let deg = Math.atan2(y, x) * 180 / Math.PI;
                        if (deg < 0) deg += 360;
                        return deg;
                    }

                    NumberAnimation {
                        id: borderAnim
                        target: borderBeamLayer
                        property: "beamProgress"
                        from: 0.0
                        to: 1.0
                        duration: 2600
                        easing.type: Easing.Linear
                        loops: Animation.Infinite
                        running: card.visible
                    }

                    Item {
                        id: rotHolder
                        anchors.fill: parent
                        visible: false

                        Item {
                            id: rotItem
                            anchors.centerIn: parent
                            width: Math.max(parent.width, parent.height) * 2.2
                            height: width
                            rotation: borderBeamLayer.calcPerimeterAngle(borderBeamLayer.beamProgress)

                            ConicalGradient {
                                anchors.fill: parent
                                angle: 0.0
                                gradient: Gradient {
                                    GradientStop { position: 0.00; color: card.palette.primary }
                                    GradientStop { position: 0.03; color: card.palette.primary }
                                    GradientStop { position: 0.09; color: card.palette.secondary }
                                    GradientStop { position: 0.16; color: card.palette.accent }
                                    GradientStop { position: 0.28; color: "transparent" }
                                    GradientStop { position: 0.98; color: "transparent" }
                                    GradientStop { position: 1.00; color: card.palette.primary }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: outerMask
                        anchors.fill: parent
                        radius: theme.windowRadius
                        color: "black"
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: parent
                        source: rotHolder
                        maskSource: outerMask
                    }
                }

                // 2. Base Subtle Border (Specular 10% white hairline)
                Rectangle {
                    anchors.fill: parent
                    radius: theme.windowRadius
                    color: "transparent"
                    border.color: theme.borderSubtle
                    border.width: 1
                }

                // F1 Dynamic Red Racing Pulse Animation
                Rectangle {
                    visible: !!(card.palette && card.palette.isF1)
                    anchors.fill: parent
                    radius: theme.windowRadius
                    color: "transparent"
                    border.color: "#E10600"
                    border.width: 1.5
                    opacity: 0.7

                    SequentialAnimation on opacity {
                        running: !!(card.palette && card.palette.isF1) && card.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.30; to: 0.95; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.95; to: 0.30; duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                // 3. Inner Card Surface (Opaque obsidian base - strictly 0% light bleed into interior)
                Rectangle {
                    id: cardInner
                    anchors.fill: parent
                    anchors.margins: 1.5
                    radius: Math.max(0, theme.windowRadius - 1)
                    color: "#090c12"

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: expireTimer.stop()
                        onExited: expireTimer.restart()
                        onClicked: {
                            let raw = notifWindow.getNotif(card.notifId);
                            if (raw) {
                                if (raw.actions && raw.actions.length > 0) {
                                    for (let i = 0; i < raw.actions.length; i++) {
                                        if (raw.actions[i].identifier === "default") {
                                            try { raw.actions[i].invoke(); } catch(e) {}
                                            break;
                                        }
                                    }
                                }
                            }
                            card.dismissCard();
                        }
                    }

                    RowLayout {
                        id: contentRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // App Icon / Logo Container
                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 8
                            color: (card.palette && card.palette.isF1) ? Qt.rgba(225/255, 6/255, 0/255, 0.20) : theme.surface
                            border.color: (card.palette && card.palette.isF1) ? "#E10600" : theme.borderSubtle
                            border.width: 1

                            Image {
                                id: iconImg
                                anchors.centerIn: parent
                                width: (card.palette && card.palette.isF1) ? 26 : (card.palette.isAntigravity ? 22 : 18)
                                height: (card.palette && card.palette.isF1) ? 18 : width
                                source: card.resolvedIcon
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                smooth: true
                                sourceSize.width: 48
                                sourceSize.height: 48
                                visible: status === Image.Ready && card.resolvedIcon !== ""

                                scale: 1.0
                                SequentialAnimation on scale {
                                    running: !!(card.palette && card.palette.isF1) && card.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.92; to: 1.06; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.06; to: 0.92; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }

                            // Pure vector logo fallback (Arch Linux logo) - never letters
                            Image {
                                anchors.centerIn: parent
                                visible: !iconImg.visible
                                width: 18
                                height: 18
                                source: "file:///home/ferram/.local/share/icons/arch.svg"
                                sourceSize.width: 36
                                sourceSize.height: 36
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                            }
                        }

                        // Text Content
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: card.palette.label
                                    color: card.palette.primary
                                    font.family: theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.4
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: card.timeStr || Qt.formatTime(new Date(), "HH:mm")
                                    color: theme.textDim
                                    font.family: theme.fontFamily
                                    font.pixelSize: 9
                                }

                                // Discreet close button
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: closeMouse.containsMouse ? theme.surfaceActive : "transparent"
                                    scale: closeMouse.pressed ? 0.88 : (closeMouse.containsMouse ? 1.15 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 750; easing.type: Easing.InOutQuart } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: closeMouse.containsMouse ? theme.text : theme.textDim
                                        font.pixelSize: 13
                                        anchors.verticalCenterOffset: -1
                                    }

                                    MouseArea {
                                        id: closeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            card.dismissCard();
                                        }
                                    }
                                }
                            }

                            Text {
                                text: card.summary
                                color: theme.text
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                text: card.bodyText
                                color: theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                visible: card.bodyText !== ""
                            }
                        }
                    }
                }
            }
        }
    }
}
