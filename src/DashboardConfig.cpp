#include "DashboardConfig.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QLoggingCategory>
#include <QProcessEnvironment>
#include <QStringList>
#include <QVariantMap>

namespace {
Q_LOGGING_CATEGORY(lcConfig, "homeui.config")
}

namespace {
const QStringList ValidPanelTypes = {
    QStringLiteral("room"),
    QStringLiteral("energy"),
    QStringLiteral("camera"),
    QStringLiteral("mode"),
    QStringLiteral("controls"),
    QStringLiteral("mqtt"),
    QStringLiteral("sonos"),
};

const QStringList ValidControlKinds = {
    QStringLiteral("switch"),
    QStringLiteral("dimmer"),
    QStringLiteral("color"),
    QStringLiteral("shutter"),
    QStringLiteral("thermostat"),
    QStringLiteral("scene"),
    QStringLiteral("progress"),
    QStringLiteral("gauge"),
    QStringLiteral("selector"),
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
        if (layout != QStringLiteral("columns") && layout != QStringLiteral("grid")) {
            *errorText = QStringLiteral("%1.layout must be 'columns' or 'grid'").arg(pagePath);
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
            if (kind == QStringLiteral("selector")) {
                const QVariant optionsValue = control.value(QStringLiteral("options"));
                if (!optionsValue.canConvert<QVariantList>() || optionsValue.toList().isEmpty()) {
                    *errorText = QStringLiteral("%1.options must be a non-empty array for selector controls").arg(controlPath);
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
