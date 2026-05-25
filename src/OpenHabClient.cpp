#include "OpenHabClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QProcessEnvironment>

namespace {
constexpr int EventReconnectDelayMs = 5000;

QString normalizedState(const QString &state)
{
    if (state == QStringLiteral("NULL") || state == QStringLiteral("UNDEF")) {
        return {};
    }

    return state;
}

bool stateLooksOn(const QString &state)
{
    const QString normalized = state.trimmed().toUpper();
    if (normalized == QStringLiteral("ON") || normalized == QStringLiteral("OPEN") || normalized == QStringLiteral("DOWN")) {
        return true;
    }

    bool ok = false;
    const double number = normalized.split(QLatin1Char(' ')).first().toDouble(&ok);
    return ok && number > 0.0;
}
}

OpenHabClient::OpenHabClient(QObject *parent)
    : QObject(parent)
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    setBaseUrl(env.value(QStringLiteral("HOMEUI_OPENHAB_URL"), QStringLiteral("http://openhab:8080")));
    setAccessToken(env.value(QStringLiteral("HOMEUI_OPENHAB_TOKEN")));
    setStatusText(QStringLiteral("OpenHAB not connected"));

    m_eventReconnectTimer.setInterval(EventReconnectDelayMs);
    m_eventReconnectTimer.setSingleShot(true);
    connect(&m_eventReconnectTimer, &QTimer::timeout, this, &OpenHabClient::connectEventStream);
}

OpenHabClient::~OpenHabClient()
{
    if (m_eventReply) {
        m_eventReply->abort();
    }
}

QString OpenHabClient::baseUrl() const
{
    return m_baseUrl.toString(QUrl::RemoveTrailingSlash);
}

void OpenHabClient::setBaseUrl(const QString &baseUrl)
{
    QUrl parsed(baseUrl.trimmed());
    if (!parsed.isValid() || parsed.scheme().isEmpty() || parsed.host().isEmpty()) {
        parsed = QUrl(QStringLiteral("http://openhab:8080"));
    }

    if (m_baseUrl == parsed) {
        return;
    }

    m_baseUrl = parsed;
    emit baseUrlChanged();
}

bool OpenHabClient::enabled() const
{
    return m_enabled;
}

void OpenHabClient::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }

    m_enabled = enabled;
    if (!m_enabled) {
        m_eventReconnectTimer.stop();
        if (m_eventReply) {
            m_eventReply->abort();
        }
        setConnected(false);
        setEventStreamConnected(false);
        setStatusText(QStringLiteral("OpenHAB disabled"));
    }

    emit enabledChanged();
}

bool OpenHabClient::connected() const
{
    return m_connected;
}

bool OpenHabClient::eventStreamConnected() const
{
    return m_eventStreamConnected;
}

QString OpenHabClient::statusText() const
{
    return m_statusText;
}

QString OpenHabClient::lastError() const
{
    return m_lastError;
}

int OpenHabClient::itemCount() const
{
    return m_itemStates.size();
}

int OpenHabClient::stateRevision() const
{
    return m_stateRevision;
}

void OpenHabClient::setAccessToken(const QString &accessToken)
{
    m_accessToken = accessToken.trimmed();
}

QString OpenHabClient::itemState(const QString &itemName, const QString &fallback) const
{
    if (itemName.isEmpty()) {
        return fallback;
    }

    const QString state = normalizedState(m_itemStates.value(itemName));
    return state.isEmpty() ? fallback : state;
}

bool OpenHabClient::itemIsOn(const QString &itemName, bool fallback) const
{
    if (itemName.isEmpty() || !m_itemStates.contains(itemName)) {
        return fallback;
    }

    return stateLooksOn(m_itemStates.value(itemName));
}

void OpenHabClient::refreshItems()
{
    if (!m_enabled) {
        return;
    }

    setStatusText(QStringLiteral("Loading OpenHAB items"));
    QNetworkReply *reply = m_network.get(makeRequest(QStringLiteral("/rest/items")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            setConnected(false);
            setLastError(reply->errorString());
            setStatusText(QStringLiteral("OpenHAB item load failed"));
            return;
        }

        parseItemsResponse(reply->readAll());
        setConnected(true);
        setLastError({});
        setStatusText(QStringLiteral("OpenHAB connected"));
    });
}

