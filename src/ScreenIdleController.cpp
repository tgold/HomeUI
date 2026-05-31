#include "ScreenIdleController.h"

#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QEvent>
#include <QLoggingCategory>

#include <limits>

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
    m_nightModeTimer.setSingleShot(true);
    connect(&m_nightModeTimer, &QTimer::timeout, this, &ScreenIdleController::refreshNightMode);

    if (QCoreApplication::instance()) {
        QCoreApplication::instance()->installEventFilter(this);
        m_filterInstalled = true;
    }
    resetIdleTimer();
    QTimer::singleShot(0, this, &ScreenIdleController::refreshNightMode);
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
    const int clamped = idleTimeoutMs <= 0 ? 0 : qMax(1000, idleTimeoutMs);
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
        m_nightModeTimer.stop();
        m_nightModeActive = false;
        if (m_idle) {
            setIdle(false);
            emit brightnessRequested(m_activeBrightness);
        }
    } else {
        refreshNightMode();
        resetIdleTimer();
    }
}

bool ScreenIdleController::nightModeEnabled() const
{
    return m_nightModeEnabled;
}

void ScreenIdleController::setNightModeEnabled(bool enabled)
{
    if (m_nightModeEnabled == enabled) {
        return;
    }
    m_nightModeEnabled = enabled;
    refreshNightMode();
}

QTime ScreenIdleController::nightModeStartTime() const
{
    return m_nightModeStartTime;
}

void ScreenIdleController::setNightModeStartTime(const QTime &time)
{
    if (!time.isValid() || m_nightModeStartTime == time) {
        return;
    }
    m_nightModeStartTime = time;
    refreshNightMode();
}

QTime ScreenIdleController::nightModeEndTime() const
{
    return m_nightModeEndTime;
}

void ScreenIdleController::setNightModeEndTime(const QTime &time)
{
    if (!time.isValid() || m_nightModeEndTime == time) {
        return;
    }
    m_nightModeEndTime = time;
    refreshNightMode();
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
    if (m_nightModeActive) {
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
    if (!m_enabled || m_nightModeActive || m_idleTimeoutMs <= 0) {
        m_idleTimer.stop();
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

bool ScreenIdleController::isWithinNightMode(const QTime &time) const
{
    if (!m_nightModeStartTime.isValid() || !m_nightModeEndTime.isValid()
        || m_nightModeStartTime == m_nightModeEndTime) {
        return false;
    }

    if (m_nightModeStartTime < m_nightModeEndTime) {
        return time >= m_nightModeStartTime && time < m_nightModeEndTime;
    }
    return time >= m_nightModeStartTime || time < m_nightModeEndTime;
}

void ScreenIdleController::refreshNightMode()
{
    if (!m_enabled) {
        m_nightModeTimer.stop();
        m_nightModeActive = false;
        return;
    }

    const bool wasNightModeActive = m_nightModeActive;
    const bool shouldBeNightModeActive = m_nightModeEnabled && isWithinNightMode(QTime::currentTime());
    m_nightModeActive = shouldBeNightModeActive;

    if (shouldBeNightModeActive) {
        m_idleTimer.stop();
        if (!m_idle) {
            qCInfo(lcIdle,
                   "Entering scheduled night screen-off until %s",
                   qPrintable(m_nightModeEndTime.toString(QStringLiteral("HH:mm"))));
            setIdle(true);
        }
    } else if (wasNightModeActive) {
        qCInfo(lcIdle,
               "Leaving scheduled night screen-off at %s",
               qPrintable(m_nightModeEndTime.toString(QStringLiteral("HH:mm"))));
        if (m_idle) {
            setIdle(false);
            emit brightnessRequested(m_activeBrightness);
        }
        resetIdleTimer();
    }

    scheduleNightModeTimer();
}

void ScreenIdleController::scheduleNightModeTimer()
{
    if (!m_enabled || !m_nightModeEnabled || !m_nightModeStartTime.isValid()
        || !m_nightModeEndTime.isValid() || m_nightModeStartTime == m_nightModeEndTime) {
        m_nightModeTimer.stop();
        return;
    }

    const QDateTime now = QDateTime::currentDateTime();
    const QDate today = now.date();
    QDateTime nextTransition;

    for (int dayOffset = 0; dayOffset < 3; ++dayOffset) {
        const QDate date = today.addDays(dayOffset);
        const QDateTime startCandidate(date, m_nightModeStartTime);
        const QDateTime endCandidate(date, m_nightModeEndTime);

        if (startCandidate > now
            && (!nextTransition.isValid() || startCandidate < nextTransition)) {
            nextTransition = startCandidate;
        }
        if (endCandidate > now
            && (!nextTransition.isValid() || endCandidate < nextTransition)) {
            nextTransition = endCandidate;
        }
    }

    if (!nextTransition.isValid()) {
        m_nightModeTimer.stop();
        return;
    }

    const qint64 delayMs = qMax<qint64>(1, now.msecsTo(nextTransition));
    m_nightModeTimer.start(static_cast<int>(qMin<qint64>(
        delayMs,
        std::numeric_limits<int>::max())));
}
