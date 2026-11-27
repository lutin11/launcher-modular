#pragma once

#include <QObject>
#include <QPoint>
#include <QRect>
#include <QTimer>

class QQuickView;

// Desktop window helper: full screen toggle and, for the frameless desktop
// packages, moving/resizing the window from the internal title bar.
class WindowController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool frameless READ frameless CONSTANT)
public:
    explicit WindowController(QQuickView *view, bool frameless = false,
                              QObject *parent = nullptr);
    Q_INVOKABLE void toggleFullScreen();
    Q_INVOKABLE void beginMove();
    // edges is a Qt::Edges bitmask: TopEdge 1, LeftEdge 2, RightEdge 4,
    // BottomEdge 8 (corners are the OR of two values).
    Q_INVOKABLE void beginResize(int edges);
    Q_INVOKABLE void minimize();
    Q_INVOKABLE void closeWindow();
    bool frameless() const;

private:
    enum Mode { None, Move, Resize };
    void updateGeometry();

    QQuickView *m_view;
    bool m_frameless;
    QTimer m_timer;
    Mode m_mode = None;
    int m_edges = 0;
    QPoint m_startCursor;
    QRect m_startGeometry;
};
