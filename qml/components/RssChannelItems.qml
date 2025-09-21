import QtQuick.XmlListModel 2.12

XmlListModel {
    id: rssModel
    query: "/(rss/channel|feed)/(item|entry)"
    XmlRole { name: "titleText"; query: "(title)[1]/string()" }
    XmlRole { name: "description"; query: "(description|summary)[1]/string()" }
    XmlRole { name: "category"; query: "(category)[1]/string()" }
    XmlRole { name: "imageUrl"; query: "(image/@href)[1]/string()" }
    XmlRole { name: "updated"; query: "(pubDate|updated)[1]/string()" }
    XmlRole { name: "author"; query: "(author|owner|creator|author/name)[1]/string()" }
    XmlRole { name: "url"; query: "((link[contains(text(),'http')]|id[contains(text(),'http')])[1])/string()"; isKey: true }
    XmlRole { name: "content"; query: "(content)[1]/string()" }
}


