#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QSet>
#include <QUrl>

class InfluxHistoryClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(QString token READ token WRITE setToken NOTIFY tokenChanged)
    Q_PROPERTY(QString org READ org WRITE setOrg NOTIFY orgChanged)
    Q_PROPERTY(QString bucket READ bucket WRITE setBucket NOTIFY bucketChanged)
    Q_PROPERTY(bool configured READ configured NOTIFY configuredChanged)

public:
    explicit InfluxHistoryClient(QObject *parent = nullptr);

    QString baseUrl() const;
    void setBaseUrl(const QString &baseUrl);

    QString token() const;
    void setToken(const QString &token);

    QString org() const;
    void setOrg(const QString &org);

    QString bucket() const;
    void setBucket(const QString &bucket);

    bool configured() const;

    Q_INVOKABLE void fetchDailyMeans(const QString &itemName,
                                     const QString &measurement,
                                     int days,
                                     bool filterByItemTag = false);

signals:
    void baseUrlChanged();
    void tokenChanged();
    void orgChanged();
    void bucketChanged();
    void configuredChanged();
    void dailyMeansReady(const QString &itemName, const QVariantList &values, const QString &error);

private:
    QString buildFluxQuery(const QString &itemName,
                           const QString &measurement,
                           int days,
                           bool filterByItemTag) const;
    static QString escapeFluxString(const QString &value);
    static QVariantList parseAnnotatedCsv(const QByteArray &body, QString *errorOut);
    void finishRequest(const QString &itemName, QNetworkReply *reply);

    QNetworkAccessManager m_network;
    QUrl m_baseUrl;
    QString m_token;
    QString m_org;
    QString m_bucket;
    QSet<QString> m_inFlight;
};
