import QtQuick

Item {
    id: setupRoot
    anchors.fill: parent

    // Circular clip
    Rectangle {
        id: circleClip
        anchors.fill: parent
        radius: width / 2
        clip: true
        color: "black"

        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.8

            Text {
                text: "Spotify Controller"
                color: "#1DB954"
                font.pixelSize: 32
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Waiting for authorization..."
                color: "#b3b3b3"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "A browser tab should have opened.\nLog in to Spotify and authorize the app."
                color: "#666666"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                lineHeight: 1.4
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Item { width: 1; height: 8 } // spacer

            Rectangle {
                id: retryButton
                width: 220
                height: 48
                radius: 24
                color: retryMouse.pressed ? "#1aa34a" : "#1DB954"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "Retry Authorization"
                    color: "black"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: retryMouse
                    anchors.fill: parent
                    onClicked: Spotify.openAuthInBrowser()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
