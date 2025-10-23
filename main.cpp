#include <QGuiApplication>
#include <QCoreApplication>
#include <QUrl>
#include <QString>
#include <QQuickView>
#include <QQmlEngine>
#include <QQmlContext>
#include <QFont>
#include <QFontDatabase>
#include "windowcontroller.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

    QGuiApplication app(argc, argv);
    app.setApplicationName("launchermodular.lut11");
    QQmlEngine engine;

    // Set global debug property
    bool debug = false; // true to enable debug
    engine.rootContext()->setContextProperty("DEBUG_MODE", debug);
    engine.addImportPath(QStringLiteral("/usr/lib/aarch64-linux-gnu/lomiri/qml/"));

    int fontId = QFontDatabase::addApplicationFont(":/fonts/DSEG7Classic-Regular.ttf");
    if (fontId == -1) {
        qWarning() << "main Failed to load font";
    } else {
        qInfo() << "main Font to load font";
    }
    QFontDatabase::addApplicationFont(":/fonts/DSEG7Classic-Bold.ttf");
    QFontDatabase::addApplicationFont(":/fonts/DSEG7Classic-BoldItalic.ttf");
    QFontDatabase::addApplicationFont(":/fonts/DSEG7Classic-Italic.ttf");
    QFontDatabase::addApplicationFont(":/fonts/DSEG7Classic-Light.ttf");
    QFontDatabase::addApplicationFont(":/fonts/DSEG7Classic-LightItalic.ttf");

    QQuickView view(&engine, nullptr);
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    WindowController controller(&view);

    engine.rootContext()->setContextProperty("WindowController", &controller);
    view.setSource(QStringLiteral("%1/qml/Main.qml").arg(app.applicationDirPath()));

    view.show();

    return app.exec();
}
