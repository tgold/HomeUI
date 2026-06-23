#include "DashboardConfig.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QLoggingCategory>
#include <QProcessEnvironment>
#include <QStringList>
#include <QVariantMap>

namespace {
Q_LOGGING_CATEGORY(lcConfig, "homeui.config")

QString localFileUrl(const QString &path)
{
    return QUrl::fromLocalFile(QFileInfo(path).absoluteFilePath()).toString();
}

QStringList assetInstallSearchDirs()
{
    QStringList dirs;
    const QFileInfo exe(QCoreApplication::applicationFilePath());
    const QString exeDir = exe.absolutePath();
    dirs << QDir(exeDir).absoluteFilePath(QStringLiteral("../share/homeui/assets"));
    dirs << QStringLiteral("/usr/local/share/homeui/assets");
    dirs << QStringLiteral("/usr/share/homeui/assets");
    return dirs;
}

QString resolveLocalAssetPath(const QString &trimmed, const QString &configBaseDir)
{
    QStringList candidates;
    if (!configBaseDir.isEmpty()) {
        candidates << QDir(configBaseDir).absoluteFilePath(trimmed);
        const QString fileName = QFileInfo(trimmed).fileName();
        if (!fileName.isEmpty() && fileName != trimmed) {
            candidates << QDir(configBaseDir).absoluteFilePath(fileName);
        }
    }

    const QString fileName = QFileInfo(trimmed).fileName();
    if (!fileName.isEmpty()) {
        for (const QString &root : assetInstallSearchDirs()) {
            candidates << QDir(root).absoluteFilePath(fileName);
        }
    }

    for (const QString &candidate : candidates) {
        if (QFileInfo::exists(candidate)) {
            return candidate;
        }
    }
    return {};
}
} // namespace

namespace {
const QStringList ValidPanelTypes = {
    QStringLiteral("room"),
    QStringLiteral("energy"),
    QStringLiteral("camera"),
    QStringLiteral("mode"),
    QStringLiteral("controls"),
    QStringLiteral("mqtt"),
    QStringLiteral("sonos"),
    QStringLiteral("grafana"),
    QStringLiteral("irrigationFloorplan"),
    QStringLiteral("schematic"),
};

const QStringList ValidControlKinds = {
    QStringLiteral("switch"),
    QStringLiteral("dimmer"),
    QStringLiteral("tunablewhite"),
    QStringLiteral("whitelight"),
    QStringLiteral("color"),
    QStringLiteral("shutter"),
    QStringLiteral("thermostat"),
    QStringLiteral("scene"),
    QStringLiteral("progress"),
    QStringLiteral("gauge"),
    QStringLiteral("selector"),
    QStringLiteral("dropdown"),
    QStringLiteral("value"),
};

const QStringList ValidCameraFormats = {
    QStringLiteral("mjpeg"),
    QStringLiteral("snapshot"),
    QStringLiteral("placeholder"),
};

bool hasObjectList(const QVariantMap &object, const QString &key)
{
    const QVariant value = object.value(key);
    if (!value.canConvert<QVariantList>()) {
        return false;
    }

    const QVariantList list = value.toList();
    for (const QVariant &entry : list) {
        if (!entry.canConvert<QVariantMap>()) {
            return false;
        }
    }
    return true;
}
}

DashboardConfig::DashboardConfig(QObject *parent)
    : QObject(parent)
{
    m_reloadDebounce.setSingleShot(true);
    m_reloadDebounce.setInterval(250);
    connect(&m_reloadDebounce, &QTimer::timeout, this, [this]() {
        qCInfo(lcConfig, "Dashboard config changed on disk - reloading");
        reload();
    });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged,
            this, &DashboardConfig::onPathChanged);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged,
            this, &DashboardConfig::onPathChanged);

    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    setSourcePath(env.value(QStringLiteral("HOMEUI_CONFIG"), defaultConfigPath()));
}

QString DashboardConfig::sourcePath() const
{
    return m_sourcePath;
}

