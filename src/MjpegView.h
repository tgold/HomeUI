#pragma once

#include <QByteArray>
#include <QElapsedTimer>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QQuickPaintedItem>
#include <QString>
#include <QTimer>
#include <QUrl>

// QQuickPaintedItem that streams a multipart/x-mixed-replace MJPEG response
// (as served by Synology Surveillance Station, axis cameras, motion, etc.)
// and paints the most recent JPEG frame. Auto-reconnects on transport errors.
class MjpegView : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY frameCountChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(int frameCount READ frameCount NOTIFY frameCountChanged)
    Q_PROPERTY(double frameRate READ frameRate NOTIFY frameRateChanged)
    Q_PROPERTY(int reconnectInterval READ reconnectInterval WRITE setReconnectInterval NOTIFY reconnectIntervalChanged)
    Q_PROPERTY(bool ignoreSslErrors READ ignoreSslErrors WRITE setIgnoreSslErrors NOTIFY ignoreSslErrorsChanged)

public:
    explicit MjpegView(QQuickItem *parent = nullptr);
    ~MjpegView() override;

    void paint(QPainter *painter) override;

    QUrl url() const;
    void setUrl(const QUrl &url);

    bool active() const;
    bool hasFrame() const;
    QString lastError() const;
    int frameCount() const;
    double frameRate() const;
    int reconnectInterval() const;
    void setReconnectInterval(int reconnectInterval);
    bool ignoreSslErrors() const;
    void setIgnoreSslErrors(bool ignoreSslErrors);

signals:
    void urlChanged();
    void activeChanged();
    void lastErrorChanged();
    void frameCountChanged();
    void frameRateChanged();
    void reconnectIntervalChanged();
    void ignoreSslErrorsChanged();

private:
    void start();
    void stop();
    void scheduleReconnect();
    void onReadyRead();
    void onFinished();
    void parseBuffer();
    void setActive(bool active);
    void setLastError(const QString &lastError);
    void updateFrameRate();

    QNetworkAccessManager m_network;
    QNetworkReply *m_reply = nullptr;
    QUrl m_url;
    QByteArray m_buffer;
    QByteArray m_boundary;
    QImage m_frame;
    QTimer m_reconnectTimer;
    QTimer m_fpsTimer;
    QElapsedTimer m_fpsWindow;
    QString m_lastError;
    int m_frameCount = 0;
    int m_recentFrames = 0;
    double m_frameRate = 0.0;
    int m_reconnectInterval = 3000;
    bool m_active = false;
    bool m_ignoreSslErrors = false;
};
