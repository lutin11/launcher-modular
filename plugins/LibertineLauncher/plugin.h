#ifndef LIBERTINELAUNCHERPLUGIN_H
#define LIBERTINELAUNCHERPLUGIN_H

#include <QQmlExtensionPlugin>

class LibertineLauncherPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri);
};

#endif
