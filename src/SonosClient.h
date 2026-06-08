#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class QNetworkReply;

class SonosClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int pollIntervalMs READ pollIntervalMs WRITE setPollIntervalMs NOTIFY pollIntervalMsChanged)

public:
    explicit SonosClient(QObject *parent = nullptr);

    int pollIntervalMs() const;
    void setPollIntervalMs(int intervalMs);

    Q_INVOKABLE void ensureZone(const QString &hostOrUrl);
    Q_INVOKABLE int zoneRevision(const QString &hostOrUrl) const;
    Q_INVOKABLE QVariantMap zoneState(const QString &hostOrUrl) const;
    Q_INVOKABLE void sendTransport(const QString &hostOrUrl, const QString &command);
    Q_INVOKABLE void setVolume(const QString &hostOrUrl, int volume);
    Q_INVOKABLE void setMuted(const QString &hostOrUrl, bool muted);
    Q_INVOKABLE void refreshFavorites(const QString &hostOrUrl);
    Q_INVOKABLE QVariantList zoneFavorites(const QString &hostOrUrl) const;
    Q_INVOKABLE int favoritesRevision(const QString &hostOrUrl) const;
    Q_INVOKABLE void playFavorite(const QString &hostOrUrl, const QString &favoriteKey);

signals:
    void pollIntervalMsChanged();
    void zoneUpdated(const QString &host);
    void zoneFavoritesUpdated(const QString &host);
    void errorOccurred(const QString &host, const QString &message);

private:
    struct FavoriteEntry {
        QString id;
        QString label;
        QString uri;
        QString itemClass;
        QString resProtocolInfo;
        QString metadata;
        QString metadataSoap;
    };

    struct ZoneData {
        QString host;
        QString title;
        QString artist;
        QString album;
        QString track;
        QString albumArtUrl;
        QString state;
        int volume = 0;
        bool muted = false;
        int revision = 0;
        QList<FavoriteEntry> favorites;
        int favoritesRevision = 0;
    };

    static QString normalizeHost(const QString &hostOrUrl);
    static QString firstTagText(const QString &xml, const QString &localTagName);
    static QString soapTagText(const QString &xml, const QString &localTagName);
    static QString decodeXmlEntities(const QString &value);
    static QString decodeXmlEntitiesOnce(const QString &value);
    static QString xmlEscape(const QString &value);
    static QString normalizeSonosAlbumArtUrl(const QString &url);
    static QString parseMetaField(const QString &metadata, const QString &localTagName);
    static QString normalizedState(const QString &raw);
    static QList<FavoriteEntry> parseFavoriteItems(const QString &didlXml);
    static QString buildFavoriteMetadata(const FavoriteEntry &entry);
    static bool favoriteKeyMatches(const FavoriteEntry &entry, const QString &favoriteKey);

    QString soapEndpoint(const QString &host, const QString &servicePath) const;
    void startPoll();
    void pollAllZones();
    void pollZone(const QString &host);
    void requestTransportInfo(const QString &host);
    void requestPositionInfo(const QString &host);
    void requestMediaInfo(const QString &host);
    void requestRenderingState(const QString &host);
    void requestFavoritesPage(const QString &host, int startingIndex, QList<FavoriteEntry> accumulated);
    void setAvTransportUri(const QString &host,
                           const QString &uri,
                           const QString &metadata,
                           const QString &metadataSoap,
                           const std::function<void(bool)> &onFinished);
    void startPlayback(const QString &host);
    void postSoap(const QString &host,
                  const QString &servicePath,
                  const QByteArray &soapAction,
                  const QByteArray &body,
                  const std::function<void(QNetworkReply *)> &onFinished,
                  const QByteArray &userAgent = QByteArray("HomeUI/0.1"));
    void applyZoneUpdate(const QString &host, const std::function<bool(ZoneData &)> &updater);

    QNetworkAccessManager m_network;
    QHash<QString, ZoneData> m_zones;
    QTimer m_pollTimer;
    int m_pollIntervalMs = 2000;
};
