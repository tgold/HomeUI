#include "SonosClient.h"

#include <QLoggingCategory>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QUrl>
#include <QXmlStreamReader>

namespace {
Q_LOGGING_CATEGORY(lcSonos, "homeui.sonos")
}

SonosClient::SonosClient(QObject *parent)
    : QObject(parent)
{
    m_pollTimer.setInterval(m_pollIntervalMs);
    connect(&m_pollTimer, &QTimer::timeout, this, &SonosClient::pollAllZones);
}

int SonosClient::pollIntervalMs() const
{
    return m_pollIntervalMs;
}

void SonosClient::setPollIntervalMs(int intervalMs)
{
    const int clamped = qMax(500, intervalMs);
    if (m_pollIntervalMs == clamped) {
        return;
    }
    m_pollIntervalMs = clamped;
    m_pollTimer.setInterval(m_pollIntervalMs);
    emit pollIntervalMsChanged();
}

void SonosClient::ensureZone(const QString &hostOrUrl)
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty()) {
        return;
    }
    if (!m_zones.contains(host)) {
        ZoneData zone;
        zone.host = host;
        m_zones.insert(host, zone);
    }

    startPoll();
    pollZone(host);
}

int SonosClient::zoneRevision(const QString &hostOrUrl) const
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty() || !m_zones.contains(host)) {
        return 0;
    }
    return m_zones.value(host).revision;
}

QVariantMap SonosClient::zoneState(const QString &hostOrUrl) const
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty() || !m_zones.contains(host)) {
        return {};
    }

    const ZoneData zone = m_zones.value(host);
    return {
        { QStringLiteral("host"), zone.host },
        { QStringLiteral("title"), zone.title },
        { QStringLiteral("artist"), zone.artist },
        { QStringLiteral("album"), zone.album },
        { QStringLiteral("track"), zone.track },
        { QStringLiteral("albumArt"), zone.albumArtUrl },
        { QStringLiteral("state"), zone.state },
        { QStringLiteral("volume"), zone.volume },
        { QStringLiteral("mute"), zone.muted ? QStringLiteral("ON") : QStringLiteral("OFF") }
    };
}

void SonosClient::sendTransport(const QString &hostOrUrl, const QString &command)
{
    const QString host = normalizeHost(hostOrUrl);
    const QString normalized = command.trimmed().toUpper();
    if (host.isEmpty() || normalized.isEmpty()) {
        return;
    }

    QByteArray action;
    QByteArray body;
    if (normalized == "PLAY") {
        action = "urn:schemas-upnp-org:service:AVTransport:1#Play";
        body = "<u:Play xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>";
    } else if (normalized == "PAUSE") {
        action = "urn:schemas-upnp-org:service:AVTransport:1#Pause";
        body = "<u:Pause xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Pause>";
    } else if (normalized == "NEXT") {
        action = "urn:schemas-upnp-org:service:AVTransport:1#Next";
        body = "<u:Next xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Next>";
    } else if (normalized == "PREVIOUS" || normalized == "PREV") {
        action = "urn:schemas-upnp-org:service:AVTransport:1#Previous";
        body = "<u:Previous xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:Previous>";
    } else {
        return;
    }

    postSoap(host,
             QStringLiteral("/MediaRenderer/AVTransport/Control"),
             action,
             body,
             [this, host, normalized](QNetworkReply *reply) {
                 if (reply->error() != QNetworkReply::NoError) {
                     emit errorOccurred(host, reply->errorString());
                     return;
                 }
                 // Optimistic state transition so the play/pause button flips
                 // immediately even before the next transport poll returns.
                 if (normalized == QStringLiteral("PLAY")) {
                     applyZoneUpdate(host, [](ZoneData &zone) {
                         if (zone.state == QStringLiteral("PLAYING")) {
                             return false;
                         }
                         zone.state = QStringLiteral("PLAYING");
                         return true;
                     });
                 } else if (normalized == QStringLiteral("PAUSE")) {
                     applyZoneUpdate(host, [](ZoneData &zone) {
                         if (zone.state == QStringLiteral("PAUSED_PLAYBACK")) {
                             return false;
                         }
                         zone.state = QStringLiteral("PAUSED_PLAYBACK");
                         return true;
                     });
                 }
                 pollZone(host);
             });
}

