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
    id:_mainFeed

    clip:true

    property var model : RssModel.itemModel
    property var refreshing:  cachedHttpRequestInstance.waitingForResults;
    property var currentSearch : null
    property var currentSection : null
    property var channelsList : []
    property bool isFeeds: false

    Component.onCompleted: {
        RssModel.dbInit()
        updateFeedsTimer.start();

    }

    onRefreshingChanged: if(!refreshing) {
        //listSortingTimer.restart();
    }

    //------------------------------ Components -----------------------------

    Component {
        id:channelComponent
        RssChannel {
        }
    }

    Component {
        id:channelItemsComponent
        RssChannelItems {
            id:channelItemsComponentObj
        }
    }

    WorkerScript {
        id:feedItemsParser
        source : "../Jslibs/Processing/FeedItemsParser.js"

        onMessage :  (message) => {
            var item = message.item
            feedList.model.append(item);
        }
    }

    // Timer  used to allow  for multiple updates that  result in a single sorting
    Timer {
        id:listSortingTimer
        interval:1000
        repeat: false
        running:false
        onTriggered : {
            console.log("Timer Sorting..")
            feedList.model.sort();
            var sortFunctions = {
                "Publication Date" : function sortByPubDate(a,b) {
                    return  (new Date(b['firstEntryPubDate'] )).getTime() - (new Date( a['firstEntryPubDate'])).getTime();
                },
                "Title" : function sortByTitle(a,b) {
                    return  a['titleText'].localeCompare (b['titleText']);
                }
            }
        }
    }
    Timer {
        id:updateFeedsTimer
        interval:10
        repeat: false
        running:false
        onTriggered : {
            console.log("Timer updating..")
            RssModel.buildModel()
            _mainFeed.updateFeed();
        }
    }

    CachedHttpRequest {
        id:cachedHttpRequestInstance
        isResultJSON : false;
        isLoggingEnabled:false;
        onlyReturnFreshCache: Connectivity.status !== NetworkingStatus.Offline ;
        cachingTimeMiliSec: appSettings.feedCacheTimeout * 60000;
        recachingFactor: 0.25;
        cachedResponseIsEnough:true
    }

    //--------------------------------- Functions ----------------------------------

    function updateFeed() {
        if( !RssModel.itemModel || RssModel.itemModel.length ==  0 ||  _mainFeed.refreshing ||  listSortingTimer.running ) {
            _mainFeed.isFeeds = false;
            return;
        }
        if(Connectivity.status === NetworkingStatus.Offline  ) {
            console.log("Limited connectivity... not updating.");
            if( feedList.model && feedList.model.length) {
              return;
            }
        }

        console.log("updating the feeds..");
        feedList.model.clear();
        channelsList = [];
        _mainFeed.isFeeds = RssModel.itemModel.count > 0
        for(let i=0; i < RssModel.itemModel.count;i++) {
    			let url = RssModel.itemModel.get(i);
    			cachedHttpRequestInstance.send(url.rss_uri, {"url": url.rss_uri});
    		}
    }

    Feed {
        id:feedList

        anchors {
            topMargin: parent.top
            fill:parent
        }

        model: FeedsModel {
            id:feedModel
        }

        Rectangle {
            anchors {
                fill:parent
            }
            z:1
            opacity: 0.6
            visible:  _mainFeed.isFeeds === false
            color: "transparent"
            ProgressBar {
                anchors {
                    horizontalCenter:parent.horizontalCenter
                    bottom:loadingLabel.top
                    margins:units.gu(2)
                }
                indeterminate:true
                visible: _mainFeed.isFeeds
            }
             Label {
                 id: noFeeds
                 text: _mainFeed.isFeeds ? i18n.tr("Loading feeds…") : i18n.tr("Go to the page management to add feeds.")
                 color: launchermodular.settings.textColor
                 font.weight: Font.Bold
                 wrapMode: Text.Wrap
                 horizontalAlignment:Text.AlignHCenter
                 anchors {
                   verticalCenter:parent.verticalCenter
                   left:parent.left
                   right:parent.right
                   margins:units.gu(2)
                 }
             }
        }

        pullToRefresh {
            enabled: true
            refreshing: feedList.model.count == 0  || listSortingTimer.running || _mainFeed.refreshing
            onRefresh: _mainFeed.updateFeed()
        }

        delegate: FeedItem {
            visible: !_mainFeed.currentSection || _mainFeed.currentSection == itemData['channel']

            onClicked:{
                feedList.currentIndex = index;
                Qt.openUrlExternally(itemData.url);
            }
        }
    }

    Connections {
        target: cachedHttpRequestInstance

        onResponseDataUpdated: (response, data) => {
            try {
                const channel = channelComponent.createObject(null, {});
                const loadChannelData = function() {
                    if (channel.status !== XmlListModel.Ready) return;

                    let channelData = channel.get(0);

                    // Set namespace declaration if channelData is empty
                    if (!channelData) {
                        channel.namespaceDeclarations = "declare default element namespace 'http://www.w3.org/2005/Atom';";
                        channel.xml = response;
                        return;
                    }

                    // Check if Atom feed and store additional data
                    if (channel.namespaceDeclarations === "declare default element namespace 'http://www.w3.org/2005/Atom';") {
                        channelData.isAtom = true;
                    }

                    console.log("channel:", JSON.stringify(channelData));
                    channelData.feedUrl = data.url;
                    channelData.fullXml = response;
                    channelsList.push(channelData);

                    loadChannelItems(channelData);
                    channel.statusChanged.disconnect(loadChannelData);
                };

                channel.statusChanged.connect(loadChannelData);
                channel.xml = response;

            } catch (e) {
                console.log("Failed to load channel:", e);
            }
        }

        onRequestError: (error, errorResult) => {
            console.log("ERROR: Failed to load channel:", error, "Results:", errorResult);
        }

        function loadChannelItems(channelData) {
            const channelItems = channelItemsComponent.createObject(null, {});

            if (channelData.isAtom) {
                channelItems.namespaceDeclarations = "declare default element namespace 'http://www.w3.org/2005/Atom';";
            }

            const parseChannelItems = function() {
                if (channelItems.status !== XmlListModel.Ready) return;

                if (channelItems.count === 0) {
                    channelItems.statusChanged.disconnect(parseChannelItems);
                    channelItems.destroy();
                    return;
                }

                for (let i = 0; i < Math.min(channelItems.count, appSettings.itemsToLoadPerChannel); i++) {
                    try {
                        const item = channelItems.get(i);
                        feedItemsParser.sendMessage({ item, channelData });
                    } catch (e) {
                        console.log("Couldn't parse item:", i, "for:", channelData.feedUrl);
                    }
                }

                listSortingTimer.restart();
                channelItems.statusChanged.disconnect(parseChannelItems);
            };

            channelItems.statusChanged.connect(parseChannelItems);
            channelItems.xml = channelData.fullXml;
        }
    }

}
