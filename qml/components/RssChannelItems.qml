import QtQuick.XmlListModel 2.12

XmlListModel {
    id: rssModel
    query: "/(rss/channel|feed)/(item|entry)"
    XmlRole { name: "titleText"; query: "title/string()" }
    XmlRole { name: "description"; query: "(description|summary)/string()" }
    XmlRole { name: "category"; query: "category/string()" }
    XmlRole { name: "imageUrl"; query: "(media:thumbnail|image/@href)/string()" }
    XmlRole { name: "updated"; query: "(pubDate|updated)/string()" }
    XmlRole { name: "author"; query: "(author|owner|creator|author/name)/string()" }
    XmlRole { name: "url"; query: "(link[contains(text(),'http')]|id[contains(text(),'http')])/string()"; isKey: true }
    XmlRole { name: "content"; query: "(content)/string()" }
}


