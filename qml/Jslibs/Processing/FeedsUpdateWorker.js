

WorkerScript.onMessage = function (message) {
	try {
		WorkerScript.sendMessage({"url":message.url});
	} catch(e) {
		console.log("Failed to load url :" + JSON.stringify(message.url) + " got exception : " + e);
	}
}
