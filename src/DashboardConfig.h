#pragma once

#include <QObject>
#include <QVariantList>

class DashboardConfig : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString sourcePath READ sourcePath WRITE setSourcePath NOTIFY sourcePathChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY validChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY errorTextChanged)
    Q_PROPERTY(QVariantList pages READ pages NOTIFY pagesChanged)
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    explicit DashboardConfig(QObject *parent = nullptr);

    QString sourcePath() const;
    void setSourcePath(const QString &sourcePath);

    bool valid() const;
    QString errorText() const;
    QVariantList pages() const;
    int revision() const;

    Q_INVOKABLE bool reload();

signals:
    void sourcePathChanged();
    void validChanged();
    void errorTextChanged();
    void pagesChanged();
    void revisionChanged();

private:
    static QString defaultConfigPath();
    bool validateConfig(const QVariantMap &config, QString *errorText) const;
    bool validatePanel(const QVariantMap &panel, const QString &path, QString *errorText) const;
    void setValid(bool valid);
    void setErrorText(const QString &errorText);
    void setPages(const QVariantList &pages);

    QString m_sourcePath;
    bool m_valid = false;
    QString m_errorText;
    QVariantList m_pages;
    int m_revision = 0;
};
