#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "platform.h"

void PlatformPlugin::registerTypes(const char *uri) {
    //@uri Platform
    qmlRegisterSingletonType<Platform>(uri, 1, 0, "Platform", [](QQmlEngine*, QJSEngine*) -> QObject* { return new Platform; });
}

void PlatformPlugin::initializeEngine(QQmlEngine *engine, const char *uri) {
    // Les chemins d'import doivent être connus avant la création du singleton,
    // donc avant toute compilation de composant QML.
    Platform::setImportPaths(engine->importPathList());
    QQmlExtensionPlugin::initializeEngine(engine, uri);
}
