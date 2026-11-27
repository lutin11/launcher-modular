.pragma library

// Table of the bundled pages that depend on a QML module living outside this
// project. A page whose module is missing cannot be loaded: creating the object
// is enough to make the whole file fail, and the error propagates to its parent
// ("Type X unavailable" followed by "module ... is not installed"). Such a page
// is therefore removed from the list of pages that can be added, and replaced by
// an explicit empty state.
//
// Each value is a list of boolean property names of Platform. A module
// dependency is always blocking: a missing module breaks the file that imports
// it, on every machine.
//
// Personal pages in ~/.launchermodular/pages are unknown here: they are never
// filtered, and a load error there is still reported as it is by Main.qml.
var PAGES = {
    "Folders.qml": ["hasThumbnailerModule", "hasContentModule"],
    "Videos.qml": ["hasThumbnailerModule"],
    "Music.qml": ["hasThumbnailerModule", "hasMultimediaModule", "hasSystemInfoModule",
                  "hasLocalStorageModule"],
    "Picture.qml": ["hasThumbnailerModule"],
    "NextcloudFolders.qml": ["hasContentModule", "hasDownloadManagerModule"],
    "Rss.qml": ["hasConnectivityModule", "hasLocalStorageModule"],
    "Todo.qml": ["hasLocalStorageModule"],
    "Notes.qml": ["hasLocalStorageModule"],
    // The calendar page loads its data through QtOrganizer at run time, so the
    // module itself is what makes the file fail, not the provider: a machine
    // without a provider shows an empty calendar, which the page already does.
    "Calendar.qml": ["hasOrganizerModule"],
    "Clock.qml": ["hasSensorsModule", "hasSystemInfoModule"]
};

// Module names as they should be shown to the user (never translated: these are
// module names, not user interface labels).
var MODULES = {
    "hasThumbnailerModule": "Lomiri.Thumbnailer",
    "hasContentModule": "Lomiri.Content",
    "hasDownloadManagerModule": "Lomiri.DownloadManager",
    "hasConnectivityModule": "Lomiri.Connectivity",
    "hasMultimediaModule": "QtMultimedia",
    "hasHistoryModule": "Lomiri.History",
    "hasContactsModule": "Lomiri.Contacts",
    "hasSensorsModule": "QtSensors",
    "hasSystemInfoModule": "QtSystemInfo",
    "hasLocalStorageModule": "QtQuick.LocalStorage"
};

// True when the page can be offered on this machine. platform is the Platform
// singleton: a JavaScript library has no access to it on its own.
function isAvailable(platform, pageFileName) {
    var capabilities = PAGES[pageFileName];
    if (capabilities === undefined || platform === undefined || platform === null) {
        return true;
    }
    for (var i = 0; i < capabilities.length; i++) {
        if (platform[capabilities[i]] !== true) {
            return false;
        }
    }
    return true;
}

// Only the modules really missing on this machine: showing a dependency that is
// present would mislead the reader more than inform them.
function missingModules(platform, pageFileName) {
    var capabilities = PAGES[pageFileName];
    if (capabilities === undefined || platform === undefined || platform === null) {
        return [];
    }
    var names = [];
    for (var i = 0; i < capabilities.length; i++) {
        if (platform[capabilities[i]] !== true) {
            var name = MODULES[capabilities[i]];
            if (name !== undefined) {
                names.push(name);
            }
        }
    }
    return names;
}