void SonosClient::setVolume(const QString &hostOrUrl, int volume)
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty()) {
        return;
    }
    const int clamped = qBound(0, volume, 100);
    const QByteArray body = QStringLiteral(
                                "<u:SetVolume xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\">"
                                "<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>%1</DesiredVolume>"
                                "</u:SetVolume>")
                                .arg(clamped)
                                .toUtf8();

    postSoap(host,
             QStringLiteral("/MediaRenderer/RenderingControl/Control"),
             QByteArray("urn:schemas-upnp-org:service:RenderingControl:1#SetVolume"),
             body,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() != QNetworkReply::NoError) {
                     emit errorOccurred(host, reply->errorString());
                     return;
                 }
                 pollZone(host);
             });
}

void SonosClient::setMuted(const QString &hostOrUrl, bool muted)
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty()) {
        return;
    }
    const QByteArray body = QStringLiteral(
                                "<u:SetMute xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\">"
                                "<InstanceID>0</InstanceID><Channel>Master</Channel><DesiredMute>%1</DesiredMute>"
                                "</u:SetMute>")
                                .arg(muted ? 1 : 0)
                                .toUtf8();

    postSoap(host,
             QStringLiteral("/MediaRenderer/RenderingControl/Control"),
             QByteArray("urn:schemas-upnp-org:service:RenderingControl:1#SetMute"),
             body,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() != QNetworkReply::NoError) {
                     emit errorOccurred(host, reply->errorString());
                     return;
                 }
                 pollZone(host);
             });
}

QString SonosClient::normalizeHost(const QString &hostOrUrl)
{
    const QString raw = hostOrUrl.trimmed();
    if (raw.isEmpty()) {
        return {};
    }

    QUrl asUrl(raw);
    if (asUrl.isValid() && !asUrl.scheme().isEmpty()) {
        const QString host = asUrl.host().trimmed();
        return host;
    }

    QString host = raw;
    const int slashIdx = host.indexOf('/');
    if (slashIdx >= 0) {
        host = host.left(slashIdx);
    }
    const int colonIdx = host.indexOf(':');
    if (colonIdx >= 0) {
        host = host.left(colonIdx);
    }
    return host.trimmed();
}

QString SonosClient::firstTagText(const QString &xml, const QString &localTagName)
{
    QXmlStreamReader reader(xml);
    while (!reader.atEnd()) {
        reader.readNext();
        if (reader.isStartElement() && reader.name().compare(localTagName, Qt::CaseInsensitive) == 0) {
            return reader.readElementText(QXmlStreamReader::IncludeChildElements).trimmed();
        }
    }
    return {};
}

