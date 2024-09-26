#include <QVariant>
#include <QString>
#include <QUrl>
#include <QFile>
#include "mysettings.h"

MySettings::MySettings() : _acc() {

}

QString MySettings::getBackgroundFile()
{
	QVariant answer = _acc.getUserProperty(
		"org.freedesktop.Accounts.User",
		"BackgroundFile");
	QString filename = answer.toString();

    if (filename.isEmpty() || !QFile::exists(filename))
		    return "../assets/wallpaper.png";
    else
		    return filename;
}

void MySettings::setBackgroundFile(const QString &filename)
{
	QUrl backgroundFile(filename);
	if (!backgroundFile.isLocalFile())
		return;

	_acc.customSetUserProperty("SetBackgroundFile",
				backgroundFile.path());
	emit(backgroundFileChanged());
}
