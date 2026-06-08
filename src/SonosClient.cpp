#include "SonosClient.h"

#include <QLoggingCategory>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QUrl>
#include <QUrlQuery>
#include <QXmlStreamReader>

#include <algorithm>

namespace {
Q_LOGGING_CATEGORY(lcSonos, "homeui.sonos")

bool looksLikeUrlOrUri(const QString &value)
{
    const QString v = value.trimmed();
    if (v.isEmpty()) {
        return false;
    }
    return v.startsWith(QStringLiteral("http://"), Qt::CaseInsensitive)
        || v.startsWith(QStringLiteral("https://"), Qt::CaseInsensitive)
        || v.startsWith(QStringLiteral("x-sonos"), Qt::CaseInsensitive)
        || v.contains(QStringLiteral("sid="), Qt::CaseInsensitive)
        || v.contains(QStringLiteral("cid="), Qt::CaseInsensitive)
        || v.contains(QLatin1Char('?'));
}

bool isGenericSourceLabel(const QString &value)
{
    const QString v = value.trimmed();
    if (v.isEmpty()) {
        return false;
    }
    static const QStringList genericLabels = {
        QStringLiteral("Spotify"),
        QStringLiteral("Amazon Music"),
        QStringLiteral("Apple Music"),
        QStringLiteral("YouTube Music"),
        QStringLiteral("TuneIn"),
        QStringLiteral("Pandora"),
        QStringLiteral("Deezer"),
        QStringLiteral("SoundCloud"),
        QStringLiteral("Qobuz"),
        QStringLiteral("Tidal"),
        QStringLiteral("Radio"),
        QStringLiteral("Line-In"),
        QStringLiteral("Audio Line-In"),
        QStringLiteral("TV"),
        QStringLiteral("x-rincon-mp3radio"),
    };
    for (const QString &label : genericLabels) {
        if (v.compare(label, Qt::CaseInsensitive) == 0) {
            return true;
        }
    }
    return false;
}

bool isBetterMetadata(const QString &candidate, const QString &current)
{
    const QString c = candidate.trimmed();
    const QString cur = current.trimmed();
    if (c.isEmpty()) {
        return false;
    }
    if (cur.isEmpty()) {
        return !isGenericSourceLabel(c);
    }
    if (isGenericSourceLabel(c) && !isGenericSourceLabel(cur)) {
        return false;
    }
    if (!isGenericSourceLabel(c) && isGenericSourceLabel(cur)) {
        return true;
    }
    const bool candidateLooksLikeUrl = looksLikeUrlOrUri(c);
    const bool currentLooksLikeUrl = looksLikeUrlOrUri(cur);
    if (candidateLooksLikeUrl && !currentLooksLikeUrl) {
        return false;
    }
    if (!candidateLooksLikeUrl && currentLooksLikeUrl) {
        return true;
    }
    return c != cur;
}

bool hasTrackLevelMetadata(const QString &artist, const QString &title)
{
    return !artist.trimmed().isEmpty()
        || (!title.trimmed().isEmpty() && !isGenericSourceLabel(title));
}

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
    refreshFavorites(host);
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

void SonosClient::refreshFavorites(const QString &hostOrUrl)
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty() || !m_zones.contains(host)) {
        return;
    }
    requestFavoritesPage(host, 0, {});
}

QVariantList SonosClient::zoneFavorites(const QString &hostOrUrl) const
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty() || !m_zones.contains(host)) {
        return {};
    }

    QVariantList favorites;
    for (const FavoriteEntry &entry : m_zones.value(host).favorites) {
        favorites.append(QVariantMap{
            { QStringLiteral("id"), entry.id },
            { QStringLiteral("label"), entry.label },
            { QStringLiteral("command"), entry.label },
        });
    }
    return favorites;
}

int SonosClient::favoritesRevision(const QString &hostOrUrl) const
{
    const QString host = normalizeHost(hostOrUrl);
    if (host.isEmpty() || !m_zones.contains(host)) {
        return 0;
    }
    return m_zones.value(host).favoritesRevision;
}

