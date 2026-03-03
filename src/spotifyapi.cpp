#include "spotifyapi.h"

#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrlQuery>

static const QString API_BASE = QStringLiteral("https://api.spotify.com/v1");

SpotifyAPI::SpotifyAPI(QObject *parent)
    : SpotifyAuth(parent)
    , m_pollTimer(new QTimer(this))
{
    m_pollTimer->setInterval(2000);
    connect(m_pollTimer, &QTimer::timeout, this, &SpotifyAPI::poll);

    // Start polling only after authentication
    if (isAuthenticated()) {
        m_pollTimer->start();
    }
    connect(this, &SpotifyAuth::authenticatedChanged, this, [this]() {
        if (isAuthenticated()) {
            m_pollTimer->start();
            poll();  // Immediate first poll
        } else {
            m_pollTimer->stop();
        }
    });
}

// ---------------------------------------------------------------------------
// Polling
// ---------------------------------------------------------------------------

void SpotifyAPI::poll()
{
    if (!ensureToken())
        return;

    QUrl url(API_BASE + QStringLiteral("/me/player"));
    QNetworkRequest req = authorizedRequest(url);

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        // No active playback
        if (status == 204 || reply->error() != QNetworkReply::NoError) {
            if (m_hasPlayback) {
                m_hasPlayback = false;
                emit playbackAvailableChanged();
            }
            return;
        }

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isObject())
            return;

        QJsonObject obj = doc.object();
        QJsonObject item = obj.value("item").toObject();

        if (item.isEmpty()) {
            // Player active but no track
            bool playing = obj.value("is_playing").toBool(false);
            bool shuffleState = obj.value("shuffle_state").toBool(false);
            if (m_isPlaying != playing) {
                m_isPlaying = playing;
                emit playStateChanged();
            }
            if (m_shuffle != shuffleState) {
                m_shuffle = shuffleState;
                emit shuffleChanged();
            }
            if (m_hasPlayback) {
                m_hasPlayback = false;
                emit playbackAvailableChanged();
            }
            return;
        }

        // We have playback
        if (!m_hasPlayback) {
            m_hasPlayback = true;
            emit playbackAvailableChanged();
        }

        // Track info
        QString newTrackId = item.value("id").toString();
        QString newName = item.value("name").toString(QStringLiteral("Unknown"));

        // Artists: comma-joined
        QJsonArray artistsArr = item.value("artists").toArray();
        QStringList artistNames;
        for (const QJsonValue &a : artistsArr)
            artistNames.append(a.toObject().value("name").toString());
        QString newArtist = artistNames.join(QStringLiteral(", "));

        // Album art: prefer 640x640, fallback to first
        QJsonArray images = item.value("album").toObject().value("images").toArray();
        QUrl newArtUrl;
        for (const QJsonValue &img : images) {
            QJsonObject imgObj = img.toObject();
            if (imgObj.value("width").toInt() == 640) {
                newArtUrl = QUrl(imgObj.value("url").toString());
                break;
            }
        }
        if (newArtUrl.isEmpty() && !images.isEmpty()) {
            newArtUrl = QUrl(images.first().toObject().value("url").toString());
        }

        // Playback state
        bool newPlaying = obj.value("is_playing").toBool(false);
        bool newShuffle = obj.value("shuffle_state").toBool(false);
        int newProgress = obj.value("progress_ms").toInt(0);
        int newDuration = item.value("duration_ms").toInt(1);
        int newVolume = obj.value("device").toObject().value("volume_percent").toInt(50);

        // Emit signals for changes
        if (newTrackId != m_trackId) {
            QString direction = m_trackId.isEmpty() ? QString() : QStringLiteral("left");
            m_trackId = newTrackId;
            m_trackName = newName;
            m_artist = newArtist;
            m_artUrl = newArtUrl;
            emit trackChanged(direction);
        }

        if (newPlaying != m_isPlaying) {
            m_isPlaying = newPlaying;
            emit playStateChanged();
        }

        if (newShuffle != m_shuffle) {
            m_shuffle = newShuffle;
            emit shuffleChanged();
        }

        if (newVolume != m_volume) {
            m_volume = newVolume;
            emit volumeChanged();
        }

        // Always update progress
        m_progressMs = newProgress;
        m_durationMs = newDuration;
        emit progressChanged();
    });
}

// ---------------------------------------------------------------------------
// API request helper
// ---------------------------------------------------------------------------

