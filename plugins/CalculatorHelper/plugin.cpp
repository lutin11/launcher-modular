#include <QtQml>
#include <QtQml/QQmlContext>

#include "plugin.h"
#include "calculatorhelper.h"

void CalculatorHelperPlugin::registerTypes(const char *uri) {
    //@uri CalculatorHelper
    qmlRegisterSingletonType<CalculatorHelper>(uri, 1, 0, "CalculatorHelper", [](QQmlEngine*, QJSEngine*) -> QObject* { return new CalculatorHelper; });
}

