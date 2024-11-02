#ifndef CONTACTHELPERPLUGIN_H
#define CONTACTHELPERPLUGIN_H

#include <QQmlExtensionPlugin>

class ContactHelperPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override;
};

#endif