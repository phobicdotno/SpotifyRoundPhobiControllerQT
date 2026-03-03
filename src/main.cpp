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
