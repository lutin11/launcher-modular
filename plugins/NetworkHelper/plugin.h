#ifndef NETWORKHELPERPLUGIN_H
#define NETWORKHELPERPLUGIN_H

#include <QQmlExtensionPlugin>

class NetworkHelperPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override;
};

#endif
