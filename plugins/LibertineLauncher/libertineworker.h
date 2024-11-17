#ifndef LIBERTINEWORKER_H
#define LIBERTINEWORKER_H

#include <QObject>
#include <QString>

class LibertineWorker : public QObject
{
    Q_OBJECT

public:
    explicit LibertineWorker(const QString &containerName = "", const QString &appName = "", QObject *parent = nullptr);

    void run();

signals:
    void finished();

private:
    QString m_containerName;
    QString m_appName;
};

#endif // LIBERTINEWORKER_H
