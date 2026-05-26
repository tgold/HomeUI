#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QTimer>
#include <QVariant>

class QMqttClient;
class QMqttSubscription;

class MqttClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString brokerUrl READ brokerUrl WRITE setBrokerUrl NOTIFY brokerUrlChanged)
    Q_PROPERTY(QString clientId READ clientId WRITE setClientId NOTIFY clientIdChanged)
    Q_PROPERTY(QString panelId READ panelId WRITE setPanelId NOTIFY panelIdChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int messageRevision READ messageRevision NOTIFY messageRevisionChanged)

public:
    explicit MqttClient(QObject *parent = nullptr);
    ~MqttClient() override;

    bool enabled() const;
    void setEnabled(bool enabled);

    QString brokerUrl() const;
    void setBrokerUrl(const QString &brokerUrl);

    QString username() const;
    void setUsername(const QString &username);

    QString password() const;
    void setPassword(const QString &password);

    QString clientId() const;
    void setClientId(const QString &clientId);

    QString panelId() const;
    void setPanelId(const QString &panelId);

    bool connected() const;
    QString statusText() const;
    QString lastError() const;
    int messageRevision() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void subscribe(const QString &topic, int qos = 0);
    Q_INVOKABLE void unsubscribe(const QString &topic);
    Q_INVOKABLE void publish(const QString &topic, const QString &payload, int qos = 0, bool retain = false);
    Q_INVOKABLE QString messageFor(const QString &topic, const QString &fallback = QString()) const;
    Q_INVOKABLE void setStatusField(const QString &key, const QVariant &value);
    Q_INVOKABLE void publishStatus();

signals:
    void enabledChanged();
    void brokerUrlChanged();
    void clientIdChanged();
    void panelIdChanged();
    void connectedChanged();
    void statusTextChanged();
    void lastErrorChanged();
    void messageRevisionChanged();
    void messageReceived(const QString &topic, const QString &payload);
    void pageSetRequested(const QString &page);
    void brightnessRequested(int percent);
    void reloadRequested();

private:
    void rebuildClient();
    void applyConnectionParams();
    void connectToBroker();
    void scheduleReconnect();
    void handleMessage(const QString &topic, const QByteArray &payload);
    void handlePanelControlTopic(const QString &subTopic, const QByteArray &payload);
    QString statusTopic() const;
    QByteArray statusPayload(bool online) const;
    void setConnectedState(bool connected);
    void setStatusText(const QString &statusText);
    void setLastError(const QString &lastError);
    static QString defaultClientId();

    QMqttClient *m_client = nullptr;
    bool m_enabled = true;
    QString m_host;
    quint16 m_port = 1883;
    QString m_username;
    QString m_password;
    QString m_clientId;
    QString m_panelId = QStringLiteral("main");
    QString m_brokerUrl;
    bool m_connected = false;
    QString m_statusText;
    QString m_lastError;
    QHash<QString, QString> m_messages;
    QJsonObject m_statusFields;
    int m_messageRevision = 0;
    QTimer m_reconnectTimer;
    QTimer m_heartbeatTimer;
    QHash<QString, QPointer<QMqttSubscription>> m_subscriptions;
};
