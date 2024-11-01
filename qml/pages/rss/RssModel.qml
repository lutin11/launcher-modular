pragma Singleton
import QtQuick 2.12
import QtQuick.LocalStorage 2.0

QtObject {
    property var db: LocalStorage.openDatabaseSync("rsss-scope", "1.0", "Rsss", 1000000)
    property ListModel itemModel : ListModel {id: rssModel}

    signal dbInitialized

    function dbInit()
    {

        try {
            db.transaction(function (tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS rss (rss_id INTEGER PRIMARY KEY, rss_uri TEXT);')
            })
            dbInitialized()
        } catch (err) {
            console.log("Error creating table in database: " + err)
        };
    }

    function populateModel(targetModel) {
        if (DEBUG_MODE) console.log("Populating model")
        targetModel.clear()
        db.transaction(function (tx) {
            var results = tx.executeSql('SELECT rss_id, rss_uri FROM rss ORDER BY rss_id DESC;')
            for (var i = 0; i < results.rows.length; i++) {
                let rss = {
                    id: results.rows.item(i).rss_id,
                    rss_uri: results.rows.item(i).rss_uri
                }
                targetModel.append(rss)
                if (DEBUG_MODE) console.log("Append:", JSON.stringify(rss))
            }
        })
    }

    function buildModel()
    {
        if (DEBUG_MODE) console.log("Model building");
        itemModel.clear()
        db.transaction(function (tx) {
            var results = tx.executeSql('SELECT rss_id, rss_uri FROM rss ORDER BY rss_id DESC;')
            for (var i = 0; i < results.rows.length; i++) {
                if (DEBUG_MODE) console.log(results.rows.item(i).rss_uri)
                let rss = {
                    id: results.rows.item(i).rss_id,
                    rss_uri: results.rows.item(i).rss_uri
                }
                itemModel.append(rss)
                if (DEBUG_MODE) console.log("Append:" + JSON.stringify(rss))
            }
        })

    }

    function count()
    {
        var count = 0
        db.transaction(function (tx) {
            var result = tx.executeSql('SELECT count(*) as nb FROM rss')
            count = parseInt(result.nb)
        })

        return count
    }


    function save(rss_uri_)
    {
        if (DEBUG_MODE) console.log("will save:" + JSON.stringify(rss_uri_))
        var rowid = 0;
        db.transaction(function (tx) {
            tx.executeSql('INSERT INTO rss(rss_uri) VALUES(?)', [rss_uri_])
            var result = tx.executeSql('SELECT last_insert_rowid()')
            rowid = parseInt(result.insertId)
        })
        var rss = {
            id: rowid,
            rss_uri: rss_uri_
        }

        itemModel.insert(0, rss)
    }

    function update(index, rss_uri_)
    {
        var data = itemModel.get(index)

        db.transaction(function (tx) {
            tx.executeSql('update rss set rss_uri=? where rss_id = ?', [rss_uri_, rss.id])
        })

        data.rss_uri = rss_uri_

    }

    function remove(index)
    {
        var data = itemModel.get(index)
        db.transaction(function (tx) {
            if (DEBUG_MODE) console.log("delete rowid:" + data.id)
            tx.executeSql('delete from rss where rss_id = ?', [data.id])
        })

        itemModel.remove(index, 1)
    }

    Component.onCompleted:{
        RssModel.dbInit()
        RssModel.buildModel()
        if (DEBUG_MODE) console.log("nb itemModel:", RssModel.itemModel.count)
    }
}
