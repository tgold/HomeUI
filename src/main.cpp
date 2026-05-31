#include "DashboardConfig.h"
#include "MjpegView.h"
#include "OpenHabClient.h"
#include "ScreenIdleController.h"
#include "SonosClient.h"

#ifdef HOMEUI_HAS_MQTT
#include "MqttClient.h"
#endif

#include <QCoreApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLoggingCategory>
#include <QProcess>
#include <QProcessEnvironment>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QStringList>
#include <QTime>
#include <QUrl>
#include <qqml.h>

namespace {

Q_LOGGING_CATEGORY(lcBrightness, "homeui.brightness")
Q_LOGGING_CATEGORY(lcMain, "homeui.main")

QString envValue(const QProcessEnvironment &env, const QString &name, const QString &fallback = QString())
{
    return env.value(name, fallback);
}

int envInt(const QProcessEnvironment &env, const QString &name, int fallback)
{
    const QString raw = env.value(name);
    if (raw.isEmpty()) {
        return fallback;
    }
    bool ok = false;
    const int value = raw.toInt(&ok);
    return ok ? value : fallback;
}

bool envBool(const QProcessEnvironment &env, const QString &name, bool fallback)
{
    const QString raw = env.value(name).trimmed().toLower();
    if (raw.isEmpty()) {
        return fallback;
    }
    if (raw == QStringLiteral("1") || raw == QStringLiteral("true")
        || raw == QStringLiteral("yes") || raw == QStringLiteral("on")) {
        return true;
    }
    if (raw == QStringLiteral("0") || raw == QStringLiteral("false")
        || raw == QStringLiteral("no") || raw == QStringLiteral("off")) {
        return false;
    }
    return fallback;
}

QTime parseClockTime(const QString &raw, const QTime &fallback, const QString &label)
{
    const QString trimmed = raw.trimmed();
    if (trimmed.isEmpty()) {
        return fallback;
    }

    const QStringList formats = {
        QStringLiteral("H:mm"),
        QStringLiteral("HH:mm"),
        QStringLiteral("H:mm:ss"),
        QStringLiteral("HH:mm:ss"),
    };
    for (const QString &format : formats) {
        const QTime parsed = QTime::fromString(trimmed, format);
        if (parsed.isValid()) {
            return parsed;
        }
    }

    qCWarning(lcMain,
              "Ignoring invalid %s time '%s' (expected HH:mm)",
              qPrintable(label),
              qPrintable(trimmed));
    return fallback;
}

QString findBacklightPath()
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    const QString configured = env.value(QStringLiteral("HOMEUI_BRIGHTNESS_PATH"));
    if (!configured.isEmpty() && QFile::exists(configured)) {
        return configured;
    }

    QDir base(QStringLiteral("/sys/class/backlight"));
    if (!base.exists()) {
        return {};
    }
    const QStringList entries = base.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        const QString candidate = base.absoluteFilePath(entry) + QStringLiteral("/brightness");
        if (QFile::exists(candidate)) {
            return candidate;
        }
    }
    return {};
}

int readMaxBrightness(const QString &brightnessPath)
{
    QFileInfo info(brightnessPath);
    const QString maxPath = info.absolutePath() + QStringLiteral("/max_brightness");
    QFile file(maxPath);
    if (!file.open(QIODevice::ReadOnly)) {
        return 255;
    }
    bool ok = false;
    const int value = file.readAll().trimmed().toInt(&ok);
    return (ok && value > 0) ? value : 255;
}

QString displayPowerCommand(bool powerOn)
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    const QString configured = env.value(powerOn
            ? QStringLiteral("HOMEUI_DISPLAY_ON_COMMAND")
            : QStringLiteral("HOMEUI_DISPLAY_OFF_COMMAND"))
        .trimmed();
    if (!configured.isEmpty()) {
        return configured;
    }

    const QString vcgencmd = QStandardPaths::findExecutable(QStringLiteral("vcgencmd"));
    if (!vcgencmd.isEmpty()) {
        return QStringLiteral("%1 display_power %2").arg(vcgencmd, powerOn ? QStringLiteral("1") : QStringLiteral("0"));
    }

    const QString xset = QStandardPaths::findExecutable(QStringLiteral("xset"));
    if (!xset.isEmpty()) {
        return QStringLiteral("%1 dpms force %2").arg(xset, powerOn ? QStringLiteral("on") : QStringLiteral("off"));
    }

    return {};
}