void OpenHabClient::reconnectEvents()
{
    if (m_eventReply) {
        m_eventReply->abort();
        return;
    }

    connectEventStream();
}

void OpenHabClient::sendCommand(const QString &itemName, const QString &command)
{
    if (!m_enabled || itemName.isEmpty() || command.isEmpty()) {
        return;
    }

    const QString encodedItem = QString::fromUtf8(QUrl::toPercentEncoding(itemName));
    QNetworkRequest request = makeRequest(QStringLiteral("/rest/items/%1").arg(encodedItem), "text/plain");
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("text/plain"));

    QNetworkReply *reply = m_network.post(request, command.toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply, itemName, command]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            setLastError(QStringLiteral("%1: %2").arg(itemName, reply->errorString()));
            setStatusText(QStringLiteral("OpenHAB command failed"));
            return;
        }

        // Optimistically update the tapped tile while the event stream catches up.
        updateItemState(itemName, command);
        setLastError({});
        setStatusText(QStringLiteral("Command sent: %1").arg(itemName));
    });
}

void OpenHabClient::start()
{
    if (!m_enabled) {
        return;
    }

    refreshItems();
    connectEventStream();
}

QNetworkRequest OpenHabClient::makeRequest(const QString &path, const QByteArray &acceptHeader) const
{
    QNetworkRequest request(makeUrl(path));
    request.setRawHeader("Accept", acceptHeader);
    request.setRawHeader("User-Agent", "HomeUI/0.1");
    if (!m_accessToken.isEmpty()) {
        request.setRawHeader("Authorization", QByteArray("Bearer ") + m_accessToken.toUtf8());
    }
    return request;
}

QUrl OpenHabClient::makeUrl(const QString &path) const
{
    QUrl url = m_baseUrl;
    QString basePath = url.path();
    if (basePath.endsWith(QLatin1Char('/'))) {
        basePath.chop(1);
    }
    url.setPath(basePath + path);
    return url;
}

void OpenHabClient::setConnected(bool connected)
{
    if (m_connected == connected) {
        return;
    }

    m_connected = connected;
    emit connectedChanged();
}

void OpenHabClient::setEventStreamConnected(bool connected)
{
    if (m_eventStreamConnected == connected) {
        return;
    }

    m_eventStreamConnected = connected;
    emit eventStreamConnectedChanged();
}

void OpenHabClient::setStatusText(const QString &statusText)
{
    if (m_statusText == statusText) {
        return;
    }

    m_statusText = statusText;
    emit statusTextChanged();
}

void OpenHabClient::setLastError(const QString &lastError)
{
    if (m_lastError == lastError) {
        return;
    }

    m_lastError = lastError;
    emit lastErrorChanged();
}

void OpenHabClient::updateItemState(const QString &itemName, const QString &state)
{
    if (itemName.isEmpty() || m_itemStates.value(itemName) == state) {
        return;
    }

    const bool itemWasKnown = m_itemStates.contains(itemName);
    m_itemStates.insert(itemName, state);
    ++m_stateRevision;
    emit stateRevisionChanged();
    emit itemStateChanged(itemName, state);
    if (!itemWasKnown) {
        emit itemCountChanged();
    }
}

void OpenHabClient::parseItemsResponse(const QByteArray &body)
{
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(body, &error);
    if (error.error != QJsonParseError::NoError || !doc.isArray()) {
        setLastError(QStringLiteral("OpenHAB items response was not JSON"));
        return;
    }

    int changed = 0;
    const QJsonArray items = doc.array();
    for (const QJsonValue &value : items) {
        const QJsonObject item = value.toObject();
        const QString name = item.value(QStringLiteral("name")).toString();
        const QString state = item.value(QStringLiteral("state")).toString();
        if (name.isEmpty()) {
            continue;
        }

        if (!m_itemStates.contains(name) || m_itemStates.value(name) != state) {
            m_itemStates.insert(name, state);
            emit itemStateChanged(name, state);
            ++changed;
        }
    }

    if (changed > 0) {
        ++m_stateRevision;
        emit stateRevisionChanged();
    }
    emit itemCountChanged();
}

