#include "InfluxHistoryClient.h"

#include <QDateTime>
#include <QVector>
#include <QJsonDocument>
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
    setOrg(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_ORG")));
    setBucket(trimmedEnv(env, QStringLiteral("HOMEUI_INFLUX_BUCKET")));
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

bool InfluxHistoryClient::configured() const
{
    return !baseUrl().isEmpty() && !m_token.isEmpty() && !m_org.isEmpty() && !m_bucket.isEmpty();
}

QString InfluxHistoryClient::escapeFluxString(const QString &value)
{
    return QString(value).replace(QLatin1String("\\"), QStringLiteral("\\\\")).replace(QLatin1Char('"'),
                                                                                      QStringLiteral("\\\""));
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

    timeIndex = -1;
    valueIndex = -1;
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

    QUrl url(m_baseUrl);
    url.setPath(QStringLiteral("/api/v2/query"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("org"), m_org);
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/vnd.flux"));
    request.setRawHeader("Authorization", QByteArray("Token ") + m_token.toUtf8());
    request.setHeader(QNetworkRequest::AcceptHeader, QStringLiteral("application/csv"));

    const QByteArray flux = buildFluxQuery(item, measurement, days, filterByItemTag).toUtf8();
    qCDebug(lcInflux, "POST %s (item=%s)", qUtf8Printable(url.toString()), qUtf8Printable(item));

    QNetworkReply *reply = m_network.post(request, flux);
    connect(reply, &QNetworkReply::finished, this, [this, item, reply]() {
        finishRequest(item, reply);
    });
}

void InfluxHistoryClient::finishRequest(const QString &itemName, QNetworkReply *reply)
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
    const QVariantList values = parseAnnotatedCsv(body, &parseError);
    if (!parseError.isEmpty()) {
        emit dailyMeansReady(itemName, {}, parseError);
        return;
    }

    qCDebug(lcInflux, "Influx daily means for %s: %d points", qUtf8Printable(itemName), values.size());
    emit dailyMeansReady(itemName, values, {});
}
