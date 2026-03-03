# SpotifyRoundPhobiControllerQT - Design Document

## Overview
C++ Qt6/QML port of SpotifyRoundPhobiController — a gesture-based Spotify controller for a 1000x1000px round touchscreen. Full-bleed rotating album art with vinyl record aesthetic, no visible buttons, pure gesture control.

## Architecture

```
SpotifyRoundPhobiControllerQT/
├── CMakeLists.txt
├── src/
│   ├── main.cpp                 # QGuiApplication, QML engine, display detection
│   ├── spotifyauth.h/cpp        # PKCE OAuth, token storage, refresh
│   └── spotifyapi.h/cpp         # Playback control, polling, signals to QML
├── qml/
│   ├── main.qml                 # Frameless window, view switching
│   ├── PlayerView.qml           # Circular viewport, album art, vinyl center, overlays
│   ├── SetupView.qml            # Auth waiting screen
│   └── components/
│       ├── AlbumArt.qml         # Rotating art with slide transitions
│       ├── ProgressRing.qml     # SVG-style progress arc
│       ├── VinylCenter.qml      # Label with artist/song/spindle
│       ├── FeedbackOverlay.qml  # Play/pause/heart/shuffle burst animations
│       ├── TrackToast.qml       # Track info toast (fade in/out)
│       └── VolumeOverlay.qml    # Volume arc indicator
├── config.json                  # Tokens (gitignored)
└── screenshot.png               # Same screenshot as original project
```

## C++ Backend

### SpotifyAuth (spotifyauth.h/cpp)
- PKCE OAuth2 flow using QNetworkAccessManager
- Embedded QTcpServer listening on 127.0.0.1:8888 for OAuth callback
- Token persistence via JSON file (config.json)
- Auto-refresh with QTimer before expiry
- Shared config.json with the Python version (same CLIENT_ID, same tokens)

### SpotifyAPI (spotifyapi.h/cpp, inherits SpotifyAuth)
- Q_PROPERTY bindings for QML: trackId, trackName, artist, artUrl, isPlaying, shuffle, volume, progressMs, durationMs
- Q_INVOKABLE methods: play(), pause(), nextTrack(), prevTrack(), toggleShuffle(), setVolume(int), saveTrack(QString)
- QTimer-based polling every 2 seconds
- Signals: trackChanged(), playStateChanged(), shuffleChanged(), volumeChanged()

## QML Frontend

### Circular Viewport
- layer.enabled + OpacityMask with Rectangle { radius: width/2 }

### Album Art
- Two Image items for slide transitions (A/B layers)
- RotationAnimation: 30s per revolution, pauses when not playing
- Slide transitions: NumberAnimation on x (400ms ease-in-out)

### Progress Ring
- Canvas item drawing arc with context.arc()
- Updates via requestAnimationFrame-style Timer for smooth interpolation

### Vinyl Center
- 33% of viewport, centered
- Radial gradient background (semi-transparent black)
- Artist name (uppercase, letter-spaced) top
- Spindle dot center
- Song title bottom

### Gestures (MultiPointTouchArea + TapHandler)
| Gesture | Action |
|---------|--------|
| Tap (outside center) | Play / Pause |
| Double-tap (center) | Like song (heart burst) |
| Double-tap (outside) | Toggle shuffle (icon burst) |
| Swipe left | Next track |
| Swipe right | Previous track |
| Swipe up/down | Show track info toast |
| Two-finger vertical | Volume up/down |
| Long-press 1.8s | Close app |
| Escape key | Close app |

### Feedback Animations
- Play/Pause: SVG icon with scale+opacity animation (600ms)
- Heart burst: Scale 0.3→1.2→2.5, opacity fade (800ms)
- Shuffle/sequential burst: Same animation with shuffle/arrow SVG
- Track toast: Fade in/out over 3s, blurred dark background
- Volume: Arc overlay with percentage text

## Build System
- CMake with find_package(Qt6 COMPONENTS Quick Network Gui)
- qt_add_qml_module for QML resources

## Shared Config
Both projects share config.json format and CLIENT_ID so Spotify auth works across both without re-authorizing.
