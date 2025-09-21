#include <algorithm>
#include <QString>
#include <QStringList>
#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QDebug>
#include <QQmlListProperty>
#include <QRegularExpression>
#include <QStandardPaths>
#include "apphandler.h"
#include "appinfo.h"

#define APP_SYS_PATH "/usr/share/applications/"
#define HOME_PATH QDir::homePath()

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
    loadAppsFromDir(APP_SYS_PATH);
    loadAppsFromDir(QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation));
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

      AppInfo* app = _appinfos.last();
      qDebug() << "Parsing libertine desktop app:" << fileName << "->" << fileName.left(fileName.size() - QString(".desktop").size()) << "OnlyShowIn:" << app->getProp("OnlyShowIn");
      if(app->getProp("OnlyShowIn") == nullptr) {
        _appinfos.append(new AppInfo(container, fileName.left(fileName.size() - QString(".desktop").size()), filestream.readAll(), true));
        
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
void AppHandler::loadAppsFromDir(const QString& path)
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
      _appinfos.append(new AppInfo(fileName.left(fileName.size() - QString(".desktop").size()), filestream.readAll()));
      if(!_appinfos.last()->getProp("X-Lomiri-UAL-Source-Desktop").isEmpty()) {
        QFile subfile(_appinfos.last()->getProp("X-Lomiri-UAL-Source-Desktop"));
        subfile.open(QIODevice::ReadOnly | QIODevice::Text);
        QTextStream subfilestream(&subfile);
        subfilestream.setCodec("UTF-8");
        _appinfos.last()->import(subfilestream.readAll());
      }
    }
    qDebug() << _appinfos.size() << " desktop file read from " << path;
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
    apphandler->_appinfos.clear();
    emit apphandler->appinfoChanged();
}
void AppHandler::reload() {
    _appinfos.clear();
    _fav_appinfos.clear();
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

