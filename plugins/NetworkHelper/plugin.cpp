#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "networkhelper.h"

void NetworkHelperPlugin::registerTypes(const char *uri) {
    //@uri NetworkHelper
    qmlRegisterSingletonType<NetworkHelper>(uri, 1, 0, "NetworkHelper", [](QQmlEngine*, QJSEngine*) -> QObject* { return new NetworkHelper; });
}

