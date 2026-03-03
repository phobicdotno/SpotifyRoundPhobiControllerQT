import QtQuick

Item {
    id: volRoot
    anchors.fill: parent
    z: 30
    visible: false

    property int volumeValue: 0

    function show(vol) {
        volumeValue = vol;
        volRoot.visible = true;
        volCanvas.requestPaint();
        volAnim.restart();
    }

    // Centered container
    Item {
        id: volContainer
        width: 200
        height: 240
        anchors.centerIn: parent
        scale: 0.5
        opacity: 0

        Canvas {
            id: volCanvas
            width: 200
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = 100;
                var cy = 100;
                var r = 80;

                // Background ring
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.strokeStyle = "rgba(255,255,255,0.2)";
                ctx.lineWidth = 8;
                ctx.stroke();

                // Foreground arc (#1DB954)
                if (volRoot.volumeValue > 0) {
                    var startAngle = -Math.PI / 2;
                    var endAngle = startAngle + (2 * Math.PI * volRoot.volumeValue / 100);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, startAngle, endAngle);
                    ctx.strokeStyle = "#1DB954";
                    ctx.lineWidth = 8;
                    ctx.lineCap = "round";
                    ctx.stroke();
                }
            }
        }

        Text {
            id: volText
            text: volRoot.volumeValue
            color: "white"
            font.pixelSize: 28
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: volCanvas.top
            anchors.topMargin: 86  // Center inside the ring
            horizontalAlignment: Text.AlignHCenter
        }
    }

    SequentialAnimation {
        id: volAnim

        ParallelAnimation {
            NumberAnimation {
                target: volContainer; property: "scale"
                from: 0.5; to: 1.1; duration: 160
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: volContainer; property: "opacity"
                from: 0; to: 1; duration: 160
                easing.type: Easing.OutQuad
            }
        }
        NumberAnimation {
            target: volContainer; property: "scale"
            from: 1.1; to: 1.0; duration: 120
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: 400 }
        NumberAnimation {
            target: volContainer; property: "opacity"
            from: 1; to: 0; duration: 120
            easing.type: Easing.InQuad
        }

        onFinished: {
            volRoot.visible = false;
            volContainer.scale = 0.5;
            volContainer.opacity = 0;
        }
    }
}
