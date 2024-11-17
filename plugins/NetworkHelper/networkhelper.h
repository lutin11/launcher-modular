#ifndef NETWORKHELPER_H
#define NETWORKHELPER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>

class NetworkHelper : public QObject {
    Q_OBJECT
public:
    explicit NetworkHelper(QObject *parent = nullptr);

    // QML-callable function
    Q_INVOKABLE void checkUrlReachable(const QString &url);

signals:
    void urlCheckCompleted(bool reachable, bool isRssFeed);

private slots:
    void onReplyFinished();

private:
    QNetworkAccessManager *manager;
    QNetworkReply *reply;
};

#endif // NETWORKHELPER_H
