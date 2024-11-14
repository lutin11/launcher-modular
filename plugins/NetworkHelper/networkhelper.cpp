#include "networkhelper.h"
#include <QNetworkRequest>
#include <QXmlStreamReader>
#include <QDebug>
#include <QUrl>
#include <QObject>

NetworkHelper::NetworkHelper(QObject *parent) : QObject(parent), manager(new QNetworkAccessManager(this)) {
    connect(manager, &QNetworkAccessManager::finished, this, &NetworkHelper::onReplyFinished);
}

void NetworkHelper::checkUrlReachable(const QString &url) {
    reply = manager->get(QNetworkRequest(QUrl(url)));  // Directly pass the QNetworkRequest
}

void NetworkHelper::onReplyFinished() {
    bool isReachable = (reply->error() == QNetworkReply::NoError);
    bool isRssFeed = false;

    if (isReachable) {
        // Check for RSS-compatible content types
        QString contentType = reply->header(QNetworkRequest::ContentTypeHeader).toString();

        qDebug() << "Content Type:" << contentType;

        if (contentType.contains("rss") || contentType.contains("xml")) {
            // Parse XML content to identify RSS elements
            QXmlStreamReader xml(reply);
            while (!xml.atEnd() && !xml.hasError()) {
                xml.readNext();
                if (xml.isStartElement()) {
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

