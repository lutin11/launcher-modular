import QtQuick.XmlListModel 2.12

XmlListModel {
	id:_rssChannel
  query: "/(rss/channel|feed|channel)"
	XmlRole { name: "titleText"; query: "title/string()" }
	XmlRole { name: "description"; query: "description/string()" }
	XmlRole { name: "imageUrl"; query: "image/url/string()" }
	XmlRole { name: "pubDate"; query: "(pubDate|updated|lastBuildDate)/string()" }
	XmlRole { name: "firstEntryPubDate"; query: "(item|entry)[1]/(pubDate|updated)/string()" }
}

