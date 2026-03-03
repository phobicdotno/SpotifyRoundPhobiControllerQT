import QtQuick

Item {
    id: ringRoot

    property real progress: 0.0  // 0.0 to 1.0
    property bool playing: false
    property int currentProgressMs: 0
    property int currentDurationMs: 1

    // Smooth interpolation
    property real displayProgress: 0.0
    property real lastPollTime: 0
    property int progressAtPoll: 0

    // Size: 33% of parent, centered
    width: parent.width * 0.33
    height: width
    anchors.centerIn: parent

    Canvas {
        id: ringCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx = width / 2;
            var cy = height / 2;
            var r = (width / 2) - 4;  // slight padding
            var strokeWidth = r * 0.0075 * 2;  // 0.75% of radius, x2 for visibility
            if (strokeWidth < 2) strokeWidth = 2;

            // Background arc: full circle
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.strokeStyle = "rgba(255,255,255,0.1)";
            ctx.lineWidth = strokeWidth;
            ctx.stroke();

            // Progress arc: partial, starting from top (-90deg = -PI/2)
            if (ringRoot.displayProgress > 0) {
                var startAngle = -Math.PI / 2;
                var endAngle = startAngle + (2 * Math.PI * ringRoot.displayProgress);
                ctx.beginPath();
                ctx.arc(cx, cy, r, startAngle, endAngle);
                ctx.strokeStyle = "rgba(255,255,255,0.9)";
                ctx.lineWidth = strokeWidth;
                ctx.lineCap = "round";
                ctx.stroke();
            }
        }
    }

    // ~60fps interpolation timer when playing
    Timer {
        id: interpTimer
        interval: 16  // ~60fps
        running: ringRoot.playing
        repeat: true
        onTriggered: {
            if (ringRoot.currentDurationMs > 0) {
                var now = Date.now();
                var elapsed = now - ringRoot.lastPollTime;
                var current = ringRoot.progressAtPoll + elapsed;
                var clamped = Math.min(current, ringRoot.currentDurationMs);
                ringRoot.displayProgress = clamped / ringRoot.currentDurationMs;
                ringCanvas.requestPaint();
            }
        }
    }

    // Update poll reference when progress changes from backend
    onCurrentProgressMsChanged: {
        lastPollTime = Date.now();
        progressAtPoll = currentProgressMs;
        if (currentDurationMs > 0) {
            displayProgress = currentProgressMs / currentDurationMs;
        }
        ringCanvas.requestPaint();
    }

    onCurrentDurationMsChanged: {
        if (currentDurationMs > 0) {
            displayProgress = currentProgressMs / currentDurationMs;
        }
        ringCanvas.requestPaint();
    }

    // Repaint when not playing (stopped state)
    onPlayingChanged: {
        ringCanvas.requestPaint();
    }

    Component.onCompleted: {
        lastPollTime = Date.now();
        ringCanvas.requestPaint();
    }
}
