#ifndef MYSETTINGS_H
#define MYSETTINGS_H
#include <QString>
#include "accountsservice.h"
#include <QDir>
#include <QStandardPaths>

class MySettings: public QObject {
    Q_OBJECT

public:
    MySettings();
    ~MySettings() = default;
    Q_INVOKABLE QString getBackgroundFile();
    Q_INVOKABLE QString getHomeLocation();
    Q_INVOKABLE QString getPicturesLocation();
    Q_INVOKABLE QString getMusicLocation();
public slots:
    void setBackgroundFile(const QString &filename);
signals:
    void backgroundFileChanged();
protected:
    AccountsService _acc;
};
#endif
