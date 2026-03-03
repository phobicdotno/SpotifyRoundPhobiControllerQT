import QtQuick

Item {
    id: feedbackRoot
    anchors.fill: parent
    z: 30
    visible: false

    property string mode: "pause"  // "pause" or "play"

    function show() {
        feedbackRoot.visible = true;
        feedbackAnim.restart();
    }

    // Container at center
    Item {
        id: iconContainer
        width: 80
        height: 80
        anchors.centerIn: parent
        scale: 0.5
        opacity: 0

        // Pause icon: two rectangles
        Item {
            id: pauseIcon
            anchors.fill: parent
            visible: feedbackRoot.mode === "pause"

            Rectangle {
                x: 20; y: 12
                width: 14; height: 56
                radius: 3
                color: "white"
            }
            Rectangle {
                x: 46; y: 12
                width: 14; height: 56
                radius: 3
                color: "white"
            }
        }

        // Play icon: triangle via Canvas
        Canvas {
            id: playIcon
            anchors.fill: parent
            visible: feedbackRoot.mode === "play"
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.beginPath();
                ctx.moveTo(20, 8);
                ctx.lineTo(68, 40);
                ctx.lineTo(20, 72);
                ctx.closePath();
                ctx.fillStyle = "white";
                ctx.fill();
            }
            Component.onCompleted: requestPaint()
        }
    }

    SequentialAnimation {
        id: feedbackAnim

        ParallelAnimation {
            NumberAnimation {
                target: iconContainer; property: "scale"
                from: 0.5; to: 1.1; duration: 120
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: iconContainer; property: "opacity"
                from: 0; to: 1; duration: 120
                easing.type: Easing.OutQuad
            }
        }
        NumberAnimation {
            target: iconContainer; property: "scale"
            from: 1.1; to: 1.0; duration: 120
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: 240 }
        NumberAnimation {
            target: iconContainer; property: "opacity"
            from: 1; to: 0; duration: 120
            easing.type: Easing.InQuad
        }

        onFinished: {
            feedbackRoot.visible = false;
            iconContainer.scale = 0.5;
            iconContainer.opacity = 0;
        }
    }
}
