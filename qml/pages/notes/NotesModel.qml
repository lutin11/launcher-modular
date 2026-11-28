pragma Singleton
import QtQuick 2.12
import QtQuick.LocalStorage 2.0

// Local storage of the Notes page. Same pattern as the Todo page: a SQLite
// database opened through QtQuick.LocalStorage, and a ListModel kept in sync
// for the views. No network, no credentials: notes stay on the device.
QtObject {
    property var db: LocalStorage.openDatabaseSync("notes-scope", "1.0", "Notes", 1000000)
    property ListModel itemModel: ListModel {}

    function dbInit() {
        try {
            db.transaction(function (tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS notes (note_id INTEGER PRIMARY KEY, title TEXT, body TEXT, created_date INTEGER, updated_date INTEGER, remote_name TEXT);')
            })
        } catch (err) {
            console.log("Notes: cannot create the table: " + err)
        }
        // Databases created before the Nextcloud synchronisation have no
        // remote_name column.
        try {
            db.transaction(function (tx) {
                tx.executeSql('ALTER TABLE notes ADD COLUMN remote_name TEXT')
            })
        } catch (err) {
            // Column already present.
        }
    }

    function buildModel() {
        itemModel.clear()
        try {
            db.transaction(function (tx) {
                var results = tx.executeSql('SELECT note_id, title, updated_date FROM notes ORDER BY updated_date DESC')
                for (var i = 0; i < results.rows.length; i++) {
                    var row = results.rows.item(i)
                    itemModel.append({
                        id: row.note_id,
                        title: row.title,
                        updatedDate: row.updated_date
                    })
                }
            })
        } catch (err) {
            console.log("Notes: cannot read the table: " + err)
        }
    }

    // Returns the identifier of the saved note: the existing one when noteId is
    // set, the newly inserted row otherwise.
    function save(noteId, title, body) {
        var id = noteId
        try {
            db.transaction(function (tx) {
                if (noteId > 0) {
                    tx.executeSql('UPDATE notes SET title=?, body=?, updated_date=? WHERE note_id=?',
                                  [title, body, Date.now(), noteId])
                } else {
                    tx.executeSql('INSERT INTO notes(title, body, created_date, updated_date) VALUES(?, ?, ?, ?)',
                                  [title, body, Date.now(), Date.now()])
                    var result = tx.executeSql('SELECT last_insert_rowid() AS id')
                    id = parseInt(result.rows.item(0).id)
                }
            })
        } catch (err) {
            console.log("Notes: cannot save the note: " + err)
        }
        buildModel()
        return id
    }

    // Name of the note file on the Nextcloud server, when it has been synced.
    function setRemote(noteId, remoteName) {
        try {
            db.transaction(function (tx) {
                tx.executeSql('UPDATE notes SET remote_name=? WHERE note_id=?',
                              [remoteName, noteId])
            })
        } catch (err) {
            console.log("Notes: cannot store the remote name: " + err)
        }
    }

    // Applies a file downloaded from Nextcloud: updates an existing note or
    // creates one. The modification date is the server's, so the next
    // comparison knows which side is newer.
    function applyRemote(noteId, title, body, remoteName, mtime) {
        var updated = mtime > 0 ? mtime : Date.now()
        try {
            db.transaction(function (tx) {
                if (noteId > 0) {
                    tx.executeSql('UPDATE notes SET title=?, body=?, updated_date=?, remote_name=? WHERE note_id=?',
                                  [title, body, updated, remoteName, noteId])
                } else {
                    tx.executeSql('INSERT INTO notes(title, body, created_date, updated_date, remote_name) VALUES(?, ?, ?, ?, ?)',
                                  [title, body, updated, updated, remoteName])
                }
            })
        } catch (err) {
            console.log("Notes: cannot apply the remote note: " + err)
        }
        buildModel()
    }

    function load(noteId) {
        var note = { id: noteId, title: "", body: "", remoteName: "" }
        try {
            db.transaction(function (tx) {
                var result = tx.executeSql('SELECT title, body, remote_name FROM notes WHERE note_id=?', [noteId])
                if (result.rows.length > 0) {
                    note.title = result.rows.item(0).title
                    note.body = result.rows.item(0).body
                    note.remoteName = result.rows.item(0).remote_name || ""
                }
            })
        } catch (err) {
            console.log("Notes: cannot load the note: " + err)
        }
        return note
    }

    // Every note with its body, used by the Nextcloud export.
    function all() {
        var notes = []
        try {
            db.transaction(function (tx) {
                var result = tx.executeSql('SELECT note_id, title, body, updated_date, remote_name FROM notes ORDER BY updated_date ASC')
                for (var i = 0; i < result.rows.length; i++) {
                    var row = result.rows.item(i)
                    notes.push({ id: row.note_id, title: row.title, body: row.body,
                                 updatedDate: row.updated_date,
                                 remoteName: row.remote_name || "" })
                }
            })
        } catch (err) {
            console.log("Notes: cannot read all the notes: " + err)
        }
        return notes
    }

    function remove(noteId) {
        try {
            db.transaction(function (tx) {
                tx.executeSql('DELETE FROM notes WHERE note_id=?', [noteId])
            })
        } catch (err) {
            console.log("Notes: cannot delete the note: " + err)
        }
        buildModel()
    }

    function removeAll() {
        try {
            db.transaction(function (tx) {
                tx.executeSql('DELETE FROM notes')
            })
        } catch (err) {
            console.log("Notes: cannot clear the notes: " + err)
        }
        buildModel()
    }
}