bool applyDisplayPower(bool powerOn, const QString &reason)
{
    static int lastRequestedPowerState = -1;
    const int requestedPowerState = powerOn ? 1 : 0;
    if (lastRequestedPowerState == requestedPowerState) {
        return true;
    }

    const QString command = displayPowerCommand(powerOn);
    if (command.isEmpty()) {
        qCWarning(lcBrightness,
                  "Display power %s skipped: no backlight control and no display power command configured (%s)",
                  powerOn ? "on" : "off",
                  qPrintable(reason));
        return false;
    }

    const bool started = QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), command});
    if (!started) {
        qCWarning(lcBrightness,
                  "Unable to start display power %s command '%s' (%s)",
                  powerOn ? "on" : "off",
                  qPrintable(command),
                  qPrintable(reason));
        return false;
    }

    lastRequestedPowerState = requestedPowerState;
    qCInfo(lcBrightness,
           "Requested display power %s via '%s' (%s)",
           powerOn ? "on" : "off",
           qPrintable(command),
           qPrintable(reason));
    return true;
}

void applyBrightnessPercent(int percent)
{
    const int clamped = qBound(0, percent, 100);
    const QString brightnessPath = findBacklightPath();
    if (brightnessPath.isEmpty()) {
        applyDisplayPower(clamped > 0, QStringLiteral("no /sys/class/backlight device found, requested %1%").arg(clamped));
        return;
    }
    const int maxValue = readMaxBrightness(brightnessPath);
    const int raw = (maxValue * clamped) / 100;

    QFile file(brightnessPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcBrightness, "Unable to write %s: %s", qPrintable(brightnessPath), qPrintable(file.errorString()));
        applyDisplayPower(clamped > 0, QStringLiteral("unable to write %1, requested %2%").arg(brightnessPath).arg(clamped));
        return;
    }
    file.write(QByteArray::number(raw));
    qCInfo(lcBrightness, "Set brightness to %d%% (raw=%d max=%d)", clamped, raw, maxValue);
}

