cmake_minimum_required(VERSION 3.21)
project(SpotifyRoundPhobiControllerQT VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Gui)

qt_add_executable(SpotifyController
    src/main.cpp
    src/spotifyauth.h
    src/spotifyauth.cpp
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
