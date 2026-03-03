#include "spotifyauth.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRandomGenerator>
#include <QTcpSocket>
#include <QUrl>
#include <QUrlQuery>
#include <QDateTime>

SpotifyAuth::SpotifyAuth(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
    loadConfig();
    // Only start callback server if not yet authenticated
    if (!isAuthenticated())
        startCallbackServer();
}

bool SpotifyAuth::isAuthenticated() const
{
    return !m_refreshToken.isEmpty();
}

bool SpotifyAuth::ensureToken()
{
    if (m_accessToken.isEmpty() || m_refreshToken.isEmpty())
        return false;

    qint64 now = QDateTime::currentSecsSinceEpoch();
    if (now < m_tokenExpiry)
        return true;

    refreshAccessToken();
    return !m_accessToken.isEmpty() && now < m_tokenExpiry;
}

QNetworkRequest SpotifyAuth::authorizedRequest(const QUrl &url) const
{
    QNetworkRequest req(url);
    req.setRawHeader("Authorization", QStringLiteral("Bearer %1").arg(m_accessToken).toUtf8());
    return req;
}

void SpotifyAuth::openAuthInBrowser()
{
    // Ensure callback server is running for the OAuth redirect
    if (!m_callbackServer || !m_callbackServer->isListening())
        startCallbackServer();

    m_codeVerifier = generateCodeVerifier();
    QString challenge = generateCodeChallenge(m_codeVerifier);

    QUrl url(AUTH_URL);
    QUrlQuery query;
    query.addQueryItem("client_id", CLIENT_ID);
    query.addQueryItem("response_type", "code");
    query.addQueryItem("redirect_uri", REDIRECT_URI);
    query.addQueryItem("scope", SCOPES);
    query.addQueryItem("code_challenge_method", "S256");
    query.addQueryItem("code_challenge", challenge);
    url.setQuery(query);

    QDesktopServices::openUrl(url);
}

// ---------------------------------------------------------------------------
// Config persistence
// ---------------------------------------------------------------------------

void SpotifyAuth::loadConfig()
{
    // Primary: shared config with the Python version
    QString sharedPath = QStringLiteral("C:/DevOps/SpotifyRoundPhobiController/config.json");
    if (QFile::exists(sharedPath)) {
        m_configPath = sharedPath;
    } else {
        // Fallback: next to the executable
        m_configPath = QCoreApplication::applicationDirPath() + QStringLiteral("/config.json");
    }

    QFile file(m_configPath);
    if (!file.open(QIODevice::ReadOnly))
        return;

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject())
        return;

    QJsonObject obj = doc.object();
    m_clientId     = obj.value("client_id").toString();
    m_refreshToken = obj.value("refresh_token").toString();
    m_accessToken  = obj.value("access_token").toString();
    m_tokenExpiry  = static_cast<qint64>(obj.value("token_expiry").toDouble(0));

    // If no client_id in file, use the built-in one
    if (m_clientId.isEmpty())
        m_clientId = CLIENT_ID;
}

void SpotifyAuth::saveConfig()
{
    QJsonObject obj;
    obj["client_id"]     = m_clientId;
    obj["refresh_token"] = m_refreshToken;
    obj["access_token"]  = m_accessToken;
    obj["token_expiry"]  = static_cast<double>(m_tokenExpiry);

    QFile file(m_configPath);
    if (!file.open(QIODevice::WriteOnly))
        return;

    file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
    file.close();
}

// ---------------------------------------------------------------------------
// PKCE helpers
// ---------------------------------------------------------------------------

QString SpotifyAuth::generateCodeVerifier()
{
    // 96 random bytes -> base64url -> take first 128 chars
    const int rawLen = 96;
    QByteArray raw;
    raw.resize(rawLen);
    for (int i = 0; i < rawLen; ++i)
        raw[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));

    QString b64 = raw.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    return b64.left(128);
}

QString SpotifyAuth::generateCodeChallenge(const QString &verifier)
{
    QByteArray hash = QCryptographicHash::hash(verifier.toUtf8(), QCryptographicHash::Sha256);
    return hash.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
}

// ---------------------------------------------------------------------------
// OAuth callback server
// ---------------------------------------------------------------------------

