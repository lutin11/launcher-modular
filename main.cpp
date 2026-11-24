#include <QGuiApplication>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <QString>
#include <QStringList>
#include <QQuickView>
#include <QQmlEngine>
#include <QQmlContext>
#include <QFont>
#include <QFontDatabase>
#include "windowcontroller.h"

// Directory holding qml/ and assets/. A click package keeps them next to the
// binary; a system install puts them under the data directory chosen at
// configure time; an AppImage exposes the same tree under $APPDIR. The
// environment variable wins so that a source tree can be run without
// installing it.
static QString findDataDirectory()
{
    QStringList candidates;

    const QString fromEnvironment = QString::fromLocal8Bit(qgetenv("LAUNCHERMODULAR_DATA_DIR"));
    if (!fromEnvironment.isEmpty()) {
        candidates << fromEnvironment;
    }
    const QString appImage = QString::fromLocal8Bit(qgetenv("APPDIR"));
    if (!appImage.isEmpty()) {
        candidates << appImage + "/usr/share/launchermodular";
    }
    candidates << QCoreApplication::applicationDirPath()
               << QStringLiteral(LAUNCHERMODULAR_DATA_DIR);

    for (const QString &candidate : candidates) {
        if (!candidate.isEmpty() && QFileInfo::exists(candidate + "/qml/Main.qml")) {
            return QDir::cleanPath(candidate);
        }
    }
    return QString();
}

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

    QGuiApplication app(argc, argv);
    app.setApplicationName("launchermodular.lut11");
    QQmlEngine engine;

    // Set global debug property
    bool debug = false; // true to enable debug
    engine.rootContext()->setContextProperty("DEBUG_MODE", debug);

    const QString dataDirectory = findDataDirectory();
    if (dataDirectory.isEmpty()) {
        qWarning() << "main: qml/Main.qml not found. Set LAUNCHERMODULAR_DATA_DIR to the"
                      " directory that holds qml/ and assets/.";
    }

    // QML modules built with this application (Platform, AppHandler, ...): the
    // private library directory of a system install, or lib/<triplet> beside the
    // binary in a click package.
    engine.addImportPath(QStringLiteral(LAUNCHERMODULAR_IMPORT_DIR));
    engine.addImportPath(QCoreApplication::applicationDirPath()
                         + "/lib/" + QStringLiteral(__ARCH_TRIPLET__));
    // Lomiri installs some of its QML modules outside the Qt import directory.
    engine.addImportPath(QStringLiteral("/usr/lib/%1/lomiri/qml")
                         .arg(QStringLiteral(__ARCH_TRIPLET__)));

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
    view.setSource(QUrl::fromLocalFile(dataDirectory + "/qml/Main.qml"));

    view.show();

    return app.exec();
}
