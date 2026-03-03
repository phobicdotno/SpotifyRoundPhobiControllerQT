import QtQuick

Item {
    id: toastRoot
    anchors.fill: parent
    z: 20
    visible: false

    function show(name, artistName) {
        trackNameText.text = name;
        trackArtistText.text = artistName;
        toastRoot.visible = true;
        toastContainer.opacity = 0;
        fadeInOutAnim.restart();
    }

    // Toast container: bottom 120px, centered
    Rectangle {
        id: toastContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 120
        width: Math.min(contentCol.implicitWidth + 64, parent.width * 0.8)
        height: contentCol.implicitHeight + 32
        radius: 16
        color: Qt.rgba(0, 0, 0, 0.65)
        opacity: 0

        Column {
            id: contentCol
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 4

            Text {
                id: trackNameText
                color: "white"
                font.pixelSize: 22
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                id: trackArtistText
                color: "#b3b3b3"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    SequentialAnimation {
        id: fadeInOutAnim

        // Fade in (0% to 10% of 3s = 300ms)
        NumberAnimation {
            target: toastContainer; property: "opacity"
            from: 0; to: 1; duration: 300
            easing.type: Easing.InOutQuad
        }
        // Hold (10% to 80% of 3s = 2100ms)
        PauseAnimation { duration: 2100 }
        // Fade out (80% to 100% of 3s = 600ms)
        NumberAnimation {
            target: toastContainer; property: "opacity"
            from: 1; to: 0; duration: 600
            easing.type: Easing.InOutQuad
        }

        onFinished: {
            toastRoot.visible = false;
        }
    }
}
