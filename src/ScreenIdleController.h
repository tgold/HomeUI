#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

class QEvent;

// Watches global input and toggles the panel between "active" and "idle"
// states. On going idle, the configured backlight is dimmed to
// `idleBrightness` (0 = off); on the next touch / mouse / key event the
// previous `activeBrightness` is restored.
//
// The controller does not directly own a path to the backlight; emit
// `brightnessRequested(percent)` instead and let `main.cpp` poke
// `/sys/class/backlight/.../brightness` (the same code path the MQTT
// brightness/set topic uses).
class ScreenIdleController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int idleTimeoutMs READ idleTimeoutMs WRITE setIdleTimeoutMs NOTIFY idleTimeoutMsChanged)
    Q_PROPERTY(bool idle READ idle NOTIFY idleChanged)
    Q_PROPERTY(int activeBrightness READ activeBrightness WRITE setActiveBrightness NOTIFY activeBrightnessChanged)
    Q_PROPERTY(int idleBrightness READ idleBrightness WRITE setIdleBrightness NOTIFY idleBrightnessChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit ScreenIdleController(QObject *parent = nullptr);
    ~ScreenIdleController() override;

    int idleTimeoutMs() const;
    void setIdleTimeoutMs(int idleTimeoutMs);
    bool idle() const;
    int activeBrightness() const;
    void setActiveBrightness(int activeBrightness);
    int idleBrightness() const;
    void setIdleBrightness(int idleBrightness);
    bool enabled() const;
    void setEnabled(bool enabled);

    bool eventFilter(QObject *watched, QEvent *event) override;

    Q_INVOKABLE void wake();
    Q_INVOKABLE void sleep();

signals:
    void idleTimeoutMsChanged();
    void idleChanged();
    void activeBrightnessChanged();
    void idleBrightnessChanged();
    void enabledChanged();
    void brightnessRequested(int percent);

private:
    void resetIdleTimer();
    void setIdle(bool idle);

    QTimer m_idleTimer;
    int m_idleTimeoutMs = 600000;
    int m_activeBrightness = 80;
    int m_idleBrightness = 0;
    bool m_idle = false;
    bool m_enabled = true;
    bool m_filterInstalled = false;
};
