#include "libertinelauncher.h"
#include <QProcess>
#include <QObject>
#include <QString>
#include <QDebug>
#include <thread>
#include <chrono>

LibertineLauncher::LibertineLauncher(QObject *parent) : QObject(parent) {}

void LibertineLauncher::launchLibertineApp(const QString &containerName, const QString &appName)
{
    // Get the current environment and set DISPLAY and APP_EXEC_POLICY
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    QString displayValue = env.value("DISPLAY", ":0");  // Default to :1 if DISPLAY is not set
    env.insert("DISPLAY", displayValue);
    env.insert("APP_EXEC_POLICY", "unconfined");

    // Set up XWayland process synchronously
    QProcess *xWayland = new QProcess();
    xWayland->setProcessEnvironment(env);
    xWayland->start("Xwayland", QStringList() << "-once" << "-sigstop");

    if (!xWayland->waitForStarted()) {
        qDebug() << "Erreur : Impossible de démarrer Xwayland";
        return;
    }
    qDebug() << "XWayland démarré avec DISPLAY=" << displayValue;

    // Give XWayland a moment to initialize completely before launching the app
    std::this_thread::sleep_for(std::chrono::seconds(2));


    //bool appStarted = QProcess::startDetached("libertine-launch", arguments, QString(), nullptr);
    
    QProcess *process = new QProcess();
    process->setProcessEnvironment(env);

    // Start the Libertine application in a detached process
    QStringList arguments;
    arguments << "-i" << containerName << appName;

    process->startDetached("libertine-launch", arguments);

    if (!process->waitForStarted()) {
        qDebug() << "Erreur : Impossible de lancer l'application" << appName;
    } else {
        qDebug() << "Lancement de l'application" << appName << "dans le conteneur" << containerName;
    }
    
    process->waitForFinished();

    //Terminate XWayland after the app completes if needed
    if (xWayland->state() != QProcess::NotRunning) {
        xWayland->terminate();
        xWayland->waitForFinished();
    }

    qDebug() << "XWayland terminé";
}

