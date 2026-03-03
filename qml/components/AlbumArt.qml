import QtQuick

Item {
    id: artRoot
    anchors.fill: parent

    property bool playing: false
    property url artSource: ""

    // Track which layer is active: true = layerA, false = layerB
    property bool activeIsA: true
    property bool transitioning: false

    function slideTransition(newUrl, direction) {
        if (transitioning) return;
        transitioning = true;

        var incoming = activeIsA ? layerB : layerA;
        var current = activeIsA ? layerA : layerB;

        // Load new art on incoming layer
        incoming.source = newUrl;
        incoming.visible = true;
        incoming.opacity = 1;

        if (direction === "left") {
            // Next: current slides left out, incoming slides in from right
            current.slideOutX = 0;
            incoming.x = artRoot.width;
            currentSlideOut.to = -artRoot.width;
            incomingSlideIn.to = 0;
            incomingSlideIn.from = artRoot.width;
        } else {
            // Prev: current slides right out, incoming slides in from left
            current.slideOutX = 0;
            incoming.x = -artRoot.width;
            currentSlideOut.to = artRoot.width;
            incomingSlideIn.to = 0;
            incomingSlideIn.from = -artRoot.width;
        }

        currentSlideOut.target = current;
        incomingSlideIn.target = incoming;

        slideGroup.start();
    }

    // After transition completes
    function finishTransition() {
        var oldCurrent = activeIsA ? layerA : layerB;
        var newCurrent = activeIsA ? layerB : layerA;

        oldCurrent.visible = false;
        oldCurrent.opacity = 0;
        oldCurrent.x = 0;
        newCurrent.x = 0;

        // Reset rotation on the new current layer
        newCurrent.rotAngle = 0;

        activeIsA = !activeIsA;
        transitioning = false;
    }

    ParallelAnimation {
        id: slideGroup
        NumberAnimation {
            id: currentSlideOut
            property: "x"
            duration: 400
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            id: incomingSlideIn
            property: "x"
            duration: 400
            easing.type: Easing.InOutQuad
        }
        onFinished: artRoot.finishTransition()
    }

    // Layer A
    Image {
        id: layerA
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: parent.height
        fillMode: Image.PreserveAspectCrop
        visible: true
        opacity: 1
        source: ""
        property real rotAngle: 0
        property real slideOutX: 0
        transform: [
            Scale { origin.x: layerA.width/2; origin.y: layerA.height/2; xScale: 1.05; yScale: 1.05 },
            Rotation { origin.x: layerA.width/2; origin.y: layerA.height/2; angle: layerA.rotAngle }
        ]
        NumberAnimation on rotAngle {
            id: spinA
            from: 0; to: 360
            duration: 30000
            loops: Animation.Infinite
            running: artRoot.playing && artRoot.activeIsA && !artRoot.transitioning
        }
    }

    // Layer B
    Image {
        id: layerB
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: parent.height
        fillMode: Image.PreserveAspectCrop
        visible: false
        opacity: 0
        source: ""
        property real rotAngle: 0
        property real slideOutX: 0
        transform: [
            Scale { origin.x: layerB.width/2; origin.y: layerB.height/2; xScale: 1.05; yScale: 1.05 },
            Rotation { origin.x: layerB.width/2; origin.y: layerB.height/2; angle: layerB.rotAngle }
        ]
        NumberAnimation on rotAngle {
            id: spinB
            from: 0; to: 360
            duration: 30000
            loops: Animation.Infinite
            running: artRoot.playing && !artRoot.activeIsA && !artRoot.transitioning
        }
    }

    // Initial art load (no transition, just set directly)
    property bool firstLoad: true
    onArtSourceChanged: {
        if (artSource.toString() === "") return;
        if (firstLoad) {
            firstLoad = false;
            var active = activeIsA ? layerA : layerB;
            active.source = artSource;
            active.visible = true;
            active.opacity = 1;
        }
        // Subsequent changes handled via slideTransition() called externally
    }
}
