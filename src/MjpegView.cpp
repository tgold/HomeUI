#include "MjpegView.h"

#include <QLoggingCategory>
#include <QNetworkRequest>
#include <QPainter>
#include <QSslConfiguration>

namespace {
Q_LOGGING_CATEGORY(lcMjpeg, "homeui.mjpeg")

constexpr int FpsWindowMs = 2000;
constexpr int MaxBufferBytes = 32 * 1024 * 1024;
constexpr int MinRepaintIntervalMs = 66; // cap repaint rate (~15 fps) to keep swipes smooth

QByteArray boundaryFromContentType(const QByteArray &contentType)
{
    const int idx = contentType.indexOf("boundary=");
    if (idx < 0) {
        return {};
    }
    QByteArray value = contentType.mid(idx + 9).trimmed();
    const int semi = value.indexOf(';');
    if (semi >= 0) {
        value = value.left(semi).trimmed();
    }
    if (value.startsWith('"') && value.endsWith('"') && value.size() >= 2) {
        value = value.mid(1, value.size() - 2);
    }
    if (!value.startsWith("--")) {
        value.prepend("--");
    }
    return value;
}
} // namespace

MjpegView::MjpegView(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setFillColor(Qt::transparent);
    setRenderTarget(QQuickPaintedItem::FramebufferObject);

    m_reconnectTimer.setSingleShot(true);
    connect(&m_reconnectTimer, &QTimer::timeout, this, [this]() {
        if (m_url.isValid()) {
            start();
        }
    });

    m_fpsTimer.setInterval(FpsWindowMs);
    connect(&m_fpsTimer, &QTimer::timeout, this, &MjpegView::updateFrameRate);

    m_repaintTimer.setSingleShot(true);
    connect(&m_repaintTimer, &QTimer::timeout, this, [this]() {
        m_repaintPending = false;
        update();
    });
}

MjpegView::~MjpegView()
{
    stop();
}

void MjpegView::paint(QPainter *painter)
{
    const QRectF target(0, 0, width(), height());
    if (m_frame.isNull()) {
        painter->fillRect(target, QColor(QStringLiteral("#1e293b")));
        return;
    }

    const QSizeF imageSize(m_frame.width(), m_frame.height());
    if (imageSize.width() <= 0 || imageSize.height() <= 0) {
        painter->fillRect(target, QColor(QStringLiteral("#1e293b")));
        return;
    }

    const QSizeF scaled = imageSize.scaled(target.size(), Qt::KeepAspectRatio);
    const QRectF dest((target.width() - scaled.width()) / 2.0,
                      (target.height() - scaled.height()) / 2.0,
                      scaled.width(),
                      scaled.height());
    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
    painter->drawImage(dest, m_frame);
}

QUrl MjpegView::url() const
{
    return m_url;
}

void MjpegView::setUrl(const QUrl &url)
{
    if (m_url == url) {
        return;
    }
    m_url = url;
    emit urlChanged();
    stop();
    if (m_url.isValid()) {
        start();
    }
}

bool MjpegView::active() const
{
    return m_active;
}

bool MjpegView::hasFrame() const
{
    return !m_frame.isNull();
}

QString MjpegView::lastError() const
{
    return m_lastError;
}

int MjpegView::frameCount() const
{
    return m_frameCount;
}

double MjpegView::frameRate() const
{
    return m_frameRate;
}

int MjpegView::reconnectInterval() const
{
    return m_reconnectInterval;
}

void MjpegView::setReconnectInterval(int reconnectInterval)
{
    const int clamped = qMax(500, reconnectInterval);
    if (m_reconnectInterval == clamped) {
        return;
    }
    m_reconnectInterval = clamped;
    emit reconnectIntervalChanged();
}

bool MjpegView::ignoreSslErrors() const
{
    return m_ignoreSslErrors;
}

void MjpegView::setIgnoreSslErrors(bool ignoreSslErrors)
{
    if (m_ignoreSslErrors == ignoreSslErrors) {
        return;
    }
    m_ignoreSslErrors = ignoreSslErrors;
    emit ignoreSslErrorsChanged();
}

void MjpegView::start()
{
    if (!m_url.isValid()) {
        return;
    }
    if (m_reply) {
        return;
    }

    m_buffer.clear();
    m_boundary.clear();

    QNetworkRequest request(m_url);
    request.setRawHeader("Accept", "multipart/x-mixed-replace,image/jpeg,*/*");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    if (m_ignoreSslErrors) {
        QSslConfiguration config = QSslConfiguration::defaultConfiguration();
        config.setPeerVerifyMode(QSslSocket::VerifyNone);
        request.setSslConfiguration(config);
    }

    m_reply = m_network.get(request);
    if (m_ignoreSslErrors) {
        connect(m_reply, &QNetworkReply::sslErrors, m_reply,
                [this](const QList<QSslError> &) {
                    if (m_reply) {
                        m_reply->ignoreSslErrors();
                    }
                });
    }
    connect(m_reply, &QNetworkReply::readyRead, this, &MjpegView::onReadyRead);
    connect(m_reply, &QNetworkReply::finished, this, &MjpegView::onFinished);

    if (!m_fpsWindow.isValid()) {
        m_fpsWindow.start();
    }
    m_recentFrames = 0;
    m_fpsTimer.start();
    setLastError({});
    setActive(true);
    qCInfo(lcMjpeg, "Starting MJPEG stream %s", qPrintable(m_url.toString()));
}

void MjpegView::stop()
{
    m_fpsTimer.stop();
    m_reconnectTimer.stop();
    m_repaintTimer.stop();
    m_repaintPending = false;
    if (m_reply) {
        QNetworkReply *reply = m_reply;
        m_reply = nullptr;
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }
    setActive(false);
}

