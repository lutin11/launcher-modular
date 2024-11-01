import QtQuick 2.12
import Lomiri.Connectivity 1.0
import U1db 1.0 as U1db

Item {
    id: _cachedHttpReq

    signal responseDataUpdated(var response, var id)
    signal requestError(var error, var errorResults, var id)

    property bool isResultJSON: true
    property int cachingTimeMiliSec: 600000
    property real recachingFactor: 0.9
    property bool onlyReturnFreshCache: true
    property bool cachedResponseIsEnough: false
    property bool waitingForResults: false
    property bool isLoggingEnabled: false
    property alias selfCleaningTimeMs: selfCleaningTimer.interval

    function send(url, id, getData, postData) {
        id = id || Math.random();
        const requestURL = url + (getData ? "?" + _internal.mapJsonToRequest(getData) : "");
        if (isLoggingEnabled) console.log("CachedHttpRequest: Retrieving data for:", requestURL, "id:", id);

        waitingForResults = true;
        const cachedFactorPassed = _internal.retrieveFromCache(requestURL, id);
        if (cachedFactorPassed < recachingFactor) return;

        const cachedResponseReturned = cachedFactorPassed < 1 || !onlyReturnFreshCache;

        if (isLoggingEnabled) console.log("CachedHttpRequest: Sending request to URL:", requestURL);

        cachedHttpRequestWorker.sendMessage({
            "requestURL": requestURL,
            "postData": postData,
            "id": id,
            "cachedResponseReturned": cachedResponseReturned,
            "logActions": isLoggingEnabled
        });

        return id;
    }

    WorkerScript {
        id: cachedHttpRequestWorker
        source: "CachedHttpRequest.js"
        onMessage: (message) => {
            waitingForResults = false;
            if (message.success) {
                try {
                    const response = _cachedHttpReq.isResultJSON ? JSON.parse(message.responseText) : message.responseText;
                    const docId = cachedReqDbInstance.putDoc({
                        "request": message.requestURL,
                        "postData": message.postData,
                        "response": message.responseText,
                        "timestamp": Date.now(),
                        "isResultJSON": _cachedHttpReq.isResultJSON
                    }, Qt.md5(message.requestURL));

                    if (isLoggingEnabled) console.log("CachedHttpRequest: Cached response with ID:", docId);
                    if (!cachedResponseIsEnough || !message.cachedResponseReturned) {
                        responseDataUpdated(response, message.id);
                    }
                } catch (error) {
                    console.log("CachedHttpRequest: Error processing response from:", message.requestURL, "id:", message.id, "Error:", error);
                    requestError(error, message.responseText, message.id);
                }
            } else {
                requestError(message.event, message.responseText, message.id);
            }
        }
    }

    onResponseDataUpdated: { waitingForResults = false; }
    onRequestError: { waitingForResults = false; }

    U1db.Database {
        id: cachedReqDbInstance
        path: "cached-requests-db"
    }

    U1db.Index {
        id: requestIndex
        database: cachedReqDbInstance
        name: "requestIndex"
        expression: [ "request" ]
    }

    U1db.Query {
        id: getPreviousResponses
        index: requestIndex
        query: ["*"]
    }

    Timer {
        id: selfCleaningTimer
        interval: _cachedHttpReq.cachingTimeMiliSec / 2
        triggeredOnStart: true
        running: true
        onTriggered: _internal.cleanOldCachedDocs();
    }

    QtObject {
        id: _internal

        function retrieveFromCache(requestURL, id) {
            getPreviousResponses.query = [requestURL];
            if (getPreviousResponses.results.length > 0) {
                for (let i in getPreviousResponses.documents) {
                    const prvResponse = cachedReqDbInstance.getDoc(getPreviousResponses.documents[i]);
                    const age = Date.now() - prvResponse.timestamp;
                    const response = prvResponse.isResultJSON ? JSON.parse(prvResponse.response) : prvResponse.response;

                    if (age < cachingTimeMiliSec) {
                        if (isLoggingEnabled) console.log("CachedHttpRequest: Loading cached response for:", requestURL);
                        _cachedHttpReq.responseDataUpdated(response, id);
                        return age / cachingTimeMiliSec;
                    }

                    if (!onlyReturnFreshCache) {
                        console.log("CachedHttpRequest: Returning outdated cached response for:", requestURL);
                        _cachedHttpReq.responseDataUpdated(response, id);
                        return 1;
                    }
                }
            }
            return 1;
        }

        function cleanOldCachedDocs() {
            if (Connectivity.status == NetworkingStatus.Offline) return;

            getPreviousResponses.query = ["*"];
            if (isLoggingEnabled) console.log("CachedHttpRequest: Cleaning old documents...");

            getPreviousResponses.results.forEach(docId => {
                const prvResponse = cachedReqDbInstance.getDoc(docId);
                const age = Date.now() - prvResponse.timestamp;

                if (age > cachingTimeMiliSec * 1.25) {
                    if (isLoggingEnabled) console.log("CachedHttpRequest: Removing stale document for:", prvResponse.request);
                    cachedReqDbInstance.deleteDoc(docId);
                }
            });

            if (isLoggingEnabled) console.log("CachedHttpRequest: Cleaning complete.");
        }

        function mapJsonToRequest(json) {
            return Object.keys(json).map(key =>
                typeof json[key] == 'object' ? `${key}[]=${mapJsonToRequest(json[key])}` : `${key}=${json[key]}`
            ).join("&");
        }
    }
}
