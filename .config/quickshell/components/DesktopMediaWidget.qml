import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import "../theme"

Rectangle {
    id: root
    Theme { id: theme }

    implicitWidth: 448
    implicitHeight: 207

    radius: 20
    color: Qt.rgba(0.06, 0.06, 0.09, 0.65)
    border.color: Qt.rgba(255, 255, 255, 0.10)
    border.width: 1
    clip: true

    readonly property var wrapper: (root.parent && root.parent.parent && root.parent.parent.startDrag) ? root.parent.parent : null

    // Find first active MPRIS player
    readonly property var activePlayer: {
        let players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (let i = 0; i < players.length; i++) {
            let p = players[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players[0];
    }

    readonly property bool isPlaying: activePlayer ? (activePlayer.playbackState === MprisPlaybackState.Playing) : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "No Media Playing") : "No Media Playing"
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "Idle") : "Music Player Ready"
    readonly property string trackArtUrl: {
        if (!activePlayer) return "";
        let u = "";
        try {
            if (activePlayer.trackArtUrl) u = activePlayer.trackArtUrl.toString();
        } catch(e) {}
        if (!u && activePlayer.metadata && activePlayer.metadata["mpris:artUrl"]) {
            try {
                u = activePlayer.metadata["mpris:artUrl"].toString();
            } catch(e) {}
        }
        return (u || "").trim();
    }

    function getResolvedArtUrl(url) {
        if (!url) return "";
        if (url.startsWith("https://i.scdn.co/image/")) {
            let id = url.substring(url.lastIndexOf("/") + 1).split("?")[0];
            if (id) return "file:///home/ferram/.cache/spotify-covers/" + id + ".jpg";
        }
        return url;
    }

    Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Album Artwork Container
        Item {
            id: artContainer
            width: parent.height
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: artPlaceholder
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(255, 255, 255, 0.10)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 32
                    color: root.isPlaying ? (theme.blueLight != "" ? theme.blueLight : theme.blue) : theme.textDim
                }
            }

            Item {
                id: artTile
                anchors.fill: parent
                visible: root.trackArtUrl !== "" && artImg.status === Image.Ready
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artTile.width
                        height: artTile.height
                        radius: 14
                    }
                }

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: root.getResolvedArtUrl(root.trackArtUrl)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true

                    onStatusChanged: {
                        if (status === Image.Error && source.toString().indexOf(".cache/spotify-covers") !== -1) {
                            source = root.trackArtUrl;
                        }
                    }
                }
            }
        }

        // Track Info & Controls
        Column {
            width: parent.width - parent.height - 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // App badge
            Row {
                spacing: 6
                Text {
                    text: "󰓇"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#1ed760"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.isPlaying ? "NOW PLAYING" : "MEDIA"
                    color: theme.textDim
                    font.family: theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Title
            Text {
                text: root.trackTitle
                color: theme.text
                font.family: theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: parent.width
            }

            // Artist
            Text {
                text: root.trackArtist
                color: theme.textSub
                font.family: theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: parent.width
            }

            // Controls Row
            Row {
                spacing: 12

                // Prev Track Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: prevHov.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08)
                    border.color: theme.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: theme.text
                    }

                    MouseArea {
                        id: prevHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoPrevious) {
                                root.activePlayer.previous();
                            }
                        }
                    }
                }

                // Play / Pause Button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: playHov.containsMouse ? theme.blue : (theme.blueLight != "" ? theme.blueLight : theme.blue)

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: "#000000"
                    }

                    MouseArea {
                        id: playHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer) {
                                root.activePlayer.togglePlaying();
                            }
                        }
                    }
                }

                // Next Track Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: nextHov.containsMouse ? theme.surfaceActive : Qt.rgba(1, 1, 1, 0.08)
                    border.color: theme.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: theme.text
                    }

                    MouseArea {
                        id: nextHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoNext) {
                                root.activePlayer.next();
                            }
                        }
                    }
                }
            }
        }
    }
}
