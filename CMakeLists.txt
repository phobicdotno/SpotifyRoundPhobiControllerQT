cmake_minimum_required(VERSION 3.21)
project(SpotifyRoundPhobiControllerQT VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Gui Core5Compat)

qt_add_executable(SpotifyController
    src/main.cpp
    src/spotifyauth.h
    src/spotifyauth.cpp
    src/spotifyapi.h
    src/spotifyapi.cpp
)

qt_add_qml_module(SpotifyController
    URI SpotifyController
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/SetupView.qml
        qml/PlayerView.qml
        qml/components/AlbumArt.qml
        qml/components/VinylCenter.qml
        qml/components/ProgressRing.qml
        qml/components/FeedbackOverlay.qml
        qml/components/TrackToast.qml
        qml/components/VolumeOverlay.qml
        qml/components/BurstEffect.qml
)

target_link_libraries(SpotifyController PRIVATE
    Qt6::Quick
    Qt6::Network
    Qt6::Gui
    Qt6::Core5Compat
)
