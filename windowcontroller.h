#pragma once

#include <QObject>

class QQuickView;

class WindowController : public QObject
{
    Q_OBJECT
public:
    explicit WindowController(QQuickView *view, QObject *parent = nullptr);
    Q_INVOKABLE void toggleFullScreen();

private:
    QQuickView *m_view;
};
