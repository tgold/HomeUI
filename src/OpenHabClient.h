#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QTimer>
#include <QUrl>

class OpenHabClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool eventStreamConnected READ eventStreamConnected NOTIFY eventStreamConnectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int itemCount READ itemCount NOTIFY itemCountChanged)
    Q_PROPERTY(int stateRevision READ stateRevision NOTIFY stateRevisionChanged)

public:
    explicit OpenHabClient(QObject *parent = nullptr);
    ~OpenHabClient() override;

    QString baseUrl() const;
    void setBaseUrl(const QString &baseUrl);

    bool enabled() const;
    void setEnabled(bool enabled);

    bool connected() const;
    bool eventStreamConnected() const;
    QString statusText() const;
    QString lastError() const;
    int itemCount() const;
    int stateRevision() const;

    void setAccessToken(const QString &accessToken);
    Q_INVOKABLE QString itemState(const QString &itemName, const QString &fallback = QString()) const;
    Q_INVOKABLE bool itemIsOn(const QString &itemName, bool fallback = false) const;
    Q_INVOKABLE void refreshItems();
    Q_INVOKABLE void reconnectEvents();
    Q_INVOKABLE void sendCommand(const QString &itemName, const QString &command);
    Q_INVOKABLE void start();

signals:
    void baseUrlChanged();
    void enabledChanged();
    void connectedChanged();
    void eventStreamConnectedChanged();
    void statusTextChanged();
    void lastErrorChanged();
    void itemCountChanged();
    void stateRevisionChanged();
    void itemStateChanged(const QString &itemName, const QString &state);

private:
    QNetworkRequest makeRequest(const QString &path, const QByteArray &acceptHeader = "application/json") const;
    QUrl makeUrl(const QString &path) const;
    void setConnected(bool connected);
    void setEventStreamConnected(bool connected);
    void setStatusText(const QString &statusText);
    void setLastError(const QString &lastError);
    void updateItemState(const QString &itemName, const QString &state);
    void parseItemsResponse(const QByteArray &body);
    void connectEventStream();
    void scheduleEventReconnect();
    void handleEventBytes(const QByteArray &bytes);
    void dispatchEvent();
    void applyEventData(const QByteArray &data);
    static QString stateValueFromPayload(const QByteArray &payload);

    QNetworkAccessManager m_network;
    QUrl m_baseUrl;
    QString m_accessToken;
    bool m_enabled = true;
    bool m_connected = false;
    bool m_eventStreamConnected = false;
    QString m_statusText;
    QString m_lastError;
    QHash<QString, QString> m_itemStates;
    int m_stateRevision = 0;
    QNetworkReply *m_eventReply = nullptr;
    QByteArray m_eventBuffer;
    QByteArray m_currentEventData;
    QTimer m_eventReconnectTimer;
};
