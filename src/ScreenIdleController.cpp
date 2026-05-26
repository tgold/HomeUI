#include "ScreenIdleController.h"

#include <QCoreApplication>
#include <QEvent>
#include <QLoggingCategory>

namespace {
Q_LOGGING_CATEGORY(lcIdle, "homeui.idle")
}

ScreenIdleController::ScreenIdleController(QObject *parent)
    : QObject(parent)
{
    m_idleTimer.setSingleShot(true);
    connect(&m_idleTimer, &QTimer::timeout, this, [this]() {
        if (m_enabled && !m_idle) {
            setIdle(true);
        }
    });

    if (QCoreApplication::instance()) {
        QCoreApplication::instance()->installEventFilter(this);
        m_filterInstalled = true;
    }
    resetIdleTimer();
}

ScreenIdleController::~ScreenIdleController()
{
    if (m_filterInstalled && QCoreApplication::instance()) {
        QCoreApplication::instance()->removeEventFilter(this);
    }
}

int ScreenIdleController::idleTimeoutMs() const
{
    return m_idleTimeoutMs;
}

void ScreenIdleController::setIdleTimeoutMs(int idleTimeoutMs)
{
    const int clamped = qMax(1000, idleTimeoutMs);
    if (m_idleTimeoutMs == clamped) {
        return;
    }
    m_idleTimeoutMs = clamped;
    emit idleTimeoutMsChanged();
    resetIdleTimer();
}

bool ScreenIdleController::idle() const
{
    return m_idle;
}

int ScreenIdleController::activeBrightness() const
{
    return m_activeBrightness;
}

void ScreenIdleController::setActiveBrightness(int activeBrightness)
{
    const int clamped = qBound(1, activeBrightness, 100);
    if (m_activeBrightness == clamped) {
        return;
    }
    m_activeBrightness = clamped;
    emit activeBrightnessChanged();
    // Pass the new level through to the backlight whenever we are currently
    // showing the active state, regardless of whether the idle timer itself
    // is enabled - this is the channel MQTT brightness/set rides on too.
    if (!m_idle) {
        emit brightnessRequested(m_activeBrightness);
    }
}

int ScreenIdleController::idleBrightness() const
{
    return m_idleBrightness;
}

void ScreenIdleController::setIdleBrightness(int idleBrightness)
{
    const int clamped = qBound(0, idleBrightness, 100);
    if (m_idleBrightness == clamped) {
        return;
    }
    m_idleBrightness = clamped;
    emit idleBrightnessChanged();
    if (m_idle) {
        emit brightnessRequested(m_idleBrightness);
    }
}

bool ScreenIdleController::enabled() const
{
    return m_enabled;
}

void ScreenIdleController::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    emit enabledChanged();
    if (!m_enabled) {
        m_idleTimer.stop();
        if (m_idle) {
            setIdle(false);
            emit brightnessRequested(m_activeBrightness);
        }
    } else {
        resetIdleTimer();
    }
}

bool ScreenIdleController::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched);
    if (!m_enabled || event == nullptr) {
        return false;
    }
    switch (event->type()) {
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
    case QEvent::MouseMove:
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::Wheel:
    case QEvent::KeyPress:
    case QEvent::KeyRelease:
    case QEvent::TabletPress:
    case QEvent::TabletMove:
    case QEvent::TabletRelease:
        wake();
        break;
    default:
        break;
    }
    return false;
}

void ScreenIdleController::wake()
{
    if (!m_enabled) {
        return;
    }
    if (m_idle) {
        qCInfo(lcIdle, "Waking from idle (active brightness %d%%)", m_activeBrightness);
        setIdle(false);
        emit brightnessRequested(m_activeBrightness);
    }
    resetIdleTimer();
}

void ScreenIdleController::sleep()
{
    if (!m_enabled || m_idle) {
        return;
    }
    setIdle(true);
    m_idleTimer.stop();
}

void ScreenIdleController::resetIdleTimer()
{
    if (!m_enabled) {
        return;
    }
    m_idleTimer.start(m_idleTimeoutMs);
}

void ScreenIdleController::setIdle(bool idle)
{
    if (m_idle == idle) {
        return;
    }
    m_idle = idle;
    emit idleChanged();
    if (m_idle) {
        qCInfo(lcIdle, "Going idle (idle brightness %d%%)", m_idleBrightness);
        emit brightnessRequested(m_idleBrightness);
    }
}
