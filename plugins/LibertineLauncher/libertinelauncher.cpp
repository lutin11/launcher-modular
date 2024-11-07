#include "libertinelauncher.h"
#include <QProcess>
#include <QDebug>

LibertineWorker::LibertineWorker(QObject *parent) : QObject(parent), xWaylandProcess(nullptr), libertineProcess(nullptr) {}

void LibertineWorker::launchLibertineApp(const QString &containerName, const QString &appName)
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString displayValue = env.value("DISPLAY", ":1");  // Default to :0 if DISPLAY is not set
    env.insert("DISPLAY", displayValue);
    env.insert("APP_EXEC_POLICY", "unconfined");

    // Set up XWayland process
    xWaylandProcess = new QProcess(this);
    xWaylandProcess->setProcessEnvironment(env);
    xWaylandProcess->start("Xwayland", QStringList() << "-once" << "-sigstop");

    // Check XWayland start success
    if (!xWaylandProcess->waitForStarted()) {
        qDebug() << "Error: Unable to start Xwayland";
        return;
    }

    qDebug() << "XWayland started with DISPLAY=" << displayValue;

    // Set up and launch Libertine app process
    libertineProcess = new QProcess(this);
    libertineProcess->setProcessEnvironment(env);
    QStringList arguments = { "-i", containerName, appName };
    libertineProcess->start("libertine-launch", arguments);

    //Terminate XWayland after the app completes if needed
    if (xWaylandProcess->state() != QProcess::NotRunning) {
        xWaylandProcess->terminate();
        xWaylandProcess->waitForFinished();
    }

   if (!libertineProcess->waitForStarted()) {
       qDebug() << "Erreur : Impossible de lancer l'application" << appName;
   } else {
       qDebug() << "Lancement de l'application" << appName << "dans le conteneur" << containerName;
   }
    qDebug() << "Launching Libertine app" << appName << "in container" << containerName;
}
