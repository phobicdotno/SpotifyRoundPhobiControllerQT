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
