#include "appinfo.h"
#include <QBuffer>
#include <QDebug>
#include <QLocale>
#include <QSettings>
#include <QStringList>
#include <QVariant>

AppInfo::AppInfo(const QString& infos)
{
	import(infos);
	//qDebug() << "keys:" <<_appinfo.keys() << "values" << _appinfo.values();
}

AppInfo::AppInfo(const QString& container, const QString& application, const QString& infos, bool isLibertine)
{
	if (isLibertine) {
		qDebug() << "Libertine AppInfo : " << container + " "+ application;
		_appinfo.insert("Libertine", "true");
	    _appinfo.insert("Container", container);
		_appinfo.insert("Action", application);
		import(infos);
	}
}
AppInfo::AppInfo(const QString& packagename, const QString& infos, bool isLibertine)
{
	_appinfo.insert("package_name", packagename);
	if (!isLibertine) {
		_appinfo.insert("Action", "application:///"+packagename+".desktop");
	}
	import(infos);
}


void AppInfo::import(const QString& filePath)
{
    QSettings settings(filePath, QSettings::IniFormat);
    settings.setIniCodec("UTF-8");

    settings.beginGroup("Desktop Entry");

    const QStringList keys = settings.allKeys();
    for (const QString& key : keys) {
        QVariant value = settings.value(key);

        // Stockage direct
        _appinfo.insert(key, value.toString());

        // Optionnel : version tableau comme dans ton code
        _appinfo.insert(key + "[]", value.toString());
    }

    settings.endGroup();
}


void AppInfo::import(const QString& infos)
{
    _appinfo.clear();

    bool read = false;

    for (const QString& rawLine : infos.split("\n")) {

        qDebug() << "New File";

        QString line = rawLine.trimmed();

	    QString locale = (QLocale() != QLocale::c()) ? QLocale().name().split("_").first() : "c";
	    qDebug() << "Parsed line : " << line;

        // Ignorer lignes vides et commentaires
        if (line.isEmpty() || line.startsWith("#")) {
            qDebug() << "return :" << line;
            continue;
        }

        // Détection section
        if (line == "[Desktop Entry]") {
            read = true;
            qDebug() << "continue :" << line;
            continue;
        }

        if (line.startsWith("[")) {
            read = false;
            qDebug() << "stop :" << line;
            continue;
        }

        if (!read) {
            qDebug() << "return :" << line;
            continue;
        }

        // Split propre : seulement au premier '='
        int idx = line.indexOf('=');
        if (idx == -1) {
            qDebug() << "idx == -1";
            continue;
        }

        QString key = line.left(idx).trimmed();
        QString value = line.mid(idx + 1).trimmed();

        // Debug optionnel conservé
        if (getProp("package_name").contains("morph"))
            qDebug() << key << value << !_appinfo.contains(key);

        // Ne pas écraser
        if (_appinfo.contains(key)) {
            qDebug() << "clef contenue :" << key;
            continue;
        }

        // Insertion principale
        qDebug() << "inssertion :" << key << " " << value;
        _appinfo.insert(key, value);

        // Compat ancien comportement (clé[])
        //if (!key.contains("["))
        //    _appinfo.insert(key + "[]", value);
    }
}

QString AppInfo::getProp(const QString& key)
{
	QString locale = (QLocale() != QLocale::c()) ? QLocale().name().split("_").first() : "c";
    //qDebug() << "locale" <<QLocale().uiLanguages().first() << QLocale().name();
	if ( _appinfo.contains(key+"["+locale+"]") )
	{
		return _appinfo.value(key+"["+locale+"]");
	}
	else
	{
		return _appinfo.value(key); 
	}
    
}

bool AppInfo::haveProp(const QString& key)
{
	return _appinfo.contains(key);
}

void AppInfo::setName(const QString& name) { _appinfo.insert("Name", name); emit nameChanged();}
void AppInfo::setIcon(const QString& icon) { _appinfo.insert("Icon", icon); emit iconChanged();}
void AppInfo::setAction(const QString& action) { _appinfo.insert("Action", action); emit actionChanged();}

QString AppInfo::name() { return getProp("Name");}
QString AppInfo::icon() { return getProp("Icon");}
QString AppInfo::action() { return getProp("Action");}
QString AppInfo::libertine() { return getProp("Libertine");}
QString AppInfo::container() { return getProp("Container");}

QVariantMap AppInfo::fullInfo() {
	QVariantMap map;
    auto localKeys = _appinfo.keys();
    foreach(const QString& key, localKeys) {
		map.insert(key, _appinfo.value(key));
	}
	return map;
}

QVariantList AppInfo::keys() {
	QVariantList lst;
    auto localKeys = _appinfo.keys();
    foreach(const QString& key, localKeys) {
		lst << key;
	}
	return lst;
}
