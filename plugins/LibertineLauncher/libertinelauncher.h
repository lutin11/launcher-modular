#ifndef LIBERTINELAUNCHER_H
#define LIBERTINELAUNCHER_H

#include <QObject>
#include <QString>

class LibertineLauncher : public QObject
{
    Q_OBJECT
public:
    explicit LibertineLauncher(QObject *parent = nullptr);

    // Function to launch an application in a specified Libertine container
    Q_INVOKABLE void launchLibertineApp(const QString &containerName, const QString &appName);
};

#endif // LIBERTINELAUNCHER_H
