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
        env.insert("APP_EXEC_POLICY", "unconfined");

        // Start XWayland libertineProcess synchronously
        QProcess xWaylandProcess;
        xWaylandProcess.setProcessEnvironment(env);
        QStringList waylandParams;
        waylandParams << "-once" << "-sigstop";
        xWaylandProcess.start("Xwayland", waylandParams);

        // Wait for XWayland to start
        if (!xWaylandProcess.waitForStarted()) {
            qDebug() << "Erreur : Impossible de démarrer XWayland";
            emit finished();
            return;
        }
        qDebug() << "XWayland démarré avec DISPLAY=" << displayValue;

        // Launch libertine app after XWayland is ready
        QProcess libertineProcess;
        libertineProcess.setProcessEnvironment(env);
        QStringList arguments;
        arguments << "-i" << m_containerName << m_appName;
        libertineProcess.start("libertine-launch", arguments);

        if (!libertineProcess.waitForStarted()) {
            qDebug() << "Erreur : Impossible de lancer l'application" << m_appName;
        } else {
            qDebug() << "Lancement de l'application" << m_appName << "dans le conteneur" << m_containerName;
        }

        // Wait for the app to finish, then stop XWayland
        libertineProcess.waitForFinished();
        if (xWaylandProcess.state() != QProcess::NotRunning) {
            xWaylandProcess.terminate();
            xWaylandProcess.waitForFinished();
        }
        qDebug() << "XWayland terminé";

        emit finished();
}