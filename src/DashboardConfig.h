#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantList>

class DashboardConfig : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sourcePath READ sourcePath WRITE setSourcePath NOTIFY sourcePathChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY validChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY errorTextChanged)
    Q_PROPERTY(QVariantList pages READ pages NOTIFY pagesChanged)
    Q_PROPERTY(QString theme READ theme NOTIFY themeChanged)
    Q_PROPERTY(bool lcars READ lcars NOTIFY themeChanged)
    Q_PROPERTY(QString title READ title NOTIFY titleChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(bool watching READ watching WRITE setWatching NOTIFY watchingChanged)

public:
    explicit DashboardConfig(QObject *parent = nullptr);

    QString sourcePath() const;
    void setSourcePath(const QString &sourcePath);

    bool valid() const;
    QString errorText() const;
    QVariantList pages() const;
    QString theme() const;
    bool lcars() const;
    QString title() const;
    int revision() const;
    bool watching() const;
    void setWatching(bool watching);

    Q_INVOKABLE bool reload();
    Q_INVOKABLE QString resolveAssetUrl(const QString &path) const;

signals:
    void sourcePathChanged();
    void validChanged();
    void errorTextChanged();
    void pagesChanged();
    void themeChanged();
    void titleChanged();
    void revisionChanged();
    void watchingChanged();
    void configFileChanged();

private:
    static QString defaultConfigPath();
    bool validateConfig(const QVariantMap &config, QString *errorText) const;
    bool validatePanel(const QVariantMap &panel, const QString &path, QString *errorText) const;
    void setValid(bool valid);
    void setErrorText(const QString &errorText);
    void setPages(const QVariantList &pages);
    void setTheme(const QString &theme);
    void setTitle(const QString &title);
    void refreshWatchedPath();
    void onPathChanged(const QString &path);

    QString m_sourcePath;
    bool m_valid = false;
    QString m_errorText;
    QVariantList m_pages;
    QString m_theme = QStringLiteral("default");
    QString m_title;
    int m_revision = 0;
    bool m_watching = false;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadDebounce;
};
