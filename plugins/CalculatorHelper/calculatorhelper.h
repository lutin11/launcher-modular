#ifndef CALCULATORHELPER_H
#define CALCULATORHELPER_H

#include <QObject>
#include <QJSEngine>
#include <QRegularExpression>

class CalculatorHelper : public QObject {
    Q_OBJECT
public:
    explicit CalculatorHelper(QObject *parent = nullptr);

    Q_INVOKABLE void processInput(const QString &input);

signals:
    void resultReady(const QString &result);
    void noResult();

private slots:
    void onReplyFinished();

protected:
    bool isMathExpression(const QString &input) const;
    void calculateExpression(const QString &expression);
};

#endif // CalculatorHelper_H
