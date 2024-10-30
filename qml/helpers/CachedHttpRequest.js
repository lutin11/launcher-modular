WorkerScript.onMessage = function(message) {
    var http = new XMLHttpRequest();
    http.open("GET", message.requestURL, true); // Specify asynchronous (true) for clarity
    const textToRemove = [];

    http.onreadystatechange = function() {
        if (http.readyState === XMLHttpRequest.DONE) {
            if (http.status >= 200 && http.status < 300) {
                var response = http.responseText;
                for (var strToRemove of textToRemove) {
                    response = response.replace(strToRemove, '');
                }
                WorkerScript.sendMessage({
                    "success": true,
                    "http": http,
                    "responseText": response,
                    "id": message.id,
                    "requestURL": message.requestURL,
                    "cachedResponseReturned": message.cachedResponseReturned
                });
            } else {
                if (message.logActions) {
                    console.log("WorkerScript: HTTP error with status: " + http.status);
                }
                WorkerScript.sendMessage({
                    "success": false,
                    "http": http,
                    "responseText": http.responseText || "",
                    "id": message.id,
                    "requestURL": message.requestURL,
                    "cachedResponseReturned": message.cachedResponseReturned
                });
            }
        }
    };

    http.onerror = function(event) {
        WorkerScript.sendMessage({
            "success": false,
            "http": http,
            "responseText": http.responseText,
            "id": message.id,
            "requestURL": message.requestURL,
            "cachedResponseReturned": message.cachedResponseReturned,
            "event": event,
            "postData": message.postData
        });
    };

    // Initiate the network request
    http.send(message.postData || null);
};
