#include "OpenHabClient.h"

#include <QCoreApplication>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("HomeUI"));
    QGuiApplication::setOrganizationName(QStringLiteral("HomeUI"));

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
    parser.addOption(openHabUrlOption);
    parser.addOption(openHabTokenOption);
    parser.addOption(noOpenHabOption);
    parser.process(app);

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

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("openhabClient"), &openHabClient);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.load(QUrl(QStringLiteral("qrc:/HomeUI/qml/Main.qml")));
    openHabClient.start();

    return app.exec();
}
