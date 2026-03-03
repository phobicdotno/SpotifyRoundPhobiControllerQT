import QtQuick
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
        radius: width / 2
        clip: true
        color: "black"

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
                text: "Start playing\non Spotify"
                color: "#404040"
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }

        // --- Vinyl Center ---
        VinylCenter {
            id: vinylCenter
            artistText: Spotify.artist
            songText: Spotify.trackName
            z: 8
        }

        // --- Progress Ring ---
        ProgressRing {
            id: progressRing
            playing: Spotify.isPlaying
            currentProgressMs: Spotify.progressMs
            currentDurationMs: Spotify.durationMs
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

        // Long-press state
        property bool longPressTriggered: false

        Timer {
            id: singleTapTimer
            interval: 300
            repeat: false
            onTriggered: {
                viewport.waitingForDoubleTap = false;
                // Single tap (outside center only — center taps are ignored on single)
                if (!isCenterTap(viewport.lastTapX, viewport.lastTapY)) {
                    onSingleTap();
                }
                viewport.lastTapTime = 0;
            }
        }

        Timer {
            id: longPressTimer
            interval: 1800
            repeat: false
            onTriggered: {
                viewport.longPressTriggered = true;
                fadeOutAndClose.start();
            }
        }

        // Fade out animation for long-press close
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

            onPressed: function(mouse) {
                viewport.pointerDownX = mouse.x;
                viewport.pointerDownY = mouse.y;
                viewport.pointerDownTime = Date.now();
                viewport.pointerActive = true;
                viewport.longPressTriggered = false;
                longPressTimer.restart();
            }

            onPositionChanged: function(mouse) {
                if (!viewport.pointerActive) return;

                // Cancel long-press if moved too far
                var moved = Math.abs(mouse.x - viewport.pointerDownX) +
                            Math.abs(mouse.y - viewport.pointerDownY);
                if (moved > 50) {
                    longPressTimer.stop();
                }
            }

            onReleased: function(mouse) {
                if (!viewport.pointerActive) return;
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
                        // Swipe left -> next track
                        Spotify.nextTrack();
                    } else {
                        // Swipe right -> prev track
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

                // Tap detection (< 200ms, < 15px movement)
                if (dt < 200 && dist < 15) {
                    handleTap(mouse.x, mouse.y);
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
                spawnBurst(bx, by, newState ? "shuffle" : "sequential");
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
