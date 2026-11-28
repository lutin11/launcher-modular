#include <QGuiApplication>
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QUrl>
#include <QString>
#include <QStringList>
#include <QQuickView>
#include <QQuickWindow>
#include <QQmlEngine>
#include <QQmlContext>
#include <QFont>
#include <QFontDatabase>
#include <QFile>
#include <QScreen>
#include <QSettings>
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

    // Desktop packages remember the window size and position between runs.
    // Ubuntu Touch is full screen and managed by Lomiri, and a click app must
    // not touch the window geometry: the feature is desktop only.
    const bool touchSession = !qEnvironmentVariableIsEmpty("APP_ID")
            || QFile::exists(QStringLiteral("/etc/ubports/version"));

    // Desktop environments match the window to its launcher entry by this
    // name. The click package keeps its own desktop file.
    if (!touchSession)
        QGuiApplication::setDesktopFileName(QStringLiteral("LauncherModular"));

    // QtMultimedia's GStreamer backend creates a Wayland video sink for every
    // media player, even on X11. Without a compositor each creation waits for
    // its state change (about five seconds), and Home loads the music player at
    // startup. On a non-Wayland session, ask for the X11 sink the widget
    // control already uses. Ubuntu Touch and a Wayland platform keep the
    // default waylandsink; CLICKABLE_DESKTOP_MODE marks the desktop run of a
    // click package, where APP_ID is set but the session is still X11.
    const bool desktopSession = !touchSession
            || !qEnvironmentVariableIsEmpty("CLICKABLE_DESKTOP_MODE");
    if (desktopSession
            && !QGuiApplication::platformName().startsWith(QStringLiteral("wayland"))) {
        if (qEnvironmentVariableIsEmpty("QT_GSTREAMER_WINDOW_VIDEOSINK"))
            qputenv("QT_GSTREAMER_WINDOW_VIDEOSINK", "xvimagesink");
        if (qEnvironmentVariableIsEmpty("QT_GSTREAMER_WIDGET_VIDEOSINK"))
            qputenv("QT_GSTREAMER_WIDGET_VIDEOSINK", "xvimagesink");
    }

    QQuickView view(&engine, nullptr);
    view.setResizeMode(QQuickView::SizeRootObjectToView);

    // The desktop builds have no window manager decoration: the internal title
    // bar of Main.qml moves, resizes, minimizes and closes the window instead.
    if (!touchSession)
        view.setFlags(view.flags() | Qt::FramelessWindowHint);
    QSettings windowSettings(QSettings::IniFormat, QSettings::UserScope,
                             QStringLiteral("launchermodular.lut11"),
                             QStringLiteral("window"));
    if (!touchSession) {
        const int savedWidth = windowSettings.value(QStringLiteral("width"), 0).toInt();
        const int savedHeight = windowSettings.value(QStringLiteral("height"), 0).toInt();
        const int savedX = windowSettings.value(QStringLiteral("x"), 0).toInt();
        const int savedY = windowSettings.value(QStringLiteral("y"), 0).toInt();
        if (savedWidth >= 320 && savedHeight >= 320) {
            const QRect saved(savedX, savedY, savedWidth, savedHeight);
            // The position is restored only when it is still on a screen
            // (a monitor may have been removed since the last run).
            if (QGuiApplication::screenAt(saved.center()) != nullptr)
                view.setGeometry(saved);
            else
                view.resize(savedWidth, savedHeight);
        }
        // aboutToQuit avoids the private QQuickCloseEvent type of the
        // "closing" signal; the window still has its geometry here.
        QObject::connect(&app, &QCoreApplication::aboutToQuit, &view,
                         [&view, &windowSettings]() {
            windowSettings.setValue(QStringLiteral("width"), view.width());
            windowSettings.setValue(QStringLiteral("height"), view.height());
            windowSettings.setValue(QStringLiteral("x"), view.x());
            windowSettings.setValue(QStringLiteral("y"), view.y());
            windowSettings.sync();
        });
    }
    WindowController controller(&view, !touchSession);

    engine.rootContext()->setContextProperty("WindowController", &controller);
    view.setSource(QUrl::fromLocalFile(dataDirectory + "/qml/Main.qml"));

    view.show();

    return app.exec();
}
