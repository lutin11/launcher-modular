#include "networkhelper.h"
#include <QNetworkRequest>
#include <QXmlStreamReader>
#include <QUrl>
#include <QDebug>
#include <QUrl>
#include <QObject>

NetworkHelper::NetworkHelper(QObject *parent)
    : QObject(parent),
      manager(new QNetworkAccessManager(this)),
      requestManager(new QNetworkAccessManager(this)) {
    connect(manager, &QNetworkAccessManager::finished, this, &NetworkHelper::onReplyFinished);
}

void NetworkHelper::sendRequest(const QString &tag, const QString &method,
                                const QString &url, const QString &body,
                                const QString &headers) {
    QUrl qurl(url);
    if (!qurl.isValid() || (qurl.scheme() != "http" && qurl.scheme() != "https")) {
        emit requestFinished(tag, 0, QString());
        return;
    }

    QNetworkRequest request(qurl);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("launchermodular"));

    const QStringList lines = headers.split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        const int colon = line.indexOf(QLatin1Char(':'));
        if (colon > 0) {
            request.setRawHeader(line.left(colon).trimmed().toUtf8(),
                                 line.mid(colon + 1).trimmed().toUtf8());
        }
    }

    QNetworkReply *reply = requestManager->sendCustomRequest(request, method.toUtf8(), body.toUtf8());
    connect(reply, &QNetworkReply::finished, this, [this, reply, tag]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QString content = QString::fromUtf8(reply->readAll());
        reply->deleteLater();
        emit requestFinished(tag, status, content);
    });
}

void NetworkHelper::checkUrlReachable(const QString &url) {
    QUrl qurl(url);
    if (!qurl.isValid() || (qurl.scheme() != "http" && qurl.scheme() != "https")) {
        qDebug() << "Invalid URL format :" << url;
        emit urlCheckCompleted(false, false);
        return;
    }

    QNetworkRequest request(qurl);
    // To redirect to https.
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    // Add User-Agent
    request.setHeader(QNetworkRequest::UserAgentHeader,
                       QStringLiteral("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"));

    manager->get(request);
}

void NetworkHelper::onReplyFinished(QNetworkReply *reply) {
    bool isReachable = (reply->error() == QNetworkReply::NoError);
    bool isRssFeed = false;

    if (isReachable) {
        // Check for RSS-compatible content types
        QString contentType = reply->header(QNetworkRequest::ContentTypeHeader).toString();
        qDebug() << "Content Type:" << contentType;
        QXmlStreamReader xml(reply);
        while (!xml.atEnd() && !xml.hasError()) {
            xml.readNext();
            qDebug() << "RSS readNext";
            if (xml.isStartElement()) {
                qDebug() << "RSS name:" << xml.name();
                if (xml.name() == QLatin1String("rss") ||
                    xml.name() == QLatin1String("feed") ||
                    xml.name() == QLatin1String("channel") ||
                    xml.name() == QLatin1String("RDF")) {
                    isRssFeed = true;
                    break;
                }
            }
        }
    }

    emit urlCheckCompleted(isReachable, isRssFeed);
    reply->deleteLater(); // Clean up the reply object
}

