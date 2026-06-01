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
    Q_PROPERTY(QString user READ user WRITE setUser NOTIFY userChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY passwordChanged)
    Q_PROPERTY(QString org READ org WRITE setOrg NOTIFY orgChanged)
    Q_PROPERTY(QString bucket READ bucket WRITE setBucket NOTIFY bucketChanged)
    Q_PROPERTY(QString database READ database WRITE setDatabase NOTIFY databaseChanged)
    Q_PROPERTY(QString retentionPolicy READ retentionPolicy WRITE setRetentionPolicy NOTIFY retentionPolicyChanged)
    Q_PROPERTY(bool configured READ configured NOTIFY configuredChanged)
    Q_PROPERTY(bool usesInfluxV2 READ usesInfluxV2 NOTIFY configuredChanged)

public:
    explicit InfluxHistoryClient(QObject *parent = nullptr);

    QString baseUrl() const;
    void setBaseUrl(const QString &baseUrl);

    QString token() const;
    void setToken(const QString &token);

    QString user() const;
    void setUser(const QString &user);

    QString password() const;
    void setPassword(const QString &password);

    QString org() const;
    void setOrg(const QString &org);

    QString bucket() const;
    void setBucket(const QString &bucket);

    QString database() const;
    void setDatabase(const QString &database);

    QString retentionPolicy() const;
    void setRetentionPolicy(const QString &retentionPolicy);

    bool configured() const;
    bool usesInfluxV2() const;

    Q_INVOKABLE void fetchDailyMeans(const QString &itemName,
                                     const QString &measurement,
                                     int days,
                                     bool filterByItemTag = false);

signals:
    void baseUrlChanged();
    void tokenChanged();
    void userChanged();
    void passwordChanged();
    void orgChanged();
    void bucketChanged();
    void databaseChanged();
    void retentionPolicyChanged();
    void configuredChanged();
    void dailyMeansReady(const QString &itemName, const QVariantList &values, const QString &error);

private:
    QString databaseName() const;
    QString buildFluxQuery(const QString &itemName,
                           const QString &measurement,
                           int days,
                           bool filterByItemTag) const;
    QString buildInfluxQlQuery(const QString &itemName,
                               const QString &measurement,
                               int days,
                               bool filterByItemTag) const;
    static QString escapeFluxString(const QString &value);
    static QString escapeInfluxQlIdent(const QString &value);
    static QString escapeInfluxQlString(const QString &value);
    static QVariantList parseAnnotatedCsv(const QByteArray &body, QString *errorOut);
    static bool parseInfluxTimestamp(const QJsonValue &value, QDateTime *out);
    static QVariantList parseInfluxQlJson(const QByteArray &body, QString *errorOut);
    void finishRequest(const QString &itemName, QNetworkReply *reply, bool influxV1);

    QNetworkAccessManager m_network;
    QUrl m_baseUrl;
    QString m_token;
    QString m_user;
    QString m_password;
    QString m_org;
    QString m_bucket;
    QString m_database;
    QString m_retentionPolicy;
    QSet<QString> m_inFlight;
};
