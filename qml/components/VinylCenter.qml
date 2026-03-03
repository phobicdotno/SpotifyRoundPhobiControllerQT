import QtQuick

Item {
    id: vinylRoot

    property string artistText: ""
    property string songText: ""

    // Size: 33% of parent, centered
    width: parent.width * 0.33
    height: width
    anchors.centerIn: parent

    Rectangle {
        id: vinylDisc
        anchors.fill: parent
        radius: width / 2
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
        color: "transparent"

        // Radial gradient background
        gradient: Gradient {
            orientation: Gradient.Vertical
            // Approximate radial gradient with vertical gradient
        }

        // Use Canvas for true radial gradient
        Canvas {
            id: bgCanvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                var cx = width / 2;
                var cy = height / 2;
                var r = width / 2;

                ctx.clearRect(0, 0, width, height);

                // Circular clip
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.closePath();
                ctx.clip();

                // Radial gradient: rgba(0,0,0,0.7) center to rgba(0,0,0,0.5) edge
                var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                grad.addColorStop(0, "rgba(0,0,0,0.7)");
                grad.addColorStop(0.6, "rgba(0,0,0,0.6)");
                grad.addColorStop(1, "rgba(0,0,0,0.5)");
                ctx.fillStyle = grad;
                ctx.fillRect(0, 0, width, height);
            }
            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // Artist name: top 25%, uppercase, letter-spacing
        Text {
            id: artistLabel
            text: vinylRoot.artistText
            color: "white"
            font.pixelSize: vinylRoot.parent ? vinylRoot.parent.width * 0.018 : 18
            font.bold: true
            font.letterSpacing: (vinylRoot.parent ? vinylRoot.parent.width * 0.018 : 18) * 0.15
            font.capitalization: Font.AllUppercase
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.3
            width: parent.width * 0.7
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.25 - implicitHeight / 2

            // text shadow approximated with a drop shadow
            layer.enabled: true
            layer.effect: null
        }

        // Spindle dot: center, 2.5% of parent viewport size
        Rectangle {
            id: spindle
            width: vinylRoot.parent ? vinylRoot.parent.width * 0.025 : 25
            height: width
            radius: width / 2
            anchors.centerIn: parent

            // Radial gradient: #ddd center to #888 edge
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#dddddd" }
                GradientStop { position: 0.5; color: "#bbbbbb" }
                GradientStop { position: 1.0; color: "#888888" }
            }
        }

        // Song title: bottom 25%
        Text {
            id: songLabel
            text: vinylRoot.songText
            color: "white"
            opacity: 0.85
            font.pixelSize: vinylRoot.parent ? vinylRoot.parent.width * 0.018 : 18
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.3
            width: parent.width * 0.7
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.25 - implicitHeight / 2
        }
    }
}
