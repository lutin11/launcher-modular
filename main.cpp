#include <QGuiApplication>
#include <QCoreApplication>
#include <QUrl>
#include <QString>
#include <QQuickView>
#include <QQmlEngine>
#include <QQmlContext>
#include <QFont>
#include <QFontDatabase>

int main(int argc, char *argv[])
{
    QGuiApplication *app = new QGuiApplication(argc, (char**)argv);
    app->setApplicationName("launchermodular.lut11");
    QQmlEngine *engine = new QQmlEngine(app);

    // Set global debug property
    bool debug = false; // true to enable debug
    engine->rootContext()->setContextProperty("DEBUG_MODE", debug);
    engine->addImportPath(QStringLiteral("/usr/lib/aarch64-linux-gnu/lomiri/qml/"));

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

    QQuickView *view = new QQuickView(engine, nullptr);

    view->setSource(QStringLiteral("%1/qml/Main.qml").arg(app->applicationDirPath()));
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->show();

    return app->exec();
}
