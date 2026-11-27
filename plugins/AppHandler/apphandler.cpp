#include <algorithm>
#include <QString>
#include <QStringList>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QHash>
#include <QProcess>
#include <QTextStream>
#include <QDebug>
#include <QQmlListProperty>
#include <QRegularExpression>
#include <QStandardPaths>
#include "apphandler.h"
#include "appinfo.h"

#define HOME_PATH QDir::homePath()

namespace {
QStringList applicationDirs()
{
    // Every XDG applications directory, not only /usr/share/applications: on a
    // desktop, Snap and Flatpak entries live under
    // /var/lib/snapd/desktop/applications and
    // /var/lib/flatpak/exports/share/applications, announced by XDG_DATA_DIRS.
    // QStandardPaths returns them in precedence order, the user directory
    // first.
    QStringList dirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    const QString systemDir = QStringLiteral("/usr/share/applications");
    if (!dirs.contains(systemDir))
        dirs << systemDir;
    return dirs;
}
}

AppHandler::AppHandler() {
    loadAppsInfo();
    _fav = "";
    connect(this, SIGNAL(appinfoChanged()), this, SLOT(reloadFav()));
}

QList<AppInfo*> AppHandler::getApps()
{
    return _appinfos;
}
QQmlListProperty<AppInfo> AppHandler::appsinfo()
{
    return QQmlListProperty<AppInfo>(this, 0, &AppHandler::append_appinfo, &AppHandler::count_appinfo, &AppHandler::at_appinfo, &AppHandler::clear_appinfo);
}
QQmlListProperty<AppInfo> AppHandler::fav_appsinfo()
{
    return QQmlListProperty<AppInfo>(this, 0, &AppHandler::append_appinfo, &AppHandler::count_fav_appinfo, &AppHandler::at_fav_appinfo, &AppHandler::clear_appinfo);
}
void AppHandler::loadAppsInfo()
{
    // The same application id can be exported by several XDG directories (for
    // example a user override of a system entry): the first one wins, as the
    // XDG specification requires.
    QSet<QString> seen;
    const QStringList dirs = applicationDirs();
    for (const QString &dir : dirs) {
        loadAppsFromDir(dir, seen);
    }
    loadAppsLibertine();
}
void AppHandler::loadAppsLibertine()
{
    QDir dir(HOME_PATH + "/.cache/libertine-container/");
    qDebug() << "Look for container into: " << HOME_PATH + "/.cache/libertine-container/";
    QStringList containers = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    qDebug() << "Libertine container : " << containers;
    foreach (const QString &container, containers) {
      loadLibertineAppsFromDir(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/share/applications/", container);
      loadLibertineAppsFromDir(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/local/share/applications/", container);
    }
}
void AppHandler::loadLibertineAppsFromDir(const QString& path, const QString& container)
{
    QDir dir(path);
    QStringList nameFilters;
    nameFilters << "*.desktop";
    QStringList fileList = dir.entryList(nameFilters, QDir::Files);
    foreach (const QString &fileName, fileList) {
      QFile file(dir.filePath(fileName));
      file.open(QIODevice::ReadOnly | QIODevice::Text);
      QTextStream filestream(&file);
      filestream.setCodec("UTF-8");

      QString content = filestream.readAll();
      QString appId = fileName.left(fileName.size() - QString(".desktop").size());

      // Check OnlyShowIn before creating the AppInfo
      AppInfo tempApp(container, appId, content, true);
      qDebug() << "Parsing libertine desktop app:" << fileName << "->" << appId << "OnlyShowIn:" << tempApp.getProp("OnlyShowIn");
      if(tempApp.getProp("OnlyShowIn") == nullptr) {
        AppInfo* app = new AppInfo(container, appId, content, true);
        _appinfos.append(app);

        if(app->getProp("Icon").startsWith("/")) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs"+app->getProp("Icon"));
        }
        else if(QFile(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/share/icons/hicolor/128x128/apps/"+app->getProp("Icon")+".png").exists()) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/rootfs/usr/share/icons/hicolor/128x128/apps/"+app->getProp("Icon")+".png");
        }
        else if(QFile(HOME_PATH + "/.cache/libertine-container/"+container+"/usr/share/icons/hicolor/scalable/apps/"+app->getProp("Icon")+".png").exists()) {
          app->setIcon(HOME_PATH + "/.cache/libertine-container/"+container+"/usr/share/icons/hicolor/scalable/apps/"+app->getProp("Icon")+".png");
        }
        else {
          app->setIcon("image://theme/placeholder-app-icon");
        }
        qDebug() << " libertine desktop app:" << fileName << " added";
      }
    }
    qDebug() << _appinfos.size() << " libertine desktop file read from " << path;
}

namespace {

    QString readFile(const QString& path)
    {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            return QString();

        QTextStream stream(&file);
        stream.setCodec("UTF-8");
        return stream.readAll();
    }

    void resolveIconFromSourcePath(AppInfo* app, const QString& fileName)
    {
        QString iconProp = app->getProp("Icon");

        if (iconProp.isEmpty() ||
            iconProp.endsWith(".png") ||
            iconProp.endsWith(".svg") ||
            iconProp.endsWith(".xpm"))
            return;

        QString sourceAppPath = app->getProp("Path");
        if (sourceAppPath.isEmpty()) {
            qDebug() << "No path for:" << app->name() << " " << fileName;
            return;
        }

        QDir dir(sourceAppPath);
        if (!dir.exists()) {
            qDebug() << "Dir '" << sourceAppPath << "' not exists for:" << app->name();
            return;
        }

        QStringList filters;
        filters << iconProp + ".svg"
                << iconProp + ".png"
                << iconProp + ".xpm";

        QFileInfoList files = dir.entryInfoList(filters, QDir::Files);
        for (const QFileInfo &file : files) {
            qDebug() << "Found icon:" << file.absoluteFilePath();
            app->setIcon(file.absoluteFilePath());
            return; // we take the first one
        }
    }

    // QML only displays icon files (".png"/".svg"): a themed icon name such as
    // "Icon=firefox" would show the placeholder. Search the icon themes
    // directly instead of going through QIcon: QIconLoader only knows the icon
    // theme reported by the platform theme, which is not reliable for an
    // application started outside a desktop session (and missing on some
    // distributions). Entries that already point to a file are left untouched,
    // so nothing changes for the packages of Ubuntu Touch.
    QString themeIconFile(const QString &name)
    {
        // Index built once: the icon tree is large, looking up each name
        // separately would stat thousands of paths per entry.
        static QHash<QString, QString> index;
        static bool built = false;

        if (!built) {
            built = true;

            QStringList iconRoots;
            for (const QString &dataDir : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
                iconRoots << dataDir + QStringLiteral("/icons");
            iconRoots << QDir::homePath() + QStringLiteral("/.icons");
            iconRoots.removeDuplicates();

            for (const QString &iconRoot : iconRoots) {
                QDir rootDir(iconRoot);
                QStringList themes = rootDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
                themes.sort();
                // hicolor is the fallback theme every package installs to.
                if (themes.removeAll(QStringLiteral("hicolor")))
                    themes.prepend(QStringLiteral("hicolor"));

                for (const QString &theme : themes) {
                    QDir themeDir(rootDir.filePath(theme));
                    QStringList sizes = themeDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
                    // Largest first, so a 256x256 icon wins over its 16x16
                    // version; "scalable" (SVG) wins over any bitmap.
                    std::sort(sizes.begin(), sizes.end(), [](const QString &a, const QString &b) {
                        if ((a == QStringLiteral("scalable")) != (b == QStringLiteral("scalable")))
                            return a == QStringLiteral("scalable");
                        return a.section(QLatin1Char('x'), 0, 0).toInt()
                               > b.section(QLatin1Char('x'), 0, 0).toInt();
                    });

                    for (const QString &size : sizes) {
                        const QDir appsDir(themeDir.filePath(size + QStringLiteral("/apps")));
                        if (!appsDir.exists())
                            continue;
                        const QFileInfoList files = appsDir.entryInfoList(
                            QStringList() << QStringLiteral("*.svg") << QStringLiteral("*.png"),
                            QDir::Files);
                        for (const QFileInfo &file : files) {
                            const QString iconName = file.completeBaseName();
                            if (!index.contains(iconName))
                                index.insert(iconName, file.absoluteFilePath());
                        }
                    }
                }
            }
        }

        return index.value(name);
    }

    void resolveThemedIcon(AppInfo* app)
    {
        const QString iconName = app->getProp("Icon");
        if (iconName.isEmpty() || iconName.contains('/'))
            return;

        const QString iconFile = themeIconFile(iconName);
        if (!iconFile.isEmpty())
            app->setIcon(iconFile);
    }

    void importSubDesktop(AppInfo* app)
    {
        QString source = app->getProp("X-Lomiri-UAL-Source-Desktop");
        if (source.isEmpty())
            return;

        QString content = readFile(source);
        if (!content.isEmpty())
            app->import(content);
    }

}

void AppHandler::loadAppsFromDir(const QString& path, QSet<QString> &seen)
{
    QDir dir(path);
    QStringList fileList = dir.entryList({"*.desktop"}, QDir::Files);

    for (const QString &fileName : fileList) {

        QString filePath = dir.filePath(fileName);
        QString content = readFile(filePath);
        if (content.isEmpty())
            continue;

        QString appId = fileName;
        appId.chop(QString(".desktop").size());

        if (seen.contains(appId))
            continue;
        seen.insert(appId);

        AppInfo* app = new AppInfo(appId, content);

        importSubDesktop(app);
        resolveIconFromSourcePath(app, fileName);

        _appinfos.append(app);
    }
}

namespace {
QString desktopFilePath(const QString &desktopId)
{
    QString fileName = desktopId;
    const QString schemePrefix = QStringLiteral("application:///");
    if (fileName.startsWith(schemePrefix))
        fileName.remove(0, schemePrefix.size());
    if (!fileName.endsWith(QStringLiteral(".desktop")))
        fileName += QStringLiteral(".desktop");

    if (QFileInfo(fileName).isAbsolute())
        return QFileInfo::exists(fileName) ? fileName : QString();

    const QStringList dirs = applicationDirs();
    for (const QString &dir : dirs) {
        const QString candidate = QDir(dir).filePath(fileName);
        if (QFileInfo::exists(candidate))
            return candidate;
    }
    return QString();
}
}

bool AppHandler::launchApp(const QString& desktopId)
{
    const QString path = desktopFilePath(desktopId);
    if (path.isEmpty()) {
        qWarning() << "launchApp: no desktop file for" << desktopId;
        return false;
    }

    // "gio launch" applies what the desktop entry describes (Exec and its
    // field codes, Terminal, working directory); it is the desktop equivalent
    // of the Lomiri URL handler used on Ubuntu Touch. gtk-launch, which takes
    // the application id instead of the file path, is kept as a fallback.
    QString program = QStandardPaths::findExecutable(QStringLiteral("gio"));
    QStringList arguments;
    if (!program.isEmpty()) {
        arguments << QStringLiteral("launch") << path;
    } else {
        program = QStandardPaths::findExecutable(QStringLiteral("gtk-launch"));
        if (program.isEmpty()) {
            qWarning() << "launchApp: neither gio nor gtk-launch is installed";
            return false;
        }
        QString appId = QFileInfo(path).fileName();
        appId.chop(QString(".desktop").size());
        arguments << appId;
    }

    const bool started = QProcess::startDetached(program, arguments);
    if (!started)
        qWarning() << "launchApp: could not start" << program << arguments;
    return started;
}

void AppHandler::resolveThemedIcons()
{
    for (AppInfo *app : _appinfos)
        resolveThemedIcon(app);
    for (AppInfo *app : _fav_appinfos)
        resolveThemedIcon(app);
}

void AppHandler::append_appinfo(QQmlListProperty<AppInfo> *list, AppInfo *appinfo)
{
    AppHandler *appinfoBoard = qobject_cast<AppHandler*>(list->object);
    if(appinfo) {
      appinfoBoard->_appinfos.append(appinfo);
      emit appinfoBoard->appinfoChanged();
    }
}
AppInfo* AppHandler::at_appinfo(QQmlListProperty<AppInfo> *list, int index) {
    AppHandler *apphandler = qobject_cast<AppHandler*>(list->object);
    return apphandler->_appinfos.at(index);
}
AppInfo* AppHandler::at_fav_appinfo(QQmlListProperty<AppInfo> *list, int index) {
    AppHandler *apphandler = qobject_cast<AppHandler*>(list->object);
    return apphandler->_fav_appinfos.at(index);
}
int AppHandler::count_appinfo(QQmlListProperty<AppInfo> *list) {
    AppHandler *apphandler = qobject_cast<AppHandler*>(list->object);
    return apphandler->_appinfos.size();
}
int AppHandler::count_fav_appinfo(QQmlListProperty<AppInfo> *list) {
    AppHandler *apphandler = qobject_cast<AppHandler*>(list->object);
    return apphandler->_fav_appinfos.size();
}
void AppHandler::clear_appinfo(QQmlListProperty<AppInfo> *list) {
    AppHandler *apphandler = qobject_cast<AppHandler*>(list->object);
    qDeleteAll(apphandler->_appinfos);
    apphandler->_appinfos.clear();
    emit apphandler->appinfoChanged();
}
void AppHandler::reload() {
    qDeleteAll(_fav_appinfos);
    _fav_appinfos.clear();
    qDeleteAll(_appinfos);
    _appinfos.clear();
    loadAppsInfo();
}
void AppHandler::reloadFav() {
    while(_fav_appinfos.size() >0) {
      _appinfos.removeAll(_fav_appinfos[0]);
      _appinfos << _fav_appinfos.takeFirst();
    }
    if(_filtering)//temp filtering = nofav
		  return;
    QStringList favapplist = _fav.split(",");
    for(int j=0;j<favapplist.size();j++) {
      for(int i=0;i<_appinfos.size();i++) {
        if(favapplist[j]==_appinfos[i]->getProp("package_name").split("_")[0])
        {
          _fav_appinfos << _appinfos.takeAt(i);
          i = _appinfos.size()+1;
        }
      }
    }
}
void AppHandler::setFav(const QString& fav) {
    if(fav == _fav) //nothing changed
		return;
    _fav = fav;
    reloadFav();
    emit appinfoChanged();
}
void AppHandler::permaFilter(const QString& key, const QString& regexp) {
    for(int i=0;i< _appinfos.size();) {
    AppInfo* appinfo = _appinfos[i];
    auto localQRegularExpression = QRegularExpression(regexp);
    if(appinfo->haveProp(key) && !appinfo->getProp(key).contains(localQRegularExpression)) {
			delete _appinfos.takeAt(i);
		}
		else
			i++;
    }
    emit appinfoChanged();
}

void AppHandler::sort(const QString& key, bool revertsort) {
    std::sort(_appinfos.begin(), _appinfos.end(),
              [=](AppInfo* a, AppInfo* b) {
                  return revertsort
                      ? a->getProp(key) > b->getProp(key)
                      : a->getProp(key) < b->getProp(key);
              });
    emit appinfoChanged();
}

void AppHandler::tempFilter(const QString& keys, const QString& regexp, bool caseinsensitive) {
    //this disable fav
    _filtering = true;
    reloadFav();
    QStringList key_list = keys.split(";");
    QStringList accent;
      accent << "aàáâãäå" << "cç" << "eèéêë" << "iìíîï" << "nñ" << "oòóôõöø" << "sß" << "uùúûü" << "yÿ";
    QString betterRegExp = regexp;
    foreach(const QString &value, accent) {
		  betterRegExp.replace(value[0], "["+value+"]");
    }
    for(int i=0;i< _appinfos.size();) {
      bool filtered = true;
      foreach( const QString& key, key_list) {
        if(_appinfos[i]->getProp(key).contains(QRegularExpression(betterRegExp, (caseinsensitive) ? QRegularExpression::CaseInsensitiveOption : QRegularExpression::NoPatternOption)))
          filtered = false;
      }
      if(filtered == true) {
        _hideByFilter << _appinfos.takeAt(i);
      }
      else
        i++;
    }
    emit appinfoChanged();
}
void AppHandler::resetTempFilter() {
    _filtering = false;
    while(_hideByFilter.size() >0)
      _appinfos << _hideByFilter.takeFirst();
    emit appinfoChanged();
}

