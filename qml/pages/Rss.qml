import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.Controls 2.2 as QControls
import QtQuick.XmlListModel 2.12
import QtQml.Models 2.2
import Lomiri.Connectivity 1.0

import "../components"
import "../helpers"
import "rss"
import NetworkHelper 1.0

Item {
    id: _mainFeed

    clip: true

    property var model: RssModel.itemModel
    property var refreshing: cachedHttpRequestInstance.waitingForResults
    property var currentSearch: null
    property var currentSection: null
    property var channelsList: []
    property bool isFeeds: false
    property bool completed: false

    Component.onCompleted: {
        RssModel.dbInit()
        updateFeedsTimer.start()
        completed = true
    }

    onVisibleChanged: {
        if (visible &&
            completed &&
            (launchermodular.settings.rssFeedChanged ||
                !RssModel.itemModel ||
                RssModel.itemModel.length === 0 ||
                _mainFeed.refreshing ||
                listSortingTimer.running)) {

            if (DEBUG_MODE) console.log("reload")

            _mainFeed.updateFeed()

            launchermodular.settings.rssFeedChanged = false
        }
    }

    Component {
        id: channelComponent

        RssChannel {
        }
    }

    Component {
        id: channelItemsComponent

        RssChannelItems {
            id: channelItemsComponentObj
        }
    }

    WorkerScript {
        id: feedItemsParser

        source: "../Jslibs/Processing/FeedItemsParser.js"

        onMessage: (message) => {
            try {
                var item = message.item

                if (item) {
                    feedList.model.append(item)
                }
            } catch (e) {
                console.log("Feed item append failed:", e)
            }
        }
    }

    // Timer  used to allow  for multiple updates that  result in a single sorting
    Timer {
        id: listSortingTimer

        interval: 1000
        repeat: false
        running: false

        onTriggered: {
            if (DEBUG_MODE) console.log("Timer Sorting..")

            feedList.model.sort()
        }
    }

    Timer {
        id: updateFeedsTimer

        interval: 10
        repeat: false
        running: false

        onTriggered: {
            if (DEBUG_MODE) console.log("Timer updating..")

            RssModel.buildModel()
            _mainFeed.updateFeed()
        }
    }

    CachedHttpRequest {
        id: cachedHttpRequestInstance

        isResultJSON: false
        isLoggingEnabled: false

        onlyReturnFreshCache:
            Connectivity.status !== NetworkingStatus.Offline

        cachingTimeMiliSec:
            appSettings.feedCacheTimeout * 60000

        recachingFactor: 0.25
        cachedResponseIsEnough: true
    }

    //--------------------------------- Functions ----------------------------------

    function updateFeed() {
        if (!RssModel.itemModel ||
            RssModel.itemModel.length === 0 ||
            _mainFeed.refreshing ||
            listSortingTimer.running) {

            _mainFeed.isFeeds = false
            return
        }

        if (Connectivity.status === NetworkingStatus.Offline) {
            if (DEBUG_MODE) console.log("Limited connectivity... not updating.")

            if (feedList.model && feedList.model.length)
                return
        }

        if (DEBUG_MODE) console.log("updating the feeds..")

        feedList.model.clear()
        channelsList = []

        _mainFeed.isFeeds =
            RssModel.itemModel.count > 0

        for (let i = 0;
             i < RssModel.itemModel.count;
             ++i) {

            const url = RssModel.itemModel.get(i)

            cachedHttpRequestInstance.send(
                url.rss_uri,
                {
                    "url": url.rss_uri
                }
            )
        }
    }

    function detectFeedType(xml) {
        if (!xml)
            return "unknown"

        const text = String(xml).trim()

        /*
         * <feed xmlns="http://www.w3.org/2005/Atom">
         */

        if (/<rss(?:\s|>)/i.test(text))
            return "rss"

        if (/<feed(?:\s|>)/i.test(text))
            return "atom"

        if (/<rdf:RDF(?:\s|>)/i.test(text))
            return "rdf"

        return "unknown"
    }

    Feed {
        id: feedList

        anchors {
            fill: parent
        }

        model: FeedsModel {
            id: feedModel
        }

        Rectangle {
            anchors.fill: parent

            z: 1
            opacity: 0.6

            visible: _mainFeed.isFeeds === false

            color: "transparent"

            ProgressBar {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    margins: units.gu(2)
                }

                indeterminate: true
                visible: _mainFeed.isFeeds
            }

            Label {
                id: noFeeds

                text: _mainFeed.isFeeds
                    ? i18n.tr("Loading feeds…")
                    : i18n.tr("Go to the page management to add feeds.")

                color: launchermodular.settings.textColor

                font.weight: Font.Bold

                wrapMode: Text.Wrap

                horizontalAlignment: Text.AlignHCenter

                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: parent.right
                    margins: units.gu(2)
                }
            }
        }

        pullToRefresh {
            enabled: true

            refreshing:
                feedList.model.count === 0 ||
                listSortingTimer.running ||
                _mainFeed.refreshing

            onRefresh: {
                _mainFeed.updateFeed()
            }
        }

        delegate: FeedItem {
            visible:
                !_mainFeed.currentSection ||
                _mainFeed.currentSection === itemData["channel"]

            onClicked: {
                feedList.currentIndex = index
                Qt.openUrlExternally(itemData.url)
            }
        }
    }

    Connections {
        target: cachedHttpRequestInstance

        function onResponseDataUpdated(response, data) {
            try {
                if (!response) {
                    if (DEBUG_MODE) {
                        console.log(
                        "Empty response for:",
                        data ? data.url : "unknown URL")
                    }
                    return
                }

                const feedUrl =
                        data && data.url
                    ? data.url
                    : "unknown URL"

                const feedType =
                    _mainFeed.detectFeedType(response)

                if (DEBUG_MODE) {
                    console.log(
                        "Feed URL:",
                        feedUrl
                    )

                    console.log(
                        "Feed type:",
                        feedType
                    )

                    console.log(
                        "Feed response length:",
                        String(response).length
                    )
                }

                /*
                 * The response isn't XML/RSS/Atom, ignore it
                 */
                if (feedType === "unknown") {
                    if (DEBUG_MODE) {
                        console.log(
                            "Unable to detect RSS/Atom XML for:",
                            feedUrl
                        )

                        console.log(
                            String(response).substring(0, 500)
                        )
                    }

                    return
                }

                const channel =
                    channelComponent.createObject(
                        null,
                        {}
                    )

                if (!channel) {
                    if (DEBUG_MODE) {
                        console.log(
                            "Could not create RssChannel for:",
                            feedUrl
                        )
                    }
                    return
                }

                const loadChannelData = function() {
                    if (channel.status === XmlListModel.Error) {
                        if (DEBUG_MODE) {
                            console.log(
                                "RssChannel XML error for:",
                                feedUrl
                            )

                            console.log(
                                "RssChannel error:",
                                channel.errorString
                            )
                        }
                        channel.statusChanged.disconnect(
                            loadChannelData
                        )

                        channel.destroy()

                        return
                    }

                    if (channel.status !== XmlListModel.Ready) return

                    let channelData = null

                    if (channel.count > 0) channelData = channel.get(0)


                    if (!channelData && feedType === "atom") {
                        channel.statusChanged.disconnect(
                            loadChannelData
                        )

                        channel.namespaceDeclarations =
                            "declare default element namespace " +
                            "'http://www.w3.org/2005/Atom';"

                        channel.statusChanged.connect(
                            loadChannelData
                        )

                        channel.xml = response

                        return
                    }

                    if (!channelData) {
                        if (DEBUG_MODE) {
                            console.log(
                                "No channel data found for:",
                                feedUrl
                            )
                        }

                        channel.statusChanged.disconnect(
                            loadChannelData
                        )

                        channel.destroy()

                        return
                    }

                    channelData.isAtom = feedType === "atom";

                    channelData.feedUrl = feedUrl
                    channelData.fullXml = response

                    if (DEBUG_MODE) {
                        console.log(
                            "channel:",
                            JSON.stringify(channelData)
                        )
                    }

                    channelsList.push(channelData)

                    channel.statusChanged.disconnect(
                        loadChannelData
                    )

                    loadChannelItems(channelData)

                    channel.destroy()
                }

                channel.statusChanged.connect(
                    loadChannelData
                )

                /*
                 * Configure Atom before assigning XML.
                 */
                if (feedType === "atom") {
                    channel.namespaceDeclarations =
                        "declare default element namespace " +
                        "'http://www.w3.org/2005/Atom';"

                    channelData = null
                }

                channel.xml = response

            } catch (e) {
                console.log(
                    "Failed to load channel:",
                    e
                )
            }
        }

        function loadChannelItems(channelData) {
            if (!channelData ||
                !channelData.fullXml) {
                if (DEBUG_MODE) {
                    console.log(
                        "Invalid channel data; cannot load items."
                    )
                }

                return
            }

            const channelItems =
                channelItemsComponent.createObject(
                    null,
                    {}
                )

            if (!channelItems) {
                if (DEBUG_MODE) {
                    console.log(
                        "Could not create RssChannelItems."
                    )
                }

                return
            }

            if (channelData.isAtom) {
                channelItems.namespaceDeclarations =
                    "declare default element namespace " +
                    "'http://www.w3.org/2005/Atom';"
            }

            const parseChannelItems = function() {
                if (channelItems.status === XmlListModel.Error) {
                    if (DEBUG_MODE) {
                        console.log(
                            "RssChannelItems XML error for:",
                            channelData.feedUrl
                        )

                        console.log(
                            "RssChannelItems error:",
                            channelItems.errorString
                        )
                    }

                    channelItems.statusChanged.disconnect(
                        parseChannelItems
                    )

                    channelItems.destroy()

                    return
                }

                if (channelItems.status !== XmlListModel.Ready)
                    return

                if (channelItems.count === 0) {
                    if (DEBUG_MODE) {
                        console.log(
                            "No feed items found for:",
                            channelData.feedUrl
                        )
                    }

                    channelItems.statusChanged.disconnect(
                        parseChannelItems
                    )

                    channelItems.destroy()

                    return
                }

                const count =
                    Math.min(
                        channelItems.count,
                        appSettings.itemsToLoadPerChannel
                    )

                for (let i = 0; i < count; ++i) {
                    try {
                        const item =
                            channelItems.get(i)

                        if (item) {
                            feedItemsParser.sendMessage({
                                item: item,
                                channelData: channelData
                            })
                        }

                    } catch (e) {
                        console.log(
                            "Couldn't parse item:",
                            i,
                            "for:",
                            channelData.feedUrl,
                            e
                        )
                    }
                }

                listSortingTimer.restart()

                channelItems.statusChanged.disconnect(
                    parseChannelItems
                )

                channelItems.destroy()
            }

            channelItems.statusChanged.connect(
                parseChannelItems
            )

            channelItems.xml =
                channelData.fullXml
        }
    }
}
