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

                let isDevOrAgentAlert = incomingApp.includes("antigravity") || incomingApp.includes("devin") ||
                    incomingApp.includes("claude") || incomingApp.includes("codex") ||
                    incomingApp.includes("chatgpt") || incomingApp.includes("gemini") ||
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

                readonly property int lifeDurationMs: 5500

                width: notifCol.width
                implicitHeight: Math.max(68, contentRow.implicitHeight + 20)
                height: implicitHeight

                opacity: 0.0
                scale: 0.95
                transform: Translate { id: cardSlide; x: 24 }

                Component.onCompleted: {
                    notifEntrance.start();
                    expireTimer.start();
                }

                Component.onDestruction: {
                    expireTimer.stop();
                    borderAnim.stop();
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
                            primary: isCritical ? "#ff3b30" : "#ff9f0a",
                            secondary: isCritical ? "#e22b31" : "#ea580c",
                            accent: isCritical ? "#ff787d" : "#fb923c",
                            label: isCritical ? "CRITICAL BATTERY" : (isLow ? "LOW BATTERY" : "BATTERY"),
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Hearing Protection & Headphone Connection (Amber glow)
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

                    // Calendar / Reminders (checked before global F1/affiliations so category badges always win)
                    if (lowerApp.includes("remind") || lowerApp.includes("recordatorio") || lowerApp.includes("calendar") ||
                        lowerSum.includes("reminder") || lowerSum.includes("recordatorio") || lowerSum.includes("calendar")) {

                        let hintCat = card.hintCategory || "";
                        let fullTxt = (hintCat + " " + lowerSum + " " + (card.bodyText || "").toLowerCase());

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

                        if (fullTxt.includes("workshop")) {
                            return {
                                primary: "#8b5cf6",
                                secondary: "#7c3aed",
                                accent: "#a78bfa",
                                label: "REMINDERS • WORKSHOPS",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        if (fullTxt.includes("community")) {
                            return {
                                primary: "#f59e0b",
                                secondary: "#d97706",
                                accent: "#fbbf24",
                                label: "REMINDERS • COMMUNITY",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        return {
                            primary: "#06b6d4",
                            secondary: "#3b82f6",
                            accent: "#a855f7",
                            label: "REMINDERS",
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

                    // Antigravity IDE & CLI (Cosmic Cyan / Electric Blue / Cosmic Indigo)
                    if (lowerApp.includes("antigravity") || (ctx.includes("antigravity") && !lowerApp.includes("disturb") && !lowerSum.includes("disturb") && !lowerApp.includes("molestar"))) {
                        return {
                            primary: "#38bdf8",    // Electric Cyan
                            secondary: "#3b82f6",  // Antigravity Blue
                            accent: "#818cf8",     // Cosmic Indigo
                            label: "ANTIGRAVITY",
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

                    // --- 2. Formula 1 ---
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

                    // --- 5. Media ---
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

                    // --- 6. Developer & System Tools ---
                    // GitHub (Pearl White & Sky Blue)
                    if (lowerApp.includes("github") || ctx.includes("github") || ctx.includes("github.com")) {
                        return {
                            primary: "#f0f6fc",    // Pearl White
                            secondary: "#8b949e",  // Slate Silver
                            accent: "#58a6ff",     // GitHub Blue
                            label: "GITHUB",
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
                        label: (appName ? appName.toUpperCase() : "NOTIFICATION"),
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
                    let desktopEntry = (card.desktopEntry || "").toLowerCase();

                    // Do Not Disturb / No Molestar official SVG icons
                    if (lowerApp.includes("disturb") || lowerApp.includes("molestar") || lowerApp.includes("dnd") ||
                        lowerSum.includes("disturb") || lowerSum.includes("molestar") || lowerSum.includes("dnd") ||
                        lowerIcon.includes("dnd")) {
                        let isOff = lowerSum.includes("disable") || lowerSum.includes("desactivad") || lowerBody.includes("all") || lowerBody.includes("todas");
                        return isOff ? "file:///home/ferram/.local/share/icons/dnd-off.svg" : "file:///home/ferram/.local/share/icons/dnd-on.svg";
                    }

                    // Calendar / Reminders custom icons (checked before F1/Colgate so Reminders category icons match)
                    if (lowerApp.includes("remind") || lowerApp.includes("recordatorio") || lowerApp.includes("calendar")) {
                        if (ctx.includes("sara")) return "file:///home/ferram/.local/share/icons/heart.svg";
                        if (ctx.includes("marvel") || ctx.includes("doomsday")) return "file:///home/ferram/.local/share/icons/marvel.svg";
                        if (ctx.includes("f1") || ctx.includes("formula 1") || ctx.includes("formula1") || ctx.includes("grand prix")) return "file:///home/ferram/.local/share/icons/f1.svg";
                        if (ctx.includes("colgate")) return "file:///home/ferram/.local/share/icons/cp.svg";
                        if (ctx.includes("troyanos") || ctx.includes("uaq")) return "file:///home/ferram/.local/share/icons/troyanos.svg";
                        return "file:///home/ferram/.local/share/icons/calendar-3d.svg";
                    }

                    if (palette.isAntigravity) {
                        return "/usr/share/pixmaps/antigravity.png";
                    }

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

                    // Formula 1 official SVG icon
                    if (ctx.includes("formula 1") || ctx.includes("formula1") || ctx.includes("grand prix") ||
                        ctx.includes("f1 tv") || ctx.includes("f1tv") ||
                        /(?:^|[\s\-_/|(\[])f1(?:$|[\s\-_/|)\].:])/i.test(ctx)) {
                        return "file:///home/ferram/.local/share/icons/f1.svg";
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
                    if (lowerApp.includes("github") || ctx.includes("github") || ctx.includes("github.com")) {
                        return "file:///home/ferram/.local/share/icons/github.svg";
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

                    // Google Classroom official SVG icon
                    if (lowerApp.includes("classroom") || lowerSum.includes("classroom") || ctx.includes("classroom")) {
                        return "file:///home/ferram/.local/share/icons/classroom.svg";
                    }

                    // Google Docs official SVG icon
                    if (ctx.includes("google docs") || ctx.includes("docs.google") || ctx.includes("documentos de google")) {
                        return "file:///home/ferram/.local/share/icons/docs.svg";
                    }

                    // Google Drive official SVG icon
                    if (ctx.includes("google drive") || ctx.includes("drive.google") || ctx.includes("mi unidad") || ctx.includes("my drive")) {
                        return "file:///home/ferram/.local/share/icons/drive.svg";
                    }

                    // Gmail official SVG icon
                    if (lowerApp.includes("gmail") || ctx.includes("gmail") || ctx.includes("mail.google")) {
                        return "file:///home/ferram/.local/share/icons/gmail.svg";
                    }

                    // Chromium official SVG icon (monochromatic blue)
                    if (lowerApp.includes("chromium") || lowerIcon.includes("chromium") || ctx.includes("chromium")) {
                        return "file:///home/ferram/.local/share/icons/chromium.svg";
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

                // Fixed-duration auto-dismiss timer (synchronized with border animation)
                Timer {
                    id: expireTimer
                    interval: card.lifeDurationMs
                    repeat: false
                    running: false
                    onTriggered: card.dismissCard()
                }

                // 1. Moving LED Border Beam Layer (Canvas-based, uniform perimeter speed, never stalls)
                Item {
                    id: borderBeamLayer
                    anchors.fill: parent
                    opacity: 1.0

                    property real beamProgress: 0.0
                    onBeamProgressChanged: borderCanvas.requestPaint()

                    NumberAnimation {
                        id: borderAnim
                        target: borderBeamLayer
                        property: "beamProgress"
                        from: 0.0
                        to: 1.0
                        duration: 2400
                        easing.type: Easing.Linear
                        loops: Animation.Infinite
                        running: true
                    }

                    Canvas {
                        id: borderCanvas
                        anchors.fill: parent
                        antialiasing: true
                        readonly property color col1: card.palette.primary
                        readonly property color col2: card.palette.secondary
                        readonly property color col3: card.palette.accent

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onCol1Changed: requestPaint()

                        function pointAt(dist, rw, rh, rad) {
                            let lTop = Math.max(0, rw - 2 * rad);
                            let lSide = Math.max(0, rh - 2 * rad);
                            let lArc = Math.PI * rad * 0.5;
                            let perim = 2 * lTop + 2 * lSide + 4 * lArc;
                            if (perim <= 0) return { x: 0, y: 0 };

                            let d = dist % perim;
                            if (d < 0) d += perim;

                            // Top straight (left -> right)
                            if (d < lTop) return { x: rad + d, y: 0 };
                            d -= lTop;
                            // Top-right corner
                            if (d < lArc) {
                                let a = -Math.PI * 0.5 + (d / lArc) * (Math.PI * 0.5);
                                return { x: rw - rad + Math.cos(a) * rad, y: rad + Math.sin(a) * rad };
                            }
                            d -= lArc;
                            // Right straight (top -> bottom)
                            if (d < lSide) return { x: rw, y: rad + d };
                            d -= lSide;
                            // Bottom-right corner
                            if (d < lArc) {
                                let a = (d / lArc) * (Math.PI * 0.5);
                                return { x: rw - rad + Math.cos(a) * rad, y: rh - rad + Math.sin(a) * rad };
                            }
                            d -= lArc;
                            // Bottom straight (right -> left)
                            if (d < lTop) return { x: rw - rad - d, y: rh };
                            d -= lTop;
                            // Bottom-left corner
                            if (d < lArc) {
                                let a = Math.PI * 0.5 + (d / lArc) * (Math.PI * 0.5);
                                return { x: rad + Math.cos(a) * rad, y: rh - rad + Math.sin(a) * rad };
                            }
                            d -= lArc;
                            // Left straight (bottom -> top)
                            if (d < lSide) return { x: 0, y: rh - rad - d };
                            d -= lSide;
                            // Top-left corner
                            let a = Math.PI + (d / Math.max(0.001, lArc)) * (Math.PI * 0.5);
                            return { x: rad + Math.cos(a) * rad, y: rad + Math.sin(a) * rad };
                        }

                        onPaint: {
                            let ctx = getContext("2d");
                            let w = width;
                            let h = height;
                            if (w <= 4 || h <= 4) return;
                            ctx.clearRect(0, 0, w, h);

                            let pad = 1.0;
                            let rw = w - pad * 2;
                            let rh = h - pad * 2;
                            let rad = Math.min(theme.windowRadius, rw * 0.5, rh * 0.5);
                            let perim = 2 * Math.max(0, rw - 2 * rad) + 2 * Math.max(0, rh - 2 * rad) + 2 * Math.PI * rad;
                            if (perim <= 0) return;

                            let headDist = borderBeamLayer.beamProgress * perim;
                            let trailLen = perim * 0.28;
                            let steps = 20;

                            ctx.lineWidth = 2.4;
                            ctx.lineCap = "round";

                            for (let i = 0; i < steps; i++) {
                                let t0 = i / steps;
                                let t1 = (i + 1) / steps;
                                let p0 = pointAt(headDist - (1 - t0) * trailLen, rw, rh, rad);
                                let p1 = pointAt(headDist - (1 - t1) * trailLen, rw, rh, rad);

                                let r, g, b;
                                if (t1 < 0.5) {
                                    let k = t1 * 2.0;
                                    r = col3.r + (col2.r - col3.r) * k;
                                    g = col3.g + (col2.g - col3.g) * k;
                                    b = col3.b + (col2.b - col3.b) * k;
                                } else {
                                    let k = (t1 - 0.5) * 2.0;
                                    r = col2.r + (col1.r - col2.r) * k;
                                    g = col2.g + (col1.g - col2.g) * k;
                                    b = col2.b + (col1.b - col2.b) * k;
                                }
                                let alpha = Math.pow(t1, 1.4);

                                ctx.strokeStyle = Qt.rgba(r, g, b, alpha);
                                ctx.beginPath();
                                ctx.moveTo(pad + p0.x, pad + p0.y);
                                ctx.lineTo(pad + p1.x, pad + p1.y);
                                ctx.stroke();
                            }
                        }
                    }
                }

                // 2. Base Subtle Border (Specular Liquid Glass hairline)
                Rectangle {
                    anchors.fill: parent
                    radius: theme.windowRadius
                    color: "transparent"
                    border.color: theme.border
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

                // 3. Inner Card Surface (Smoked Obsidian Liquid Glass matching top bar & desktop widgets)
                Rectangle {
                    id: cardInner
                    anchors.fill: parent
                    anchors.margins: 1.5
                    radius: Math.max(0, theme.windowRadius - 1)
                    color: theme.popupBg
                    clip: true

                    // Liquid Glass 3-stop specular sheen
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.09) }
                            GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.015) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04) }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
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
