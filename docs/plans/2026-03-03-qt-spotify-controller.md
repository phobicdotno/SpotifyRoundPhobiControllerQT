# SpotifyRoundPhobiControllerQT Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite the SpotifyRoundPhobiController as a native C++ Qt6/QML app with identical UI and behavior.

**Architecture:** C++ backend (SpotifyAuth + SpotifyAPI classes using QNetworkAccessManager) exposes Q_PROPERTY/Q_INVOKABLE to QML frontend. QML handles the circular viewport, rotating album art, slide transitions, gesture recognition, and all feedback animations. OAuth callback handled by embedded QTcpServer.

**Tech Stack:** C++17, Qt6 (Quick, Network, Gui), CMake, QML

**Reference project:** `C:\DevOps\SpotifyRoundPhobiController\` (Python/web version — the source of truth for all behavior)

---

### Task 0: Install Build Toolchain

**This machine has no C++ compiler, CMake, or Qt6 installed. Install everything first.**

**Step 1: Install Visual Studio Build Tools**

Run:
```
winget install Microsoft.VisualStudio.2022.BuildTools --silent --override "--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.CMake.Project --includeRecommended"
```
This installs MSVC compiler, CMake, and Ninja.

**Step 2: Install Qt6**

Run:
```
winget install Qt.QtDesignStudio --accept-package-agreements --accept-source-agreements
```

If Qt6 is not available via winget, use the Qt online installer:
- Download from https://www.qt.io/download-qt-installer
- Install Qt 6.7+ with components: Desktop (MSVC 2022 64-bit), Qt Quick, Qt Network
- Default install path: `C:\Qt\6.7.x\msvc2022_64\`

**Step 3: Verify tools work**

Open "Developer Command Prompt for VS 2022" or "x64 Native Tools Command Prompt" and run:
```
cl /?
cmake --version
```

**Step 4: Set Qt6 path for CMake**

Set environment variable:
```
set CMAKE_PREFIX_PATH=C:\Qt\6.7.x\msvc2022_64
```
(Adjust version to match your installation)

---

### Task 1: Project Scaffold + CMake + Empty Window

**Files:**
- Create: `CMakeLists.txt`
- Create: `src/main.cpp`
- Create: `qml/main.qml`
- Create: `.gitignore`
- Create: `README.md`

**Step 1: Create .gitignore**

```gitignore
build/
config.json
*.user
CMakeUserPresets.json
.cache/
```

**Step 2: Create CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.21)
project(SpotifyRoundPhobiControllerQT VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Gui)

qt_add_executable(SpotifyController
    src/main.cpp
)

qt_add_qml_module(SpotifyController
    URI SpotifyController
    VERSION 1.0
    QML_FILES
        qml/main.qml
)

target_link_libraries(SpotifyController PRIVATE
    Qt6::Quick
    Qt6::Network
    Qt6::Gui
)
```