void DashboardConfig::setSourcePath(const QString &sourcePath)
{
    const QString cleanedPath = QDir::cleanPath(sourcePath.trimmed());
    if (m_sourcePath == cleanedPath) {
        return;
    }

    m_sourcePath = cleanedPath;
    emit sourcePathChanged();
    refreshWatchedPath();
}

bool DashboardConfig::watching() const
{
    return m_watching;
}

void DashboardConfig::setWatching(bool watching)
{
    if (m_watching == watching) {
        return;
    }
    m_watching = watching;
    emit watchingChanged();
    refreshWatchedPath();
}

void DashboardConfig::refreshWatchedPath()
{
    if (!m_watcher.files().isEmpty()) {
        m_watcher.removePaths(m_watcher.files());
    }
    if (!m_watcher.directories().isEmpty()) {
        m_watcher.removePaths(m_watcher.directories());
    }
    if (!m_watching || m_sourcePath.isEmpty()) {
        return;
    }
    const QFileInfo info(m_sourcePath);
    if (info.exists()) {
        m_watcher.addPath(m_sourcePath);
    }
    const QString dir = info.absolutePath();
    if (!dir.isEmpty() && QFileInfo(dir).isDir()) {
        m_watcher.addPath(dir);
    }
}

void DashboardConfig::onPathChanged(const QString &path)
{
    Q_UNUSED(path);
    // Editors often replace the file via tmp+rename, which drops the watch
    // on the old inode. Re-add the path on every change so future edits are
    // also caught.
    refreshWatchedPath();
    m_reloadDebounce.start();
    emit configFileChanged();
}

bool DashboardConfig::valid() const
{
    return m_valid;
}

QString DashboardConfig::errorText() const
{
    return m_errorText;
}

QVariantList DashboardConfig::pages() const
{
    return m_pages;
}

int DashboardConfig::revision() const
{
    return m_revision;
}

QString DashboardConfig::resolveAssetUrl(const QString &path) const
{
    const QString trimmed = path.trimmed();
    if (trimmed.isEmpty()) {
        return {};
    }

    if (trimmed.startsWith(QStringLiteral("qrc:"))
        || trimmed.startsWith(QStringLiteral("file:"))
        || trimmed.contains(QStringLiteral("://"))) {
        return trimmed;
    }

    const QFileInfo pathInfo(trimmed);
    if (pathInfo.isAbsolute()) {
        if (QFileInfo::exists(pathInfo.absoluteFilePath())) {
            return localFileUrl(pathInfo.absoluteFilePath());
        }
        qCWarning(lcConfig) << "Asset not found:" << trimmed;
        return {};
    }

    const QFileInfo configInfo(m_sourcePath);
    const QString baseDir = configInfo.absolutePath();
    const QString resolved = resolveLocalAssetPath(trimmed, baseDir);
    if (!resolved.isEmpty()) {
        return localFileUrl(resolved);
    }

    qCWarning(lcConfig) << "Asset not found:" << trimmed
                        << "(config dir:" << baseDir << ")";
    return {};
}

bool DashboardConfig::reload()
{
    QFile file(m_sourcePath);
    if (!file.open(QIODevice::ReadOnly)) {
        setPages({});
        setValid(false);
        setErrorText(QStringLiteral("Unable to open dashboard config '%1': %2").arg(m_sourcePath, file.errorString()));
        return false;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        setPages({});
        setValid(false);
        setErrorText(QStringLiteral("Dashboard config '%1' is not valid JSON: %2").arg(m_sourcePath, parseError.errorString()));
        return false;
    }

    const QVariantMap config = doc.object().toVariantMap();
    QString validationError;
    if (!validateConfig(config, &validationError)) {
        setPages({});
        setValid(false);
        setErrorText(QStringLiteral("Dashboard config '%1' failed validation: %2").arg(m_sourcePath, validationError));
        return false;
    }

    setPages(config.value(QStringLiteral("pages")).toList());
    setValid(true);
    setErrorText({});
    ++m_revision;
    emit revisionChanged();
    return true;
}

