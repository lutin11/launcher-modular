#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "libertinelauncher.h"
#include "libertineworker.h"

void LibertineLauncherPlugin::registerTypes(const char *uri) {
    //@uri LibertineLauncher
    qmlRegisterSingletonType<LibertineLauncher>(uri, 1, 0, "LibertineLauncher", [](QQmlEngine*, QJSEngine*) -> QObject* { return new LibertineLauncher; });
    qmlRegisterType<LibertineWorker>(uri, 1, 0, "LibertineWorker");
}
