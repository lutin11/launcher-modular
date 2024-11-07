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
    QThread *workerThread = new QThread;
    LibertineWorker *worker = new LibertineWorker(containerName, appName);

    worker->moveToThread(workerThread);

    connect(workerThread, &QThread::started, worker, &LibertineWorker::run);
    connect(worker, &LibertineWorker::finished, workerThread, &QThread::quit);
    connect(worker, &LibertineWorker::finished, worker, &LibertineWorker::deleteLater);
    connect(workerThread, &QThread::finished, workerThread, &QThread::deleteLater);

    workerThread->start();
}