void SonosClient::playFavorite(const QString &hostOrUrl, const QString &favoriteKey)
{
    const QString host = normalizeHost(hostOrUrl);
    const QString key = favoriteKey.trimmed();
    if (host.isEmpty() || key.isEmpty() || !m_zones.contains(host)) {
        return;
    }

    const QList<FavoriteEntry> favorites = m_zones.value(host).favorites;
    const auto it = std::find_if(favorites.cbegin(), favorites.cend(),
                                 [&key](const FavoriteEntry &entry) {
                                     return favoriteKeyMatches(entry, key);
                                 });
    if (it == favorites.cend()) {
        qCWarning(lcSonos, "Favorite '%s' not found on %s", qUtf8Printable(key), qUtf8Printable(host));
        emit errorOccurred(host, QStringLiteral("Favorite not found: %1").arg(key));
        return;
    }

    qCInfo(lcSonos,
           "Playing favorite '%s' on %s (uri=%s, metadataSoapBytes=%d)",
           qUtf8Printable(it->label),
           qUtf8Printable(host),
           qUtf8Printable(it->uri),
           it->metadataSoap.size());

    setAvTransportUri(host, it->uri, it->metadata, it->metadataSoap, [this, host, label = it->label](bool ok) {
        if (!ok) {
            qCWarning(lcSonos, "Failed to start favorite '%s' on %s",
                      qUtf8Printable(label), qUtf8Printable(host));
            return;
        }
        startPlayback(host);
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

QString SonosClient::soapTagText(const QString &xml, const QString &localTagName)
{
    QString value = firstTagText(xml, localTagName);
    if (!value.isEmpty()) {
        return value;
    }

    const QString pattern = QStringLiteral("<(?:\\w+:)?%1\\b[^>]*>(.*?)</(?:\\w+:)?%1>")
                                .arg(QRegularExpression::escape(localTagName));
    QRegularExpression re(pattern,
                          QRegularExpression::DotMatchesEverythingOption
                              | QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch match = re.match(xml);
    if (match.hasMatch()) {
        return match.captured(1).trimmed();
    }
    return {};
}

QString SonosClient::decodeXmlEntitiesOnce(const QString &value)
{
    QString decoded = value;
    decoded.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
    decoded.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
    decoded.replace(QStringLiteral("&quot;"), QStringLiteral("\""));
    decoded.replace(QStringLiteral("&apos;"), QStringLiteral("'"));
    decoded.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    return decoded;
}

QString SonosClient::decodeXmlEntities(const QString &value)
{
    QString decoded = value;
    for (int i = 0; i < 3; ++i) {
        const QString next = decodeXmlEntitiesOnce(decoded);
        if (next == decoded) {
            break;
        }
        decoded = next;
    }
    return decoded;
}

QString SonosClient::normalizeSonosAlbumArtUrl(const QString &url)
{
    const QString trimmed = url.trimmed();
    if (trimmed.isEmpty() || !trimmed.contains(QStringLiteral("/getaa"))) {
        return trimmed;
    }

    QUrl artUrl(trimmed);
    if (!artUrl.isValid()) {
        return trimmed;
    }

    QUrlQuery query(artUrl);
    const QString streamUri = query.queryItemValue(QStringLiteral("u"), QUrl::FullyDecoded);
    if (streamUri.isEmpty()) {
        return trimmed;
    }

    query.removeAllQueryItems(QStringLiteral("u"));
    query.addQueryItem(QStringLiteral("u"), streamUri);
    artUrl.setQuery(query);
    return artUrl.toString(QUrl::FullyEncoded);
}

QString SonosClient::xmlEscape(const QString &value)
{
    QString escaped = value;
    escaped.replace(QLatin1Char('&'), QStringLiteral("&amp;"));
    escaped.replace(QLatin1Char('<'), QStringLiteral("&lt;"));
    escaped.replace(QLatin1Char('>'), QStringLiteral("&gt;"));
    escaped.replace(QLatin1Char('"'), QStringLiteral("&quot;"));
    escaped.replace(QLatin1Char('\''), QStringLiteral("&apos;"));
    return escaped;
}

QString SonosClient::parseMetaField(const QString &metadata, const QString &localTagName)
{
    if (metadata.isEmpty()) {
        return {};
    }

    const QString decoded = decodeXmlEntities(metadata);
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

bool SonosClient::favoriteKeyMatches(const FavoriteEntry &entry, const QString &favoriteKey)
{
    const QString key = favoriteKey.trimmed();
    if (key.isEmpty()) {
        return false;
    }
    if (!entry.id.isEmpty() && entry.id.compare(key, Qt::CaseInsensitive) == 0) {
        return true;
    }
    return entry.label.compare(key, Qt::CaseInsensitive) == 0;
}

QString SonosClient::buildFavoriteMetadata(const FavoriteEntry &entry)
{
    const QString itemClass = entry.itemClass.isEmpty()
        ? QStringLiteral("object.item.audioItem")
        : entry.itemClass;
    const QString protocolInfo = entry.resProtocolInfo.isEmpty()
        ? QStringLiteral("http-get:*:audio/mpeg:*")
        : entry.resProtocolInfo;
    return QStringLiteral(
               "<DIDL-Lite xmlns:dc=\"http://purl.org/dc/elements/1.1/\" "
               "xmlns:upnp=\"urn:schemas-upnp-org:metadata-1-0/upnp/\" "
               "xmlns:r=\"urn:schemas-rinconnetworks-com:metadata-1-0/\" "
               "xmlns=\"urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/\">"
               "<item id=\"%1\" parentID=\"FV:2\" restricted=\"true\">"
               "<dc:title>%2</dc:title>"
               "<upnp:class>%3</upnp:class>"
               "<res protocolInfo=\"%5\">%4</res>"
               "</item></DIDL-Lite>")
        .arg(xmlEscape(entry.id),
             xmlEscape(entry.label),
             xmlEscape(itemClass),
             xmlEscape(entry.uri),
             xmlEscape(protocolInfo));
}

QList<SonosClient::FavoriteEntry> SonosClient::parseFavoriteItems(const QString &didlXml)
{
    QList<FavoriteEntry> favorites;
    // Parse the Browse Result while it is still XML-escaped. Decoding the full
    // document even once turns encoded &lt;/item&gt; tags inside r:resMD into
    // literal </item>, which truncates item extraction and drops TuneIn metadata.
    const QString raw = didlXml.trimmed();
    if (raw.isEmpty()) {
        return favorites;
    }

    static const QRegularExpression itemRe(
        QStringLiteral("&lt;item\\b(.*?)&gt;(.*?)&lt;/item&gt;"),
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression idAttrRe(QStringLiteral("\\bid=&quot;([^&]+)&quot;"));
    static const QRegularExpression titleRe(
        QStringLiteral("&lt;(?:\\w+:)?title\\b.*?&gt;(.*?)&lt;/(?:\\w+:)?title&gt;"),
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression classRe(
        QStringLiteral("&lt;(?:\\w+:)?class\\b.*?&gt;(.*?)&lt;/(?:\\w+:)?class&gt;"),
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression resRe(
        QStringLiteral("&lt;res\\b(.*?)&gt;(.*?)&lt;/res&gt;"),
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression resMdRe(
        QStringLiteral("&lt;(?:\\w+:)?resMD\\b.*?&gt;(.*?)&lt;/(?:\\w+:)?resMD&gt;"),
        QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression protocolInfoRe(QStringLiteral("protocolInfo=&quot;([^&]+)&quot;"));

    auto it = itemRe.globalMatch(raw);
    while (it.hasNext()) {
        const QRegularExpressionMatch itemMatch = it.next();
        const QString attrs = itemMatch.captured(1);
        const QString body = itemMatch.captured(2);

        FavoriteEntry entry;
        const QRegularExpressionMatch idMatch = idAttrRe.match(attrs);
        if (idMatch.hasMatch()) {
            entry.id = idMatch.captured(1).trimmed();
        }

        const QRegularExpressionMatch titleMatch = titleRe.match(body);
        if (titleMatch.hasMatch()) {
            entry.label = decodeXmlEntitiesOnce(titleMatch.captured(1).trimmed());
        }

        const QRegularExpressionMatch classMatch = classRe.match(body);
        if (classMatch.hasMatch()) {
            entry.itemClass = decodeXmlEntitiesOnce(classMatch.captured(1).trimmed());
        }

        const QRegularExpressionMatch resMatch = resRe.match(body);
        if (resMatch.hasMatch()) {
            const QRegularExpressionMatch protocolMatch = protocolInfoRe.match(resMatch.captured(1));
            if (protocolMatch.hasMatch()) {
                entry.resProtocolInfo = decodeXmlEntitiesOnce(protocolMatch.captured(1).trimmed());
            }
            entry.uri = decodeXmlEntitiesOnce(resMatch.captured(2).trimmed());
        }

        const QRegularExpressionMatch resMdMatch = resMdRe.match(body);
        if (resMdMatch.hasMatch()) {
            // resMD in the Browse payload is double-encoded; Sonos expects the
            // single-encoded DIDL blob in SetAVTransportURI.
            entry.metadataSoap = decodeXmlEntitiesOnce(resMdMatch.captured(1).trimmed());
            entry.metadata = decodeXmlEntities(entry.metadataSoap);
        }

        if (!entry.label.isEmpty() && !entry.uri.isEmpty()) {
            if (entry.id.isEmpty()) {
                entry.id = QStringLiteral("FV:2/%1").arg(favorites.size() + 1);
            }
            if (entry.metadataSoap.isEmpty() && entry.metadata.isEmpty()) {
                entry.metadata = buildFavoriteMetadata(entry);
            }
            favorites.append(entry);
        }
    }

    return favorites;
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
    requestMediaInfo(host);
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
                     albumArt = normalizeSonosAlbumArtUrl(albumArt);
                     if (title.isEmpty() && !streamContent.isEmpty() && !isGenericSourceLabel(streamContent)) {
                         title = streamContent;
                     }
                     if (title.isEmpty() && !radioShow.isEmpty()) {
                         title = radioShow;
                     }
                     if (track.isEmpty()) {
                         if (!title.isEmpty()) {
                             track = title;
                         } else if (!streamContent.isEmpty() && !isGenericSourceLabel(streamContent)) {
                             track = streamContent;
                         }
                     }
                     if (looksLikeUrlOrUri(track)) {
                         if (!title.isEmpty()) {
                             track = title;
                         } else if (!streamContent.isEmpty() && !isGenericSourceLabel(streamContent)) {
                             track = streamContent;
                         } else if (!radioShow.isEmpty()) {
                             track = radioShow;
                         }
                     }
                     if (looksLikeUrlOrUri(title) || isGenericSourceLabel(title)) {
                         title.clear();
                     }

                     applyZoneUpdate(host, [title, artist, album, albumArt, track](ZoneData &zone) {
                         bool changed = false;
                         if (isBetterMetadata(title, zone.title)) {
                             zone.title = title;
                             changed = true;
                         }
                         if (isBetterMetadata(artist, zone.artist)) {
                             zone.artist = artist;
                             changed = true;
                         }
                         if (isBetterMetadata(album, zone.album)) {
                             zone.album = album;
                             changed = true;
                         }
                         if (isBetterMetadata(albumArt, zone.albumArtUrl)) {
                             zone.albumArtUrl = albumArt;
                             changed = true;
                         }
                         if (isBetterMetadata(track, zone.track)) {
                             zone.track = track;
                             changed = true;
                         }
                         return changed;
                     });
                 } else {
                     qCWarning(lcSonos, "GetPositionInfo failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                 }
             });
}

void SonosClient::requestMediaInfo(const QString &host)
{
    static const QByteArray body =
        "<u:GetMediaInfo xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">"
        "<InstanceID>0</InstanceID>"
        "</u:GetMediaInfo>";

    postSoap(host,
             QStringLiteral("/MediaRenderer/AVTransport/Control"),
             QByteArray("urn:schemas-upnp-org:service:AVTransport:1#GetMediaInfo"),
             body,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() != QNetworkReply::NoError) {
                     qCWarning(lcSonos, "GetMediaInfo failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                     return;
                 }

                 const QString xml = QString::fromUtf8(reply->readAll());
                 const QString uri = firstTagText(xml, QStringLiteral("CurrentURI"));
                 const QString metadata = firstTagText(xml, QStringLiteral("CurrentURIMetaData"));
                 QString stationTitle = parseMetaField(metadata, QStringLiteral("title"));
                 QString stationArt = parseMetaField(metadata, QStringLiteral("albumArtURI"));

                 if (!stationArt.isEmpty() && stationArt.startsWith('/')) {
                     stationArt = QStringLiteral("http://%1:1400%2").arg(host, stationArt);
                 }
                 stationArt = normalizeSonosAlbumArtUrl(stationArt);
                 if (looksLikeUrlOrUri(stationTitle) || isGenericSourceLabel(stationTitle)) {
                     stationTitle.clear();
                 }

                 applyZoneUpdate(host, [stationTitle, stationArt, uri](ZoneData &zone) {
                     bool changed = false;
                     const bool trackMetadataKnown = hasTrackLevelMetadata(zone.artist, zone.title);

                     // MediaInfo often carries radio station metadata/logo even when
                     // PositionInfo only has stream URLs. For Spotify and similar
                     // sources it can also report the service name ("Spotify") and
                     // overwrite the current track title on every other poll.
                     if (!trackMetadataKnown && isBetterMetadata(stationTitle, zone.title)) {
                         zone.title = stationTitle;
                         changed = true;
                     }
                     if (!trackMetadataKnown && isBetterMetadata(stationArt, zone.albumArtUrl)) {
                         zone.albumArtUrl = stationArt;
                         changed = true;
                     }

                     if (!zone.title.isEmpty() && isBetterMetadata(zone.title, zone.track)) {
                         zone.track = zone.title;
                         changed = true;
                     } else if (!uri.isEmpty() && !looksLikeUrlOrUri(uri) && isBetterMetadata(uri, zone.track)) {
                         zone.track = uri;
                         changed = true;
                     }

                     return changed;
                 });
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

void SonosClient::requestFavoritesPage(const QString &host,
                                       int startingIndex,
                                       QList<FavoriteEntry> accumulated)
{
    if (!m_zones.contains(host)) {
        return;
    }

    const QByteArray body = QStringLiteral(
                                "<u:Browse xmlns:u=\"urn:schemas-upnp-org:service:ContentDirectory:1\">"
                                "<ObjectID>FV:2</ObjectID>"
                                "<BrowseFlag>BrowseDirectChildren</BrowseFlag>"
                                "<Filter>*</Filter>"
                                "<StartingIndex>%1</StartingIndex>"
                                "<RequestedCount>100</RequestedCount>"
                                "<SortCriteria></SortCriteria>"
                                "</u:Browse>")
                                .arg(qMax(0, startingIndex))
                                .toUtf8();

    postSoap(host,
             QStringLiteral("/MediaServer/ContentDirectory/Control"),
             QByteArray("urn:schemas-upnp-org:service:ContentDirectory:1#Browse"),
             body,
             [this, host, startingIndex, accumulated](QNetworkReply *reply) mutable {
                 if (reply->error() != QNetworkReply::NoError) {
                     qCWarning(lcSonos, "Browse favorites failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                     emit errorOccurred(host, reply->errorString());
                     return;
                 }

                 const QString xml = QString::fromUtf8(reply->readAll());
                 const QString result = soapTagText(xml, QStringLiteral("Result"));
                 const QList<FavoriteEntry> pageEntries = parseFavoriteItems(result);
                 accumulated.append(pageEntries);

                 bool ok = false;
                 const int totalMatches = soapTagText(xml, QStringLiteral("TotalMatches")).toInt(&ok);
                 const int numberReturned = soapTagText(xml, QStringLiteral("NumberReturned")).toInt();
                 const int nextIndex = startingIndex + qMax(0, numberReturned);
                 if (ok && nextIndex < totalMatches) {
                     requestFavoritesPage(host, nextIndex, accumulated);
                     return;
                 }

                 if (!m_zones.contains(host)) {
                     return;
                 }
                 ZoneData &zone = m_zones[host];
                 bool unchanged = zone.favorites.size() == accumulated.size();
                 if (unchanged) {
                     for (int i = 0; i < accumulated.size(); ++i) {
                         if (zone.favorites.at(i).id != accumulated.at(i).id
                             || zone.favorites.at(i).label != accumulated.at(i).label
                             || zone.favorites.at(i).uri != accumulated.at(i).uri) {
                             unchanged = false;
                             break;
                         }
                     }
                 }
                 const bool firstLoad = zone.favoritesRevision == 0;
                 if (unchanged && !firstLoad) {
                     return;
                 }
                 zone.favorites = accumulated;
                 ++zone.favoritesRevision;
                 if (accumulated.isEmpty()) {
                     qCWarning(lcSonos,
                               "No favorites parsed from %s (TotalMatches=%d, resultBytes=%d)",
                               qUtf8Printable(host),
                               ok ? totalMatches : -1,
                               result.size());
                 } else {
                     qCInfo(lcSonos, "Loaded %d favorites from %s", accumulated.size(), qUtf8Printable(host));
                 }
                 emit zoneFavoritesUpdated(host);
             },
             QByteArray("Sonos/83.1-61210"));
}

void SonosClient::setAvTransportUri(const QString &host,
                                     const QString &uri,
                                     const QString &metadata,
                                     const QString &metadataSoap,
                                     const std::function<void(bool)> &onFinished)
{
    const QString metadataPayload = !metadataSoap.isEmpty()
        ? metadataSoap
        : xmlEscape(metadata);
    const QByteArray body = QStringLiteral(
                                "<u:SetAVTransportURI xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">"
                                "<InstanceID>0</InstanceID>"
                                "<CurrentURI>%1</CurrentURI>"
                                "<CurrentURIMetaData>%2</CurrentURIMetaData>"
                                "</u:SetAVTransportURI>")
                                .arg(xmlEscape(uri), metadataPayload)
                                .toUtf8();

    postSoap(host,
             QStringLiteral("/MediaRenderer/AVTransport/Control"),
             QByteArray("urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"),
             body,
             [this, host, onFinished](QNetworkReply *reply) {
                 if (reply->error() != QNetworkReply::NoError) {
                     qCWarning(lcSonos, "SetAVTransportURI failed for %s: %s",
                               qUtf8Printable(host), qUtf8Printable(reply->errorString()));
                     emit errorOccurred(host, reply->errorString());
                     onFinished(false);
                     return;
                 }
                 onFinished(true);
             });
}

void SonosClient::startPlayback(const QString &host)
{
    static const QByteArray body =
        "<u:Play xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\">"
        "<InstanceID>0</InstanceID><Speed>1</Speed>"
        "</u:Play>";

    postSoap(host,
             QStringLiteral("/MediaRenderer/AVTransport/Control"),
             QByteArray("urn:schemas-upnp-org:service:AVTransport:1#Play"),
             body,
             [this, host](QNetworkReply *reply) {
                 if (reply->error() != QNetworkReply::NoError) {
                     emit errorOccurred(host, reply->errorString());
                     return;
                 }
                 applyZoneUpdate(host, [](ZoneData &zone) {
                     if (zone.state == QStringLiteral("PLAYING")) {
                         return false;
                     }
                     zone.state = QStringLiteral("PLAYING");
                     return true;
                 });
             });
}

void SonosClient::postSoap(const QString &host,
                           const QString &servicePath,
                           const QByteArray &soapAction,
                           const QByteArray &body,
                           const std::function<void(QNetworkReply *)> &onFinished,
                           const QByteArray &userAgent)
{
    QNetworkRequest request(QUrl(soapEndpoint(host, servicePath)));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("text/xml; charset=utf-8"));
    request.setRawHeader("SOAPACTION", QByteArray("\"") + soapAction + QByteArray("\""));
    request.setRawHeader("User-Agent", userAgent);

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