void MjpegView::scheduleReconnect()
{
    if (!m_url.isValid()) {
        return;
    }
    setActive(false);
    m_reconnectTimer.start(m_reconnectInterval);
}

void MjpegView::onReadyRead()
{
    if (!m_reply) {
        return;
    }
    m_buffer.append(m_reply->readAll());

    if (m_boundary.isEmpty()) {
        const QByteArray ct = m_reply->header(QNetworkRequest::ContentTypeHeader).toByteArray();
        m_boundary = boundaryFromContentType(ct);
        if (m_boundary.isEmpty()) {
            return;
        }
    }
    parseBuffer();

    if (m_buffer.size() > MaxBufferBytes) {
        qCWarning(lcMjpeg, "MJPEG buffer overflow (%lld bytes) - dropping", static_cast<long long>(m_buffer.size()));
        m_buffer.clear();
    }
}

void MjpegView::onFinished()
{
    if (!m_reply) {
        return;
    }
    const QNetworkReply::NetworkError err = m_reply->error();
    if (err != QNetworkReply::NoError && err != QNetworkReply::OperationCanceledError) {
        setLastError(m_reply->errorString());
        qCWarning(lcMjpeg, "MJPEG stream error: %s", qPrintable(m_reply->errorString()));
    }
    m_reply->disconnect(this);
    m_reply->deleteLater();
    m_reply = nullptr;
    scheduleReconnect();
}

void MjpegView::parseBuffer()
{
    while (true) {
        const int boundaryStart = m_buffer.indexOf(m_boundary);
        if (boundaryStart < 0) {
            return;
        }

        int headersStart = boundaryStart + m_boundary.size();
        // Strip the optional trailing CRLF (or LF) that follows the boundary line.
        if (m_buffer.mid(headersStart, 2) == "\r\n") {
            headersStart += 2;
        } else if (m_buffer.mid(headersStart, 1) == "\n") {
            headersStart += 1;
        } else if (m_buffer.mid(headersStart, 2) == "--") {
            // End of stream marker
            m_buffer.clear();
            return;
        }

        int headersEnd = m_buffer.indexOf("\r\n\r\n", headersStart);
        int bodyStart = -1;
        if (headersEnd >= 0) {
            bodyStart = headersEnd + 4;
        } else {
            headersEnd = m_buffer.indexOf("\n\n", headersStart);
            if (headersEnd >= 0) {
                bodyStart = headersEnd + 2;
            }
        }
        if (headersEnd < 0 || bodyStart < 0) {
            return;
        }

        const QByteArray headerBlock = m_buffer.mid(headersStart, headersEnd - headersStart);
        int contentLength = -1;
        for (const QByteArray &line : headerBlock.split('\n')) {
            QByteArray trimmed = line.trimmed();
            if (trimmed.size() < 15) {
                continue;
            }
            if (trimmed.left(15).toLower() == "content-length:") {
                contentLength = trimmed.mid(15).trimmed().toInt();
                break;
            }
        }

        QByteArray frameData;
        int frameEnd = -1;
        if (contentLength > 0) {
            if (m_buffer.size() < bodyStart + contentLength) {
                return;
            }
            frameData = m_buffer.mid(bodyStart, contentLength);
            frameEnd = bodyStart + contentLength;
        } else {
            const int nextBoundary = m_buffer.indexOf(m_boundary, bodyStart);
            if (nextBoundary < 0) {
                return;
            }
            frameData = m_buffer.mid(bodyStart, nextBoundary - bodyStart);
            while (frameData.endsWith('\r') || frameData.endsWith('\n')) {
                frameData.chop(1);
            }
            frameEnd = nextBoundary;
        }

        QImage image = QImage::fromData(frameData, "JPEG");
        if (!image.isNull()) {
            m_frame = image;
            ++m_frameCount;
            ++m_recentFrames;
            setLastError({});
            emit frameCountChanged();
            scheduleRepaint();
        }

        if (frameEnd <= 0 || frameEnd > m_buffer.size()) {
            m_buffer.clear();
            return;
        }
        m_buffer.remove(0, frameEnd);
    }
}

void MjpegView::scheduleRepaint()
{
    if (!m_repaintClock.isValid()) {
        m_repaintClock.start();
        update();
        return;
    }

    const qint64 elapsed = m_repaintClock.elapsed();
    if (elapsed >= MinRepaintIntervalMs) {
        m_repaintClock.restart();
        m_repaintTimer.stop();
        m_repaintPending = false;
        update();
        return;
    }

    if (!m_repaintPending) {
        m_repaintPending = true;
        m_repaintTimer.start(MinRepaintIntervalMs - static_cast<int>(elapsed));
    }
}

void MjpegView::setActive(bool active)
{
    if (m_active == active) {
        return;
    }
    m_active = active;
    emit activeChanged();
}

void MjpegView::setLastError(const QString &lastError)
{
    if (m_lastError == lastError) {
        return;
    }
    m_lastError = lastError;
    emit lastErrorChanged();
}

void MjpegView::updateFrameRate()
{
    if (!m_fpsWindow.isValid()) {
        m_fpsWindow.start();
        m_recentFrames = 0;
        return;
    }
    const qint64 elapsed = m_fpsWindow.restart();
    double rate = 0.0;
    if (elapsed > 0) {
        rate = (m_recentFrames * 1000.0) / static_cast<double>(elapsed);
    }
    m_recentFrames = 0;
    if (qAbs(rate - m_frameRate) > 0.05) {
        m_frameRate = rate;
        emit frameRateChanged();
    }
}
