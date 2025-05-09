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
    manager->get(QNetworkRequest(qurl));
}

void NetworkHelper::onReplyFinished(QNetworkReply *reply) {
    bool isReachable = (reply->error() == QNetworkReply::NoError);
    bool isRssFeed = false;

    if (isReachable) {
        // Check for RSS-compatible content types
        QString contentType = reply->header(QNetworkRequest::ContentTypeHeader).toString();

        qDebug() << "Content Type:" << contentType;

        if (contentType.contains("rss") || contentType.contains("xml") || contentType.contains("html")) {
            // Parse XML content to identify RSS elements
            qDebug() << "RSS url feed reachable";
            QXmlStreamReader xml(reply);
            while (!xml.atEnd() && !xml.hasError()) {
                xml.readNext();
                qDebug() << "RSS readNext";
                if (xml.isStartElement()) {
                    qDebug() << "RSS name:" << xml.name();
                    if (xml.name() == "rss" || xml.name() == "feed" || xml.name() == "channel") {
                        isRssFeed = true;
                        break;
                    }
                }
            }
        }
    }

    emit urlCheckCompleted(isReachable, isRssFeed);
    reply->deleteLater(); // Clean up the reply object
}

