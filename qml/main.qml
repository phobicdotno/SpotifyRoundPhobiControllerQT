import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 1000
    height: 1000
    visible: true
    flags: Qt.FramelessWindowHint | Qt.Window
    color: "black"
    title: "Spotify Controller"

    Rectangle {
        anchors.fill: parent
        color: "black"

        Rectangle {
            id: viewport
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            radius: width / 2
            clip: true
            color: "#111"

            Text {
                anchors.centerIn: parent
                text: "SpotifyController\nQt6 + QML"
                color: "#1DB954"
                font.pixelSize: 32
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }
}
