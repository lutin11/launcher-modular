#ifndef PLATFORMPLUGIN_H
#define PLATFORMPLUGIN_H

#include <QQmlExtensionPlugin>

class QQmlEngine;
class QJSEngine;

class PlatformPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri);
    // Transmet les chemins d'import du moteur à Platform : c'est ce qui permet
    // de savoir si un module QML extérieur (Lomiri.History, Lomiri.Contacts…)
    // est installé sur la machine.
    void initializeEngine(QQmlEngine *engine, const char *uri);
};

#endif
