#ifndef LIBERTINELAUNCHER_H
#define LIBERTINELAUNCHER_H

#include <QObject>
#include <QString>

class LibertineLauncher : public QObject
{
    Q_OBJECT
public:
    // Constructeur explicite
    explicit LibertineLauncher(QObject *parent = nullptr);

    // Méthode invocable depuis QML pour lancer une application dans un conteneur Libertine
    Q_INVOKABLE void launchLibertineApp(const QString &containerName, const QString &appName);
};

#endif // LIBERTINELAUNCHER_H
