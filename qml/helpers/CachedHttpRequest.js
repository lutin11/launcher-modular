WorkerScript.onMessage = function(message) {
    //console.log("------ CachedHttpRequest.js: " + message.requestURL)
    var http = new XMLHttpRequest();
    http.open("GET", message.requestURL);
    var textToRemove = [];

    http.onreadystatechange = function() {
        if (http.readyState === XMLHttpRequest.DONE) {
            if (http.status >= 200 && http.status < 300) {
                var response = http.responseText;
                for (var strToRemove of textToRemove) {
                    response = response.replace(strToRemove, '');
                    //console.log("------ Removing from response: " + strToRemove);
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
                    //console.log("CachedHttpRequest:Worker: HTTP readyState: " + http.readyState + ", status: " + http.status);
                }
                if (http.response) {
                    var response = http.response;
                    for (var strToRemove of textToRemove) {
                        response = response.replace(strToRemove, '');
                    }
                    textToRemove.push(response);
                    //console.log("++++++++++++ Redirected or Error response from: " + message.requestURL);
                }
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

    http.send(message.postData ? message.postData : null);
};
