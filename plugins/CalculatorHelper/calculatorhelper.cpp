#include "calculatorhelper.h"
#include <QObject>
#include <QJSEngine>
#include <QDebug>
#include <QRegularExpression>

CalculatorHelper::CalculatorHelper(QObject *parent) : QObject(parent) {}

void CalculatorHelper::processInput(const QString &input) {
    qDebug() << "CalculatorHelper receive" << input;
    if (isMathExpression(input)) {
        calculateExpression(input);
    } else {
        qDebug() << "noResult";
        emit noResult();
    }
}

void CalculatorHelper::calculateExpression(const QString &expression) {
    QJSEngine engine;
    QJSValue result = engine.evaluate(expression);

    if (!result.isError()) {
        qDebug() << "Compute result is:" << result.toString();
        emit resultReady(expression + "=" +result.toString());
    } else {
        qDebug() << "computingError";
        emit resultReady(expression + "=");
    }
}

bool CalculatorHelper::isMathExpression(const QString &input) const {
    QRegularExpression mathExprPattern(R"(^[0-9\.\s\+\-\*\/\%\(\)]*$)");
    return mathExprPattern.match(input).hasMatch() && input.contains(QRegularExpression(R"([\+\-\*\/\%])"));
}

