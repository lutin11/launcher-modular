#include "libertinelauncher.h"
#include <QProcess>
#include <QObject>
#include <QString>
#include <QDebug>

LibertineLauncher::LibertineLauncher(QObject *parent) : QObject(parent) {}

void LibertineLauncher::launchLibertineApp(const QString &containerName, const QString &appName)
{
    QProcess *process = new QProcess(this);

    // Définir les variables d'environnement
    QStringList env = QProcess::systemEnvironment();

    // Définir APP_EXEC_POLICY
    env << "APP_EXEC_POLICY=unconfined";

    // Exécution de la commande "libertine-launch"
    QStringList arguments;
    arguments << "-i" << containerName << appName; // Utilisez `appName` sans l'argument `-a`

    process->start("libertine-launch", arguments);

    if (!process->waitForStarted()) {
        qDebug() << "Erreur : Impossible de lancer l'application" << appName;
    } else {
        qDebug() << "Lancement de l'application" << appName << "dans le conteneur" << containerName;
    }

    process->waitForFinished();
}


