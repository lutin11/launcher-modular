#ifndef LIBERTINELAUNCHER_H
#define LIBERTINELAUNCHER_H

#include <QObject>
#include <QString>

class QProcess;

class LibertineWorker : public QObject
{
    Q_OBJECT

public:
    explicit LibertineWorker(QObject *parent = nullptr);

    Q_INVOKABLE void launchLibertineApp(const QString &containerName, const QString &appName);

private:
    QProcess *xWaylandProcess;
    QProcess *libertineProcess;
};

#endif // LIBERTINELAUNCHER_H
