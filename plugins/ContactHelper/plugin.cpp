#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "contacthelper.h"

void ContactHelperPlugin::registerTypes(const char *uri) {
    //@uri ContactHelper
    qmlRegisterType<ContactHelper>(uri, 1, 0, "ContactHelper");}

