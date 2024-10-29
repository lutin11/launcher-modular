WorkerScript.onMessage = function parseItems(message) {
    var item = message.item;
    var channelData = message.channelData;

    // Extract domain from feed URL
    var channelDomainMatch = ("" + channelData["feedUrl"]).match(/https?:\/\/([^\/]+)/);
    var channelDomain = channelDomainMatch ? channelDomainMatch.pop() : "unknown";

    try {
        item["chImageUrl"] = channelData["imageUrl"];
        item["domain"] = channelDomain;
        item["channel"] = channelData["titleText"] || channelDomain;

        // Extract date from title or description if "updated" is missing
        if (!item["updated"]) {
            let dateMatch = item["title"].match(/(\d{4}[\-./]\d\d[\-./]\d\d|\d\d[\-./]\d\d[\-./]\d{4})/) ||
                            item["description"].match(/(\d{4}[\-./]\d\d[\-./]\d\d|\d\d[\-./]\d\d[\-./]\d{4})/);
            if (dateMatch) {
                item["updated"] = Date.parse(dateMatch[0]);
            }
        }

        // Format date for display
        item["updateDate"] = new Date(item["updated"]).toDateString();
        item["itemData"] = JSON.parse(JSON.stringify(item));

        WorkerScript.sendMessage({ "item": item });
    } catch (e) {
        console.log("Couldn't parse item for: " + channelData["feedUrl"] + ", error: " + e.message);
    }
};