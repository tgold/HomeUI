#include "DashboardConfig.h"
#include "MjpegView.h"
#include "OpenHabClient.h"

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
#include <QProcessEnvironment>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringList>
#include <QUrl>
#include <qqml.h>

namespace {

Q_LOGGING_CATEGORY(lcBrightness, "homeui.brightness")

QString envValue(const QProcessEnvironment &env, const QString &name, const QString &fallback = QString())
{
    return env.value(name, fallback);
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

void applyBrightnessPercent(int percent)
{
    const int clamped = qBound(0, percent, 100);
    const QString brightnessPath = findBacklightPath();
    if (brightnessPath.isEmpty()) {
        qCWarning(lcBrightness, "Brightness request ignored: no /sys/class/backlight device found (requested %d%%)", clamped);
        return;
    }
    const int maxValue = readMaxBrightness(brightnessPath);
    const int raw = (maxValue * clamped) / 100;

    QFile file(brightnessPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcBrightness, "Unable to write %s: %s", qPrintable(brightnessPath), qPrintable(file.errorString()));
        return;
    }
    file.write(QByteArray::number(raw));
    qCInfo(lcBrightness, "Set brightness to %d%% (raw=%d max=%d)", clamped, raw, maxValue);
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("HomeUI"));
    QGuiApplication::setOrganizationName(QStringLiteral("HomeUI"));

    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();

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
    parser.addOption(openHabUrlOption);
    parser.addOption(openHabTokenOption);
    parser.addOption(noOpenHabOption);
    parser.addOption(configOption);
    parser.addOption(mqttBrokerOption);
    parser.addOption(mqttUserOption);
    parser.addOption(mqttPasswordOption);
    parser.addOption(mqttClientIdOption);
    parser.addOption(mqttPanelIdOption);
    parser.addOption(noMqttOption);
    parser.process(app);

    DashboardConfig dashboardConfig;
    if (parser.isSet(configOption)) {
        dashboardConfig.setSourcePath(parser.value(configOption));
    }
    dashboardConfig.reload();

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

    qmlRegisterType<MjpegView>("HomeUI", 1, 0, "MjpegView");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("dashboardConfig"), &dashboardConfig);
    engine.rootContext()->setContextProperty(QStringLiteral("openhabClient"), &openHabClient);

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
    QObject::connect(&mqttClient, &MqttClient::brightnessRequested, &app, [](int percent) {
        applyBrightnessPercent(percent);
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

    return app.exec();
}