void applyLogLevel(const QString &level)
{
    if (level.isEmpty()) {
        return;
    }
    const QString lower = level.trimmed().toLower();
    // Map a small set of friendly aliases to Qt logging filter rules. Users
    // who need more granular control can still set QT_LOGGING_RULES
    // directly; that wins over our default.
    QString rules;
    if (lower == QStringLiteral("debug")) {
        rules = QStringLiteral("homeui.*.debug=true\nqt.*.debug=false\n");
    } else if (lower == QStringLiteral("warning") || lower == QStringLiteral("warn")) {
        rules = QStringLiteral("homeui.*.debug=false\nhomeui.*.info=false\n");
    } else if (lower == QStringLiteral("error") || lower == QStringLiteral("critical")) {
        rules = QStringLiteral("homeui.*.debug=false\nhomeui.*.info=false\nhomeui.*.warning=false\n");
    } else {
        // info (default) - homeui.*.info=true is implied by Qt's default.
        rules = QStringLiteral("homeui.*.debug=false\n");
    }
    QLoggingCategory::setFilterRules(rules);
    qSetMessagePattern(QStringLiteral("[%{time yyyy-MM-dd hh:mm:ss.zzz}] %{category} %{type}: %{message}"));
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("HomeUI"));
    QGuiApplication::setOrganizationName(QStringLiteral("HomeUI"));

    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    // Avoid Qt6CT / desktop system palettes bleeding into Quick Controls (invisible
    // ComboBox text on dark tiles). Respect an explicit user override.
    if (!env.contains(QStringLiteral("QT_QUICK_CONTROLS_STYLE"))) {
        qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    }

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Native OpenHAB touchscreen dashboard"));
    parser.addHelpOption();
    const QCommandLineOption openHabUrlOption(
        QStringLiteral("openhab-url"),
        QStringLiteral("OpenHAB base URL, for example http://openhabian:8080."),
        QStringLiteral("url"));
    const QCommandLineOption openHabTokenOption(
        QStringLiteral("openhab-token"),
        QStringLiteral("OpenHAB API token. HOMEUI_OPENHAB_TOKEN is preferred for regular use."),
        QStringLiteral("token"));
    const QCommandLineOption noOpenHabOption(
        QStringLiteral("no-openhab"),
        QStringLiteral("Start the UI without connecting to OpenHAB."));
    const QCommandLineOption configOption(
        QStringLiteral("config"),
        QStringLiteral("Dashboard JSON config path. HOMEUI_CONFIG is preferred for regular use."),
        QStringLiteral("path"));
    const QCommandLineOption noWatchOption(
        QStringLiteral("no-watch-config"),
        QStringLiteral("Disable automatic reload when dashboard.json changes on disk."));
    const QCommandLineOption mqttBrokerOption(
        QStringLiteral("mqtt-broker"),
        QStringLiteral("MQTT broker URL, for example mqtt://openhabian:1883."),
        QStringLiteral("url"));
    const QCommandLineOption mqttUserOption(
        QStringLiteral("mqtt-username"),
        QStringLiteral("MQTT username. HOMEUI_MQTT_USERNAME is preferred for regular use."),
        QStringLiteral("user"));
    const QCommandLineOption mqttPasswordOption(
        QStringLiteral("mqtt-password"),
        QStringLiteral("MQTT password. HOMEUI_MQTT_PASSWORD is preferred for regular use."),
        QStringLiteral("password"));
    const QCommandLineOption mqttClientIdOption(
        QStringLiteral("mqtt-client-id"),
        QStringLiteral("MQTT client id. Defaults to homeui-<host>-<pid>."),
        QStringLiteral("id"));
    const QCommandLineOption mqttPanelIdOption(
        QStringLiteral("mqtt-panel-id"),
        QStringLiteral("Panel identifier used in home/panel/<id>/ topics. Defaults to 'main'."),
        QStringLiteral("id"));
    const QCommandLineOption noMqttOption(
        QStringLiteral("no-mqtt"),
        QStringLiteral("Start the UI without connecting to MQTT."));
    const QCommandLineOption idleTimeoutOption(
        QStringLiteral("idle-timeout"),
        QStringLiteral("Milliseconds of inactivity before the screen dims (default 600000, 0 disables)."),
        QStringLiteral("ms"));
    const QCommandLineOption activeBrightnessOption(
        QStringLiteral("active-brightness"),
        QStringLiteral("Brightness percent restored on wake (default 80)."),
        QStringLiteral("percent"));
    const QCommandLineOption idleBrightnessOption(
        QStringLiteral("idle-brightness"),
        QStringLiteral("Brightness percent applied when idle (default 0 = off)."),
        QStringLiteral("percent"));
    const QCommandLineOption noNightModeOption(
        QStringLiteral("no-night-mode"),
        QStringLiteral("Disable the scheduled overnight screen-off window."));
    const QCommandLineOption nightModeStartOption(
        QStringLiteral("night-start"),
        QStringLiteral("Clock time when overnight screen-off starts (default 00:00)."),
        QStringLiteral("HH:mm"));
    const QCommandLineOption nightModeEndOption(
        QStringLiteral("night-end"),
        QStringLiteral("Clock time when the screen turns back on (default 06:30)."),
        QStringLiteral("HH:mm"));
    const QCommandLineOption logLevelOption(
        QStringLiteral("log-level"),
        QStringLiteral("Log verbosity: debug | info | warning | error. HOMEUI_LOG_LEVEL is preferred for regular use."),
        QStringLiteral("level"));
    parser.addOption(openHabUrlOption);
    parser.addOption(openHabTokenOption);
    parser.addOption(noOpenHabOption);
    parser.addOption(configOption);
    parser.addOption(noWatchOption);
    parser.addOption(mqttBrokerOption);
    parser.addOption(mqttUserOption);
    parser.addOption(mqttPasswordOption);
    parser.addOption(mqttClientIdOption);
    parser.addOption(mqttPanelIdOption);
    parser.addOption(noMqttOption);
    parser.addOption(idleTimeoutOption);
    parser.addOption(activeBrightnessOption);
    parser.addOption(idleBrightnessOption);
    parser.addOption(noNightModeOption);
    parser.addOption(nightModeStartOption);
    parser.addOption(nightModeEndOption);
    parser.addOption(logLevelOption);
    parser.process(app);

    const QString logLevel = parser.isSet(logLevelOption)
        ? parser.value(logLevelOption)
        : envValue(env, QStringLiteral("HOMEUI_LOG_LEVEL"), QStringLiteral("info"));
    applyLogLevel(logLevel);
    qCInfo(lcMain, "HomeUI starting (Qt %s, log level %s)", qVersion(), qPrintable(logLevel));

    DashboardConfig dashboardConfig;
    if (parser.isSet(configOption)) {
        dashboardConfig.setSourcePath(parser.value(configOption));
    }
    dashboardConfig.reload();
    dashboardConfig.setWatching(!parser.isSet(noWatchOption));

    OpenHabClient openHabClient;
    if (parser.isSet(openHabUrlOption)) {
        openHabClient.setBaseUrl(parser.value(openHabUrlOption));
    }
    if (parser.isSet(openHabTokenOption)) {
        openHabClient.setAccessToken(parser.value(openHabTokenOption));
    }
    if (parser.isSet(noOpenHabOption)) {
        openHabClient.setEnabled(false);
    }

    ScreenIdleController screenIdle;
    SonosClient sonosClient;
    const int idleTimeoutMs = parser.isSet(idleTimeoutOption)
        ? parser.value(idleTimeoutOption).toInt()
        : envInt(env, QStringLiteral("HOMEUI_IDLE_TIMEOUT_MS"), 600000);
    screenIdle.setIdleTimeoutMs(idleTimeoutMs);
    const int activeBrightness = parser.isSet(activeBrightnessOption)
        ? parser.value(activeBrightnessOption).toInt()
        : envInt(env, QStringLiteral("HOMEUI_ACTIVE_BRIGHTNESS"), 80);
    const int idleBrightness = parser.isSet(idleBrightnessOption)
        ? parser.value(idleBrightnessOption).toInt()
        : envInt(env, QStringLiteral("HOMEUI_IDLE_BRIGHTNESS"), 0);
    screenIdle.setActiveBrightness(activeBrightness);
    screenIdle.setIdleBrightness(idleBrightness);
    const bool nightModeEnabled = parser.isSet(noNightModeOption)
        ? false
        : envBool(env, QStringLiteral("HOMEUI_NIGHT_MODE_ENABLED"), true);
    const QTime nightModeStart = parseClockTime(
        parser.isSet(nightModeStartOption)
            ? parser.value(nightModeStartOption)
            : envValue(env, QStringLiteral("HOMEUI_NIGHT_MODE_START")),
        QTime(0, 0),
        QStringLiteral("night mode start"));
    const QTime nightModeEnd = parseClockTime(
        parser.isSet(nightModeEndOption)
            ? parser.value(nightModeEndOption)
            : envValue(env, QStringLiteral("HOMEUI_NIGHT_MODE_END")),
        QTime(6, 30),
        QStringLiteral("night mode end"));
    screenIdle.setNightModeStartTime(nightModeStart);
    screenIdle.setNightModeEndTime(nightModeEnd);
    screenIdle.setNightModeEnabled(nightModeEnabled);
    QObject::connect(&screenIdle, &ScreenIdleController::brightnessRequested,
                     &app, [](int percent) {
                         applyBrightnessPercent(percent);
                     });
    screenIdle.refreshNightMode();

    qmlRegisterType<MjpegView>("HomeUI", 1, 0, "MjpegView");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("dashboardConfig"), &dashboardConfig);
    engine.rootContext()->setContextProperty(QStringLiteral("openhabClient"), &openHabClient);
    engine.rootContext()->setContextProperty(QStringLiteral("sonosClient"), &sonosClient);
    engine.rootContext()->setContextProperty(QStringLiteral("screenIdle"), &screenIdle);