QString SonosClient::parseMetaField(const QString &metadata, const QString &localTagName)
{
    if (metadata.isEmpty()) {
        return {};
    }

    // Decode XML entities from Sonos DIDL metadata without relying on
    // QString::fromHtmlEscaped (missing on some distro Qt builds). Some
    // Sonos payloads are double-escaped, so decode a few rounds.
    QString decoded = metadata;
    for (int i = 0; i < 3; ++i) {
        QString next = decoded;
        next.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
        next.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
        next.replace(QStringLiteral("&quot;"), QStringLiteral("\""));
        next.replace(QStringLiteral("&apos;"), QStringLiteral("'"));
        next.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
        if (next == decoded) {
            break;
        }
        decoded = next;
    }

    QString value = firstTagText(decoded, localTagName);
    if (!value.isEmpty()) {
        return value;
    }

    // Fallback for payloads with awkward namespace/formatting combinations.
    const QString tagPattern = QStringLiteral("<(?:\\w+:)?%1\\b[^>]*>(.*?)</(?:\\w+:)?%1>")
                                   .arg(QRegularExpression::escape(localTagName));
    QRegularExpression re(tagPattern,
                          QRegularExpression::DotMatchesEverythingOption
                              | QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch m = re.match(decoded);
    if (m.hasMatch()) {
        return m.captured(1).trimmed();
    }
    return {};
}

QString SonosClient::normalizedState(const QString &raw)
{
    const QString value = raw.trimmed().toUpper();
    if (value == QStringLiteral("TRANSITIONING")) {
        return QStringLiteral("PLAYING");
    }
    return value;
}

QString SonosClient::soapEndpoint(const QString &host, const QString &servicePath) const
{
    return QStringLiteral("http://%1:1400%2").arg(host, servicePath);
}

void SonosClient::startPoll()
{
    if (!m_pollTimer.isActive()) {
        m_pollTimer.start();
    }
}

void SonosClient::pollAllZones()
{
    const auto keys = m_zones.keys();
    for (const QString &host : keys) {
        pollZone(host);
    }
}

void SonosClient::pollZone(const QString &host)
{
    if (!m_zones.contains(host)) {
        return;
    }

    requestTransportInfo(host);
    requestPositionInfo(host);
    requestRenderingState(host);
}

void SonosClient::requestTransportInfo(const QString &host)
{
    static const QByteArray body =
        "<u:GetTransportInfo xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">"
        "<InstanceID>0</InstanceID>"
        "</u:GetTransportInfo>";

    postSoap(host,
             QStringLiteral("/MediaRenderer/AVTransport/Control"),
             QByteArray("urn:schemas-upnp-org:service:AVTransport:1#GetTransportInfo"),
             body,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() == QNetworkReply::NoError) {
                     const QString xml = QString::fromUtf8(reply->readAll());
                     const QString state = normalizedState(firstTagText(xml, QStringLiteral("CurrentTransportState")));
                     if (!state.isEmpty()) {
                         applyZoneUpdate(host, [state](ZoneData &zone) {
                             if (zone.state == state) {
                                 return false;
                             }
                             zone.state = state;
                             return true;
                         });
                     }
                 } else {
                     qCWarning(lcSonos, "GetTransportInfo failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                 }
             });
}

void SonosClient::requestPositionInfo(const QString &host)
{
    static const QByteArray body =
        "<u:GetPositionInfo xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">"
        "<InstanceID>0</InstanceID>"
        "</u:GetPositionInfo>";

    postSoap(host,
             QStringLiteral("/MediaRenderer/AVTransport/Control"),
             QByteArray("urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo"),
             body,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() == QNetworkReply::NoError) {
                     const QString xml = QString::fromUtf8(reply->readAll());
                     const QString metadata = firstTagText(xml, QStringLiteral("TrackMetaData"));
                     QString title = parseMetaField(metadata, QStringLiteral("title"));
                     QString artist = parseMetaField(metadata, QStringLiteral("creator"));
                     QString album = parseMetaField(metadata, QStringLiteral("album"));
                     QString albumArt = parseMetaField(metadata, QStringLiteral("albumArtURI"));
                     const QString streamContent = parseMetaField(metadata, QStringLiteral("streamContent"));
                     const QString radioShow = parseMetaField(metadata, QStringLiteral("radioShowMd"));
                     QString track = firstTagText(xml, QStringLiteral("TrackURI"));

                     if (!albumArt.isEmpty() && albumArt.startsWith('/')) {
                         albumArt = QStringLiteral("http://%1:1400%2").arg(host, albumArt);
                     }
                     if (title.isEmpty() && !streamContent.isEmpty()) {
                         title = streamContent;
                     }
                     if (title.isEmpty() && !radioShow.isEmpty()) {
                         title = radioShow;
                     }
                     if (track.isEmpty()) {
                         track = !title.isEmpty() ? title : streamContent;
                     }
                     if (track.startsWith(QStringLiteral("x-sonos"))
                         || track.startsWith(QStringLiteral("http://"))
                         || track.startsWith(QStringLiteral("https://"))) {
                         if (!title.isEmpty()) {
                             track = title;
                         } else if (!streamContent.isEmpty()) {
                             track = streamContent;
                         } else if (!radioShow.isEmpty()) {
                             track = radioShow;
                         }
                     }

                     applyZoneUpdate(host, [title, artist, album, albumArt, track](ZoneData &zone) {
                         bool changed = false;
                         if (zone.title != title) { zone.title = title; changed = true; }
                         if (zone.artist != artist) { zone.artist = artist; changed = true; }
                         if (zone.album != album) { zone.album = album; changed = true; }
                         if (zone.albumArtUrl != albumArt) { zone.albumArtUrl = albumArt; changed = true; }
                         if (zone.track != track) { zone.track = track; changed = true; }
                         return changed;
                     });
                 } else {
                     qCWarning(lcSonos, "GetPositionInfo failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                 }
             });
}

void SonosClient::requestRenderingState(const QString &host)
{
    static const QByteArray volumeBody =
        "<u:GetVolume xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\">"
        "<InstanceID>0</InstanceID><Channel>Master</Channel>"
        "</u:GetVolume>";
    static const QByteArray muteBody =
        "<u:GetMute xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\">"
        "<InstanceID>0</InstanceID><Channel>Master</Channel>"
        "</u:GetMute>";

    postSoap(host,
             QStringLiteral("/MediaRenderer/RenderingControl/Control"),
             QByteArray("urn:schemas-upnp-org:service:RenderingControl:1#GetVolume"),
             volumeBody,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() == QNetworkReply::NoError) {
                     const QString xml = QString::fromUtf8(reply->readAll());
                     bool ok = false;
                     const int volume = firstTagText(xml, QStringLiteral("CurrentVolume")).toInt(&ok);
                     if (ok) {
                         applyZoneUpdate(host, [volume](ZoneData &zone) {
                             if (zone.volume == volume) {
                                 return false;
                             }
                             zone.volume = volume;
                             return true;
                         });
                     }
                 } else {
                     qCWarning(lcSonos, "GetVolume failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                 }
             });

    postSoap(host,
             QStringLiteral("/MediaRenderer/RenderingControl/Control"),
             QByteArray("urn:schemas-upnp-org:service:RenderingControl:1#GetMute"),
             muteBody,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() == QNetworkReply::NoError) {
                     const QString xml = QString::fromUtf8(reply->readAll());
                     const QString mutedValue = firstTagText(xml, QStringLiteral("CurrentMute")).trimmed();
                     const bool muted = (mutedValue == QStringLiteral("1")
                                         || mutedValue.compare(QStringLiteral("ON"), Qt::CaseInsensitive) == 0);
                     applyZoneUpdate(host, [muted](ZoneData &zoneData) {
                         if (zoneData.muted == muted) {
                             return false;
                         }
                         zoneData.muted = muted;
                         return true;
                     });
                 } else {
                     qCWarning(lcSonos, "GetMute failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                 }
             });
}

void SonosClient::postSoap(const QString &host,
                           const QString &servicePath,
                           const QByteArray &soapAction,
                           const QByteArray &body,
                           const std::function<void(QNetworkReply *)> &onFinished)
{
    QNetworkRequest request(QUrl(soapEndpoint(host, servicePath)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("text/xml; charset=utf-8"));
    request.setRawHeader("SOAPACTION", QByteArray("\"") + soapAction + QByteArray("\""));
    request.setRawHeader("User-Agent", "HomeUI/0.1");

    const QByteArray envelope =
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
        "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" "
        "s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
        "<s:Body>" + body + "</s:Body></s:Envelope>";

    QNetworkReply *reply = m_network.post(request, envelope);
    connect(reply, &QNetworkReply::finished, this, [reply, onFinished]() {
        onFinished(reply);
        reply->deleteLater();
    });
}

void SonosClient::applyZoneUpdate(const QString &host, const std::function<bool(ZoneData &)> &updater)
{
    if (!m_zones.contains(host)) {
        return;
    }
    ZoneData &zone = m_zones[host];
    if (!updater(zone)) {
        return;
    }
    ++zone.revision;
    emit zoneUpdated(host);
}
