#pragma once
#include "spotifyauth.h"
#include <QTimer>
#include <QUrl>
#include <QJsonArray>
#include <QJsonDocument>
#include <functional>

class SpotifyAPI : public SpotifyAuth
{
    Q_OBJECT

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

    QString trackId() const { return m_trackId; }
    QString trackName() const { return m_trackName; }
    QString artist() const { return m_artist; }
    QUrl artUrl() const { return m_artUrl; }
    bool isPlaying() const { return m_isPlaying; }
    bool shuffle() const { return m_shuffle; }
    int volume() const { return m_volume; }
    int progressMs() const { return m_progressMs; }
    int durationMs() const { return m_durationMs; }
    bool hasPlayback() const { return m_hasPlayback; }

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
                    std::function<void(const QJsonObject &)> callback = nullptr,
                    const QJsonObject &body = {});

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

    QTimer *m_pollTimer;
};