QString DashboardConfig::defaultConfigPath()
{
    const QString appDirPath = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        QDir::current().absoluteFilePath(QStringLiteral("config/dashboard.json")),
        QDir(appDirPath).absoluteFilePath(QStringLiteral("../config/dashboard.json")),
        QStringLiteral("/etc/homeui/dashboard.json"),
    };

    for (const QString &candidate : candidates) {
        if (QFile::exists(candidate)) {
            return QDir::cleanPath(candidate);
        }
    }

    return QDir::cleanPath(candidates.first());
}

bool DashboardConfig::validateConfig(const QVariantMap &config, QString *errorText) const
{
    if (!hasObjectList(config, QStringLiteral("pages"))) {
        *errorText = QStringLiteral("'pages' must be a non-empty array of page objects");
        return false;
    }

    const QVariantList pages = config.value(QStringLiteral("pages")).toList();
    if (pages.isEmpty()) {
        *errorText = QStringLiteral("'pages' must contain at least one page");
        return false;
    }

    for (int pageIndex = 0; pageIndex < pages.size(); ++pageIndex) {
        const QVariantMap page = pages.at(pageIndex).toMap();
        const QString pagePath = QStringLiteral("pages[%1]").arg(pageIndex);
        const QString title = page.value(QStringLiteral("title")).toString();
        if (title.trimmed().isEmpty()) {
            *errorText = QStringLiteral("%1.title must be set").arg(pagePath);
            return false;
        }

        const QString layout = page.value(QStringLiteral("layout"), QStringLiteral("columns")).toString();
        if (layout != QStringLiteral("columns")
            && layout != QStringLiteral("grid")
            && layout != QStringLiteral("masonry")) {
            *errorText = QStringLiteral("%1.layout must be 'columns', 'grid' or 'masonry'").arg(pagePath);
            return false;
        }

        if (layout == QStringLiteral("columns")) {
            if (!hasObjectList(page, QStringLiteral("columns")) || page.value(QStringLiteral("columns")).toList().isEmpty()) {
                *errorText = QStringLiteral("%1.columns must contain at least one column").arg(pagePath);
                return false;
            }

            const QVariantList columns = page.value(QStringLiteral("columns")).toList();
            for (int columnIndex = 0; columnIndex < columns.size(); ++columnIndex) {
                const QVariantMap column = columns.at(columnIndex).toMap();
                const QString columnPath = QStringLiteral("%1.columns[%2]").arg(pagePath).arg(columnIndex);
                if (!hasObjectList(column, QStringLiteral("panels")) || column.value(QStringLiteral("panels")).toList().isEmpty()) {
                    *errorText = QStringLiteral("%1.panels must contain at least one panel").arg(columnPath);
                    return false;
                }

                const QVariantList panels = column.value(QStringLiteral("panels")).toList();
                for (int panelIndex = 0; panelIndex < panels.size(); ++panelIndex) {
                    if (!validatePanel(panels.at(panelIndex).toMap(), QStringLiteral("%1.panels[%2]").arg(columnPath).arg(panelIndex), errorText)) {
                        return false;
                    }
                }
            }
        } else {
            if (!hasObjectList(page, QStringLiteral("panels")) || page.value(QStringLiteral("panels")).toList().isEmpty()) {
                *errorText = QStringLiteral("%1.panels must contain at least one panel").arg(pagePath);
                return false;
            }

            const QVariantList panels = page.value(QStringLiteral("panels")).toList();
            for (int panelIndex = 0; panelIndex < panels.size(); ++panelIndex) {
                if (!validatePanel(panels.at(panelIndex).toMap(), QStringLiteral("%1.panels[%2]").arg(pagePath).arg(panelIndex), errorText)) {
                    return false;
                }
            }
        }
    }

    return true;
}

