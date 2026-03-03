#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QScreen>

#include "spotifyapi.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("SpotifyController");

    SpotifyAPI *spotify = new SpotifyAPI(&app);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Spotify", spotify);
    engine.loadFromModule("SpotifyController", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