void SpotifyAuth::startCallbackServer()
{
    m_callbackServer = new QTcpServer(this);
    connect(m_callbackServer, &QTcpServer::newConnection, this, [this]() {
        QTcpSocket *sock = m_callbackServer->nextPendingConnection();
        if (!sock)
            return;

        connect(sock, &QTcpSocket::readyRead, this, [this, sock]() {
            QByteArray data = sock->readAll();
            handleCallback(data);

            // Send a minimal HTML response then close
            QByteArray body =
                "<html><body><h2>Authentication successful!</h2>"
                "<p>You can close this tab and return to the app.</p></body></html>";
            QByteArray response =
                "HTTP/1.1 200 OK\r\n"
                "Content-Type: text/html\r\n"
                "Content-Length: " + QByteArray::number(body.size()) + "\r\n"
                "Connection: close\r\n\r\n" + body;
            sock->write(response);
            sock->flush();
            sock->disconnectFromHost();
        });
    });

    if (!m_callbackServer->listen(QHostAddress::LocalHost, 8888)) {
        qWarning() << "SpotifyAuth: could not start callback server on port 8888:"
                    << m_callbackServer->errorString();
    }
}

void SpotifyAuth::handleCallback(const QByteArray &requestData)
{
    // Parse "GET /callback?code=XXXX HTTP/1.1\r\n..."
    QString req = QString::fromUtf8(requestData);
    int start = req.indexOf('?');
    int end   = req.indexOf(' ', start);
    if (start < 0 || end < 0)
        return;

    QString queryString = req.mid(start + 1, end - start - 1);
    QUrlQuery query(queryString);
    QString code = query.queryItemValue("code");

    if (!code.isEmpty())
        exchangeCode(code);
}

// ---------------------------------------------------------------------------
// Token exchange / refresh
// ---------------------------------------------------------------------------

void SpotifyAuth::exchangeCode(const QString &code)
{
    QUrlQuery params;
    params.addQueryItem("grant_type", "authorization_code");
    params.addQueryItem("code", code);
    params.addQueryItem("redirect_uri", REDIRECT_URI);
    params.addQueryItem("client_id", m_clientId.isEmpty() ? QString(CLIENT_ID) : m_clientId);
    params.addQueryItem("code_verifier", m_codeVerifier);

    QUrl tokenUrl{QString::fromLatin1(TOKEN_URL)};
    QNetworkRequest req{tokenUrl};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");

    QNetworkReply *reply = m_nam->post(req, params.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "SpotifyAuth: token exchange failed:" << reply->errorString();
            emit authCompleted(false);
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonObject obj = doc.object();

        m_accessToken  = obj.value("access_token").toString();
        m_refreshToken = obj.value("refresh_token").toString();
        int expiresIn  = obj.value("expires_in").toInt(3600);
        m_tokenExpiry  = QDateTime::currentSecsSinceEpoch() + expiresIn - 60;

        if (m_clientId.isEmpty())
            m_clientId = CLIENT_ID;

        saveConfig();

        emit authenticatedChanged();
        emit authCompleted(true);
    });
}

void SpotifyAuth::refreshAccessToken()
{
    if (m_refreshToken.isEmpty() || m_clientId.isEmpty())
        return;

    QUrlQuery params;
    params.addQueryItem("grant_type", "refresh_token");
    params.addQueryItem("refresh_token", m_refreshToken);
    params.addQueryItem("client_id", m_clientId);

    QUrl tokenUrl{QString::fromLatin1(TOKEN_URL)};
    QNetworkRequest req{tokenUrl};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");

    // Synchronous-style: use a local event loop so ensureToken() can return a
    // meaningful value. This blocks briefly (~200-500 ms) but keeps the API
    // simple for callers.
    QEventLoop loop;
    QNetworkReply *reply = m_nam->post(req, params.toString(QUrl::FullyEncoded).toUtf8());
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "SpotifyAuth: token refresh failed:" << reply->errorString();
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    QJsonObject obj = doc.object();

    m_accessToken = obj.value("access_token").toString();
    if (obj.contains("refresh_token"))
        m_refreshToken = obj.value("refresh_token").toString();

    int expiresIn = obj.value("expires_in").toInt(3600);
    m_tokenExpiry = QDateTime::currentSecsSinceEpoch() + expiresIn - 60;

    saveConfig();
    emit authenticatedChanged();
}
