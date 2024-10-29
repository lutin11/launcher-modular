import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.Controls 2.2 as QControls
import QtQuick.XmlListModel 2.12
import QtQml.Models 2.2
import Lomiri.Connectivity 1.0

import "../components"
import "../helpers"
import HelperFunctions 1.0

Item {
    id:_mainFeed

    clip:true

    property var model : ["https://www.radiofrance.fr/franceinter/rss", "https://www.mediapart.fr/articles/feed"]
    property var refreshing:  cachedHttpRequestInstance.waitingForResults;
    property var currentSearch : null
    property var currentSection : null
    property var channelsList : []

    Component.onCompleted: {
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
        if( !_mainFeed.model || _mainFeed.model.length ==  0 ||  _mainFeed.refreshing ||  listSortingTimer.running ) {
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
    //		_mainFeed.header.sectionsModel = [];
    //		for(var i in _mainFeed.model) {
    //			var url = _mainFeed.model[i];
    //			cachedHttpRequestInstance.send(url, {"url": url});
    //		}
        cachedHttpRequestInstance.send("https://www.radiofrance.fr/franceinter/rss", {"url": "https://www.radiofrance.fr/franceinter/rss"});
        cachedHttpRequestInstance.send("https://www.mediapart.fr/articles/feed", {"url": "https://www.mediapart.fr/articles/feed"});
    }

    Feed {
        id:feedList

        anchors {
            topMargin:_mainFeed.header.height
            fill:parent
        }

        model: FeedsModel {
            id:feedModel
        }
        highlightFollowsCurrentItem:true
        highlightMoveDuration: 250
        snapMode:ListView.SnapToItem

        pullToRefresh {
            enabled: true
            refreshing:  feedList.model.count == 0  || listSortingTimer.running || _mainFeed.refreshing
            onRefresh: _mainFeed.updateFeed()
        }

        section.property :appSettings.showSections && !_mainFeed.currentSection ? appSettings.mainFeedSectionField : ""
        section.criteria: ViewSection.FullString
        section.labelPositioning: ViewSection.InlineLabels

        section.delegate: ListItem {
            height: sectionHeader.implicitHeight + units.gu(2)
            Label {
                id: sectionHeader
                text: section
                font.weight: Font.Bold
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle {
            anchors {
                fill:parent
            }
            z:1
            opacity: 0.3
            visible:  _mainFeed.model.length  == 0 ||  feedList.model.count == 0  || listSortingTimer.running || _mainFeed.refreshing
            color: "transparent"
            ProgressBar {
                anchors {
                    horizontalCenter:parent.horizontalCenter
                    bottom:loadingLabel.top
                    margins:units.gu(2)
                }
                indeterminate:true
                visible: _mainFeed.model.length > 0

            }
            Label {
                id:loadingLabel
                anchors {
                    verticalCenter:parent.verticalCenter
                    left:parent.left
                    right:parent.right
                    margins:units.gu(2)
                }
                text: _mainFeed.model.length > 0 ? i18n.tr("Loading feeds…") : i18n.tr("Long press-me to setup rss feeds")
                wrapMode: Text.Wrap
                horizontalAlignment:Text.AlignHCenter
            }
        }

        delegate: FeedItem {
            visible: !_mainFeed.currentSection || _mainFeed.currentSection == itemData['channel'] //_mainFeed.itemMatchSearch(itemData,_mainFeed.currentSearch)

            onClicked:{
                feedList.currentIndex = index;
                Qt.openUrlExternally(itemData.url);
            }
        }

        Timer {
            interval: appSettings.updateFeedEveryXMinutes*60000
            running: appSettings.updateFeedEveryXMinutes > 0
            repeat: true
            triggeredOnStart:false
            onTriggered: {
                _mainFeed.updateFeed();
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

                console.log("channelItems.status:", channelItems.status, "nb message:", channelItems.count);

                if (channelItems.count === 0) {
                    //root.primaryPageNotify(i18n.tr("Couldn't parse channel: %1").arg(channelData.feedUrl));
                    console.log("Couldn't parse channel:", channelData.feedUrl);
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
