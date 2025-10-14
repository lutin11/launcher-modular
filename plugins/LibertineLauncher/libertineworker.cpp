#include "libertineworker.h"
#include <QProcess>
#include <QObject>
#include <QString>
#include <QThread>
#include <QDebug>


LibertineWorker::LibertineWorker(const QString &containerName, const QString &appName, QObject *parent)
    : QObject(parent), m_containerName(containerName), m_appName(appName) {}

void LibertineWorker::run() {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        QString displayValue = env.value("DISPLAY", ":0");  // TODO set environement at launcher modular startup
        env.insert("DISPLAY", displayValue);

        QProcess libertineProcess;
        libertineProcess.setProcessEnvironment(env);

        libertineProcess.start("ubuntu-app-launch", QStringList() << m_containerName + "_" + m_appName);

        if (!libertineProcess.waitForStarted()) {
            qDebug() << "Erreur : Failed to start application" << m_appName;
        } else {
            qDebug() << "Application " << m_appName << " starting into containers " << m_containerName;
        }

        // Wait for the app to finish, then stop XWayland
        libertineProcess.waitForFinished(-1);// avoid the 30-second timeout

        emit finished();
}