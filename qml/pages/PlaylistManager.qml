import QtQuick 2.4
import QtQuick.LocalStorage 2.0

Item {
    id: playlistManager

    property var db: null

    property ListModel itemModel : ListModel {}

    // Initialize database on completion
    Component.onCompleted: {
        initDatabase()
        buildModel()
    }

    function initDatabase() {
        db = LocalStorage.openDatabaseSync("LauncherPlaylists", "1.0", "Playlists database", 1000000)

        db.transaction(function(tx) {
            tx.executeSql('CREATE TABLE IF NOT EXISTS playlists(name TEXT PRIMARY KEY)')
            tx.executeSql('CREATE TABLE IF NOT EXISTS tracks(id INTEGER PRIMARY KEY AUTOINCREMENT, playlist TEXT, path TEXT, name TEXT, FOREIGN KEY(playlist) REFERENCES playlists(name))')
        })
    }

    /**
     * Save a playlist with its tracks
     * @param name - Playlist name
     * @param tracks - Array of {path: string, name: string}
     * @return true on success
     */
    function savePlaylist(name, tracks) {
        if (!db || !name || name.length === 0) return false

        var success = false
        db.transaction(function(tx) {
            // Insert playlist
            tx.executeSql('INSERT OR REPLACE INTO playlists VALUES(?)', [name])

            // Remove existing tracks for this playlist
            tx.executeSql('DELETE FROM tracks WHERE playlist=?', [name])

            // Insert new tracks
            for (var i = 0; i < tracks.length; i++) {
                tx.executeSql('INSERT INTO tracks(playlist, path, name) VALUES(?, ?, ?)',
                    [name, tracks[i].path, tracks[i].name])
            }
            success = true
        })
        if (success) buildModel()
        return success
    }

    /**
     * Get all playlist names
     * @return Array of playlist names
     */
    function loadPlaylists() {
        if (!db) return []

        var playlists = []
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT name FROM playlists ORDER BY name')
            for (var i = 0; i < rs.rows.length; i++) {
                playlists.push(rs.rows.item(i).name)
            }
        })
        return playlists
    }

    /**
     * Get tracks in a playlist
     * @param name - Playlist name
     * @return Array of {path: string, name: string}
     */
    function loadPlaylist(name) {
        if (!db || !name) return []

        var tracks = []
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT path, name FROM tracks WHERE playlist=? ORDER BY id', [name])
            for (var i = 0; i < rs.rows.length; i++) {
                tracks.push({
                    path: rs.rows.item(i).path,
                    name: rs.rows.item(i).name
                })
            }
        })
        return tracks
    }

    /**
     * Get track count for a playlist
     * @param name - Playlist name
     * @return Number of tracks
     */
    function getPlaylistCount(name) {
        if (!db || !name) return 0

        var count = 0
        db.transaction(function(tx) {
            var rs = tx.executeSql('SELECT COUNT(*) as cnt FROM tracks WHERE playlist=?', [name])
            if (rs.rows.length > 0) {
                count = rs.rows.item(0).cnt
            }
        })
        return count
    }

    /**
     * Delete a playlist and its tracks
     * @param name - Playlist name
     * @return true on success
     */
    function deletePlaylist(name) {
        if (!db || !name) return false

        var success = false
        db.transaction(function(tx) {
            tx.executeSql('DELETE FROM tracks WHERE playlist=?', [name])
            tx.executeSql('DELETE FROM playlists WHERE name=?', [name])
            success = true
        })
        if (success) buildModel()
        return success
    }

    /**
     * Rename a playlist
     * @param oldName - Current playlist name
     * @param newName - New playlist name
     * @return true on success
     */
    function renamePlaylist(oldName, newName) {
        if (!db || !oldName || !newName || oldName === newName) return false

        var success = false
        db.transaction(function(tx) {
            // Check if new name already exists
            var check = tx.executeSql('SELECT name FROM playlists WHERE name=?', [newName])
            if (check.rows.length === 0) {
                tx.executeSql('UPDATE tracks SET playlist=? WHERE playlist=?', [newName, oldName])
                tx.executeSql('DELETE FROM playlists WHERE name=?', [oldName])
                tx.executeSql('INSERT INTO playlists VALUES(?)', [newName])
                success = true
            }
        })
        if (success) buildModel()
        return success
    }

    function buildModel() {
        itemModel.clear()
        var names = loadPlaylists()
        for (var i = 0; i < names.length; i++) {
            itemModel.append({name: names[i]})
        }
    }
}
