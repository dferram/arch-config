import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    Theme { id: theme }

    required property var parentWindow
    property string activePopupId: ""
    signal togglePopup(string id)

    implicitHeight: pill.implicitHeight
    implicitWidth: pill.implicitWidth

    // Platform caching per player/track so switching tabs never causes the platform or icon to vanish
    property var platformCache: ({})
    property var playerPlatformCache: ({})

    // Strict platform detector: ONLY allows Spotify, YouTube, and SoundCloud; discards Instagram and other web tabs
    function detectPlayerPlatform(p) {
        if (!p) return "";
        let tTitle = (p.trackTitle || "").toLowerCase().trim();
        let tArtist = (p.trackArtist || "").toLowerCase().trim();
        let tAlbum = (p.trackAlbum || "").toLowerCase().trim();
        let ident = (p.identity || "").toLowerCase().trim();
        let dEntry = (p.desktopEntry || "").toLowerCase().trim();
        let dbName = (p.dbusName || "").toLowerCase().trim();
        let art = (p.trackArtUrl || "").toLowerCase().trim();
        let url = "";
        if (p.metadata && p.metadata["xesam:url"]) {
            url = (p.metadata["xesam:url"] || "").toLowerCase().trim();
        }
        if (p.metadata && p.metadata["mpris:artUrl"]) {
            art += " " + (p.metadata["mpris:artUrl"] || "").toLowerCase().trim();
        }

        // Cache key for track
        let cacheKey = (dbName || ident || "player") + "::" + tTitle + "::" + tArtist;

        // 1. Strict ban on social & messaging apps (Instagram, WhatsApp, Telegram, Facebook, Twitter, TikTok, Discord, LinkedIn, etc.)
        let allInfo = tTitle + " " + tArtist + " " + tAlbum + " " + ident + " " + url;
        if (allInfo.includes("instagram") || 
            allInfo.includes("whatsapp") || 
            allInfo.includes("telegram") || 
            allInfo.includes("facebook") || 
            allInfo.includes("twitter") || 
            allInfo.includes("tiktok") || 
            allInfo.includes("discord") || 
            allInfo.includes("zoom") || 
            allInfo.includes("meet.google") || 
            allInfo.includes("twitch") ||
            allInfo.includes("linkedin")) {
            if (root.platformCache[cacheKey]) delete root.platformCache[cacheKey];
            return "";
        }

        // 2. SPOTIFY (Native client, Spotify Web player tab, or spotify dbus)
        if (ident === "spotify" || dEntry === "spotify" || dbName.includes(".spotify") || 
            art.includes("scdn.co") || url.includes("spotify.com") || 
            tTitle.includes("spotify") || tArtist.includes("spotify")) {
            root.platformCache[cacheKey] = "spotify";
            if (dbName) root.playerPlatformCache[dbName] = "spotify";
            return "spotify";
        }

        // 3. SOUNDCLOUD (Web player tab, soundcloud app, or soundcloud cdn art)
        if (ident.includes("soundcloud") || url.includes("soundcloud.com") || 
            art.includes("sndcdn.com") || tTitle.includes("soundcloud") || 
            tArtist.includes("soundcloud")) {
            root.platformCache[cacheKey] = "soundcloud";
            if (dbName) root.playerPlatformCache[dbName] = "soundcloud";
            return "soundcloud";
        }

        // 4. YOUTUBE (PWA, native client, or tab with youtube url/art)
        if (ident.includes("youtube") || url.includes("youtube.com") || url.includes("youtu.be") || 
            art.includes("ytimg.com") || art.includes("ggpht.com") || 
            tTitle.includes("youtube") || tArtist.includes("youtube")) {
            root.platformCache[cacheKey] = "youtube";
            if (dbName) root.playerPlatformCache[dbName] = "youtube";
            return "youtube";
        }

        // 5. Browser heuristics: check Hyprland window titles for SoundCloud or YouTube
        if (ident.includes("chromium") || ident.includes("chrome") || ident.includes("firefox") || 
            ident.includes("brave") || ident.includes("edge") || ident.includes("zen") || ident.includes("browser")) {
            try {
                if (typeof Hyprland !== "undefined" && Hyprland.toplevels && Hyprland.toplevels.values) {
                    let toplevels = Hyprland.toplevels.values;

                    // Pass A: Check for SoundCloud anywhere in open window titles
                    for (let i = 0; i < toplevels.length; i++) {
                        let win = toplevels[i];
                        let wTitle = (win.title || "").toLowerCase();
                        if (wTitle.includes("soundcloud")) {
                            root.platformCache[cacheKey] = "soundcloud";
                            if (dbName) root.playerPlatformCache[dbName] = "soundcloud";
                            return "soundcloud";
                        }
                    }

                    // Pass B: Check for SoundCloud standard "Title by Artist" format or artist name in browser title
                    if (tArtist.length >= 2 || tTitle.length >= 2) {
                        for (let i = 0; i < toplevels.length; i++) {
                            let win = toplevels[i];
                            let wTitle = (win.title || "").toLowerCase();
                            if (wTitle.includes(" by ")) {
                                if ((tArtist.length >= 2 && wTitle.includes(tArtist)) || 
                                    (tTitle.length >= 2 && wTitle.includes(tTitle))) {
                                    root.platformCache[cacheKey] = "soundcloud";
                                    if (dbName) root.playerPlatformCache[dbName] = "soundcloud";
                                    return "soundcloud";
                                }
                            }
                            if (tArtist.length >= 3 && wTitle.includes(tArtist) && !wTitle.includes("youtube")) {
                                root.platformCache[cacheKey] = "soundcloud";
                                if (dbName) root.playerPlatformCache[dbName] = "soundcloud";
                                return "soundcloud";
                            }
                        }
                    }

                    // Pass C: Check for YouTube matching current track title or channel
                    for (let i = 0; i < toplevels.length; i++) {
                        let win = toplevels[i];
                        let wTitle = (win.title || "").toLowerCase();
                        if (wTitle.includes("youtube") || wTitle.includes("youtu.be")) {
                            if (tTitle.length > 2) {
                                let cleanTrack = tTitle.replace(/[^a-z0-9\s]/g, " ").trim();
                                let words = cleanTrack.split(/\s+/).filter(function(w) { return w.length >= 3; });
                                for (let k = 0; k < words.length; k++) {
                                    if (wTitle.includes(words[k])) {
                                        root.platformCache[cacheKey] = "youtube";
                                        if (dbName) root.playerPlatformCache[dbName] = "youtube";
                                        return "youtube";
                                    }
                                }
                            }
                            if (tArtist.length > 2 && wTitle.includes(tArtist)) {
                                root.platformCache[cacheKey] = "youtube";
                                if (dbName) root.playerPlatformCache[dbName] = "youtube";
                                return "youtube";
                            }
                        }
                    }
                }
            } catch(e) {}

            // Pass D: Cache fallback (user switched to a non-media tab like LinkedIn, Docs, GitHub)
            if (root.platformCache[cacheKey]) {
                return root.platformCache[cacheKey];
            }
            if (dbName && root.playerPlatformCache[dbName]) {
                return root.playerPlatformCache[dbName];
            }
        }

        return "";
    }

    // Track available players with valid tracks strictly matching Spotify, YouTube, or SoundCloud
    property var validPlayers: {
        let vals = Mpris.players.values;
        if (!vals) return [];

        let hasNativeSpotify = false;
        for (let i = 0; i < vals.length; i++) {
            let ident = (vals[i].identity || "").toLowerCase();
            let dEntry = (vals[i].desktopEntry || "").toLowerCase();
            let dbName = (vals[i].dbusName || "").toLowerCase();
            if (ident === "spotify" || dEntry === "spotify" || dbName.includes(".spotify")) {
                hasNativeSpotify = true;
                break;
            }
        }

        let res = [];
        for (let i = 0; i < vals.length; i++) {
            let p = vals[i];
            let tTitle = (p.trackTitle || "").trim();
            if (tTitle.length === 0) continue;

            let plat = root.detectPlayerPlatform(p);
            if (plat === "") continue; // ONLY Spotify, YouTube, SoundCloud

            // Filter out Spotify internal Chromium CEF ghost instance if native Spotify is present
            if (plat === "spotify" && (p.identity || "").toLowerCase().includes("chromium")) {
                let art = (p.trackArtUrl || "").trim();
                let artMeta = (p.metadata && p.metadata["mpris:artUrl"]) ? p.metadata["mpris:artUrl"].toString().trim() : "";
                let artist = (p.trackArtist || "").trim();
                if (!art && !artMeta && !artist) continue;
            }

            res.push(p);
        }
        return res;
    }

    // Select active media player strictly from valid allowed players
    property var activePlayer: {
        let list = validPlayers;
        if (list.length === 0) return null;

        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i];
        }
        for (let i = 0; i < list.length; i++) {
            if (root.detectPlayerPlatform(list[i]) === "spotify") return list[i];
        }
        return list[0];
    }

    property bool isPlaying: activePlayer ? activePlayer.playbackState === MprisPlaybackState.Playing : false
    property string trackTitle: (activePlayer && activePlayer.trackTitle) ? activePlayer.trackTitle : ""
    property string trackArtist: (activePlayer && activePlayer.trackArtist) ? activePlayer.trackArtist : ""
    property string trackAlbum: (activePlayer && activePlayer.trackAlbum) ? activePlayer.trackAlbum : ""

    // Extract album artwork URL (handles trackArtUrl and mpris:artUrl)
    property string artUrl: {
        if (!activePlayer) return "";
        let u = activePlayer.trackArtUrl || "";
        if (!u && activePlayer.metadata && activePlayer.metadata["mpris:artUrl"]) {
            u = activePlayer.metadata["mpris:artUrl"];
        }
        return u;
    }

    property string displayLabel: {
        if (!trackTitle) return "";
        let full = trackArtist ? trackArtist + " • " + trackTitle : trackTitle;
        if (full.length > 28) return full.substring(0, 26) + "…";
        return full;
    }

    property real currentPosition: 0
    property real trackLength: 0
    property bool isDraggingSeek: false
    property real dragPosition: 0
    property bool showRemainingTime: false

    function updateTrackLength() {
        if (!root.activePlayer) {
            root.trackLength = 0;
            return;
        }
        let len = root.activePlayer.length;
        if (typeof len === "number" && !isNaN(len) && len > 0) {
            if (len > 100000) len = len / 1000000.0;
            root.trackLength = len;
            return;
        }
        if (root.activePlayer.metadata && root.activePlayer.metadata["mpris:length"]) {
            let mLen = Number(root.activePlayer.metadata["mpris:length"]);
            if (!isNaN(mLen) && mLen > 0) {
                if (mLen > 100000) mLen = mLen / 1000000.0;
                root.trackLength = mLen;
                return;
            }
        }
    }

    function syncPosition() {
        if (!root.activePlayer) {
            root.currentPosition = 0;
            root.trackLength = 0;
            return;
        }
        root.updateTrackLength();
        if (!root.isDraggingSeek) {
            let pos = root.activePlayer.position;
            if (!isNaN(pos) && pos >= 0) {
                if (pos > 100000 && root.trackLength > 0 && pos > root.trackLength * 10) {
                    root.currentPosition = pos / 1000000.0;
                } else {
                    root.currentPosition = pos;
                }
            }
        }
    }

    // Explicit MPRIS C++ signal connections so property updates are instantly reactive
    Connections {
        target: root.activePlayer
        function onLengthChanged() { root.updateTrackLength(); }
        function onPositionChanged() { root.syncPosition(); }
        function onPlaybackStateChanged() { root.updateTrackLength(); root.syncPosition(); }
        function onMetadataChanged() { root.updateTrackLength(); root.syncPosition(); }
        function onTrackTitleChanged() { root.updateTrackLength(); root.syncPosition(); }
    }

    Process {
        id: seekProc
    }

    function seekToRatio(ratio) {
        if (!root.activePlayer || root.trackLength <= 0) return;
        let clampedRatio = Math.max(0, Math.min(1.0, ratio));
        let targetSec = clampedRatio * root.trackLength;
        root.currentPosition = targetSec;
        if (root.activePlayer.canSeek) {
            try {
                root.activePlayer.position = targetSec;
            } catch(e) {}
        }
        let pName = root.activePlayer.dbusName || "";
        if (pName.startsWith("org.mpris.MediaPlayer2.")) {
            pName = pName.replace("org.mpris.MediaPlayer2.", "");
            seekProc.command = ["playerctl", "-p", pName, "position", Math.round(targetSec).toString()];
            seekProc.running = true;
        }
    }

    function formatTime(seconds) {
        if (isNaN(seconds) || seconds <= 0) return "0:00";
        let total = Math.floor(seconds);
        let hrs = Math.floor(total / 3600);
        let mins = Math.floor((total % 3600) / 60);
        let secs = total % 60;
        let sSecs = (secs < 10 ? "0" : "") + secs;
        if (hrs > 0) {
            let sMins = (mins < 10 ? "0" : "") + mins;
            return hrs + ":" + sMins + ":" + sSecs;
        }
        return mins + ":" + sSecs;
    }

    function focusPlayerWindow() {
        if (root.activePlayer && root.activePlayer.canRaise) {
            root.activePlayer.raise();
        }
        try {
            if (typeof Hyprland !== "undefined") {
                if (root.isSpotify) {
                    Hyprland.dispatch("focuswindow class:^(Spotify|spotify)$");
                } else if (root.isYouTube || root.isSoundCloud) {
                    Hyprland.dispatch("focuswindow class:^(chromium|google-chrome|firefox|zen|brave)$");
                }
            }
        } catch(e) {}
    }

    function cycleLoop() {
        if (!root.activePlayer || !root.activePlayer.loopSupported) return;
        let cur = root.activePlayer.loopState;
        if (cur === MprisLoopState.None) {
            root.activePlayer.loopState = MprisLoopState.Playlist;
        } else if (cur === MprisLoopState.Playlist) {
            root.activePlayer.loopState = MprisLoopState.Track;
        } else {
            root.activePlayer.loopState = MprisLoopState.None;
        }
    }

    function toggleShuffle() {
        if (!root.activePlayer || !root.activePlayer.shuffleSupported) return;
        root.activePlayer.shuffle = !root.activePlayer.shuffle;
    }

    // Platform identification using detectPlayerPlatform (Instagram and others strictly blocked)
    property string currentPlatform: root.detectPlayerPlatform(root.activePlayer)
    property bool isSpotify: currentPlatform === "spotify"
    property bool isYouTube: currentPlatform === "youtube"
    property bool isSoundCloud: currentPlatform === "soundcloud"
    property bool isInstagram: false
    property bool isTwitch: false

    // Dynamic album color extracted via hypr-media-palette (Spotify only)
    property color dynamicAlbumColor: "#e2e8f0"
    property color dynamicAlbumColorSecondary: "#cbd5e1"
    property color dynamicAlbumColorAccent: "#94a3b8"

    // Base platform accent color (Dynamic for Spotify based on album, fixed for YouTube & SoundCloud)
    property color mediaAccentColor: {
        if (isSpotify) return dynamicAlbumColor;
        if (isYouTube) return "#ef4444";
        if (isSoundCloud) return "#ff5500";
        return theme.blueLight;
    }

    Behavior on mediaAccentColor { ColorAnimation { duration: 350; easing.type: Easing.OutQuad } }

    property bool isAccentLight: {
        let lum = 0.299 * root.mediaAccentColor.r + 0.587 * root.mediaAccentColor.g + 0.114 * root.mediaAccentColor.b;
        return lum > 0.70;
    }

    // Visualizer Bars Colorimetry (Matches album for Spotify, strictly red for YouTube, orange for SoundCloud)
    property color albumColorPrimary: {
        if (isSpotify) return dynamicAlbumColor;
        if (isYouTube) return "#ef4444";
        if (isSoundCloud) return "#ff5500";
        return theme.blueLight;
    }
    property color albumColorSecondary: {
        if (isSpotify) return dynamicAlbumColorSecondary;
        return Qt.lighter(albumColorPrimary, 1.25);
    }
    property color albumColorAccent: {
        if (isSpotify) return dynamicAlbumColorAccent;
        return Qt.lighter(albumColorSecondary, 1.35);
    }

    Behavior on albumColorPrimary { ColorAnimation { duration: 350; easing.type: Easing.OutQuad } }
    Behavior on albumColorSecondary { ColorAnimation { duration: 350; easing.type: Easing.OutQuad } }
    Behavior on albumColorAccent { ColorAnimation { duration: 350; easing.type: Easing.OutQuad } }

    Process {
        id: paletteProc
        command: ["/home/ferram/.local/bin/hypr-media-palette", root.artUrl, root.trackTitle, root.trackAlbum]
        stdout: StdioCollector {
            onTextChanged: {
                if (!root.isSpotify) return;
                let lines = text.trim().split("\n");
                if (lines.length >= 3) {
                    let c1 = lines[0].trim();
                    let c2 = lines[1].trim();
                    let c3 = lines[2].trim();
                    if (c1.startsWith("#")) root.dynamicAlbumColor = c1;
                    if (c2.startsWith("#")) root.dynamicAlbumColorSecondary = c2;
                    if (c3.startsWith("#")) root.dynamicAlbumColorAccent = c3;
                }
            }
        }
    }

    function updatePalette() {
        if (root.isSpotify && root.artUrl && root.artUrl !== "") {
            paletteProc.command = ["/home/ferram/.local/bin/hypr-media-palette", root.artUrl, root.trackTitle, root.trackAlbum];
            paletteProc.running = true;
        } else {
            root.dynamicAlbumColor = "#e2e8f0";
            root.dynamicAlbumColorSecondary = "#cbd5e1";
            root.dynamicAlbumColorAccent = "#94a3b8";
        }
    }

    onArtUrlChanged: updatePalette()
    onIsSpotifyChanged: updatePalette()
    onTrackAlbumChanged: updatePalette()
    Component.onCompleted: updatePalette()

    property string playerBrandName: {
        if (isYouTube) return "YouTube";
        if (isSpotify) return "Spotify";
        if (isSoundCloud) return "SoundCloud";
        return "Media";
    }

    // Official SoundCloud SVG vector
    property string soundcloudSvgUri: Qt.resolvedUrl("../icons/soundcloud.svg")

    // Official Spotify SVG vector (ALWAYS official Spotify green #1db954)
    property string spotifySvgUri: {
        let col = theme.urlColor(root.mediaAccentColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.78) translate(-12, -12)'><path fill-rule='evenodd' clip-rule='evenodd' d='M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z' fill='" + col + "'/></g></svg>";
    }

    // Official YouTube SVG vector (ALWAYS official YouTube red)
    property string youtubeSvgUri: {
        let col = theme.urlColor(root.mediaAccentColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.82) translate(-12, -12)'><path d='M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814z' fill='" + col + "'/><polygon points='9.545,15.568 9.545,8.432 15.818,12' fill='%23ffffff'/></g></svg>";
    }

    // Generic clean audio note SVG vector
    property string defaultMediaSvgUri: {
        let col = theme.urlColor(root.mediaAccentColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.78) translate(-12, -12)'><path d='M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z' fill='" + col + "'/></g></svg>";
    }

    // Lucide Control SVG Vectors (Constant standard theme colors)
    property string shuffleSvgUri: {
        let col = (activePlayer && activePlayer.shuffle) ? theme.urlColor(root.mediaAccentColor) : "%23a1a1aa";
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M2 18h1.4c1.3 0 2.5-.6 3.3-1.7l6.1-8.6c.7-1.1 2-1.7 3.3-1.7H22'/><path d='m18 2 4 4-4 4'/><path d='M2 6h1.4c1.3 0 2.5.6 3.3 1.7l1.7 2.4'/><path d='m14.5 13.9 1.7 2.4c.8 1.1 2 1.7 3.3 1.7H22'/><path d='m18 22 4-4-4-4'/></svg>";
    }

    property string prevSvgUri: {
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23f1f5f9' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><polygon points='19 20 9 12 19 4 19 20' fill='%23f1f5f9'/><line x1='5' y1='19' x2='5' y2='5'/></svg>";
    }

    property string nextSvgUri: {
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='%23f1f5f9' stroke-width='2.2' stroke-linecap='round' stroke-linejoin='round'><polygon points='5 4 15 12 5 20 5 4' fill='%23f1f5f9'/><line x1='19' y1='5' x2='19' y2='19'/></svg>";
    }

    property string repeatSvgUri: {
        let isLoop = activePlayer && (activePlayer.loopState !== MprisLoopState.None);
        let col = isLoop ? theme.urlColor(root.mediaAccentColor) : "%23a1a1aa";
        let isTrack = activePlayer && (activePlayer.loopState === MprisLoopState.Track);
        if (isTrack) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='m17 2 4 4-4 4'/><path d='M3 11v-1a4 4 0 0 1 4-4h14'/><path d='m7 22-4-4 4-4'/><path d='M21 13v1a4 4 0 0 1-4 4H3'/><path d='M11 10h1v4' stroke-width='1.8'/></svg>";
        }
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none' stroke='" + col + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='m17 2 4 4-4 4'/><path d='M3 11v-1a4 4 0 0 1 4-4h14'/><path d='m7 22-4-4 4-4'/><path d='M21 13v1a4 4 0 0 1-4 4H3'/></svg>";
    }



    // Periodic timer to continuously track position in real-time
    Timer {
        id: progressTimer
        interval: 200
        running: root.isPlaying && root.trackTitle !== "" && !root.isDraggingSeek
        repeat: true
        onTriggered: root.syncPosition()
    }

    // Secondary timer to maintain sync when paused or while popup is open
    Timer {
        id: pausedSyncTimer
        interval: 1000
        running: root.activePlayer !== null && (!root.isPlaying || root.activePopupId === "media")
        repeat: true
        onTriggered: root.syncPosition()
    }

    onActivePlayerChanged: {
        root.syncPosition();
        root.updatePalette();
    }
    onTrackTitleChanged: {
        root.syncPosition();
        root.updatePalette();
    }
    onIsPlayingChanged: root.syncPosition()
    onActivePopupIdChanged: {
        if (activePopupId === "media") {
            root.syncPosition();
            root.updatePalette();
        }
    }

    // Only show pill if an allowed player (Spotify, YouTube, SoundCloud) has a track loaded
    visible: root.activePlayer !== null && root.currentPlatform !== "" && root.trackTitle !== ""

    // --- BAR PILL: CLEAN BRAND LOGO + TRACK TITLE ---
    BarPill {
        id: pill
        iconSource: {
            if (root.isYouTube) return root.youtubeSvgUri;
            if (root.isSpotify) return root.spotifySvgUri;
            if (root.isSoundCloud) return root.soundcloudSvgUri;
            return root.defaultMediaSvgUri;
        }
        text: root.displayLabel
        accentColor: root.mediaAccentColor
        active: root.activePopupId === "media"
        pulsingIcon: false

        onClicked: {
            root.togglePopup("media");
        }

        onRightClicked: {
            if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next();
        }

        // Subtle mini progress line at bottom of the pill (matches brand color, e.g. Spotify Green / accent)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.bottomMargin: 2
            height: 2
            radius: 1
            color: Qt.rgba(255, 255, 255, 0.16)
            visible: root.trackLength > 0

            Rectangle {
                height: parent.height
                radius: parent.radius
                width: {
                    if (root.trackLength <= 0) return 0;
                    let pct = Math.max(0, Math.min(1.0, root.currentPosition / root.trackLength));
                    return Math.round(parent.width * pct);
                }
                color: root.mediaAccentColor

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            }
        }
    }

    // --- POPUP WINDOW: ULTRA-MODERN GLASS LIQUID MEDIA CARD ---
    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "media" && root.activePlayer !== null && root.currentPlatform !== "" && root.trackTitle !== ""
        onVisibleChanged: if (visible) root.updatePalette()
        implicitWidth: 350
        implicitHeight: cardLayout.implicitHeight + 42
        color: "transparent"

        Rectangle {
            id: cardContainer
            anchors.fill: parent
            anchors.topMargin: 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: 16
            clip: true

            opacity: popup.visible ? 1.0 : 0.0
            scale: popup.visible ? 1.0 : 0.95
            transformOrigin: Item.Top
            transform: Translate {
                y: popup.visible ? 0 : -8
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

            // 1. Ambient Brand Aura (Spotify Green / Platform Brand)
            RadialGradient {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: -40
                anchors.topMargin: -40
                width: 300
                height: 300
                opacity: root.isPlaying ? 0.30 : 0.14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.mediaAccentColor }
                    GradientStop { position: 0.45; color: Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, 0.16) }
                    GradientStop { position: 0.85; color: "transparent" }
                }
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            // 2. Liquid Glass Top Specular Bevel Line (Apple Hallmark)
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.25; color: Qt.rgba(255, 255, 255, 0.25) }
                    GradientStop { position: 0.75; color: Qt.rgba(255, 255, 255, 0.25) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Main Vertical Content
            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                // --- HEADER: Brand Chip + Multi-player Switcher + Waveform Equalizer ---
                Item {
                    width: parent.width
                    height: 26

                    // Left: Interactive Brand Chip
                    Rectangle {
                        id: brandChip
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: brandRow.implicitWidth + 16
                        radius: 13
                        color: brandMa.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                        border.color: brandMa.containsMouse ? root.mediaAccentColor : Qt.rgba(255, 255, 255, 0.12)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            id: brandRow
                            anchors.centerIn: parent
                            spacing: 6

                            Image {
                                width: 14
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                source: {
                                    if (root.isYouTube) return root.youtubeSvgUri;
                                    if (root.isSpotify) return root.spotifySvgUri;
                                    if (root.isSoundCloud) return root.soundcloudSvgUri;
                                    return root.defaultMediaSvgUri;
                                }
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: root.playerBrandName
                                color: brandMa.containsMouse ? theme.text : theme.textSub
                                font.family: theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: brandMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.focusPlayerWindow()
                        }
                    }

                    // Right: Status Badge
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        width: statusRow.implicitWidth + 14
                        radius: 12
                        color: root.isPlaying ? Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, 0.18) : Qt.rgba(255, 255, 255, 0.06)
                        border.color: root.isPlaying ? Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, 0.45) : Qt.rgba(255, 255, 255, 0.10)
                        border.width: 1

                        Row {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 6

                            // Clean Minimal Status Dot
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: root.isPlaying ? root.mediaAccentColor : theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: root.isPlaying ? 1.0 : 0.6
                            }

                            Text {
                                text: root.isPlaying ? "Playing" : "Paused"
                                color: root.isPlaying ? root.mediaAccentColor : theme.textMuted
                                font.family: theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Divider line
                Rectangle {
                    width: parent.width
                    height: 1
                    color: theme.borderSubtle
                }

                // --- MAIN TRACK BODY: Artwork + Metadata ---
                Row {
                    width: parent.width
                    spacing: 14

                    // Artwork Container with Ambient Glow & Modern Frame
                    Item {
                        id: artWrapper
                        width: 88
                        height: 88
                        anchors.verticalCenter: parent.verticalCenter
                        scale: root.isPlaying ? 1.0 : 0.96

                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                        // 1. Soft Ambient Diffuse Glow behind Artwork
                        RectangularGlow {
                            id: artGlow
                            anchors.fill: artTile
                            glowRadius: root.isPlaying ? 16 : 8
                            spread: 0.12
                            color: Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, root.isPlaying ? 0.45 : 0.18)
                            cornerRadius: 14

                            Behavior on glowRadius { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        // 2. Main Rounded Art Tile (properly masked to smooth rounded corners)
                        Item {
                            id: artTile
                            anchors.fill: parent

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: artTile.width
                                    height: artTile.height
                                    radius: 14
                                }
                            }

                            // Surface placeholder background
                            Rectangle {
                                anchors.fill: parent
                                color: theme.surface
                            }

                            // Full Album Art Image
                            Image {
                                id: fullArtImg
                                anchors.fill: parent
                                source: root.artUrl
                                visible: root.artUrl !== "" && status === Image.Ready
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                mipmap: true
                            }

                            // Fallback icons
                            Image {
                                anchors.centerIn: parent
                                width: 50
                                height: 50
                                visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && root.isSoundCloud
                                source: root.soundcloudSvgUri
                                fillMode: Image.PreserveAspectFit
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 50
                                height: 50
                                visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && root.isSpotify
                                source: root.spotifySvgUri
                                fillMode: Image.PreserveAspectFit
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 54
                                height: 54
                                visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && root.isYouTube
                                source: root.youtubeSvgUri
                                fillMode: Image.PreserveAspectFit
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && !root.isSoundCloud && !root.isSpotify && !root.isYouTube
                                source: root.defaultMediaSvgUri
                                fillMode: Image.PreserveAspectFit
                            }

                            // Clickable hover play/pause overlay on cover
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 0.45)
                                visible: artMa.containsMouse
                                opacity: artMa.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Image {
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 28
                                    source: root.isPlaying ?
                                        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='%23ffffff'><rect x='6' y='4' width='4' height='16' rx='1.5'/><rect x='14' y='4' width='4' height='16' rx='1.5'/></svg>" :
                                        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='%23ffffff'><polygon points='6 4 20 12 6 20'/></svg>"
                                }
                            }
                        }

                        // 3. Crisp Specular & Accent Border Frame
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "transparent"
                            border.color: artMa.containsMouse ?
                                Qt.rgba(255, 255, 255, 0.40) :
                                (root.isPlaying ? Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, 0.45) : Qt.rgba(255, 255, 255, 0.16))
                            border.width: 1

                            Behavior on border.color { ColorAnimation { duration: 180 } }
                        }

                        // 4. Interactive Mouse Area
                        MouseArea {
                            id: artMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer) root.activePlayer.togglePlaying();
                            }
                        }
                    }

                    // Metadata Column
                    Column {
                        width: parent.width - artWrapper.width - 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Title
                        Text {
                            width: parent.width
                            text: root.trackTitle || "No Track"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            lineHeight: 1.15
                        }

                        // Artist (Uses platform accent color, e.g. Spotify green)
                        Row {
                            width: parent.width
                            spacing: 5
                            visible: root.trackArtist !== ""

                            Text {
                                text: root.trackArtist
                                color: root.mediaAccentColor
                                font.family: theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                width: Math.min(implicitWidth, parent.width)
                            }
                        }

                        // Album
                        Text {
                            visible: root.trackAlbum !== "" && root.trackAlbum.toLowerCase() !== root.trackTitle.toLowerCase()
                            width: parent.width
                            text: "󰀥 " + root.trackAlbum
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                // --- BARRAS DE VOLUMEN / ESPECTRO (ÚNICO ELEMENTO CON LA COLORIMETRÍA DEL ÁLBUM) ---
                Rectangle {
                    id: visualizerBox
                    width: parent.width
                    height: 48
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.40)
                    border.color: Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1
                    clip: true

                    // 24 Dynamic Audio Spectrum Bars with Gravity Peak Caps (Uses album colorimetry!)
                    RowLayout {
                        id: barsRow
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 5
                        anchors.bottomMargin: 5
                        spacing: 3

                        property var barHeights: [8, 12, 18, 24, 28, 33, 30, 25, 20, 26, 31, 35, 31, 26, 21, 25, 28, 23, 18, 15, 12, 10, 8, 6]
                        property var peakHeights: [8, 12, 18, 24, 28, 33, 30, 25, 20, 26, 31, 35, 31, 26, 21, 25, 28, 23, 18, 15, 12, 10, 8, 6]

                        // Real-time PipeWire audio spectrum visualizer via CAVA
                        Process {
                            id: cavaProc
                            command: ["/home/ferram/.local/bin/cava", "-p", "/home/ferram/.config/cava/quickshell.conf"]
                            running: root.isPlaying && popup.visible
                            stdout: SplitParser {
                                splitMarker: "\n"
                                onRead: data => {
                                    let trimmed = data.trim();
                                    if (trimmed.length === 0) return;
                                    let parts = trimmed.split(";");
                                    if (parts.length >= 24) {
                                        let newBars = [];
                                        let newPeaks = [];
                                        let oldPeaks = barsRow.peakHeights;
                                        let maxH = visualizerBox.height - 12;

                                        for (let i = 0; i < 24; i++) {
                                            let val = parseInt(parts[i]);
                                            let target = isNaN(val) ? 4 : Math.max(4, Math.min(maxH, val));
                                            newBars.push(target);

                                            let oldP = (oldPeaks && oldPeaks[i]) ? oldPeaks[i] : 4;
                                            let newP = Math.max(target, oldP - 1.2);
                                            newPeaks.push(newP);
                                        }
                                        barsRow.barHeights = newBars;
                                        barsRow.peakHeights = newPeaks;
                                    }
                                }
                            }
                            onRunningChanged: {
                                if (!running) {
                                    let zero = [];
                                    for (let i = 0; i < 24; i++) zero.push(4);
                                    barsRow.barHeights = zero;
                                    barsRow.peakHeights = zero;
                                }
                            }
                        }

                        Repeater {
                            model: 24
                            delegate: Item {
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Empty Track / Slot (replaces the old detached mesh)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: Qt.rgba(255, 255, 255, 0.04)
                                }

                                // Gradient Bar (ONLY element that reflects album colorimetry!)
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    radius: 2
                                    height: {
                                        if (!root.isPlaying) return 4;
                                        return (barsRow.barHeights && barsRow.barHeights[index]) ? barsRow.barHeights[index] : 4;
                                    }
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0.0; color: root.albumColorPrimary }
                                        GradientStop { position: 1.0; color: Qt.rgba(root.albumColorPrimary.r, root.albumColorPrimary.g, root.albumColorPrimary.b, 0.35) }
                                    }

                                    Behavior on height {
                                        NumberAnimation { duration: 45; easing.type: Easing.OutQuad }
                                    }
                                }

                                // Floating Gravity Peak Cap (album highlight color)
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottomMargin: {
                                        if (!root.isPlaying) return 4;
                                        let p = (barsRow.peakHeights && barsRow.peakHeights[index]) ? barsRow.peakHeights[index] : 4;
                                        return Math.max(4, Math.min(parent.height - 2, p + 2));
                                    }
                                    height: 2
                                    radius: 1
                                    color: Qt.lighter(root.albumColorPrimary, 1.25)

                                    Behavior on anchors.bottomMargin {
                                        NumberAnimation { duration: 45; easing.type: Easing.OutQuad }
                                    }
                                }
                            }
                        }
                    }

                    // Click visualizer to toggle play/pause
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer) root.activePlayer.togglePlaying();
                        }
                    }
                }

                // --- PROGRESS SLIDER & TIMESTAMPS (ALWAYS STANDARD COLOR, E.G. SPOTIFY GREEN) ---
                Column {
                    id: progressCol
                    width: parent.width
                    spacing: 6

                    // Scrubber Bar Area
                    Item {
                        id: progressHitArea
                        width: parent.width
                        height: 18

                        Rectangle {
                            id: progressTrough
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: (seekArea.containsMouse || root.isDraggingSeek) ? 6 : 4
                            radius: height / 2
                            color: Qt.rgba(255, 255, 255, 0.18)
                            border.color: Qt.rgba(255, 255, 255, 0.10)
                            border.width: 1

                            Behavior on height { NumberAnimation { duration: 120 } }

                            // Standard Brand Progress Fill (e.g. Spotify Green / accent)
                            Rectangle {
                                id: progressFill
                                height: parent.height
                                radius: parent.radius
                                width: {
                                    if (root.trackLength <= 0) return 0;
                                    let cur = root.isDraggingSeek ? root.dragPosition : root.currentPosition;
                                    let pct = Math.max(0, Math.min(1.0, cur / root.trackLength));
                                    return Math.round(parent.width * pct);
                                }
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.mediaAccentColor }
                                    GradientStop { position: 1.0; color: Qt.lighter(root.mediaAccentColor, 1.25) }
                                }

                                Behavior on width {
                                    enabled: !root.isDraggingSeek
                                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                                }
                            }

                            // Glowing Scrubber Knob (standard accent border)
                            Rectangle {
                                id: scrubberKnob
                                visible: root.trackLength > 0
                                width: (seekArea.containsMouse || root.isDraggingSeek) ? 14 : 10
                                height: width
                                radius: width / 2
                                color: "#ffffff"
                                border.color: root.mediaAccentColor
                                border.width: 2.5
                                anchors.verticalCenter: parent.verticalCenter
                                x: {
                                    if (root.trackLength <= 0) return 0;
                                    let cur = root.isDraggingSeek ? root.dragPosition : root.currentPosition;
                                    let pct = Math.max(0, Math.min(1.0, cur / root.trackLength));
                                    return Math.max(0, Math.min(parent.width - width, Math.round(parent.width * pct) - (width / 2)));
                                }

                                Behavior on width { NumberAnimation { duration: 120 } }
                                Behavior on x {
                                    enabled: !root.isDraggingSeek
                                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                                }
                            }
                        }

                        MouseArea {
                            id: seekArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            onPressed: (mouse) => {
                                root.isDraggingSeek = true;
                                let ratio = Math.max(0, Math.min(1.0, mouse.x / width));
                                root.dragPosition = ratio * (root.trackLength > 0 ? root.trackLength : 1);
                            }

                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let ratio = Math.max(0, Math.min(1.0, mouse.x / width));
                                    root.dragPosition = ratio * (root.trackLength > 0 ? root.trackLength : 1);
                                }
                            }

                            onReleased: (mouse) => {
                                let ratio = Math.max(0, Math.min(1.0, mouse.x / width));
                                root.seekToRatio(ratio);
                                root.isDraggingSeek = false;
                            }
                        }
                    }

                    // Timestamps: Clean left anchor and right anchor
                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.formatTime(root.isDraggingSeek ? root.dragPosition : root.currentPosition)
                            color: theme.textSub
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }

                        Text {
                            id: rightTimeTxt
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (root.showRemainingTime) {
                                    let cur = root.isDraggingSeek ? root.dragPosition : root.currentPosition;
                                    let rem = Math.max(0, root.trackLength - cur);
                                    return "-" + root.formatTime(rem);
                                }
                                return root.formatTime(root.trackLength);
                            }
                            color: timeToggleMa.containsMouse ? theme.text : theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium

                            MouseArea {
                                id: timeToggleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showRemainingTime = !root.showRemainingTime
                            }
                        }
                    }
                }

                // --- BALANCED PLAYBACK CONTROLS: Shuffle, Prev, Play/Pause, Next, Repeat ---
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    // 1. Shuffle Button
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: shufMa.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        scale: shufMa.pressed ? 0.90 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        opacity: (root.activePlayer && root.activePlayer.shuffleSupported) ? 1.0 : 0.4

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: root.shuffleSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        // Active Indicator Dot
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 3
                            height: 3
                            radius: 1.5
                            color: root.mediaAccentColor
                            visible: root.activePlayer && root.activePlayer.shuffle
                        }

                        MouseArea {
                            id: shufMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (root.activePlayer && root.activePlayer.shuffleSupported) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.toggleShuffle()
                        }
                    }

                    // 2. Previous Track Button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: prevMa.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.04)
                        border.color: prevMa.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        scale: prevMa.pressed ? 0.88 : (prevMa.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Image {
                            anchors.centerIn: parent
                            width: 15
                            height: 15
                            source: root.prevSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous();
                            }
                        }
                    }

                    // 3. Play / Pause Hero Button (Standard Brand Color, e.g. Spotify Green)
                    Item {
                        width: 48
                        height: 48
                        anchors.verticalCenter: parent.verticalCenter

                        // Ambient Glow Layer
                        Rectangle {
                            anchors.centerIn: parent
                            width: 54
                            height: 54
                            radius: 27
                            color: Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, playMa.containsMouse ? 0.45 : 0.25)
                            scale: playMa.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150 } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Gradient Button
                        Rectangle {
                            id: playBtn
                            anchors.fill: parent
                            radius: 24
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: playMa.containsMouse ? Qt.lighter(root.mediaAccentColor, 1.15) : root.mediaAccentColor }
                                GradientStop { position: 1.0; color: Qt.darker(root.mediaAccentColor, 1.20) }
                            }
                            scale: playMa.pressed ? 0.90 : (playMa.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                            Image {
                                anchors.centerIn: parent
                                width: 17
                                height: 17
                                source: {
                                    let iconFill = root.isAccentLight ? "%2312151c" : "%23ffffff";
                                    return root.isPlaying ?
                                        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='" + iconFill + "'><rect x='6' y='4' width='4' height='16' rx='1.5'/><rect x='14' y='4' width='4' height='16' rx='1.5'/></svg>" :
                                        "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='" + iconFill + "'><polygon points='6 4 20 12 6 20'/></svg>";
                                }
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                id: playMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer) root.activePlayer.togglePlaying();
                                }
                            }
                        }
                    }

                    // 4. Next Track Button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: nextMa.containsMouse ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.04)
                        border.color: nextMa.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        scale: nextMa.pressed ? 0.88 : (nextMa.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Image {
                            anchors.centerIn: parent
                            width: 15
                            height: 15
                            source: root.nextSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next();
                            }
                        }
                    }

                    // 5. Repeat / Loop Button
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: repMa.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        scale: repMa.pressed ? 0.90 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        opacity: (root.activePlayer && root.activePlayer.loopSupported) ? 1.0 : 0.4

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: root.repeatSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        // Active Indicator Dot
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 3
                            height: 3
                            radius: 1.5
                            color: root.mediaAccentColor
                            visible: root.activePlayer && (root.activePlayer.loopState !== MprisLoopState.None)
                        }

                        MouseArea {
                            id: repMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (root.activePlayer && root.activePlayer.loopSupported) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.cycleLoop()
                        }
                    }
                }


            }
        }
    }
}
