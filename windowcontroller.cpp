#include "windowcontroller.h"
#include <QQuickView>
#include <QCursor>
#include <QGuiApplication>
#include <QDebug>

WindowController::WindowController(QQuickView *view, bool frameless, QObject *parent)
    : QObject(parent), m_view(view), m_frameless(frameless)
{
    // The drag and resize loops follow the global cursor, so that they also
    // work while the window itself is moving under the pointer.
    m_timer.setInterval(16);
    connect(&m_timer, &QTimer::timeout, this, &WindowController::updateGeometry);
}

bool WindowController::frameless() const
{
    return m_frameless;
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

void WindowController::beginMove()
{
    if (!m_view)
        return;

    m_mode = Move;
    m_startCursor = QCursor::pos();
    m_startGeometry = m_view->geometry();
    m_timer.start();
}

void WindowController::beginResize(int edges)
{
    if (!m_view || edges == 0)
        return;

    m_mode = Resize;
    m_edges = edges;
    m_startCursor = QCursor::pos();
    m_startGeometry = m_view->geometry();
    m_timer.start();
}

void WindowController::updateGeometry()
{
    if (!m_view || m_mode == None)
        return;

    if (QGuiApplication::mouseButtons() == Qt::NoButton) {
        m_mode = None;
        m_timer.stop();
        return;
    }

    const QPoint delta = QCursor::pos() - m_startCursor;

    if (m_mode == Move) {
        m_view->setPosition(m_startGeometry.topLeft() + delta);
        return;
    }

    // Resize from the stored geometry, so that the opposite edge stays put.
    const int minWidth = 320;
    const int minHeight = 320;
    QRect geometry = m_startGeometry;

    if (m_edges & Qt::LeftEdge)
        geometry.setLeft(qMin(m_startGeometry.left() + delta.x(),
                              m_startGeometry.right() - minWidth));
    if (m_edges & Qt::RightEdge)
        geometry.setRight(qMax(m_startGeometry.right() + delta.x(),
                               m_startGeometry.left() + minWidth));
    if (m_edges & Qt::TopEdge)
        geometry.setTop(qMin(m_startGeometry.top() + delta.y(),
                             m_startGeometry.bottom() - minHeight));
    if (m_edges & Qt::BottomEdge)
        geometry.setBottom(qMax(m_startGeometry.bottom() + delta.y(),
                                m_startGeometry.top() + minHeight));

    m_view->setGeometry(geometry);
}

void WindowController::minimize()
{
    if (m_view)
        m_view->showMinimized();
}

void WindowController::closeWindow()
{
    if (m_view)
        m_view->close();
}
