#include "networkhelper.h"
#include <QNetworkRequest>
#include <QXmlStreamReader>
#include <QUrl>
#include <QDebug>
#include <QUrl>
#include <QObject>

NetworkHelper::NetworkHelper(QObject *parent) : QObject(parent), manager(new QNetworkAccessManager(this)) {
    connect(manager, &QNetworkAccessManager::finished, this, &NetworkHelper::onReplyFinished);
}

void NetworkHelper::checkUrlReachable(const QString &url) {
    QUrl qurl(url);
    if (!qurl.isValid() || qurl.scheme() != "http" && qurl.scheme() != "https") {
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

