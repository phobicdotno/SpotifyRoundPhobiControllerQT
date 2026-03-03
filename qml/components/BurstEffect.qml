import QtQuick

Item {
    id: burstRoot
    width: 80
    height: 80

    property real burstX: 0
    property real burstY: 0
    property string burstType: "heart"  // "heart", "shuffle", or "sequential"

    x: burstX - width / 2
    y: burstY - height / 2
    opacity: 0.5
    scale: 0.3
    z: 30

    function start() {
        burstAnim.start();
    }

    // Heart shape
    Canvas {
        id: heartCanvas
        anchors.fill: parent
        visible: burstRoot.burstType === "heart"
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            // Scale SVG viewBox (0 0 100 100) to our size
            var s = width / 100;
            ctx.save();
            ctx.scale(s, s);
            ctx.beginPath();
            ctx.moveTo(50, 88);
            // Left curve
            ctx.bezierCurveTo(25, 65, 5, 50, 5, 30);
            // Left arc approximation
            ctx.bezierCurveTo(5, 12, 18, 5, 28, 5);
            ctx.bezierCurveTo(38, 5, 48, 12, 50, 20);
            // Right arc approximation
            ctx.bezierCurveTo(52, 12, 62, 5, 72, 5);
            ctx.bezierCurveTo(82, 5, 95, 12, 95, 30);
            ctx.bezierCurveTo(95, 50, 75, 65, 50, 88);
            ctx.closePath();
            ctx.fillStyle = "white";
            ctx.fill();
            ctx.restore();
        }
        Component.onCompleted: requestPaint()
    }

    // Shuffle icon (crossing arrows)
    Canvas {
        id: shuffleCanvas
        anchors.fill: parent
        visible: burstRoot.burstType === "shuffle"
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var s = width / 100;
            ctx.save();
            ctx.scale(s, s);
            ctx.strokeStyle = "white";
            ctx.lineWidth = 6;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            // Top line: 15,65 -> 40,65 -> 60,35 -> 85,35
            ctx.beginPath();
            ctx.moveTo(15, 65);
            ctx.lineTo(40, 65);
            ctx.lineTo(60, 35);
            ctx.lineTo(85, 35);
            ctx.stroke();
            // Arrow head at 85,35
            ctx.beginPath();
            ctx.moveTo(75, 25);
            ctx.lineTo(85, 35);
            ctx.lineTo(75, 45);
            ctx.stroke();

            // Bottom line: 15,35 -> 40,35 -> 60,65 -> 85,65
            ctx.beginPath();
            ctx.moveTo(15, 35);
            ctx.lineTo(40, 35);
            ctx.lineTo(60, 65);
            ctx.lineTo(85, 65);
            ctx.stroke();
            // Arrow head at 85,65
            ctx.beginPath();
            ctx.moveTo(75, 55);
            ctx.lineTo(85, 65);
            ctx.lineTo(75, 75);
            ctx.stroke();

            ctx.restore();
        }
        Component.onCompleted: requestPaint()
    }

    // Sequential icon (right arrow)
    Canvas {
        id: sequentialCanvas
        anchors.fill: parent
        visible: burstRoot.burstType === "sequential"
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var s = width / 100;
            ctx.save();
            ctx.scale(s, s);
            ctx.strokeStyle = "white";
            ctx.lineWidth = 6;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            // Arrow: 15,50 -> 75,50
            ctx.beginPath();
            ctx.moveTo(15, 50);
            ctx.lineTo(75, 50);
            ctx.stroke();
            // Arrow head
            ctx.beginPath();
            ctx.moveTo(65, 40);
            ctx.lineTo(75, 50);
            ctx.lineTo(65, 60);
            ctx.stroke();

            ctx.restore();
        }
        Component.onCompleted: requestPaint()
    }

    SequentialAnimation {
        id: burstAnim

        ParallelAnimation {
            NumberAnimation {
                target: burstRoot; property: "scale"
                from: 0.3; to: 1.2; duration: 240
                easing.type: Easing.OutQuad
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: burstRoot; property: "scale"
                from: 1.2; to: 2.5; duration: 560
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: burstRoot; property: "opacity"
                from: 0.5; to: 0; duration: 560
                easing.type: Easing.InQuad
            }
        }

        onFinished: burstRoot.destroy()
    }
}
