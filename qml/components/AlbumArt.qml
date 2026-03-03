import QtQuick
import Qt5Compat.GraphicalEffects

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

    // Shared circle mask for both layers
    Rectangle {
        id: artMask
        width: artRoot.width
        height: artRoot.height
        radius: width / 2
        visible: false
    }

    // Single VSync-driven spin for both layers
    FrameAnimation {
        running: artRoot.playing
        onTriggered: {
            var delta = 360 * frameTime / 30;  // 30s per full rotation
            if (artRoot.activeIsA || artRoot.transitioning)
                layerA.rotAngle = (layerA.rotAngle + delta) % 360;
            if (!artRoot.activeIsA || artRoot.transitioning)
                layerB.rotAngle = (layerB.rotAngle + delta) % 360;
        }
    }

    // Called immediately on swipe — starts flip-out before API responds
    function beginTransition(direction) {
        if (transitioning) return;
        transitioning = true;
        pendingDirection = direction;
        pendingUrl = "";
        flippingOut = true;

        // Sync incoming layer's spin angle for seamless handoff
        var current = activeIsA ? layerA : layerB;
        var incoming = activeIsA ? layerB : layerA;
        incoming.rotAngle = current.rotAngle;

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
        incoming.imgSource = pendingUrl;
        waitingForLoad = false;

        if (incoming.imgStatus === Image.Ready) {
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

        activeIsA = !activeIsA;
        transitioning = false;
    }

    // Flip-out animation
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

    // Flip-in animation
    NumberAnimation {
        id: flipInAnim
        property: "flipAngle"
        duration: 300
        easing.type: Easing.OutQuad
        onFinished: artRoot.finishTransition()
    }

    // Layer A — circular before 3D transforms
    Item {
        id: layerA
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        visible: true
        opacity: 1
        property real rotAngle: 0
        property real flipAngle: 0
        property alias imgSource: imgA.source
        property alias imgStatus: imgA.status

        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: artMask
        }

        transform: [
            Scale { origin.x: layerA.width/2; origin.y: layerA.height/2; xScale: 1.05; yScale: 1.05 },
            Rotation { origin.x: layerA.width/2; origin.y: layerA.height/2; angle: layerA.rotAngle },
            Rotation {
                origin.x: layerA.width/2; origin.y: layerA.height/2
                axis { x: 0; y: 1; z: 0 }
                angle: layerA.flipAngle
            }
        ]

        Image {
            id: imgA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
        }

        onImgStatusChanged: {
            if (imgStatus === Image.Ready && artRoot.waitingForLoad) {
                artRoot.waitingForLoad = false;
                artRoot.startFlipIn();
            }
        }
    }

    // Layer B
    Item {
        id: layerB
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        visible: false
        opacity: 0
        property real rotAngle: 0
        property real flipAngle: 0
        property alias imgSource: imgB.source
        property alias imgStatus: imgB.status

        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: artMask
        }

        transform: [
            Scale { origin.x: layerB.width/2; origin.y: layerB.height/2; xScale: 1.05; yScale: 1.05 },
            Rotation { origin.x: layerB.width/2; origin.y: layerB.height/2; angle: layerB.rotAngle },
            Rotation {
                origin.x: layerB.width/2; origin.y: layerB.height/2
                axis { x: 0; y: 1; z: 0 }
                angle: layerB.flipAngle
            }
        ]

        Image {
            id: imgB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
        }

        onImgStatusChanged: {
            if (imgStatus === Image.Ready && artRoot.waitingForLoad) {
                artRoot.waitingForLoad = false;
                artRoot.startFlipIn();
            }
        }
    }

    // Initial art load
    property bool firstLoad: true
    onArtSourceChanged: {
        if (artSource.toString() === "") return;
        if (firstLoad) {
            firstLoad = false;
            var active = activeIsA ? layerA : layerB;
            active.imgSource = artSource;
            active.visible = true;
            active.opacity = 1;
        }
    }
}