bool DashboardConfig::validatePanel(const QVariantMap &panel, const QString &path, QString *errorText) const
{
    const QString type = panel.value(QStringLiteral("type")).toString();
    if (!ValidPanelTypes.contains(type)) {
        *errorText = QStringLiteral("%1.type must be one of: %2").arg(path, ValidPanelTypes.join(QStringLiteral(", ")));
        return false;
    }

    if (type == QStringLiteral("controls")) {
        if (!hasObjectList(panel, QStringLiteral("controls"))) {
            *errorText = QStringLiteral("%1.controls must be an array of control objects").arg(path);
            return false;
        }

        const QVariantList controls = panel.value(QStringLiteral("controls")).toList();
        for (int controlIndex = 0; controlIndex < controls.size(); ++controlIndex) {
            const QVariantMap control = controls.at(controlIndex).toMap();
            const QString controlPath = QStringLiteral("%1.controls[%2]").arg(path).arg(controlIndex);
            const QVariant kindValue = control.contains(QStringLiteral("kind"))
                                           ? control.value(QStringLiteral("kind"))
                                           : control.value(QStringLiteral("widget"));
            QString kind;
            if (kindValue.isValid() && !kindValue.toString().isEmpty()) {
                kind = kindValue.toString().toLower();
                if (!ValidControlKinds.contains(kind)) {
                    *errorText = QStringLiteral("%1.kind must be one of: %2")
                                     .arg(controlPath, ValidControlKinds.join(QStringLiteral(", ")));
                    return false;
                }
            }
            if (kind == QStringLiteral("selector") || kind == QStringLiteral("dropdown")) {
                const QVariant optionsValue = control.value(QStringLiteral("options"));
                if (!optionsValue.canConvert<QVariantList>() || optionsValue.toList().isEmpty()) {
                    *errorText = QStringLiteral("%1.options must be a non-empty array for %2 controls")
                                     .arg(controlPath, kind);
                    return false;
                }
            }
        }
    }

    if (type == QStringLiteral("sonos")) {
        const QVariant itemsValue = panel.value(QStringLiteral("items"));
        if (!itemsValue.canConvert<QVariantMap>()) {
            *errorText = QStringLiteral("%1.items must be an object of role->item mappings").arg(path);
            return false;
        }
        const QVariant favoritesValue = panel.value(QStringLiteral("favorites"));
        if (favoritesValue.isValid() && !favoritesValue.canConvert<QVariantList>()) {
            *errorText = QStringLiteral("%1.favorites must be an array of {label, command} objects").arg(path);
            return false;
        }
    }

    if (type == QStringLiteral("mqtt") && !hasObjectList(panel, QStringLiteral("items"))) {
        *errorText = QStringLiteral("%1.items must be an array of mqtt entries").arg(path);
        return false;
    }

    if (type == QStringLiteral("camera")) {
        const QVariant formatValue = panel.value(QStringLiteral("format"));
        if (formatValue.isValid() && !formatValue.toString().isEmpty()) {
            const QString format = formatValue.toString().toLower();
            if (!ValidCameraFormats.contains(format)) {
                *errorText = QStringLiteral("%1.format must be one of: %2")
                                 .arg(path, ValidCameraFormats.join(QStringLiteral(", ")));
                return false;
            }
        }
    }

    if (type == QStringLiteral("grafana")) {
        const QString baseUrl = panel.value(QStringLiteral("baseUrl")).toString().trimmed();
        if (baseUrl.isEmpty()) {
            *errorText = QStringLiteral("%1.baseUrl must be a non-empty Grafana base URL "
                                        "(e.g. http://grafana.local:3000)").arg(path);
            return false;
        }
        const QString dashboardUid = panel.value(QStringLiteral("dashboardUid")).toString().trimmed();
        if (dashboardUid.isEmpty()) {
            *errorText = QStringLiteral("%1.dashboardUid must be a non-empty Grafana dashboard UID")
                             .arg(path);
            return false;
        }
        const QVariant panelIdValue = panel.value(QStringLiteral("panelId"));
        bool panelIdOk = false;
        const int panelId = panelIdValue.toInt(&panelIdOk);
        if (!panelIdOk || panelId <= 0) {
            *errorText = QStringLiteral("%1.panelId must be a positive integer Grafana panel id")
                             .arg(path);
            return false;
        }
        const QVariant extraValue = panel.value(QStringLiteral("extraParams"));
        if (extraValue.isValid() && !extraValue.canConvert<QVariantMap>()) {
            *errorText = QStringLiteral("%1.extraParams must be an object of key/value query parameters")
                             .arg(path);
            return false;
        }
    }

    if (type == QStringLiteral("irrigationFloorplan")) {
        const QVariant imageSourceValue = panel.value(QStringLiteral("imageSource"));
        if (!imageSourceValue.isValid() || imageSourceValue.toString().trimmed().isEmpty()) {
            *errorText = QStringLiteral("%1.imageSource must be a non-empty image path/url").arg(path);
            return false;
        }

        if (!hasObjectList(panel, QStringLiteral("zones"))) {
            *errorText = QStringLiteral("%1.zones must be an array of zone objects").arg(path);
            return false;
        }
        const QVariantList zones = panel.value(QStringLiteral("zones")).toList();
        if (zones.isEmpty()) {
            *errorText = QStringLiteral("%1.zones must contain at least one zone").arg(path);
            return false;
        }
        for (int zoneIndex = 0; zoneIndex < zones.size(); ++zoneIndex) {
            const QVariantMap zone = zones.at(zoneIndex).toMap();
            const QString zonePath = QStringLiteral("%1.zones[%2]").arg(path).arg(zoneIndex);
            if (zone.value(QStringLiteral("label")).toString().trimmed().isEmpty()) {
                *errorText = QStringLiteral("%1.label must be set").arg(zonePath);
                return false;
            }
            const QVariant xValue = zone.value(QStringLiteral("x"));
            const QVariant yValue = zone.value(QStringLiteral("y"));
            bool xOk = false;
            bool yOk = false;
            const double x = xValue.toDouble(&xOk);
            const double y = yValue.toDouble(&yOk);
            if (!xOk || !yOk || x < 0.0 || x > 1.0 || y < 0.0 || y > 1.0) {
                *errorText = QStringLiteral("%1.x and %1.y must be numbers between 0 and 1").arg(zonePath);
                return false;
            }
            if (zone.value(QStringLiteral("activityItem")).toString().trimmed().isEmpty()) {
                *errorText = QStringLiteral("%1.activityItem must be set").arg(zonePath);
                return false;
            }
        }

        const QVariant sensorsValue = panel.value(QStringLiteral("sensors"));
        if (sensorsValue.isValid()) {
            if (!sensorsValue.canConvert<QVariantList>()) {
                *errorText = QStringLiteral("%1.sensors must be an array of sensor objects").arg(path);
                return false;
            }
            const QVariantList sensors = sensorsValue.toList();
            for (int sensorIndex = 0; sensorIndex < sensors.size(); ++sensorIndex) {
                if (!sensors.at(sensorIndex).canConvert<QVariantMap>()) {
                    *errorText = QStringLiteral("%1.sensors[%2] must be an object").arg(path).arg(sensorIndex);
                    return false;
                }
                const QVariantMap sensor = sensors.at(sensorIndex).toMap();
                const QString sensorPath = QStringLiteral("%1.sensors[%2]").arg(path).arg(sensorIndex);
                if (sensor.value(QStringLiteral("label")).toString().trimmed().isEmpty()) {
                    *errorText = QStringLiteral("%1.label must be set").arg(sensorPath);
                    return false;
                }
                if (sensor.value(QStringLiteral("item")).toString().trimmed().isEmpty()) {
                    *errorText = QStringLiteral("%1.item must be set").arg(sensorPath);
                    return false;
                }
            }
        }
    }

    if (type == QStringLiteral("schematic")) {
        const bool hasLabels = hasObjectList(panel, QStringLiteral("labels"));
        const bool hasControls = hasObjectList(panel, QStringLiteral("controls"));
        if (!hasLabels && !hasControls) {
            *errorText = QStringLiteral("%1 must define labels and/or controls arrays").arg(path);
            return false;
        }

        if (hasLabels) {
            const QVariantList labels = panel.value(QStringLiteral("labels")).toList();
            for (int labelIndex = 0; labelIndex < labels.size(); ++labelIndex) {
                const QVariantMap label = labels.at(labelIndex).toMap();
                const QString labelPath = QStringLiteral("%1.labels[%2]").arg(path).arg(labelIndex);
                if (label.value(QStringLiteral("label")).toString().trimmed().isEmpty()) {
                    *errorText = QStringLiteral("%1.label must be set").arg(labelPath);
                    return false;
                }

                const QVariant xValue = label.value(QStringLiteral("x"));
                const QVariant yValue = label.value(QStringLiteral("y"));
                bool xOk = false;
                bool yOk = false;
                const double x = xValue.toDouble(&xOk);
                const double y = yValue.toDouble(&yOk);
                if (!xOk || !yOk || x < 0.0 || x > 1.0 || y < 0.0 || y > 1.0) {
                    *errorText = QStringLiteral("%1.x and %1.y must be numbers between 0 and 1").arg(labelPath);
                    return false;
                }

                const QString item = label.value(QStringLiteral("item")).toString().trimmed();
                if (item.isEmpty() && !label.contains(QStringLiteral("value"))) {
                    *errorText = QStringLiteral("%1.item must be set unless value is provided").arg(labelPath);
                    return false;
                }
            }
        }

        if (hasControls) {
            const QVariantList controls = panel.value(QStringLiteral("controls")).toList();
            for (int controlIndex = 0; controlIndex < controls.size(); ++controlIndex) {
                const QVariantMap control = controls.at(controlIndex).toMap();
                const QString controlPath = QStringLiteral("%1.controls[%2]").arg(path).arg(controlIndex);
                if (control.value(QStringLiteral("label")).toString().trimmed().isEmpty()) {
                    *errorText = QStringLiteral("%1.label must be set").arg(controlPath);
                    return false;
                }

                const QString gutter = control.value(QStringLiteral("gutter")).toString().trimmed().toLower();
                if (!gutter.isEmpty() && gutter != QStringLiteral("left") && gutter != QStringLiteral("right")) {
                    *errorText = QStringLiteral("%1.gutter must be 'left' or 'right' when set").arg(controlPath);
                    return false;
                }
                if (gutter != QStringLiteral("left") && gutter != QStringLiteral("right")) {
                    const QVariant xValue = control.value(QStringLiteral("x"));
                    const QVariant yValue = control.value(QStringLiteral("y"));
                    bool xOk = false;
                    bool yOk = false;
                    const double x = xValue.toDouble(&xOk);
                    const double y = yValue.toDouble(&yOk);
                    if (!xOk || !yOk || x < 0.0 || x > 1.0 || y < 0.0 || y > 1.0) {
                        *errorText = QStringLiteral("%1.x and %1.y must be numbers between 0 and 1").arg(controlPath);
                        return false;
                    }
                }

                const QString kind = control.value(QStringLiteral("kind")).toString().trimmed().toLower();
                if (kind == QStringLiteral("selector") || kind == QStringLiteral("dropdown")) {
                    if (!hasObjectList(control, QStringLiteral("options"))) {
                        *errorText = QStringLiteral("%1.options must be a non-empty array for %2 controls")
                                          .arg(controlPath, kind);
                        return false;
                    }
                }
            }
        }
    }

    return true;
}

void DashboardConfig::setValid(bool valid)
{
    if (m_valid == valid) {
        return;
    }

    m_valid = valid;
    emit validChanged();
}

void DashboardConfig::setErrorText(const QString &errorText)
{
    if (m_errorText == errorText) {
        return;
    }

    m_errorText = errorText;
    emit errorTextChanged();
}

void DashboardConfig::setPages(const QVariantList &pages)
{
    m_pages = pages;
    emit pagesChanged();
}
