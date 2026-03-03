#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QScreen>
#include <QQuickWindow>

#include "spotifyapi.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("SpotifyController");

    // Auto-detect square display (round touchscreen)
    QScreen *targetScreen = nullptr;
    for (QScreen *screen : QGuiApplication::screens()) {
        QSize size = screen->size();
        if (size.width() == size.height() && size.width() <= 1080) {
            targetScreen = screen;
            break;
        }
    }

    SpotifyAPI *spotify = new SpotifyAPI(&app);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("Spotify", spotify);
    engine.loadFromModule("SpotifyController", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    // Position window on the detected square display
    if (targetScreen) {
        QObject *rootObj = engine.rootObjects().first();
        QQuickWindow *window = qobject_cast<QQuickWindow*>(rootObj);
        if (window) {
            QRect geo = targetScreen->geometry();
            window->setPosition(geo.topLeft());
            window->resize(geo.size());
        }
    }

    return app.exec();
}
