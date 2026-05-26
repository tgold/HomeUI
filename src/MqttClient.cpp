#include "MqttClient.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QMqttClient>
#include <QMqttSubscription>
#include <QMqttTopicName>
#include <QSysInfo>
#include <QUrl>

namespace {
constexpr int ReconnectDelayMs = 5000;
constexpr int HeartbeatIntervalMs = 30000;
}

MqttClient::MqttClient(QObject *parent)
    : QObject(parent)
{
    m_clientId = defaultClientId();
    m_statusText = QStringLiteral("MQTT not connected");

    m_reconnectTimer.setSingleShot(true);
    m_reconnectTimer.setInterval(ReconnectDelayMs);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &MqttClient::connectToBroker);

    m_heartbeatTimer.setInterval(HeartbeatIntervalMs);
    connect(&m_heartbeatTimer, &QTimer::timeout, this, &MqttClient::publishStatus);

    rebuildClient();
}

MqttClient::~MqttClient()
{
    if (m_client && m_connected) {
        m_client->publish(QMqttTopicName(statusTopic()), statusPayload(false), 1, true);
        m_client->disconnectFromHost();
    }
}

bool MqttClient::enabled() const
{
    return m_enabled;
}

void MqttClient::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    if (!m_enabled) {
        stop();
        setStatusText(QStringLiteral("MQTT disabled"));
    }
    emit enabledChanged();
}

QString MqttClient::brokerUrl() const
{
    return m_brokerUrl;
}

void MqttClient::setBrokerUrl(const QString &brokerUrl)
{
    const QString trimmed = brokerUrl.trimmed();
    if (m_brokerUrl == trimmed) {
        return;
    }

    m_brokerUrl = trimmed;
    m_host.clear();
    m_port = 1883;

    if (!trimmed.isEmpty()) {
        QString candidate = trimmed;
        if (!candidate.contains(QStringLiteral("://"))) {
            candidate.prepend(QStringLiteral("mqtt://"));
        }
        const QUrl url(candidate);
        if (url.isValid() && !url.host().isEmpty()) {
            m_host = url.host();
            if (url.port() > 0) {
                m_port = static_cast<quint16>(url.port());
            }
            if (m_username.isEmpty() && !url.userName().isEmpty()) {
                m_username = url.userName();
            }
            if (m_password.isEmpty() && !url.password().isEmpty()) {
                m_password = url.password();
            }
        }
    }

    emit brokerUrlChanged();
    applyConnectionParams();
}

QString MqttClient::username() const
{
    return m_username;
}

void MqttClient::setUsername(const QString &username)
{
    m_username = username;
    applyConnectionParams();
}

QString MqttClient::password() const
{
    return m_password;
}

void MqttClient::setPassword(const QString &password)
{
    m_password = password;
    applyConnectionParams();
}

QString MqttClient::clientId() const
{
    return m_clientId;
}

void MqttClient::setClientId(const QString &clientId)
{
    const QString trimmed = clientId.trimmed();
    if (m_clientId == trimmed) {
        return;
    }
    m_clientId = trimmed.isEmpty() ? defaultClientId() : trimmed;
    emit clientIdChanged();
    applyConnectionParams();
}

QString MqttClient::panelId() const
{
    return m_panelId;
}

void MqttClient::setPanelId(const QString &panelId)
{
    const QString trimmed = panelId.trimmed();
    const QString next = trimmed.isEmpty() ? QStringLiteral("main") : trimmed;
    if (m_panelId == next) {
        return;
    }
    m_panelId = next;
    emit panelIdChanged();
    applyConnectionParams();
}

bool MqttClient::connected() const
{
    return m_connected;
}

QString MqttClient::statusText() const
{
    return m_statusText;
}

QString MqttClient::lastError() const
{
    return m_lastError;
}

int MqttClient::messageRevision() const
{
    return m_messageRevision;
}

void MqttClient::start()
{
    if (!m_enabled) {
        setStatusText(QStringLiteral("MQTT disabled"));
        return;
    }
    if (m_host.isEmpty()) {
        setStatusText(QStringLiteral("MQTT broker not configured"));
        return;
    }
    connectToBroker();
}

void MqttClient::stop()
{
    m_reconnectTimer.stop();
    m_heartbeatTimer.stop();
    if (m_client) {
        if (m_connected) {
            m_client->publish(QMqttTopicName(statusTopic()), statusPayload(false), 1, true);
        }
        m_client->disconnectFromHost();
    }
    setConnectedState(false);
}

void MqttClient::subscribe(const QString &topic, int qos)
{
    if (topic.isEmpty() || !m_client) {
        return;
    }
    if (m_subscriptions.contains(topic) && m_subscriptions.value(topic)) {
        return;
    }
    QMqttSubscription *subscription = m_client->subscribe(QMqttTopicFilter(topic), static_cast<quint8>(qos));
    if (!subscription) {
        setLastError(QStringLiteral("Failed to subscribe to %1").arg(topic));
        return;
    }
    m_subscriptions.insert(topic, subscription);
}

void MqttClient::unsubscribe(const QString &topic)
{
    if (!m_subscriptions.contains(topic)) {
        return;
    }
    QPointer<QMqttSubscription> subscription = m_subscriptions.take(topic);
    if (subscription) {
        subscription->unsubscribe();
    }
}

void MqttClient::publish(const QString &topic, const QString &payload, int qos, bool retain)
{
    if (topic.isEmpty() || !m_client || !m_connected) {
        return;
    }
    m_client->publish(QMqttTopicName(topic), payload.toUtf8(), static_cast<quint8>(qos), retain);
}

