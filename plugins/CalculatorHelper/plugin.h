#ifndef CALCULATORHELPERPLUGIN_H
#define CALCULATORHELPERPLUGIN_H

#include <QQmlExtensionPlugin>

class CalculatorHelperPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char *uri) override;
};

#endif
