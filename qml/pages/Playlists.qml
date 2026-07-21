import QtQuick 2.12
import Qt.labs.settings 1.0
import MySettings 1.0

QtObject {
    id: playlists

    property string playlistsDir: MySettings.getHomeLocation() + "/.launchermodular/playlists"

    function ensureDir() {
        // Directory is created on first save via FolderListModel
    }

    function savePlaylist(name, songs) {
        var content = JSON.stringify({
            "name": name,
            "created": new Date().toISOString(),
            "songs": songs
        }, null, 2)
        var xhr = new XMLHttpRequest()
        xhr.open("PUT", "file://" + playlistsDir + "/" + name + ".json", false)
        xhr.send(content)
        return xhr.status === 0 || xhr.status === 200
    }

    function loadPlaylist(name) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + playlistsDir + "/" + name + ".json", false)
        xhr.send()
        if (xhr.status === 200 || xhr.status === 0) {
            try {
                return JSON.parse(xhr.responseText)
            } catch(e) {
                return null
            }
        }
        return null
    }

    function listPlaylists() {
        var result = []
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + playlistsDir + "/", false)
        xhr.send()
        // FolderListModel approach — fallback to settings
        var stored = launchermodular.settings.playlistNames
        if (typeof stored !== 'undefined' && stored !== null) {
            result = stored
        }
        return result
    }

    function deletePlaylist(name) {
        var xhr = new XMLHttpRequest()
        xhr.open("DELETE", "file://" + playlistsDir + "/" + name + ".json", false)
        xhr.send()
        // Remove from stored names
        var names = launchermodular.settings.playlistNames || []
        var idx = names.indexOf(name)
        if (idx !== -1) {
            names.splice(idx, 1)
            launchermodular.settings.playlistNames = names
        }
    }
}
