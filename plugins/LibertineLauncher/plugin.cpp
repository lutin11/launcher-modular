#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "libertinelauncher.h"

void LibertineLauncherPlugin::registerTypes(const char *uri) {
    //@uri LibertineLauncher
    qmlRegisterSingletonType<LibertineWorker>(uri, 1, 0, "LibertineWorker", [](QQmlEngine*, QJSEngine*) -> QObject* { return new LibertineWorker; });
}