QString MqttClient::messageFor(const QString &topic, const QString &fallback) const
{
    if (topic.isEmpty()) {
        return fallback;
    }
    return m_messages.value(topic, fallback);
}

void MqttClient::setStatusField(const QString &key, const QVariant &value)
{
    if (key.isEmpty()) {
        return;
    }
    m_statusFields.insert(key, QJsonValue::fromVariant(value));
    if (m_connected) {
        publishStatus();
    }
}

void MqttClient::publishStatus()
{
    if (!m_client || !m_connected) {
        return;
    }
    m_client->publish(QMqttTopicName(statusTopic()), statusPayload(true), 1, true);
}

void MqttClient::rebuildClient()
{
    if (m_client) {
        m_client->deleteLater();
        m_client = nullptr;
    }
    m_subscriptions.clear();

    m_client = new QMqttClient(this);
    connect(m_client, &QMqttClient::connected, this, [this]() {
        setConnectedState(true);
        setStatusText(QStringLiteral("MQTT connected to %1:%2").arg(m_host).arg(m_port));
        setLastError({});

        m_statusFields.insert(QStringLiteral("mqttConnected"), true);
        publishStatus();
        m_heartbeatTimer.start();

        const QString prefix = QStringLiteral("home/panel/%1/").arg(m_panelId);
        const QStringList topics = {
            prefix + QStringLiteral("page/set"),
            prefix + QStringLiteral("brightness/set"),
            prefix + QStringLiteral("reload"),
        };
        for (const QString &topic : topics) {
            subscribe(topic, 0);
        }

        emit messageRevisionChanged();
    });
    connect(m_client, &QMqttClient::disconnected, this, [this]() {
        m_heartbeatTimer.stop();
        setConnectedState(false);
        setStatusText(QStringLiteral("MQTT disconnected"));
        scheduleReconnect();
    });
    connect(m_client, &QMqttClient::errorChanged, this, [this](QMqttClient::ClientError error) {
        if (error == QMqttClient::NoError) {
            setLastError({});
            return;
        }
        setLastError(QStringLiteral("MQTT error code %1").arg(static_cast<int>(error)));
        setStatusText(QStringLiteral("MQTT error"));
    });
    connect(m_client, &QMqttClient::messageReceived, this,
            [this](const QByteArray &message, const QMqttTopicName &topic) {
                handleMessage(topic.name(), message);
            });

    applyConnectionParams();
}

void MqttClient::applyConnectionParams()
{
    if (!m_client) {
        return;
    }
    m_client->setHostname(m_host);
    m_client->setPort(m_port);
    m_client->setUsername(m_username);
    m_client->setPassword(m_password);
    m_client->setClientId(m_clientId);

    const QByteArray will = statusPayload(false);
    // QMqttClient activates the Last Will implicitly when willTopic is set
    // to a non-empty value, so no explicit "enabled" toggle is needed.
    m_client->setWillTopic(statusTopic());
    m_client->setWillMessage(will);
    m_client->setWillQoS(1);
    m_client->setWillRetain(true);
}

void MqttClient::connectToBroker()
{
    if (!m_enabled || !m_client || m_host.isEmpty()) {
        return;
    }
    if (m_client->state() != QMqttClient::Disconnected) {
        return;
    }
    setStatusText(QStringLiteral("Connecting MQTT %1:%2").arg(m_host).arg(m_port));
    m_client->connectToHost();
}

void MqttClient::scheduleReconnect()
{
    if (m_enabled && !m_reconnectTimer.isActive() && !m_host.isEmpty()) {
        m_reconnectTimer.start();
    }
}

void MqttClient::handleMessage(const QString &topic, const QByteArray &payload)
{
    const QString text = QString::fromUtf8(payload);
    m_messages.insert(topic, text);
    ++m_messageRevision;
    emit messageRevisionChanged();
    emit messageReceived(topic, text);

    const QString prefix = QStringLiteral("home/panel/%1/").arg(m_panelId);
    if (topic.startsWith(prefix)) {
        handlePanelControlTopic(topic.mid(prefix.size()), payload);
    }
}

void MqttClient::handlePanelControlTopic(const QString &subTopic, const QByteArray &payload)
{
    const QString text = QString::fromUtf8(payload).trimmed();
    if (subTopic == QStringLiteral("page/set")) {
        emit pageSetRequested(text);
    } else if (subTopic == QStringLiteral("brightness/set")) {
        bool ok = false;
        const int level = text.toInt(&ok);
        if (ok) {
            emit brightnessRequested(level);
        }
    } else if (subTopic == QStringLiteral("reload")) {
        emit reloadRequested();
    }
}

QString MqttClient::statusTopic() const
{
    return QStringLiteral("home/panel/%1/status").arg(m_panelId);
}

QByteArray MqttClient::statusPayload(bool online) const
{
    QJsonObject payload = m_statusFields;
    payload.insert(QStringLiteral("online"), online);
    return QJsonDocument(payload).toJson(QJsonDocument::Compact);
}

void MqttClient::setConnectedState(bool connected)
{
    if (m_connected == connected) {
        return;
    }
    m_connected = connected;
    emit connectedChanged();
}

void MqttClient::setStatusText(const QString &statusText)
{
    if (m_statusText == statusText) {
        return;
    }
    m_statusText = statusText;
    emit statusTextChanged();
}

void MqttClient::setLastError(const QString &lastError)
{
    if (m_lastError == lastError) {
        return;
    }
    m_lastError = lastError;
    emit lastErrorChanged();
}

QString MqttClient::defaultClientId()
{
    return QStringLiteral("homeui-%1-%2")
        .arg(QSysInfo::machineHostName())
        .arg(QString::number(QCoreApplication::applicationPid()));
}
