#include "windowcontroller.h"
#include <QQuickView>
#include <QDebug>

WindowController::WindowController(QQuickView *view, QObject *parent)
    : QObject(parent), m_view(view)
{
}

void WindowController::toggleFullScreen()
{
    if (!m_view)
        return;

    if (m_view->windowState() == Qt::WindowFullScreen) {
        qDebug() << "WindowController: exiting fullscreen";
        m_view->showNormal();
    } else {
        qDebug() << "WindowController: entering fullscreen";
        m_view->showFullScreen();
    }
}
