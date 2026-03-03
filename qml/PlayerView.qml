import QtQuick
import Qt5Compat.GraphicalEffects
import "components"

Item {
    id: playerRoot
    anchors.fill: parent

    // Public function for showing track toast from outside
    function showTrackToast(name, artist) {
        trackToast.show(name, artist);
    }

    // --- Circular viewport ---
    Rectangle {
        id: viewport
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        color: "black"
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: viewport.width
                height: viewport.height
                radius: width / 2
            }
        }

        // --- Album Art ---
        AlbumArt {
            id: albumArt
            anchors.fill: parent
            playing: Spotify.isPlaying
        }

        // --- No-playback state ---
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            visible: !Spotify.hasPlayback
            z: 5

            Text {
                anchors.centerIn: parent
                text: "Tap to play"
                color: "#808080"
                font.pixelSize: 28
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }

        // --- Vinyl Center ---
        VinylCenter {
            id: vinylCenter
            artistText: Spotify.artist
            songText: Spotify.trackName
            visible: Spotify.hasPlayback
            z: 8
        }

        // --- Progress Ring ---
        ProgressRing {
            id: progressRing
            playing: Spotify.isPlaying
            currentProgressMs: Spotify.progressMs
            currentDurationMs: Spotify.durationMs
            visible: Spotify.hasPlayback
            z: 9
        }

        // --- Feedback Overlay (play/pause) ---
        FeedbackOverlay {
            id: pauseFeedback
            mode: "pause"
        }

        FeedbackOverlay {
            id: playFeedback
            mode: "play"
        }

        // --- Track Toast ---
        TrackToast {
            id: trackToast
        }

        // --- Volume Overlay ---
        VolumeOverlay {
            id: volumeOverlay
        }

        // --- Heart burst container (dynamic items) ---
        Item {
            id: burstContainer
            anchors.fill: parent
            z: 30
        }

        // ============================================================
        //  GESTURE ENGINE
        // ============================================================

        // Gesture state
        property real pointerDownX: 0
        property real pointerDownY: 0
        property real pointerDownTime: 0
        property bool pointerActive: false

        property real lastTapTime: 0
        property real lastTapX: 0
        property real lastTapY: 0
        property bool waitingForDoubleTap: false

        // Two-finger volume state
        property bool twoFingerActive: false
        property real twoFingerStartY: 0
        property int twoFingerStartVol: 0

        // Long-press drag state
        property bool longPressTriggered: false
        property bool draggingWindow: false
        property bool hasDragged: false
        property real dragStartScreenX: 0
        property real dragStartScreenY: 0
        property real windowStartX: 0
        property real windowStartY: 0

        Timer {
            id: singleTapTimer
            interval: 300
            repeat: false
            onTriggered: {
                viewport.waitingForDoubleTap = false;
                // When no playback, any tap starts playing
                // Otherwise, only outside-center taps toggle play/pause
                if (!Spotify.hasPlayback || !viewport.isCenterTap(viewport.lastTapX, viewport.lastTapY)) {
                    viewport.onSingleTap();
                }
                viewport.lastTapTime = 0;
            }
        }

        Timer {
            id: longPressTimer
            interval: 1000
            repeat: false
            onTriggered: {
                viewport.longPressTriggered = true;
                viewport.draggingWindow = true;
                // Store the screen-space pointer position and window position
                var global = gestureArea.mapToGlobal(viewport.pointerDownX, viewport.pointerDownY);
                viewport.dragStartScreenX = global.x;
                viewport.dragStartScreenY = global.y;
                viewport.windowStartX = playerRoot.Window.window.x;
                viewport.windowStartY = playerRoot.Window.window.y;
                // Start the close timer — will fire if held 3s total with no movement
                closeTimer.restart();
            }
        }

        Timer {
            id: closeTimer
            interval: 2000  // 2s after drag mode (1s + 2s = 3s total hold)
            repeat: false
            onTriggered: {
                // Only close if still holding and never dragged
                if (viewport.draggingWindow && !viewport.hasDragged) {
                    viewport.draggingWindow = false;
                    viewport.pointerActive = false;
                    fadeOutAndClose.start();
                }
            }
        }

        SequentialAnimation {
            id: fadeOutAndClose
            NumberAnimation {
                target: playerRoot; property: "opacity"
                to: 0.5; duration: 200
                easing.type: Easing.InQuad
            }
            ScriptAction { script: Spotify.closeApp() }
        }

        function isCenterTap(x, y) {
            var cx = viewport.width / 2;
            var cy = viewport.height / 2;
            var radius = Math.min(viewport.width, viewport.height) * 0.165;
            var dx = x - cx;
            var dy = y - cy;
            return (dx * dx + dy * dy) <= (radius * radius);
        }

        function onSingleTap() {
            if (Spotify.isPlaying) {
                Spotify.pause();
                pauseFeedback.show();
            } else {
                Spotify.play();
                playFeedback.show();
            }
        }

        function onDoubleTapCenter(x, y) {
            if (!Spotify.trackId) return;
            Spotify.saveTrack();
            spawnBurst(x, y, "heart");
        }

        function onDoubleTapOutside(x, y) {
            Spotify.toggleShuffle();
            // shuffleToggled signal will fire with newState
        }

        function spawnBurst(x, y, type) {
            var component = Qt.createComponent("components/BurstEffect.qml");
            if (component.status === Component.Ready) {
                var burst = component.createObject(burstContainer, {
                    "burstX": x,
                    "burstY": y,
                    "burstType": type
                });
                burst.start();
            }
        }

        // --- Mouse handling (primary input) ---
        MouseArea {
            id: gestureArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: false
            z: 100  // Above all overlays

            onPressed: function(mouse) {
                viewport.pointerDownX = mouse.x;
                viewport.pointerDownY = mouse.y;
                viewport.pointerDownTime = Date.now();
                viewport.pointerActive = true;
                viewport.longPressTriggered = false;
                viewport.hasDragged = false;
                longPressTimer.restart();
            }

            onPositionChanged: function(mouse) {
                if (!viewport.pointerActive) return;

                if (viewport.draggingWindow) {
                    // Any movement cancels the close timer
                    if (!viewport.hasDragged) {
                        viewport.hasDragged = true;
                        closeTimer.stop();
                    }
                    // Move the window by the delta from drag start
                    var global = gestureArea.mapToGlobal(mouse.x, mouse.y);
                    var win = playerRoot.Window.window;
                    win.x = viewport.windowStartX + (global.x - viewport.dragStartScreenX);
                    win.y = viewport.windowStartY + (global.y - viewport.dragStartScreenY);
                    return;
                }

                // Cancel long-press if moved too far before it triggers
                var moved = Math.abs(mouse.x - viewport.pointerDownX) +
                            Math.abs(mouse.y - viewport.pointerDownY);
                if (moved > 50) {
                    longPressTimer.stop();
                }
            }

            onReleased: function(mouse) {
                if (!viewport.pointerActive) return;
                if (viewport.draggingWindow) {
                    closeTimer.stop();
                    viewport.draggingWindow = false;
                    viewport.pointerActive = false;
                    return;
                }
                if (viewport.longPressTriggered) {
                    viewport.pointerActive = false;
                    return;
                }

                longPressTimer.stop();

                var dx = mouse.x - viewport.pointerDownX;
                var dy = mouse.y - viewport.pointerDownY;
                var dt = Date.now() - viewport.pointerDownTime;
                var dist = Math.sqrt(dx * dx + dy * dy);

                viewport.pointerActive = false;

                // Swipe detection - horizontal
                if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 2 && dt < 500) {
                    if (dx < 0) {
                        // Swipe left -> next track: flip out immediately, then API
                        albumArt.beginTransition("left");
                        Spotify.nextTrack();
                    } else {
                        // Swipe right -> prev track: flip out immediately, then API
                        albumArt.beginTransition("right");
                        Spotify.prevTrack();
                    }
                    return;
                }

                // Swipe detection - vertical (show track info)
                if (Math.abs(dy) > 50 && Math.abs(dy) > Math.abs(dx) * 2 && dt < 500) {
                    if (Spotify.trackId) {
                        trackToast.show(Spotify.trackName, Spotify.artist);
                    }
                    return;
                }

                // Tap detection (< 400ms, < 20px movement)
                if (dt < 400 && dist < 20) {
                    viewport.handleTap(mouse.x, mouse.y);
                }
            }
        }

        // Multi-touch handling
        MultiPointTouchArea {
            anchors.fill: parent
            minimumTouchPoints: 2
            maximumTouchPoints: 2
            z: 1  // Above MouseArea for two-finger only

            property var touchStartY: ({})
            property real initialAvgY: 0

            onPressed: function(touchPoints) {
                if (touchPoints.length >= 2) {
                    // Cancel any single-finger gesture
                    longPressTimer.stop();
                    viewport.pointerActive = false;

                    var avgY = 0;
                    for (var i = 0; i < touchPoints.length; i++) {
                        avgY += touchPoints[i].y;
                    }
                    avgY /= touchPoints.length;

                    viewport.twoFingerActive = true;
                    viewport.twoFingerStartY = avgY;
                    viewport.twoFingerStartVol = Spotify.volume;
                }
            }

            onUpdated: function(touchPoints) {
                if (!viewport.twoFingerActive || touchPoints.length < 2) return;

                var avgY = 0;
                for (var i = 0; i < touchPoints.length; i++) {
                    avgY += touchPoints[i].y;
                }
                avgY /= touchPoints.length;

                var deltaY = viewport.twoFingerStartY - avgY;  // up = positive
                var volChange = Math.round(deltaY / 3);  // ~3px per 1%
                var newVol = Math.max(0, Math.min(100, viewport.twoFingerStartVol + volChange));

                if (newVol !== Spotify.volume) {
                    Spotify.setVolume(newVol);
                    volumeOverlay.show(newVol);
                }
            }

            onReleased: function(touchPoints) {
                viewport.twoFingerActive = false;
            }
        }

        function handleTap(x, y) {
            var now = Date.now();

            if (now - viewport.lastTapTime < 300 && viewport.waitingForDoubleTap) {
                // Double-tap
                singleTapTimer.stop();
                viewport.waitingForDoubleTap = false;
                viewport.lastTapTime = 0;

                if (isCenterTap(x, y)) {
                    onDoubleTapCenter(x, y);
                } else {
                    onDoubleTapOutside(x, y);
                }
            } else {
                // Potential single tap — wait for double-tap window
                viewport.lastTapTime = now;
                viewport.lastTapX = x;
                viewport.lastTapY = y;
                viewport.waitingForDoubleTap = true;
                singleTapTimer.restart();
            }
        }

        // ============================================================
        //  SIGNAL CONNECTIONS
        // ============================================================

        Connections {
            target: Spotify

            function onTrackChanged(direction) {
                // Slide transition
                if (albumArt.firstLoad) {
                    albumArt.artSource = Spotify.artUrl;
                } else {
                    albumArt.slideTransition(Spotify.artUrl, direction);
                }
            }

            function onShuffleToggled(newState) {
                // Spawn shuffle or sequential burst at last tap position
                var bx = viewport.lastTapX > 0 ? viewport.lastTapX : viewport.width / 2;
                var by = viewport.lastTapY > 0 ? viewport.lastTapY : viewport.height / 2;
                viewport.spawnBurst(bx, by, newState ? "shuffle" : "sequential");
            }

            function onTrackSaved(alreadySaved) {
                // Could show feedback for already-saved state
            }
        }
    }

    // Escape key
    Shortcut {
        sequence: "Escape"
        onActivated: Spotify.closeApp()
    }
}