#ifdef HOMEUI_HAS_MQTT
    MqttClient mqttClient;
    const QString broker = parser.isSet(mqttBrokerOption)
        ? parser.value(mqttBrokerOption)
        : envValue(env, QStringLiteral("HOMEUI_MQTT_BROKER"));
    if (!broker.isEmpty()) {
        mqttClient.setBrokerUrl(broker);
    }
    const QString mqttUser = parser.isSet(mqttUserOption)
        ? parser.value(mqttUserOption)
        : envValue(env, QStringLiteral("HOMEUI_MQTT_USERNAME"));
    if (!mqttUser.isEmpty()) {
        mqttClient.setUsername(mqttUser);
    }
    const QString mqttPassword = parser.isSet(mqttPasswordOption)
        ? parser.value(mqttPasswordOption)
        : envValue(env, QStringLiteral("HOMEUI_MQTT_PASSWORD"));
    if (!mqttPassword.isEmpty()) {
        mqttClient.setPassword(mqttPassword);
    }
    const QString clientId = parser.isSet(mqttClientIdOption)
        ? parser.value(mqttClientIdOption)
        : envValue(env, QStringLiteral("HOMEUI_MQTT_CLIENT_ID"));
    if (!clientId.isEmpty()) {
        mqttClient.setClientId(clientId);
    }
    const QString panelId = parser.isSet(mqttPanelIdOption)
        ? parser.value(mqttPanelIdOption)
        : envValue(env, QStringLiteral("HOMEUI_MQTT_PANEL_ID"));
    if (!panelId.isEmpty()) {
        mqttClient.setPanelId(panelId);
    }
    if (parser.isSet(noMqttOption)) {
        mqttClient.setEnabled(false);
    }

    engine.rootContext()->setContextProperty(QStringLiteral("mqttClient"), &mqttClient);

    QObject::connect(&openHabClient, &OpenHabClient::connectedChanged, &mqttClient, [&]() {
        mqttClient.setStatusField(QStringLiteral("openhabConnected"), openHabClient.connected());
    });
    QObject::connect(&mqttClient, &MqttClient::reloadRequested, &dashboardConfig, [&]() {
        dashboardConfig.reload();
    });
    QObject::connect(&mqttClient, &MqttClient::brightnessRequested, &app, [&](int percent) {
        // setActiveBrightness already routes through ScreenIdleController's
        // brightnessRequested signal, which the QApplication-scoped connect
        // below forwards to applyBrightnessPercent(). No double-write.
        screenIdle.setActiveBrightness(percent);
    });
    QObject::connect(&screenIdle, &ScreenIdleController::idleChanged, &mqttClient, [&]() {
        mqttClient.setStatusField(QStringLiteral("idle"), screenIdle.idle());
    });
#else
    static QObject mqttDummy;
    engine.rootContext()->setContextProperty(QStringLiteral("mqttClient"), &mqttDummy);
    Q_UNUSED(env);
#endif

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.load(QUrl(QStringLiteral("qrc:/HomeUI/qml/Main.qml")));
    openHabClient.start();

#ifdef HOMEUI_HAS_MQTT
    mqttClient.setStatusField(QStringLiteral("openhabConnected"), openHabClient.connected());
    mqttClient.start();
#endif

    // Apply the initial backlight level so the panel boots into a known
    // brightness rather than whatever value was last written to /sys.
    if (screenIdle.enabled()) {
        applyBrightnessPercent(screenIdle.idle() ? idleBrightness : activeBrightness);
    }

    return app.exec();
}
