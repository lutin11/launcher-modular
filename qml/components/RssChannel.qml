import QtQuick.XmlListModel 2.12

XmlListModel {
	id:_rssChannel
  query: "/(rss/channel|feed|channel)"
	XmlRole { name: "titleText"; query: "(title)[1]/string()" }
	XmlRole { name: "description"; query: "(description)[1]/string()" }
	XmlRole { name: "imageUrl"; query: "(image/url)[1]/string()" }
	XmlRole { name: "pubDate"; query: "(pubDate|updated|lastBuildDate)[1]/string()" }
	XmlRole { name: "firstEntryPubDate"; query: "(item|entry)[1]/(pubDate|updated)[1]/string()" }
}