**Step 3: Create src/main.cpp**

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QScreen>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("SpotifyController");

    QQmlApplicationEngine engine;
    engine.loadFromModule("SpotifyController", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
```

**Step 4: Create qml/main.qml**

```qml
import QtQuick
import QtQuick.Window

Window {
    id: root
    width: 1000
    height: 1000
    visible: true
    flags: Qt.FramelessWindowHint | Qt.Window
    color: "black"
    title: "Spotify Controller"

    Rectangle {
        anchors.fill: parent
        color: "black"

        Rectangle {
            id: viewport
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            radius: width / 2
            clip: true
            color: "#111"

            Text {
                anchors.centerIn: parent
                text: "SpotifyController\nQt6 + QML"
                color: "#1DB954"
                font.pixelSize: 32
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Escape to close
    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }
}
```

**Step 5: Build and test**

```bash
cd C:\DevOps\SpotifyRoundPhobiControllerQT
cmake -B build -G Ninja -DCMAKE_PREFIX_PATH=C:\Qt\6.7.x\msvc2022_64
cmake --build build
build\SpotifyController.exe
```

Expected: 1000x1000 frameless black window with green "SpotifyController Qt6 + QML" text in a circle.

**Step 6: Init git and commit**

```bash
cd C:\DevOps\SpotifyRoundPhobiControllerQT
git init
git add CMakeLists.txt src/main.cpp qml/main.qml .gitignore README.md
git commit -m "feat: project scaffold with empty frameless window"
```

---

### Task 2: SpotifyAuth — PKCE OAuth + Token Management

**Files:**
- Create: `src/spotifyauth.h`
- Create: `src/spotifyauth.cpp`
- Modify: `CMakeLists.txt` (add source files)

**Step 1: Create src/spotifyauth.h**

```cpp
#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QTcpServer>
#include <QJsonObject>
#include <QTimer>

class SpotifyAuth : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool authenticated READ isAuthenticated NOTIFY authenticatedChanged)

public:
    explicit SpotifyAuth(QObject *parent = nullptr);

    bool isAuthenticated() const;
    bool ensureToken();
    QNetworkRequest authorizedRequest(const QUrl &url) const;

    Q_INVOKABLE void openAuthInBrowser();

signals:
    void authenticatedChanged();
    void authCompleted(bool success);

protected:
    QString m_clientId;
    QString m_accessToken;
    QString m_refreshToken;
    qint64 m_tokenExpiry = 0;
    QNetworkAccessManager *m_nam;

private:
    void loadConfig();
    void saveConfig();
    QString generateCodeVerifier();
    QString generateCodeChallenge(const QString &verifier);
    void exchangeCode(const QString &code);
    void refreshAccessToken();
    void startCallbackServer();
    void handleCallback(const QByteArray &requestData);

    QTcpServer *m_callbackServer = nullptr;
    QString m_codeVerifier;
    QString m_configPath;

    static constexpr const char* CLIENT_ID = "ec3a17991443408eb6f3c2bfab147cf0";
    static constexpr const char* AUTH_URL = "https://accounts.spotify.com/authorize";
    static constexpr const char* TOKEN_URL = "https://accounts.spotify.com/api/token";
    static constexpr const char* REDIRECT_URI = "http://127.0.0.1:8888/callback";
    static constexpr const char* SCOPES = "user-read-currently-playing user-modify-playback-state user-read-playback-state user-library-modify user-library-read";
};
```

**Step 2: Create src/spotifyauth.cpp**

Implement:
- `loadConfig()` / `saveConfig()`: Read/write JSON config.json next to executable (or from Python project path `C:\DevOps\SpotifyRoundPhobiController\config.json` to share tokens)
- `generateCodeVerifier()`: 128-char random base64url string
- `generateCodeChallenge()`: SHA-256 hash, base64url-encoded
- `openAuthInBrowser()`: Build auth URL with PKCE params, call `QDesktopServices::openUrl()`
- `startCallbackServer()`: QTcpServer on port 8888, parse incoming HTTP for `?code=` param
- `exchangeCode()`: POST to TOKEN_URL with code + verifier, store tokens
- `refreshAccessToken()`: POST with refresh_token grant, update tokens
- `ensureToken()`: Check expiry, refresh if needed
- `authorizedRequest()`: Return QNetworkRequest with Bearer header

The config.json path should first check `C:\DevOps\SpotifyRoundPhobiController\config.json` (shared with Python version), falling back to local.

**Step 3: Update CMakeLists.txt**

Add `src/spotifyauth.h` and `src/spotifyauth.cpp` to `qt_add_executable`.

**Step 4: Build and verify**

```bash
cmake --build build
```

Expected: Compiles without errors.

**Step 5: Commit**

```bash
git add src/spotifyauth.h src/spotifyauth.cpp CMakeLists.txt
git commit -m "feat: SpotifyAuth with PKCE OAuth and token management"
```

---

### Task 3: SpotifyAPI — Playback Control + Polling

**Files:**
- Create: `src/spotifyapi.h`
- Create: `src/spotifyapi.cpp`
- Modify: `CMakeLists.txt`
- Modify: `src/main.cpp` (register type)

**Step 1: Create src/spotifyapi.h**

```cpp
#pragma once

#include "spotifyauth.h"
#include <QTimer>
#include <QUrl>

class SpotifyAPI : public SpotifyAuth
{
    Q_OBJECT

    // Properties for QML binding
    Q_PROPERTY(QString trackId READ trackId NOTIFY trackChanged)
    Q_PROPERTY(QString trackName READ trackName NOTIFY trackChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY trackChanged)
    Q_PROPERTY(QUrl artUrl READ artUrl NOTIFY trackChanged)
    Q_PROPERTY(bool isPlaying READ isPlaying NOTIFY playStateChanged)
    Q_PROPERTY(bool shuffle READ shuffle NOTIFY shuffleChanged)
    Q_PROPERTY(int volume READ volume NOTIFY volumeChanged)
    Q_PROPERTY(int progressMs READ progressMs NOTIFY progressChanged)
    Q_PROPERTY(int durationMs READ durationMs NOTIFY progressChanged)
    Q_PROPERTY(bool hasPlayback READ hasPlayback NOTIFY playbackAvailableChanged)

public:
    explicit SpotifyAPI(QObject *parent = nullptr);

    QString trackId() const;
    QString trackName() const;
    QString artist() const;
    QUrl artUrl() const;
    bool isPlaying() const;
    bool shuffle() const;
    int volume() const;
    int progressMs() const;
    int durationMs() const;
    bool hasPlayback() const;

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void nextTrack();
    Q_INVOKABLE void prevTrack();
    Q_INVOKABLE void toggleShuffle();
    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void saveTrack();
    Q_INVOKABLE void closeApp();

signals:
    void trackChanged(const QString &direction);
    void playStateChanged();
    void shuffleChanged();
    void volumeChanged();
    void progressChanged();
    void playbackAvailableChanged();
    void trackSaved(bool alreadySaved);
    void shuffleToggled(bool newState);

private slots:
    void poll();

private:
    void apiRequest(const QString &method, const QString &path,
                    std::function<void(const QJsonObject&)> callback = nullptr,
                    const QJsonObject &body = {});

    QTimer *m_pollTimer;
    QString m_trackId;
    QString m_trackName;
    QString m_artist;
    QUrl m_artUrl;
    bool m_isPlaying = false;
    bool m_shuffle = false;
    int m_volume = 50;
    int m_progressMs = 0;
    int m_durationMs = 1;
    bool m_hasPlayback = false;
};
```

**Step 2: Create src/spotifyapi.cpp**

Implement:
- `poll()`: GET /me/player, parse JSON, update properties, emit signals on changes. Detect track changes by comparing trackId.
- `play()` / `pause()`: PUT /me/player/play or /pause
- `nextTrack()` / `prevTrack()`: POST /me/player/next or /previous
- `toggleShuffle()`: GET current state, PUT /me/player/shuffle?state=opposite
- `setVolume(int)`: PUT /me/player/volume?volume_percent=N
- `saveTrack()`: Check /me/tracks/contains, then PUT /me/tracks?ids=trackId
- `closeApp()`: QGuiApplication::quit()
- `apiRequest()`: Helper that uses ensureToken(), sends request via QNetworkAccessManager, handles 401 retry and 429 rate limiting

Poll timer: 2000ms interval, starts automatically.

**Step 3: Update main.cpp — register SpotifyAPI as QML singleton**

```cpp
#include "spotifyapi.h"
// In main():
qmlRegisterSingletonType<SpotifyAPI>("SpotifyController", 1, 0, "Spotify",
    [](QQmlEngine *, QJSEngine *) -> QObject* { return new SpotifyAPI; });
```

**Step 4: Update CMakeLists.txt**

Add `src/spotifyapi.h` and `src/spotifyapi.cpp` to sources.

**Step 5: Build and verify**

```bash
cmake --build build
```

Expected: Compiles. Can test by temporarily adding debug output in poll().

**Step 6: Commit**

```bash
git add src/spotifyapi.h src/spotifyapi.cpp src/main.cpp CMakeLists.txt
git commit -m "feat: SpotifyAPI with playback control and polling"
```

---

### Task 4: SetupView — Auth Waiting Screen

**Files:**
- Create: `qml/SetupView.qml`
- Modify: `qml/main.qml`
- Modify: `CMakeLists.txt` (add QML file)

**Step 1: Create qml/SetupView.qml**

Circular clip-path view matching the Python version's setup screen:
- Black background with circle clip
- "Spotify Controller" title in Spotify green (#1DB954), 32px bold
- "Waiting for authorization..." subtitle in #b3b3b3
- "A browser tab should have opened..." hint in #666
- "Retry Authorization" button: Spotify green, rounded, calls Spotify.openAuthInBrowser()
- Polls Spotify.authenticated every 2s, emits signal when auth completes

**Step 2: Update main.qml**

- Import SpotifyController 1.0
- Show SetupView when !Spotify.authenticated, PlayerView (placeholder) when authenticated
- Use Loader or state-based visibility

**Step 3: Update CMakeLists.txt**

Add `qml/SetupView.qml` to QML_FILES.

**Step 4: Build and test**

Expected: On launch (with no config.json), shows setup screen. Browser opens for auth. After authorizing, switches to player.

**Step 5: Commit**

```bash
git add qml/SetupView.qml qml/main.qml CMakeLists.txt
git commit -m "feat: setup view with auth flow"
```

---

### Task 5: Album Art — Rotating Vinyl + Slide Transitions

**Files:**
- Create: `qml/components/AlbumArt.qml`
- Modify: `CMakeLists.txt`

**Step 1: Create qml/components/AlbumArt.qml**

Two Image items (layer A and B) for crossfade/slide transitions:

```qml
Item {
    id: albumArt
    property url artUrl: ""
    property bool playing: false
    property string slideDirection: "left"

    // Image A
    Image {
        id: artA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: albumArt.artUrl
        visible: true

        RotationAnimation on rotation {
            id: spinA
            from: artA.rotation
            to: artA.rotation + 360
            duration: 30000
            loops: Animation.Infinite
            running: albumArt.playing
        }

        // Scale slightly to avoid corner gaps during rotation
        transform: Scale { xScale: 1.05; yScale: 1.05; origin.x: artA.width/2; origin.y: artA.height/2 }
    }

    // Image B (for transitions)
    Image {
        id: artB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        visible: false
        // Same rotation setup
    }

    // Slide transition logic:
    // On artUrl change: load new URL into inactive image,
    // animate active out (translateX) and incoming in (translateX), 400ms
    // Then swap active/inactive
}
```

Key behaviors to match:
- 30-second full rotation (matching CSS `animation: spin 30s linear infinite`)
- Scale 1.05 to avoid white corners during rotation
- Slide-out-left / slide-in-right for "next" (400ms ease-in-out)
- Slide-out-right / slide-in-left for "prev"
- Animation pauses when not playing

**Step 2: Update CMakeLists.txt**

Add to QML_FILES.

**Step 3: Build and test**

Expected: Album art rotates when playing, stops when paused. Track changes show slide transition.

**Step 4: Commit**

```bash
git add qml/components/AlbumArt.qml CMakeLists.txt
git commit -m "feat: rotating album art with slide transitions"
```

---

### Task 6: Vinyl Center + Progress Ring

**Files:**
- Create: `qml/components/VinylCenter.qml`
- Create: `qml/components/ProgressRing.qml`
- Modify: `CMakeLists.txt`

**Step 1: Create qml/components/VinylCenter.qml**

Centered circle, 33% of viewport:
- Radial gradient: rgba(0,0,0,0.7) center → rgba(0,0,0,0.5) edge
- 1px border rgba(255,255,255,0.1)
- Artist name: top 25%, uppercase, letter-spacing 0.15em, 2.2vmin font, bold
- Spindle dot: center, 2.5vmin, radial gradient gray
- Song title: bottom 25%, 1.8vmin font, opacity 0.85

**Step 2: Create qml/components/ProgressRing.qml**

Canvas item matching the SVG progress ring:
- Same position as vinyl center (33vmin circle)
- Background arc: rgba(255,255,255,0.1), stroke-width 0.75
- Progress arc: rgba(255,255,255,0.9), stroke-width 0.75
- Rotated -90deg so progress starts from top
- Smooth interpolation: QML Timer at 60fps interpolates between polls
- Properties: progress (0.0-1.0)

**Step 3: Update CMakeLists.txt**

**Step 4: Build and test**

Expected: Vinyl center label shows artist/song. Progress ring tracks playback.

**Step 5: Commit**

```bash
git add qml/components/VinylCenter.qml qml/components/ProgressRing.qml CMakeLists.txt
git commit -m "feat: vinyl center label and progress ring"
```

---

### Task 7: Gesture Engine

**Files:**
- Modify: `qml/main.qml` or create `qml/PlayerView.qml`
- Modify: `CMakeLists.txt`

**Step 1: Create qml/PlayerView.qml**

Full player view with gesture handling using MultiPointTouchArea:

Gesture mapping (must match Python version exactly):
| Gesture | Detection | Action |
|---------|-----------|--------|
| Single tap (outside center) | dt<200ms, dist<15px, 300ms debounce | play/pause |
| Double-tap (center) | Two taps <300ms apart, inside 16.5% radius | like (heart burst) |
| Double-tap (outside) | Two taps <300ms apart, outside center | toggle shuffle |
| Swipe left | dx>50px, dx>2*dy, dt<500ms | next track |
| Swipe right | same, positive dx | prev track |
| Swipe up/down | dy>50px, dy>2*dx, dt<500ms | show track toast |
| Two-finger vertical | 2 touch points, track avgY delta | volume (3px per 1%) |
| Long-press 1.8s | Hold without moving >50px | fade + close |
| Escape | Key press | close |

Implementation approach:
- MultiPointTouchArea fills the circular viewport
- Track touch start position, time, and pointer count
- onReleased: compute dx, dy, dt, dist → classify gesture
- Timer for 300ms tap debounce (single vs double)
- Timer for 1800ms long-press detection
- Two-finger: track average Y on move, compute volume delta

Center detection: point distance from center <= viewport_size * 0.165

**Step 2: Wire gestures to Spotify API calls**

Each gesture calls the appropriate Spotify.xxx() method and triggers the corresponding feedback animation.

**Step 3: Build and test**

Test each gesture manually. Expected: All gestures trigger correct Spotify actions.

**Step 4: Commit**

```bash
git add qml/PlayerView.qml CMakeLists.txt
git commit -m "feat: gesture engine with all touch interactions"
```

---

### Task 8: Feedback Animations

**Files:**
- Create: `qml/components/FeedbackOverlay.qml`
- Create: `qml/components/TrackToast.qml`
- Create: `qml/components/VolumeOverlay.qml`
- Modify: `CMakeLists.txt`

**Step 1: Create FeedbackOverlay.qml**

Reusable overlay for play/pause/heart/shuffle burst:
- Centered in viewport
- Scale animation: 0.5→1.1→1.0 (600ms)
- Opacity animation: 0→1→1→0 (600ms)
- Heart burst variant: scale 0.3→1.2→2.5, opacity 0.5→0 (800ms), positioned at tap coordinates
- Shuffle/sequential burst: same as heart but with different SVG icon
- Play icon: triangle (polygon)
- Pause icon: two rounded rectangles
- Heart: SVG path
- Shuffle: crossing arrows SVG path
- Sequential: right arrow SVG path

All SVGs match the paths from the Python version's app.js exactly.

**Step 2: Create TrackToast.qml**

Toast matching the Python version:
- Positioned: bottom 120px, centered horizontally
- Background: rgba(0,0,0,0.65), border-radius 16px, backdrop blur
- Track name: white, 22px, bold
- Artist: #b3b3b3, 16px
- Animation: fadeInOut 3s (0% opacity:0 → 10% opacity:1 → 80% opacity:1 → 100% opacity:0)
- Max-width 80%
- Note: Qt Quick doesn't have backdrop-filter; use a blurred ShaderEffect or just the semi-transparent background

**Step 3: Create VolumeOverlay.qml**

Volume arc indicator:
- SVG arc (Canvas): background ring rgba(255,255,255,0.2), foreground #1DB954
- Both stroke-width 8, radius 80
- Percentage text: white, 28px, bold
- Same feedbackPop animation as other overlays
- Duration: 800ms

**Step 4: Update CMakeLists.txt**

**Step 5: Build and test**

Test by tapping/swiping. Expected: All feedback animations match the Python version.

**Step 6: Commit**

```bash
git add qml/components/FeedbackOverlay.qml qml/components/TrackToast.qml qml/components/VolumeOverlay.qml CMakeLists.txt
git commit -m "feat: feedback animations — play/pause, heart, shuffle, toast, volume"
```

---

### Task 9: Display Detection + Window Positioning

**Files:**
- Modify: `src/main.cpp`

**Step 1: Add square display detection**

```cpp
// In main(), before engine.load():
QScreen *targetScreen = nullptr;
for (QScreen *screen : QGuiApplication::screens()) {
    QSize size = screen->size();
    if (size.width() == size.height() && size.width() <= 1080) {
        targetScreen = screen;
        break;
    }
}
```

**Step 2: Position window on target screen**

Pass screen geometry to QML via context property, or position the window from C++ after it's created:
```cpp
if (targetScreen) {
    QRect geo = targetScreen->geometry();
    // Set window position and size via root object
}
```

**Step 3: Build and test**

Test with single monitor (window at 0,0) and if possible with the round display connected.

**Step 4: Commit**

```bash
git add src/main.cpp
git commit -m "feat: auto-detect square display and position window"
```

---

### Task 10: Integration + Polish

**Files:**
- Modify: `qml/main.qml` — wire everything together
- Modify: `qml/PlayerView.qml` — integrate all components
- Copy: `screenshot.png` from Python project

**Step 1: Wire all components in PlayerView**

- AlbumArt bound to Spotify.artUrl, Spotify.isPlaying
- VinylCenter bound to Spotify.artist, Spotify.trackName
- ProgressRing bound to Spotify.progressMs, Spotify.durationMs
- Gestures trigger Spotify methods + feedback animations
- TrackToast shown on Spotify.trackChanged signal
- No-playback overlay when !Spotify.hasPlayback

**Step 2: Smooth progress interpolation**

Add a QML Timer (16ms interval) that interpolates progress between polls:
```qml
Timer {
    interval: 16
    running: Spotify.isPlaying
    repeat: true
    onTriggered: {
        var elapsed = Date.now() - lastPollTime
        var current = progressAtPoll + elapsed
        progressRing.progress = Math.min(current, Spotify.durationMs) / Spotify.durationMs
    }
}
```

**Step 3: Copy screenshot and create README**

Copy screenshot.png from the Python project. Update README.md with build instructions.

**Step 4: Full manual test**

- Launch app
- Verify auth flow works (shared config.json)
- Play/pause via tap
- Next/prev via swipe
- Shuffle via double-tap
- Like via center double-tap
- Volume via two-finger
- Track toast via vertical swipe
- Long-press close
- Escape close
- Progress ring tracks smoothly
- Album art rotates and slides on track change

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: complete integration — all features working"
```

---

### Task 11: GitHub Repo + Push

**Step 1: Create GitHub repo**

```bash
cd C:\DevOps\SpotifyRoundPhobiControllerQT
gh repo create SpotifyRoundPhobiControllerQT --private --source=. --push
```

**Step 2: Verify**

Check https://github.com/phobicdotno/SpotifyRoundPhobiControllerQT

---

## Notes

- **Shared config.json**: The Qt version reads `C:\DevOps\SpotifyRoundPhobiController\config.json` first so you don't need to re-authorize Spotify
- **Same CLIENT_ID**: Both versions use `ec3a17991443408eb6f3c2bfab147cf0`
- **Sync rule**: Any final behavioral changes should be applied to both projects and committed in both
