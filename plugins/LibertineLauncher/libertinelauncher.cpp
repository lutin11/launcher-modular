#include "libertinelauncher.h"
#include "libertineworker.h"
#include <QProcess>
#include <QObject>
#include <QString>
#include <QThread>
#include <QDebug>

LibertineLauncher::LibertineLauncher(QObject *parent) : QObject(parent) {}

void LibertineLauncher::launchLibertineApp(const QString &containerName, const QString &appName)
{
    LibertineWorker *worker = new LibertineWorker(containerName, appName);
    
    worker->run();
}