void OpenHabClient::connectEventStream()
{
    if (!m_enabled || m_eventReply) {
        return;
    }

    setStatusText(QStringLiteral("Connecting OpenHAB events"));
    QNetworkRequest request = makeRequest(QStringLiteral("/rest/events?topics=openhab/items/*"), "text/event-stream");
    request.setRawHeader("Cache-Control", "no-cache");

    m_eventReply = m_network.get(request);
    connect(m_eventReply, &QNetworkReply::metaDataChanged, this, [this]() {
        if (!m_eventReply) {
            return;
        }

        const int status = m_eventReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status >= 200 && status < 300) {
            setEventStreamConnected(true);
            setConnected(true);
            setStatusText(QStringLiteral("OpenHAB event stream connected"));
        }
    });
    connect(m_eventReply, &QIODevice::readyRead, this, [this]() {
        if (m_eventReply) {
            handleEventBytes(m_eventReply->readAll());
        }
    });
    connect(m_eventReply, &QNetworkReply::finished, this, [this]() {
        if (!m_eventReply) {
            return;
        }

        const QNetworkReply::NetworkError error = m_eventReply->error();
        const QString errorString = m_eventReply->errorString();
        m_eventReply->deleteLater();
        m_eventReply = nullptr;
        setEventStreamConnected(false);

        if (m_enabled && error != QNetworkReply::OperationCanceledError) {
            if (error != QNetworkReply::NoError) {
                setLastError(errorString);
                setStatusText(QStringLiteral("OpenHAB event stream disconnected"));
            }
            scheduleEventReconnect();
        }
    });
}

void OpenHabClient::scheduleEventReconnect()
{
    if (m_enabled && !m_eventReconnectTimer.isActive()) {
        m_eventReconnectTimer.start();
    }
}

void OpenHabClient::handleEventBytes(const QByteArray &bytes)
{
    m_eventBuffer.append(bytes);

    while (true) {
        int newline = m_eventBuffer.indexOf('\n');
        if (newline < 0) {
            break;
        }

        QByteArray line = m_eventBuffer.left(newline);
        m_eventBuffer.remove(0, newline + 1);
        if (line.endsWith('\r')) {
            line.chop(1);
        }

        if (line.isEmpty()) {
            dispatchEvent();
        } else if (line.startsWith("data:")) {
            QByteArray data = line.mid(5).trimmed();
            if (!m_currentEventData.isEmpty()) {
                m_currentEventData.append('\n');
            }
            m_currentEventData.append(data);
        }
    }
}

void OpenHabClient::dispatchEvent()
{
    if (m_currentEventData.isEmpty()) {
        return;
    }

    applyEventData(m_currentEventData);
    m_currentEventData.clear();
}

void OpenHabClient::applyEventData(const QByteArray &data)
{
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject()) {
        return;
    }

    const QJsonObject event = doc.object();
    const QString topic = event.value(QStringLiteral("topic")).toString();
    const QStringList topicParts = topic.split(QLatin1Char('/'));
    if (topicParts.size() < 3 || topicParts.at(0) != QStringLiteral("openhab") || topicParts.at(1) != QStringLiteral("items")) {
        return;
    }

    const QString itemName = topicParts.at(2);
    const QString state = stateValueFromPayload(event.value(QStringLiteral("payload")).toString().toUtf8());
    if (!state.isEmpty()) {
        updateItemState(itemName, state);
    }
}

QString OpenHabClient::stateValueFromPayload(const QByteArray &payload)
{
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(payload, &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject()) {
        return {};
    }

    const QJsonObject object = doc.object();
    const QJsonValue value = object.value(QStringLiteral("value"));
    if (value.isString()) {
        return value.toString();
    }
    if (value.isDouble()) {
        return QString::number(value.toDouble());
    }

    const QJsonValue state = object.value(QStringLiteral("state"));
    if (state.isString()) {
        return state.toString();
    }

    return {};
}
