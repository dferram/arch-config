import QtQuick
import QtQuick.Layouts
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

    // Select active media player (prefer Playing status, then one with track title)
    property var activePlayer: {
        let vals = Mpris.players.values;
        if (!vals || vals.length === 0) return null;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].playbackState === MprisPlaybackState.Playing) return vals[i];
        }
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].trackTitle && vals[i].trackTitle.length > 0) return vals[i];
        }
        return vals[0];
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

    function formatTime(seconds) {
        if (isNaN(seconds) || seconds <= 0) return "0:00";
        let mins = Math.floor(seconds / 60);
        let secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    // Platform identification
    property bool isInstagram: {
        if (!activePlayer) return false;
        let title = (root.trackTitle || "").toLowerCase();
        let artist = (activePlayer.trackArtist || "").toLowerCase();
        let album = (activePlayer.trackAlbum || "").toLowerCase();
        let ident = (activePlayer.identity || "").toLowerCase();
        return title.includes("instagram") || artist.includes("instagram") || album.includes("instagram") || ident.includes("instagram");
    }

    property bool isSpotify: {
        if (!activePlayer) return false;
        let ident = (activePlayer.identity || "").toLowerCase();
        let entry = (activePlayer.desktopEntry || "").toLowerCase();
        let art = (root.artUrl || "").toLowerCase();
        let title = (root.trackTitle || "").toLowerCase();
        let url = "";
        if (activePlayer.metadata && activePlayer.metadata["xesam:url"]) {
            url = (activePlayer.metadata["xesam:url"] || "").toLowerCase();
        }
        return ident.includes("spotify") || entry.includes("spotify") || art.includes("scdn.co") || url.includes("spotify") || title.includes("spotify");
    }

    property bool isTwitch: {
        if (!activePlayer) return false;
        let title = (root.trackTitle || "").toLowerCase();
        let ident = (activePlayer.identity || "").toLowerCase();
        return title.includes("twitch") || ident.includes("twitch");
    }

    property bool isSoundCloud: {
        if (!activePlayer) return false;
        let title = (root.trackTitle || "").toLowerCase();
        let url = "";
        if (activePlayer.metadata && activePlayer.metadata["xesam:url"]) {
            url = (activePlayer.metadata["xesam:url"] || "").toLowerCase();
        }
        return title.includes("soundcloud") || url.includes("soundcloud");
    }

    property bool isYouTube: {
        if (!activePlayer) return false;
        // Priority check: Never match YouTube if another platform is detected
        if (root.isInstagram || root.isSpotify || root.isTwitch || root.isSoundCloud) return false;

        let ident = (activePlayer.identity || "").toLowerCase();
        let title = (root.trackTitle || "").toLowerCase();
        let artist = (activePlayer.trackArtist || "").toLowerCase();
        let url = "";
        if (activePlayer.metadata && activePlayer.metadata["xesam:url"]) {
            url = (activePlayer.metadata["xesam:url"] || "").toLowerCase();
        }
        let art = (root.artUrl || "").toLowerCase();
        
        // Direct MPRIS check
        if (ident.includes("youtube") || 
            title.includes("youtube") || 
            artist.includes("youtube") || 
            url.includes("youtube") || 
            url.includes("youtu.be") || 
            art.includes("ytimg.com")) {
            return true;
        }

        // Web browser player check:
        // ONLY match YouTube if a browser window CURRENTLY has "youtube" in its live title
        // Never check initialTitle!
        if (ident.includes("chromium") || ident.includes("chrome") || ident.includes("firefox") || ident.includes("brave") || ident.includes("edge") || ident.includes("zen") || ident.includes("browser")) {
            try {
                if (typeof Hyprland !== "undefined" && Hyprland.toplevels && Hyprland.toplevels.values) {
                    let toplevels = Hyprland.toplevels.values;
                    for (let i = 0; i < toplevels.length; i++) {
                        let win = toplevels[i];
                        let wTitle = (win.title || "").toLowerCase();
                        if (wTitle.includes("youtube")) {
                            // If title contains the current track or a snippet of it, or "- youtube"
                            if (root.trackTitle.length > 3) {
                                let snippet = root.trackTitle.substring(0, Math.min(10, root.trackTitle.length)).toLowerCase();
                                if (wTitle.includes(snippet)) return true;
                            }
                            if (wTitle.includes("- youtube")) return true;
                        }
                    }
                }
            } catch(e) {}
        }

        return false;
    }

    property color mediaAccentColor: {
        if (isInstagram) return "#e1306c"; // Instagram Pink
        if (isYouTube) return "#ef4444";   // YouTube Red
        if (isSpotify) return "#1ed760";   // Spotify Green
        if (isTwitch) return "#a970ff";    // Twitch Purple
        if (isSoundCloud) return "#ff5500";// SoundCloud Orange
        return theme.blueLight;
    }

    property string playerBrandName: {
        if (isInstagram) return "Instagram";
        if (isYouTube) return "YouTube";
        if (isSpotify) return "Spotify";
        if (isTwitch) return "Twitch";
        if (isSoundCloud) return "SoundCloud";
        return activePlayer ? (activePlayer.identity || "Media") : "Media";
    }

    // Official Instagram SVG vector
    property string instagramSvgUri: {
        let col = theme.urlColor(root.mediaAccentColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.80) translate(-12, -12)'><rect x='2.5' y='2.5' width='19' height='19' rx='5.5' stroke='" + col + "' stroke-width='2'/><circle cx='12' cy='12' r='4.5' stroke='" + col + "' stroke-width='2'/><circle cx='17.5' cy='6.5' r='1.2' fill='" + col + "'/></g></svg>";
    }

    // Official Spotify SVG vector matching Arch Linux HostBadge geometry
    property string spotifySvgUri: {
        let col = theme.urlColor(root.mediaAccentColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.78) translate(-12, -12)'><path fill-rule='evenodd' clip-rule='evenodd' d='M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z' fill='" + col + "'/></g></svg>";
    }

    // Official YouTube SVG vector with YouTube Red background and white play triangle
    property string youtubeSvgUri: {
        let col = theme.urlColor(root.mediaAccentColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.82) translate(-12, -12)'><path d='M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814z' fill='" + col + "'/><polygon points='9.545,15.568 9.545,8.432 15.818,12' fill='%23ffffff'/></g></svg>";
    }

    // Generic clean audio note SVG vector for other players
    property string defaultMediaSvgUri: {
        let col = theme.urlColor(root.mediaAccentColor);
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.78) translate(-12, -12)'><path d='M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z' fill='" + col + "'/></g></svg>";
    }

    Timer {
        interval: 1000
        running: root.isPlaying && (root.activePopupId === "media")
        repeat: true
    }

    // Only show pill if a player has a track loaded
    visible: trackTitle !== ""

    // --- BAR PILL: CLEAN BRAND LOGO + TRACK TITLE (matching Arch HostBadge) ---
    BarPill {
        id: pill
        iconSource: {
            if (root.isInstagram) return root.instagramSvgUri;
            if (root.isYouTube) return root.youtubeSvgUri;
            if (root.isSpotify) return root.spotifySvgUri;
            return root.defaultMediaSvgUri;
        }
        text: root.displayLabel
        accentColor: root.mediaAccentColor
        active: root.activePopupId === "media"

        onClicked: {
            root.togglePopup("media");
        }

        onRightClicked: {
            if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next();
        }
    }

    PopupWindow {
        id: popup
        anchor.window: root.parentWindow
        anchor.item: pill
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8

        visible: root.activePopupId === "media" && root.trackTitle !== ""
        implicitWidth: 330
        implicitHeight: cardLayout.implicitHeight + 28
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: theme.radiusLarge

            Column {
                id: cardLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: 12

                // Header: Identity & Playing Badge
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 6
                        color: Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, 0.18)

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            visible: root.isInstagram
                            source: root.instagramSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            visible: root.isSpotify
                            source: root.spotifySvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            visible: root.isYouTube
                            source: root.youtubeSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            visible: !root.isInstagram && !root.isSpotify && !root.isYouTube
                            source: root.defaultMediaSvgUri
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        text: root.playerBrandName
                        color: theme.textSub
                        font.family: theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { Layout.fillWidth: true; width: 1; height: 1 }

                    // Playing / Paused badge
                    Rectangle {
                        width: stateTxt.implicitWidth + 12
                        height: 20
                        radius: 10
                        color: root.isPlaying ? Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, 0.2) : theme.surface
                        border.color: root.isPlaying ? root.mediaAccentColor : theme.borderSubtle
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: stateTxt
                            anchors.centerIn: parent
                            text: root.isPlaying ? "Playing" : "Paused"
                            color: root.isPlaying ? root.mediaAccentColor : theme.textMuted
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: theme.borderSubtle }

                // Main Track Content: Large Album Art + Info
                Row {
                    width: parent.width
                    spacing: 14

                    // Large Album Art Cover / Brand Logo
                    Rectangle {
                        width: 80
                        height: 80
                        radius: 8
                        color: theme.surface
                        border.color: root.isPlaying ? Qt.rgba(root.mediaAccentColor.r, root.mediaAccentColor.g, root.mediaAccentColor.b, 0.4) : theme.border
                        border.width: 1
                        clip: true

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

                        // Official Instagram Logo fallback
                        Image {
                            anchors.centerIn: parent
                            width: 48
                            height: 48
                            visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && root.isInstagram
                            source: root.instagramSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        // Official Spotify Logo fallback
                        Image {
                            anchors.centerIn: parent
                            width: 48
                            height: 48
                            visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && root.isSpotify
                            source: root.spotifySvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        // Official YouTube Logo fallback
                        Image {
                            anchors.centerIn: parent
                            width: 52
                            height: 52
                            visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && root.isYouTube
                            source: root.youtubeSvgUri
                            fillMode: Image.PreserveAspectFit
                        }

                        // Generic note fallback if none
                        Text {
                            anchors.centerIn: parent
                            visible: (root.artUrl === "" || fullArtImg.status !== Image.Ready) && !root.isInstagram && !root.isSpotify && !root.isYouTube
                            text: "🎵"
                            font.pixelSize: 32
                        }
                    }

                    // Metadata Column
                    Column {
                        width: parent.width - 94
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            width: parent.width
                            text: root.trackTitle || "No Track"
                            color: theme.text
                            font.family: theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        Text {
                            width: parent.width
                            text: root.trackArtist || "Unknown Artist"
                            color: root.mediaAccentColor
                            font.family: theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: root.trackAlbum !== ""
                            width: parent.width
                            text: "💿 " + root.trackAlbum
                            color: theme.textMuted
                            font.family: theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                // Progress Bar (if length is available)
                Column {
                    width: parent.width
                    spacing: 4
                    visible: root.activePlayer && root.activePlayer.length > 0

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: theme.surface

                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: {
                                if (!root.activePlayer || root.activePlayer.length <= 0) return 0;
                                let pct = root.activePlayer.position / root.activePlayer.length;
                                return Math.min(parent.width, Math.max(0, parent.width * pct));
                            }
                            color: root.mediaAccentColor
                        }
                    }

                    Row {
                        width: parent.width
                        Text {
                            text: root.activePlayer ? root.formatTime(root.activePlayer.position) : "0:00"
                            color: theme.textMuted
                            font.pixelSize: 10
                        }
                        Item { Layout.fillWidth: true; width: 1; height: 1 }
                        Text {
                            text: root.activePlayer ? root.formatTime(root.activePlayer.length) : "0:00"
                            color: theme.textMuted
                            font.pixelSize: 10
                        }
                    }
                }

                // Playback Controls Row (Prev, Play/Pause, Next)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // 1. Previous Track Button
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: prevMa.containsMouse ? theme.surfaceHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "⏮"
                            color: theme.textSub
                            font.pixelSize: 15
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

                    // 2. Play / Pause Prominent Circle
                    Rectangle {
                        width: 44
                        height: 44
                        radius: 22
                        color: playMa.containsMouse ? Qt.darker(root.mediaAccentColor, 1.15) : root.mediaAccentColor
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "⏸" : "▶"
                            color: "#ffffff"
                            font.pixelSize: 17
                            font.weight: Font.Bold
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

                    // 3. Next Track Button
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: nextMa.containsMouse ? theme.surfaceHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "⏭"
                            color: theme.textSub
                            font.pixelSize: 15
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
                }
            }
        }
    }
}
