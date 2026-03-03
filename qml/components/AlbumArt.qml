import QtQuick

Item {
    id: artRoot
    anchors.fill: parent

    property bool playing: false
    property url artSource: ""

    // Track which layer is active: true = layerA, false = layerB
    property bool activeIsA: true
    property bool transitioning: false
    property string pendingDirection: ""
    property bool waitingForLoad: false
    property bool flippingOut: false
    property url pendingUrl: ""

    // Called immediately on swipe — starts flip-out before API responds
    function beginTransition(direction) {
        if (transitioning) return;
        transitioning = true;
        pendingDirection = direction;
        pendingUrl = "";
        flippingOut = true;

        // Sync incoming layer's spin angle so it continues seamlessly
        var current = activeIsA ? layerA : layerB;
        var incoming = activeIsA ? layerB : layerA;
        incoming.rotAngle = current.rotAngle;
        incoming.lastSpinTime = 0;

        flipOutAnim.target = current;
        flipOutAnim.to = (direction === "left") ? -90 : 90;
        flipOutAnim.start();
    }

    // Called when trackChanged fires with new art URL
    function slideTransition(newUrl, direction) {
        if (!transitioning) {
            beginTransition(direction);
        }
        pendingUrl = newUrl;

        if (!flippingOut) {
            loadAndFlipIn();
        }
    }

    function loadAndFlipIn() {
        var incoming = activeIsA ? layerB : layerA;
        incoming.source = pendingUrl;
        waitingForLoad = false;

        if (incoming.status === Image.Ready) {
            startFlipIn();
        } else {
            waitingForLoad = true;
        }
    }

    function startFlipIn() {
        var incoming = activeIsA ? layerB : layerA;
        var dir = pendingDirection;

        incoming.flipAngle = (dir === "left") ? 90 : -90;
        incoming.visible = true;
        incoming.opacity = 1;

        flipInAnim.target = incoming;
        flipInAnim.from = incoming.flipAngle;
        flipInAnim.to = 0;
        flipInAnim.start();
    }

    function finishTransition() {
        var oldCurrent = activeIsA ? layerA : layerB;
        var newCurrent = activeIsA ? layerB : layerA;

        oldCurrent.visible = false;
        oldCurrent.opacity = 0;
        oldCurrent.flipAngle = 0;
        newCurrent.flipAngle = 0;
        // Don't reset rotAngle — spin continues seamlessly

        activeIsA = !activeIsA;
        transitioning = false;
    }

    // Flip-out animation (current record leaves)
    NumberAnimation {
        id: flipOutAnim
        property: "flipAngle"
        duration: 300
        easing.type: Easing.InQuad
        onFinished: {
            artRoot.flippingOut = false;
            if (artRoot.pendingUrl.toString() !== "") {
                artRoot.loadAndFlipIn();
            }
        }
    }

    // Flip-in animation (new record arrives)
    NumberAnimation {
        id: flipInAnim
        property: "flipAngle"
        duration: 300
        easing.type: Easing.OutQuad
        onFinished: artRoot.finishTransition()
    }

    // Layer A
    Image {
        id: layerA
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectCrop
        visible: true
        opacity: 1
        source: ""
        cache: true
        asynchronous: true
        property real rotAngle: 0
        property real flipAngle: 0
        property real lastSpinTime: 0

        transform: [
            Scale { origin.x: layerA.width/2; origin.y: layerA.height/2; xScale: 1.05; yScale: 1.05 },
            Rotation { origin.x: layerA.width/2; origin.y: layerA.height/2; angle: layerA.rotAngle },
            Rotation {
                origin.x: layerA.width/2; origin.y: layerA.height/2
                axis { x: 0; y: 1; z: 0 }
                angle: layerA.flipAngle
            }
        ]

        // Spin keeps running during transitions — both layers spin together
        Timer {
            interval: 16
            repeat: true
            running: (artRoot.activeIsA || artRoot.transitioning) && artRoot.playing
            onTriggered: {
                var now = Date.now();
                if (layerA.lastSpinTime > 0) {
                    var dt = now - layerA.lastSpinTime;
                    layerA.rotAngle = (layerA.rotAngle + 360 * dt / 30000) % 360;
                }
                layerA.lastSpinTime = now;
            }
            onRunningChanged: {
                if (running) layerA.lastSpinTime = Date.now();
            }
        }

        onStatusChanged: {
            if (status === Image.Ready && artRoot.waitingForLoad) {
                artRoot.waitingForLoad = false;
                artRoot.startFlipIn();
            }
        }
    }

    // Layer B
    Image {
        id: layerB
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
        opacity: 0
        source: ""
        cache: true
        asynchronous: true
        property real rotAngle: 0
        property real flipAngle: 0
        property real lastSpinTime: 0

        transform: [
            Scale { origin.x: layerB.width/2; origin.y: layerB.height/2; xScale: 1.05; yScale: 1.05 },
            Rotation { origin.x: layerB.width/2; origin.y: layerB.height/2; angle: layerB.rotAngle },
            Rotation {
                origin.x: layerB.width/2; origin.y: layerB.height/2
                axis { x: 0; y: 1; z: 0 }
                angle: layerB.flipAngle
            }
        ]

        Timer {
            interval: 16
            repeat: true
            running: (!artRoot.activeIsA || artRoot.transitioning) && artRoot.playing
            onTriggered: {
                var now = Date.now();
                if (layerB.lastSpinTime > 0) {
                    var dt = now - layerB.lastSpinTime;
                    layerB.rotAngle = (layerB.rotAngle + 360 * dt / 30000) % 360;
                }
                layerB.lastSpinTime = now;
            }
            onRunningChanged: {
                if (running) layerB.lastSpinTime = Date.now();
            }
        }

        onStatusChanged: {
            if (status === Image.Ready && artRoot.waitingForLoad) {
                artRoot.waitingForLoad = false;
                artRoot.startFlipIn();
            }
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
    }
}
