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
                tx.executeSql('CREATE TABLE IF NOT EXISTS notes (note_id INTEGER PRIMARY KEY, title TEXT, body TEXT, created_date INTEGER, updated_date INTEGER);')
            })
        } catch (err) {
            console.log("Notes: cannot create the table: " + err)
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

    function load(noteId) {
        var note = { id: noteId, title: "", body: "" }
        try {
            db.transaction(function (tx) {
                var result = tx.executeSql('SELECT title, body FROM notes WHERE note_id=?', [noteId])
                if (result.rows.length > 0) {
                    note.title = result.rows.item(0).title
                    note.body = result.rows.item(0).body
                }
            })
        } catch (err) {
            console.log("Notes: cannot load the note: " + err)
        }
        return note
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
