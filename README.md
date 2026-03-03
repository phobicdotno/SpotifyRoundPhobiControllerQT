# SpotifyRoundPhobiControllerQT

<p align="center">
  <img src="screenshot.png" width="400" style="border-radius: 50%;" />
</p>

C++ Qt6/QML Spotify controller designed for a 1000x1000 round touchscreen display. Features rotating vinyl album art, gesture-based playback control, and automatic square display detection.

## Build Instructions

### Prerequisites

- Qt 6.8.3 (MinGW 13.1 kit)
- MinGW 13.1
- CMake 4.2+
- Ninja

### Build

```bash
cmake -B build -G Ninja \
  -DCMAKE_PREFIX_PATH=C:/Qt/6.8.3/mingw_64 \
  -DCMAKE_C_COMPILER=C:/Qt/Tools/mingw1310_64/bin/gcc.exe \
  -DCMAKE_CXX_COMPILER=C:/Qt/Tools/mingw1310_64/bin/g++.exe
cmake --build build
```

### Run

```bash
build/SpotifyController.exe
```

## Gesture Reference

| Gesture | Action |
|---|---|
| Tap (outside center) | Play / Pause |
| Swipe Left | Next Track |
| Swipe Right | Previous Track |
| Swipe Up/Down | Show Track Info |
| Double-Tap (center) | Save / Like Track |
| Double-Tap (outside) | Toggle Shuffle |
| Two-Finger Drag Up/Down | Volume Up / Down |
| Long Press (1.8s) | Close App |
| Escape Key | Close App |
