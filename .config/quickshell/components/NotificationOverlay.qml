import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"

PanelWindow {
    id: root

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
    visible: activeList.length > 0

    Theme { id: theme }

    property var activeList: []
    property var osdService: null

    function dismissNotif(notif) {
        if (!notif) return;
        let arr = [];
        for (let i = 0; i < root.activeList.length; i++) {
            if (root.activeList[i] && root.activeList[i].id !== notif.id) {
                arr.push(root.activeList[i]);
            }
        }
        root.activeList = arr;
        try { notif.dismiss(); } catch(e) {}
    }

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        extraHints: ["x-kde-origin-name"]

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

                if (root.osdService) {
                    root.osdService.show(osdType, val, isMuted, text);
                }

                try { notif.dismiss(); } catch(e) {}
                return;
            }

            let arr = [];
            let isSingleton = incomingApp.includes("bater") || incomingApp.includes("battery");

            for (let i = 0; i < root.activeList.length; i++) {
                let existing = root.activeList[i];
                if (!existing) continue;

                // Replace duplicate if same id OR if same content OR singleton (volume/brightness/battery/hearing/headphones)
                let existingApp = (existing.appName || "").toLowerCase();
                let existingSum = (existing.summary || "").toLowerCase();
                let isDuplicate = (existing.id === notif.id) ||
                    (incomingSum.length > 0 && incomingSum === existingSum && incomingApp === existingApp) ||
                    ((incomingApp.includes("hearing") || incomingSum.includes("headphone")) &&
                     (existingApp.includes("hearing") || existingSum.includes("headphone")));

                let matchSingleton = isSingleton && (
                    (incomingApp.includes("volume") && (existingApp.includes("volume") || existingSum.includes("volume"))) ||
                    (incomingApp.includes("bright") && (existingApp.includes("bright") || existingSum.includes("bright"))) ||
                    ((incomingApp.includes("bater") || incomingApp.includes("battery")) && (existingApp.includes("bater") || existingApp.includes("battery")))
                );

                if (isDuplicate || matchSingleton) {
                    try { existing.dismiss(); } catch(e) {}
                    continue;
                }
                arr.push(existing);
            }
            arr.unshift(notif); // Newest on top
            if (arr.length > 4) {
                let old = arr.pop();
                try { old.dismiss(); } catch(e) {}
            }
            root.activeList = arr;
        }
    }

    Column {
        id: notifCol
        width: parent.width
        spacing: 8

        Repeater {
            model: root.activeList

            delegate: Item {
                id: card
                required property var modelData
                width: notifCol.width
                implicitHeight: Math.max(68, contentRow.implicitHeight + 20)
                height: implicitHeight

                property string appName: modelData ? (modelData.appName || "") : ""
                property string summary: modelData ? (modelData.summary || "") : ""
                property string bodyText: modelData ? (modelData.body || "") : ""
                property int urgency: modelData ? modelData.urgency : 1

                // Consolidated Metadata String for robust origin & app detection (Chromium, PWAs, Native)
                property string metaContext: {
                    let s = (appName + " " + summary + " " + bodyText).toLowerCase();
                    if (modelData) {
                        if (modelData.appIcon) s += " " + modelData.appIcon.toLowerCase();
                        if (modelData.desktopEntry) s += " " + modelData.desktopEntry.toLowerCase();
                        if (modelData.hints) {
                            try {
                                for (let k in modelData.hints) {
                                    if (k === "image-data" || k === "image_data" || k === "icon_data") continue;
                                    s += " " + k + ":" + String(modelData.hints[k]).toLowerCase();
                                }
                            } catch(e) {}
                            try {
                                s += " " + JSON.stringify(modelData.hints).toLowerCase();
                            } catch(e) {}
                        }
                        if (modelData.actions) {
                            try {
                                for (let i = 0; i < modelData.actions.length; i++) {
                                    let act = modelData.actions[i];
                                    if (act) {
                                        s += " " + (act.identifier || "").toLowerCase() + " " + (act.text || "").toLowerCase();
                                    }
                                }
                            } catch(e) {}
                        }
                    }
                    return s;
                }

                readonly property bool isWhatsApp: metaContext.includes("whatsapp") || metaContext.includes("web.whatsapp.com")
                readonly property bool isInstagram: metaContext.includes("instagram") || metaContext.includes("instagram.com")

                Connections {
                    target: card.modelData
                    function onClosed() {
                        root.dismissNotif(card.modelData);
                    }
                }

                // Dynamic Color Resolution based on sender
                property var palette: {
                    let lowerApp = (appName || "").toLowerCase();
                    let lowerSum = (summary || "").toLowerCase();
                    let lowerBody = (bodyText || "").toLowerCase();
                    let appIconName = (modelData && modelData.appIcon) ? modelData.appIcon.toLowerCase() : "";

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

                    // Battery alert (Red LED beam)
                    if (lowerApp.includes("bater") || lowerApp.includes("battery") || lowerSum.includes("bater") || lowerSum.includes("battery")) {
                        return {
                            primary: "#ff3b30",    // Apple Coral Red
                            secondary: "#e22b31",  // Deep Carmine
                            accent: "#ff787d",     // Red glow
                            label: "BATTERY",
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

                    // Hyprland / Arch Linux (Official Arch Cyan)
                    if (lowerApp.includes("hypr") || lowerApp.includes("arch") || lowerSum.includes("hypr") || lowerSum.includes("arch")) {
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

                    // Calendar / Reminders (Category-driven LED beam & border)
                    if (lowerApp.includes("remind") || lowerApp.includes("recordatorio") || lowerApp.includes("calendar") ||
                        lowerSum.includes("reminder") || lowerSum.includes("recordatorio") || lowerSum.includes("calendar")) {

                        let hintCat = "";
                        if (modelData && modelData.hints) {
                            try {
                                if (modelData.hints.category) hintCat = String(modelData.hints.category);
                                else if (modelData.hints["category"]) hintCat = String(modelData.hints["category"]);
                                else if (modelData.hints["x-category"]) hintCat = String(modelData.hints["x-category"]);
                            } catch(e) {}
                        }

                        let fullTxt = (hintCat + " " + lowerSum + " " + (card.bodyText || "").toLowerCase());

                        // Colgate-Palmolive (Red)
                        if (fullTxt.includes("colgate")) {
                            return {
                                primary: "#ef4444",
                                secondary: "#dc2626",
                                accent: "#f87171",
                                label: "REMINDERS • COLGATE",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Personal (Emerald Green)
                        if (fullTxt.includes("personal")) {
                            return {
                                primary: "#10b981",
                                secondary: "#059669",
                                accent: "#34d399",
                                label: "REMINDERS • PERSONAL",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Projects (Cyan)
                        if (fullTxt.includes("project")) {
                            return {
                                primary: "#06b6d4",
                                secondary: "#0891b2",
                                accent: "#22d3ee",
                                label: "REMINDERS • PROJECTS",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // School (Purple)
                        if (fullTxt.includes("school") || fullTxt.includes("escuela")) {
                            return {
                                primary: "#a855f7",
                                secondary: "#9333ea",
                                accent: "#c084fc",
                                label: "REMINDERS • SCHOOL",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Health (Amber)
                        if (fullTxt.includes("health") || fullTxt.includes("salud")) {
                            return {
                                primary: "#f59e0b",
                                secondary: "#d97706",
                                accent: "#fbbf24",
                                label: "REMINDERS • HEALTH",
                                isAntigravity: false,
                                isNightLight: false
                            };
                        }

                        // Urgent (Orange)
                        if (fullTxt.includes("urgent") || fullTxt.includes("urgente")) {
                            return {
                                primary: "#f97316",
                                secondary: "#ea580c",
                                accent: "#fb923c",
                                label: "REMINDERS • URGENT",
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

                    // Antigravity (Cosmic Cyan / Electric Blue / Cosmic Indigo)
                    if (lowerApp.includes("antigravity")) {
                        return {
                            primary: "#38bdf8",    // Electric Cyan
                            secondary: "#3b82f6",  // Antigravity Blue
                            accent: "#818cf8",     // Cosmic Indigo
                            label: "ANTIGRAVITY IDE",
                            isAntigravity: true,
                            isNightLight: false
                        };
                    }

                    // Spotify (Vibrant Green)
                    if (lowerApp.includes("spotify")) {
                        return {
                            primary: "#1ed760",
                            secondary: "#1db954",
                            accent: "#10b981",
                            label: "SPOTIFY",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Discord / Vesktop (Blurple)
                    if (lowerApp.includes("discord") || lowerApp.includes("vesktop")) {
                        return {
                            primary: "#5865f2",
                            secondary: "#7289da",
                            accent: "#818cf8",
                            label: "DISCORD",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Telegram (Blue)
                    if (lowerApp.includes("telegram")) {
                        return {
                            primary: "#229ed9",
                            secondary: "#0088cc",
                            accent: "#38bdf8",
                            label: "TELEGRAM",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Slack (Aubergine / Multi-accent)
                    if (lowerApp.includes("slack")) {
                        return {
                            primary: "#e01e5a",
                            secondary: "#ecb22e",
                            accent: "#2eb67d",
                            label: "SLACK",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Firefox / Zen (Warm flame)
                    if (lowerApp.includes("firefox") || lowerApp.includes("zen")) {
                        return {
                            primary: "#ff7139",
                            secondary: "#ff3b30",
                            accent: "#a855f7",
                            label: "BROWSER",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Chromium (Cyan & Blue shades)
                    if (lowerApp.includes("chromium") || card.metaContext.includes("chromium")) {
                        return {
                            primary: "#1767d1",
                            secondary: "#679ef5",
                            accent: "#afccf9",
                            label: "CHROMIUM",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Google Chrome (Google Blue)
                    if (lowerApp.includes("chrome")) {
                        return {
                            primary: "#4285f4",
                            secondary: "#ea4335",
                            accent: "#fbbc05",
                            label: "CHROME",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // VS Code (Code Blue)
                    if (lowerApp.includes("code") || lowerApp.includes("vscode")) {
                        return {
                            primary: "#007acc",
                            secondary: "#0098ff",
                            accent: "#38bdf8",
                            label: "VS CODE",
                            isAntigravity: false,
                            isNightLight: false
                        };
                    }

                    // Default (Dynamic Wallpaper Red / Crimson LED Beam)
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
                    if (palette.isAntigravity) {
                        return "/usr/share/pixmaps/antigravity.png";
                    }

                    let rawIcon = modelData ? (modelData.appIcon || "") : "";
                    let lowerIcon = rawIcon.toLowerCase();
                    let lowerApp = (appName || "").toLowerCase();
                    let lowerSum = (modelData && modelData.summary) ? modelData.summary.toLowerCase() : "";
                    let lowerBody = (modelData && modelData.body) ? modelData.body.toLowerCase() : "";
                    // WhatsApp official SVG icon
                    if (card.isWhatsApp) {
                        return "file:///home/ferram/.local/share/icons/whatsapp.svg";
                    }

                    // Instagram official SVG icon
                    if (card.isInstagram) {
                        return "file:///home/ferram/.local/share/icons/instagram.svg";
                    }

                    // Chromium official SVG icon (monochromatic blue)
                    if (lowerApp.includes("chromium") || lowerIcon.includes("chromium") || card.metaContext.includes("chromium")) {
                        return "file:///home/ferram/.local/share/icons/chromium.svg";
                    }

                    // Google Chrome official SVG icon
                    if (lowerApp.includes("chrome") || lowerIcon.includes("chrome") || card.metaContext.includes("chrome")) {
                        return "file:///home/ferram/.local/share/icons/chrome.svg";
                    }

                    // Hyprland / Arch Linux official SVG logo
                    if (lowerApp.includes("hypr") || lowerApp.includes("arch") || lowerSum.includes("hypr") || lowerSum.includes("arch") || card.metaContext.includes("hypr") || card.metaContext.includes("arch")) {
                        return "file:///home/ferram/.local/share/icons/arch.svg";
                    }

                    // Spotify official SVG icon
                    if (lowerApp.includes("spotify") || lowerIcon.includes("spotify") || card.metaContext.includes("spotify")) {
                        return "file:///home/ferram/.local/share/icons/spotify.svg";
                    }

                    // Discord / Vesktop official SVG icon
                    if (lowerApp.includes("discord") || lowerApp.includes("vesktop") || lowerIcon.includes("discord") || card.metaContext.includes("discord")) {
                        return "file:///home/ferram/.local/share/icons/discord.svg";
                    }

                    // Telegram official SVG icon
                    if (lowerApp.includes("telegram") || lowerIcon.includes("telegram") || card.metaContext.includes("telegram")) {
                        return "file:///home/ferram/.local/share/icons/telegram.svg";
                    }

                    // Hearing Safety / Headphone Connected vector icon
                    if (lowerApp.includes("hearing") || lowerSum.includes("hearing") || lowerSum.includes("high volume") ||
                        lowerApp.includes("headphone") || lowerSum.includes("headphone") || lowerIcon.includes("headphone") ||
                        lowerSum.includes("audífono") || lowerSum.includes("audifono")) {
                        return "file:///home/ferram/.local/share/icons/headphones.svg";
                    }

                    // Calendar / Reminders custom 3D SVG icon
                    if (lowerApp.includes("remind") || lowerApp.includes("recordatorio") || lowerApp.includes("calendar")) {
                        return "file:///home/ferram/.local/share/icons/calendar-3d.svg";
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

                    // Battery icon
                    if (lowerApp.includes("bater") || lowerApp.includes("battery") || lowerIcon.includes("battery")) {
                        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23ff3b30' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'><circle cx='12' cy='12' r='10'/><line x1='12' y1='8' x2='12' y2='12'/><line x1='12' y1='16' x2='12.01' y2='16'/></svg>";
                    }

                    if (modelData && modelData.image && modelData.image !== "") {
                        return modelData.image;
                    }

                    if (rawIcon !== "") {
                        if (rawIcon.startsWith("/") || rawIcon.startsWith("file://") || rawIcon.startsWith("data:")) {
                            return rawIcon;
                        }
                        let qPath = Quickshell.iconPath(rawIcon);
                        if (qPath) return qPath;
                        return "image://icon/" + rawIcon;
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
                        if (card.modelData && card.modelData.expireTimeout > 0) return card.modelData.expireTimeout;
                        return 6500;
                    }
                    running: true
                    onTriggered: root.dismissNotif(card.modelData)
                }

                // 1. Moving LED Border Beam Layer (Continuous Perimeter Trace)
                Item {
                    anchors.fill: parent

                    Item {
                        id: rotHolder
                        anchors.fill: parent
                        visible: false

                        Item {
                            anchors.centerIn: parent
                            width: Math.max(parent.width, parent.height) * 2.2
                            height: width

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 4600
                                loops: Animation.Infinite
                                running: true
                            }

                            ConicalGradient {
                                anchors.fill: parent
                                angle: 0.0
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: card.palette.primary }
                                    GradientStop { position: 0.07; color: card.palette.secondary }
                                    GradientStop { position: 0.14; color: card.palette.accent }
                                    GradientStop { position: 0.25; color: "transparent" }
                                    GradientStop { position: 1.0; color: "transparent" }
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
                            if (card.modelData) {
                                if (card.modelData.actions && card.modelData.actions.length > 0) {
                                    for (let i = 0; i < card.modelData.actions.length; i++) {
                                        if (card.modelData.actions[i].identifier === "default") {
                                            card.modelData.actions[i].invoke();
                                            break;
                                        }
                                    }
                                }
                                root.dismissNotif(card.modelData);
                            }
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
                            color: theme.surface
                            border.color: theme.borderSubtle
                            border.width: 1

                            Image {
                                id: iconImg
                                anchors.centerIn: parent
                                width: card.palette.isAntigravity ? 22 : 18
                                height: width
                                source: card.resolvedIcon
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                sourceSize.width: 36
                                sourceSize.height: 36
                                visible: status === Image.Ready && card.resolvedIcon !== ""
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
                                    text: Qt.formatTime(new Date(), "HH:mm")
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
                                        onClicked: root.dismissNotif(card.modelData)
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
