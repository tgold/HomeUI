#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>
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

signals:
    void pollIntervalMsChanged();
    void zoneUpdated(const QString &host);
    void errorOccurred(const QString &host, const QString &message);

private:
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
    };

    static QString normalizeHost(const QString &hostOrUrl);
    static QString firstTagText(const QString &xml, const QString &localTagName);
    static QString parseMetaField(const QString &metadata, const QString &localTagName);
    static QString normalizedState(const QString &raw);

    QString soapEndpoint(const QString &host, const QString &servicePath) const;
    void startPoll();
    void pollAllZones();
    void pollZone(const QString &host);
    void requestTransportInfo(const QString &host);
    void requestPositionInfo(const QString &host);
    void requestMediaInfo(const QString &host);
    void requestRenderingState(const QString &host);
    void postSoap(const QString &host,
                  const QString &servicePath,
                  const QByteArray &soapAction,
                  const QByteArray &body,
                  const std::function<void(QNetworkReply *)> &onFinished);
    void applyZoneUpdate(const QString &host, const std::function<bool(ZoneData &)> &updater);

    QNetworkAccessManager m_network;
    QHash<QString, ZoneData> m_zones;
    QTimer m_pollTimer;
    int m_pollIntervalMs = 2000;
};