void SpotifyAPI::apiRequest(const QString &method, const QString &path,
                            std::function<void(const QJsonObject &)> callback,
                            const QJsonObject &body)
{
    if (!ensureToken())
        return;

    QUrl url(API_BASE + path);
    QNetworkRequest req = authorizedRequest(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    QNetworkReply *reply = nullptr;
    QByteArray bodyData;
    if (!body.isEmpty())
        bodyData = QJsonDocument(body).toJson(QJsonDocument::Compact);

    if (method == QStringLiteral("GET")) {
        reply = m_nam->get(req);
    } else if (method == QStringLiteral("PUT")) {
        reply = m_nam->put(req, bodyData);
    } else if (method == QStringLiteral("POST")) {
        reply = m_nam->post(req, bodyData);
    } else if (method == QStringLiteral("DELETE")) {
        reply = m_nam->deleteResource(req);
    }

    if (!reply)
        return;

    connect(reply, &QNetworkReply::finished, this, [this, reply, callback, method, path, body]() {
        reply->deleteLater();

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

        // Handle 401: refresh token and retry once
        if (status == 401) {
            if (ensureToken()) {
                // Retry the request once with fresh token
                QUrl retryUrl(API_BASE + path);
                QNetworkRequest retryReq = authorizedRequest(retryUrl);
                retryReq.setHeader(QNetworkRequest::ContentTypeHeader,
                                   QStringLiteral("application/json"));

                QByteArray retryBody;
                if (!body.isEmpty())
                    retryBody = QJsonDocument(body).toJson(QJsonDocument::Compact);

                QNetworkReply *retryReply = nullptr;
                if (method == QStringLiteral("GET"))
                    retryReply = m_nam->get(retryReq);
                else if (method == QStringLiteral("PUT"))
                    retryReply = m_nam->put(retryReq, retryBody);
                else if (method == QStringLiteral("POST"))
                    retryReply = m_nam->post(retryReq, retryBody);

                if (retryReply && callback) {
                    connect(retryReply, &QNetworkReply::finished, this,
                            [retryReply, callback]() {
                                retryReply->deleteLater();
                                QByteArray data = retryReply->readAll();
                                QJsonDocument doc = QJsonDocument::fromJson(data);
                                callback(doc.isObject() ? doc.object() : QJsonObject());
                            });
                }
                return;
            }
        }

        // Handle 429: rate limited — log and schedule a retry via poll
        if (status == 429) {
            int retryAfter = reply->rawHeader("Retry-After").toInt();
            if (retryAfter < 1)
                retryAfter = 2;
            qWarning() << "SpotifyAPI: rate limited, retry after" << retryAfter << "seconds";
            // Don't block; just let the next poll handle it
            return;
        }

        if (callback) {
            QByteArray data = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(data);
            callback(doc.isObject() ? doc.object() : QJsonObject());
        }
    });
}

// ---------------------------------------------------------------------------
// Playback controls
// ---------------------------------------------------------------------------

void SpotifyAPI::play()
{
    if (m_hasPlayback) {
        // Active device exists — just resume
        apiRequest(QStringLiteral("PUT"), QStringLiteral("/me/player/play"));
        QTimer::singleShot(500, this, &SpotifyAPI::poll);
        return;
    }

    // No active playback — find a device and transfer playback to it
    if (!ensureToken())
        return;

    QUrl url(API_BASE + QStringLiteral("/me/player/devices"));
    QNetworkRequest req = authorizedRequest(url);

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonArray devices = doc.object().value("devices").toArray();

        if (devices.isEmpty()) {
            qWarning() << "SpotifyAPI: no devices available — open Spotify on a device first";
            return;
        }

        // Pick the first available device
        QString deviceId = devices.first().toObject().value("id").toString();

        // Transfer playback and start playing
        QJsonObject body;
        body[QStringLiteral("device_ids")] = QJsonArray{deviceId};
        body[QStringLiteral("play")] = true;
        apiRequest(QStringLiteral("PUT"), QStringLiteral("/me/player"), nullptr, body);

        // Poll after a short delay to pick up the new state
        QTimer::singleShot(1000, this, &SpotifyAPI::poll);
    });
}

void SpotifyAPI::pause()
{
    apiRequest(QStringLiteral("PUT"), QStringLiteral("/me/player/pause"));
    QTimer::singleShot(500, this, &SpotifyAPI::poll);
}

void SpotifyAPI::nextTrack()
{
    apiRequest(QStringLiteral("POST"), QStringLiteral("/me/player/next"));
    QTimer::singleShot(500, this, &SpotifyAPI::poll);
}

void SpotifyAPI::prevTrack()
{
    apiRequest(QStringLiteral("POST"), QStringLiteral("/me/player/previous"));
    QTimer::singleShot(500, this, &SpotifyAPI::poll);
}

void SpotifyAPI::toggleShuffle()
{
    bool newState = !m_shuffle;
    QString path = QStringLiteral("/me/player/shuffle?state=%1")
                       .arg(newState ? QStringLiteral("true") : QStringLiteral("false"));

    apiRequest(QStringLiteral("PUT"), path, [this, newState](const QJsonObject &) {
        m_shuffle = newState;
        emit shuffleChanged();
        emit shuffleToggled(newState);
    });
}

void SpotifyAPI::setVolume(int percent)
{
    percent = qBound(0, percent, 100);
    QString path = QStringLiteral("/me/player/volume?volume_percent=%1").arg(percent);
    apiRequest(QStringLiteral("PUT"), path, [this, percent](const QJsonObject &) {
        m_volume = percent;
        emit volumeChanged();
    });
}

void SpotifyAPI::saveTrack()
{
    if (m_trackId.isEmpty())
        return;

    if (!ensureToken())
        return;

    // /me/tracks/contains returns a JSON array, not an object, so we use
    // a direct network call instead of the apiRequest helper.
    QString currentTrackId = m_trackId;
    QUrl checkUrl(API_BASE + QStringLiteral("/me/tracks/contains?ids=%1").arg(currentTrackId));
    QNetworkRequest req = authorizedRequest(checkUrl);

    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, currentTrackId]() {
        reply->deleteLater();

        QByteArray data = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(data);

        if (doc.isArray() && !doc.array().isEmpty() && doc.array().first().toBool()) {
            // Already saved
            emit trackSaved(true);
            return;
        }

        // Save the track
        QString savePath = QStringLiteral("/me/tracks?ids=%1").arg(currentTrackId);
        apiRequest(QStringLiteral("PUT"), savePath, [this](const QJsonObject &) {
            emit trackSaved(false);
        });
    });
}

void SpotifyAPI::closeApp()
{
    QGuiApplication::quit();
}
