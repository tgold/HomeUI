#include "InfluxHistoryClient.h"

#include <QDateTime>
#include <QVector>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLoggingCategory>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcessEnvironment>
#include <QUrlQuery>

#include <algorithm>

namespace {
Q_LOGGING_CATEGORY(lcInflux, "homeui.influx")

QString trimmedEnv(const QProcessEnvironment &env, const QString &name, const QString &fallback = QString())
{
    return env.value(name, fallback).trimmed();
}
} // namespace

InfluxHistoryClient::InfluxHistoryClient(QObject *parent)
    : QObject(parent)
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    setBaseUrl(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_URL")));
    setToken(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_TOKEN")));
    setUser(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_USER")));
    setPassword(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_PASSWORD")));
    setOrg(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_ORG")));
    setBucket(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_BUCKET")));
    setDatabase(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_DATABASE")));
}

QString InfluxHistoryClient::baseUrl() const
{
    QString url = m_baseUrl.toString();
    while (url.endsWith(QLatin1Char('/'))) {
        url.chop(1);
    }
    return url;
}

void InfluxHistoryClient::setBaseUrl(const QString &baseUrl)
{
    QUrl parsed(baseUrl.trimmed());
    if (!parsed.isValid() || parsed.scheme().isEmpty() || parsed.host().isEmpty()) {
        parsed = QUrl();
    }

    if (m_baseUrl == parsed) {
        return;
    }

    m_baseUrl = parsed;
    emit baseUrlChanged();
    emit configuredChanged();
}

QString InfluxHistoryClient::token() const
{
    return m_token;
}

void InfluxHistoryClient::setToken(const QString &token)
{
    const QString trimmed = token.trimmed();
    if (m_token == trimmed) {
        return;
    }

    m_token = trimmed;
    emit tokenChanged();
    emit configuredChanged();
}

QString InfluxHistoryClient::user() const
{
    return m_user;
}

void InfluxHistoryClient::setUser(const QString &user)
{
    const QString trimmed = user.trimmed();
    if (m_user == trimmed) {
        return;
    }

    m_user = trimmed;
    emit userChanged();
    emit configuredChanged();
}

QString InfluxHistoryClient::password() const
{
    return m_password;
}

void InfluxHistoryClient::setPassword(const QString &password)
{
    if (m_password == password) {
        return;
    }

    m_password = password;
    emit passwordChanged();
    emit configuredChanged();
}

QString InfluxHistoryClient::org() const
{
    return m_org;
}

void InfluxHistoryClient::setOrg(const QString &org)
{
    const QString trimmed = org.trimmed();
    if (m_org == trimmed) {
        return;
    }

    m_org = trimmed;
    emit orgChanged();
    emit configuredChanged();
}

QString InfluxHistoryClient::bucket() const
{
    return m_bucket;
}

void InfluxHistoryClient::setBucket(const QString &bucket)
{
    const QString trimmed = bucket.trimmed();
    if (m_bucket == trimmed) {
        return;
    }

    m_bucket = trimmed;
    emit bucketChanged();
    emit configuredChanged();
}

QString InfluxHistoryClient::database() const
{
    return m_database;
}

void InfluxHistoryClient::setDatabase(const QString &database)
{
    const QString trimmed = database.trimmed();
    if (m_database == trimmed) {
        return;
    }

    m_database = trimmed;
    emit databaseChanged();
    emit configuredChanged();
}

bool InfluxHistoryClient::usesInfluxV2() const
{
    return !m_token.isEmpty();
}

QString InfluxHistoryClient::databaseName() const
{
    if (!m_database.isEmpty()) {
        return m_database;
    }
    return m_bucket;
}

bool InfluxHistoryClient::configured() const
{
    if (baseUrl().isEmpty()) {
        return false;
    }

    if (usesInfluxV2()) {
        return !m_org.isEmpty() && !m_bucket.isEmpty();
    }

    return !m_user.isEmpty() && !m_password.isEmpty() && !databaseName().isEmpty();
}

QString InfluxHistoryClient::escapeFluxString(const QString &value)
{
    return QString(value).replace(QLatin1String("\\"), QStringLiteral("\\\\")).replace(QLatin1Char('"'),
                                                                                      QStringLiteral("\\\""));
}

QString InfluxHistoryClient::escapeInfluxQlIdent(const QString &value)
{
    return QString(value).replace(QLatin1String("\\"), QStringLiteral("\\\\")).replace(QLatin1Char('"'),
                                                                                       QStringLiteral("\\\""));
}

QString InfluxHistoryClient::escapeInfluxQlString(const QString &value)
{
    return QString(value).replace(QLatin1Char('\''), QStringLiteral("\\'"));
}

QString InfluxHistoryClient::buildFluxQuery(const QString &itemName,
                                            const QString &measurement,
                                            int days,
                                            bool filterByItemTag) const
{
    const int safeDays = qMax(1, days);
    const QString range = QStringLiteral("-%1d").arg(safeDays);
    const QString measurementName = measurement.trimmed().isEmpty() ? itemName.trimmed() : measurement.trimmed();

    QString filter = QStringLiteral("  |> filter(fn: (r) => r._measurement == \"%1\" and r._field == \"value\")\n")
                         .arg(escapeFluxString(measurementName));
    if (filterByItemTag) {
        filter += QStringLiteral("  |> filter(fn: (r) => r.item == \"%1\")\n").arg(escapeFluxString(itemName.trimmed()));
    }

    return QStringLiteral("from(bucket: \"%1\")\n"
                          "  |> range(start: %2)\n"
                          "%3"
                          "  |> aggregateWindow(every: 1d, fn: mean, createEmpty: false)\n"
                          "  |> keep(columns: [\"_time\", \"_value\"])\n")
        .arg(escapeFluxString(m_bucket), range, filter);
}

QString InfluxHistoryClient::buildInfluxQlQuery(const QString &itemName,
                                                const QString &measurement,
                                                int days,
                                                bool filterByItemTag) const
{
    const int safeDays = qMax(1, days);
    const QString measurementName = measurement.trimmed().isEmpty() ? itemName.trimmed() : measurement.trimmed();
    const QString fromClause = QStringLiteral("FROM \"%1\"").arg(escapeInfluxQlIdent(measurementName));

    QString whereClause = QStringLiteral("time > now() - %1d").arg(safeDays);
    if (filterByItemTag) {
        whereClause = QStringLiteral("\"item\" = '%1' AND %2")
                          .arg(escapeInfluxQlString(itemName.trimmed()), whereClause);
    }

    return QStringLiteral("SELECT mean(\"value\") %1 WHERE %2 GROUP BY time(1d) fill(none)")
        .arg(fromClause, whereClause);
}

QVariantList InfluxHistoryClient::parseAnnotatedCsv(const QByteArray &body, QString *errorOut)
{
    if (errorOut) {
        errorOut->clear();
    }

    const QString text = QString::fromUtf8(body).trimmed();
    if (text.isEmpty()) {
        return {};
    }

    if (text.startsWith(QLatin1Char('{')) || text.startsWith(QLatin1Char('['))) {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        if (doc.isObject()) {
            const QString message = doc.object().value(QStringLiteral("message")).toString();
            if (!message.isEmpty() && errorOut) {
                *errorOut = message;
            }
        }
        return {};
    }

    const QStringList lines = text.split(QLatin1Char('\n'), Qt::SkipEmptyParts);

    struct Point {
        qint64 epochMs = 0;
        double value = 0.0;
    };
    QVector<Point> points;

    int timeIndex = -1;
    int valueIndex = -1;
    for (int i = 0; i < lines.size(); ++i) {
        const QString line = lines.at(i).trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#'))) {
            continue;
        }

        const QStringList cells = line.split(QLatin1Char(','));
        if (timeIndex < 0) {
            for (int c = 0; c < cells.size(); ++c) {
                const QString cell = cells.at(c).trimmed();
                if (cell == QStringLiteral("_time")) {
                    timeIndex = c;
                } else if (cell == QStringLiteral("_value")) {
                    valueIndex = c;
                }
            }
            continue;
        }

        if (cells.size() <= qMax(timeIndex, valueIndex)) {
            continue;
        }

        const QString timeText = cells.at(timeIndex).trimmed();
        const QString valueText = cells.at(valueIndex).trimmed();
        if (timeText.isEmpty() || valueText.isEmpty()) {
            continue;
        }

        QDateTime timestamp = QDateTime::fromString(timeText, Qt::ISODateWithMs);
        if (!timestamp.isValid()) {
            timestamp = QDateTime::fromString(timeText, Qt::ISODate);
        }
        if (!timestamp.isValid()) {
            continue;
        }

        bool ok = false;
        const double value = valueText.toDouble(&ok);
        if (!ok) {
            continue;
        }

        Point point;
        point.epochMs = timestamp.toMSecsSinceEpoch();
        point.value = value;
        points.append(point);
    }

    std::sort(points.begin(), points.end(), [](const Point &a, const Point &b) {
        return a.epochMs < b.epochMs;
    });

    QVariantList values;
    values.reserve(points.size());
    for (const Point &point : points) {
        values.append(point.value);
    }
    return values;
}

QVariantList InfluxHistoryClient::parseInfluxQlJson(const QByteArray &body, QString *errorOut)
{
    if (errorOut) {
        errorOut->clear();
    }

    QJsonParseError parseError{};
    const QJsonDocument doc = QJsonDocument::fromJson(body, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        if (errorOut) {
            *errorOut = parseError.error == QJsonParseError::NoError
                            ? QStringLiteral("invalid InfluxQL response")
                            : parseError.errorString();
        }
        return {};
    }

    const QJsonArray results = doc.object().value(QStringLiteral("results")).toArray();
    if (results.isEmpty()) {
        return {};
    }

    const QJsonObject first = results.at(0).toObject();
    const QString statementError = first.value(QStringLiteral("error")).toString();
    if (!statementError.isEmpty()) {
        if (errorOut) {
            *errorOut = statementError;
        }
        return {};
    }

    const QJsonArray series = first.value(QStringLiteral("series")).toArray();
    if (series.isEmpty()) {
        return {};
    }

    const QJsonArray values = series.at(0).toObject().value(QStringLiteral("values")).toArray();
    if (values.isEmpty()) {
        return {};
    }

    struct Point {
        qint64 epochMs = 0;
        double value = 0.0;
    };
    QVector<Point> points;
    points.reserve(values.size());

    for (const QJsonValue &rowValue : values) {
        const QJsonArray row = rowValue.toArray();
        if (row.size() < 2 || row.at(1).isNull()) {
            continue;
        }

        const QString timeText = row.at(0).toString();
        QDateTime timestamp = QDateTime::fromString(timeText, Qt::ISODateWithMs);
        if (!timestamp.isValid()) {
            timestamp = QDateTime::fromString(timeText, Qt::ISODate);
        }
        if (!timestamp.isValid()) {
            continue;
        }

        bool ok = false;
        const double value = row.at(1).toDouble(ok);
        if (!ok) {
            continue;
        }

        Point point;
        point.epochMs = timestamp.toMSecsSinceEpoch();
        point.value = value;
        points.append(point);
    }

    std::sort(points.begin(), points.end(), [](const Point &a, const Point &b) {
        return a.epochMs < b.epochMs;
    });

    QVariantList out;
    out.reserve(points.size());
    for (const Point &point : points) {
        out.append(point.value);
    }
    return out;
}

void InfluxHistoryClient::fetchDailyMeans(const QString &itemName,
                                          const QString &measurement,
                                          int days,
                                          bool filterByItemTag)
{
    const QString item = itemName.trimmed();
    if (item.isEmpty()) {
        emit dailyMeansReady(item, {}, QStringLiteral("empty item name"));
        return;
    }

    if (!configured()) {
        emit dailyMeansReady(item, {}, QStringLiteral("Influx not configured"));
        return;
    }

    if (m_inFlight.contains(item)) {
        return;
    }

    m_inFlight.insert(item);

    const bool influxV1 = !usesInfluxV2();
    QUrl url(m_baseUrl);
    QNetworkRequest request(url);

    QNetworkReply *reply = nullptr;
    if (influxV1) {
        url.setPath(QStringLiteral("/query"));
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("db"), databaseName());
        query.addQueryItem(QStringLiteral("u"), m_user);
        query.addQueryItem(QStringLiteral("p"), m_password);
        query.addQueryItem(QStringLiteral("q"), buildInfluxQlQuery(item, measurement, days, filterByItemTag));
        url.setQuery(query);
        request.setUrl(url);
        qCDebug(lcInflux, "GET %s (item=%s, db=%s)", qUtf8Printable(url.toString(QUrl::RemovePassword)),
                qUtf8Printable(item), qUtf8Printable(databaseName()));
        reply = m_network.get(request);
    } else {
        url.setPath(QStringLiteral("/api/v2/query"));
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("org"), m_org);
        url.setQuery(query);
        request.setUrl(url);
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/vnd.flux"));
        request.setRawHeader("Authorization", QByteArray("Token ") + m_token.toUtf8());
        request.setRawHeader("Accept", "application/csv");

        const QByteArray flux = buildFluxQuery(item, measurement, days, filterByItemTag).toUtf8();
        qCDebug(lcInflux, "POST %s (item=%s)", qUtf8Printable(url.toString()), qUtf8Printable(item));
        reply = m_network.post(request, flux);
    }

    connect(reply, &QNetworkReply::finished, this, [this, item, reply, influxV1]() {
        finishRequest(item, reply, influxV1);
    });
}

void InfluxHistoryClient::finishRequest(const QString &itemName, QNetworkReply *reply, bool influxV1)
{
    reply->deleteLater();
    m_inFlight.remove(itemName);

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();

    if (reply->error() != QNetworkReply::NoError) {
        const QString detail = body.isEmpty() ? reply->errorString() : QString::fromUtf8(body).trimmed();
        qCWarning(lcInflux,
                  "Influx query for %s failed: %s (HTTP %d)",
                  qUtf8Printable(itemName),
                  qUtf8Printable(detail),
                  status);
        emit dailyMeansReady(itemName, {}, detail);
        return;
    }

    QString parseError;
    const QVariantList values =
        influxV1 ? parseInfluxQlJson(body, &parseError) : parseAnnotatedCsv(body, &parseError);
    if (!parseError.isEmpty()) {
        emit dailyMeansReady(itemName, {}, parseError);
        return;
    }

    qCDebug(lcInflux, "Influx daily means for %s: %d points", qUtf8Printable(itemName), values.size());
    emit dailyMeansReady(itemName, values, {});
}
