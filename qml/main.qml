import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 1000
    height: 1000
    visible: true
    flags: Qt.FramelessWindowHint | Qt.Window
    color: "transparent"
    title: "Spotify Controller"

    // --- Setup View (auth waiting) ---
    SetupView {
        id: setupView
        anchors.fill: parent
        visible: !Spotify.authenticated
        z: 100
    }

    // --- Player View (main app) ---
    PlayerView {
        id: playerView
        anchors.fill: parent
        visible: Spotify.authenticated
    }

    // Wire trackChanged to show toast when track changes
    Connections {
        target: Spotify
        function onTrackChanged(direction) {
            if (Spotify.authenticated && Spotify.trackName && direction) {
                playerView.showTrackToast(Spotify.trackName, Spotify.artist);
            }
        }
    }
}
