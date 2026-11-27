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

    // QML-callable functions
    Q_INVOKABLE void checkUrlReachable(const QString &url);

    // Sends an arbitrary HTTP request. QML's XMLHttpRequest refuses the REPORT
    // verb used by CalDAV ("Unsupported HTTP method type"), and libcurl-less
    // alternatives do not exist in QML: the network stack of Qt is used here.
    // headers holds "Name: value" lines separated by newlines.
    Q_INVOKABLE void sendRequest(const QString &tag, const QString &method,
                                 const QString &url, const QString &body,
                                 const QString &headers);

signals:
    void urlCheckCompleted(bool reachable, bool isRssFeed);
    void requestFinished(const QString &tag, int status, const QString &body);

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    QNetworkAccessManager *manager;
    // Separate manager: the finished() handler of the one above is reserved
    // for the RSS checks and consumes the reply body.
    QNetworkAccessManager *requestManager;
};

#endif // NETWORKHELPER_H
