import QtQuick 2.12
import NetworkHelper 1.0
import "."

// Sending notes to a Nextcloud folder.
//
// The destination is chosen in the settings of the Notes page: either the
// global Nextcloud account of the application, or the account of a
// "Nextcloud folders" page. Notes are uploaded as Markdown files into a
// "Notes" folder (name configurable) at the root of that account.
//
// Only WebDAV is used (MKCOL for the folder, PUT for the note), with the same
// credentials as the folder page. Nothing is deleted on the server.
QtObject {
    id: nextcloudNotes

    property bool busy: false
    // Callbacks of the NetworkHelper requests, by tag. The tag is prefixed:
    // NetworkHelper is shared with the RSS and CalDAV code, whose tags are
    // "PUT:n" or "REPORT:n"; two Notes instances must not collide either.
    property var callbacks: ({})
    property int requestCounter: 0
    property string instanceTag: Math.random().toString(36).substring(2, 8)

    // Nextcloud answers 423 (Locked) while a note is open in its web editor or
    // in the Notes app. The lock is usually released quickly: retry a couple
    // of times before giving up.
    property Timer retryTimer: Timer {
        interval: 1500
        repeat: false
        property var action: null
        onTriggered: {
            var pending = action
            action = null
            if (pending)
                pending()
        }
    }

    function retryLater(action) {
        retryTimer.action = action
        retryTimer.restart()
    }

    // QtObject has no default property: the connection is held by a property.
    property var network: Connections {
        target: NetworkHelper
        function onRequestFinished(tag, status, body) {
            var callback = nextcloudNotes.callbacks[tag]
            if (callback) {
                delete nextcloudNotes.callbacks[tag]
                callback(status, body)
            }
        }
    }

    // XMLHttpRequest refuses MKCOL ("Unsupported HTTP method type"), so the
    // application's NetworkHelper (QNetworkAccessManager) sends the arbitrary
    // verbs used by WebDAV.
    function send(account, method, url, body, headers, callback) {
        requestCounter++
        var tag = "notes-" + instanceTag + ":" + method + ":" + requestCounter
        callbacks[tag] = callback
        NetworkHelper.sendRequest(tag, method, url, body ? body : "",
                                  "Authorization: " + authHeader(account) + headers)
    }

    function configuredAccount(account) {
        return !!(account && account.url && account.user && account.password)
    }

    function globalAccount() {
        return {
            url: launchermodular.settings.nextcloudUrl || "",
            user: launchermodular.settings.nextcloudUser || "",
            password: launchermodular.settings.nextcloudPassword || ""
        }
    }

    // Account stored in a "Nextcloud folders" page (own config first, legacy
    // page data second). The global settings are not used here: they are
    // listed as a separate choice.
    function pageAccount(page) {
        var data = page.data || {}
        var config = (page.uid && page.uid.length > 0)
                ? launchermodular.getPageConfig(page.uid) : ({})
        return {
            url: config.nextcloudUrl || data.nextcloudUrl || "",
            user: config.nextcloudUser || data.nextcloudUser || "",
            password: config.nextcloudPassword || data.nextcloudPassword || ""
        }
    }

    // Choices offered by the Notes settings: the global account (when set) and
    // each configured "Nextcloud folders" page.
    function availableSources() {
        var sources = []
        var global = globalAccount()
        if (configuredAccount(global)) {
            sources.push({
                id: "global",
                label: i18n.tr("Global account") + " — " + global.user + " — " + global.url
            })
        }
        for (var index = 0; index < launchermodular.pageModel.count; index++) {
            var page = launchermodular.pageModel.get(index)
            if (page.name !== "NextcloudFolders.qml")
                continue
            var account = pageAccount(page)
            if (!configuredAccount(account))
                continue
            sources.push({
                id: (page.uid && page.uid.length > 0) ? page.uid : ("page:" + index),
                label: account.user + " — " + account.url
            })
        }
        return sources
    }

    // Resolves the configured source of a Notes page config. Returns null when
    // nothing is chosen or the account no longer exists.
    function accountFor(config) {
        var source = (config && config.notesSyncSource) ? String(config.notesSyncSource) : ""
        if (source.length === 0)
            return null
        if (source === "global") {
            var global = globalAccount()
            return configuredAccount(global) ? global : null
        }
        for (var index = 0; index < launchermodular.pageModel.count; index++) {
            var page = launchermodular.pageModel.get(index)
            if (page.name !== "NextcloudFolders.qml")
                continue
            var id = (page.uid && page.uid.length > 0) ? page.uid : ("page:" + index)
            if (id !== source)
                continue
            var account = pageAccount(page)
            return configuredAccount(account) ? account : null
        }
        return null
    }

    // Single folder name under the root of the account. Path separators and
    // characters the server may refuse are replaced.
    function folderFor(config) {
        var raw = (config && config.notesSyncFolder) ? String(config.notesSyncFolder) : "Notes"
        raw = raw.replace(/[\/\\:*?"<>|]/g, "-")
        raw = raw.replace(/[\u0000-\u001f]/g, "")
        raw = raw.replace(/\s+/g, " ").trim()
        while (raw.charAt(0) === ".")
            raw = raw.substring(1)
        if (raw.length === 0)
            raw = "Notes"
        if (raw.length > 60)
            raw = raw.substring(0, 60).trim()
        return raw
    }

    // "My note" -> "My note.md". Names are stable (the title), so saving the
    // same note again replaces its file on the server.
    function fileName(title, noteId) {
        var base = String(title || "").trim()
        base = base.replace(/[\/\\:*?"<>|]/g, "-")
        base = base.replace(/[\u0000-\u001f]/g, "")
        base = base.replace(/\s+/g, " ").trim()
        while (base.charAt(0) === ".")
            base = base.substring(1)
        if (base.length > 80)
            base = base.substring(0, 80).trim()
        base = base.replace(/\.md$/i, "")
        if (base.length === 0)
            base = "Note"
        // The note number keeps two notes with the same title apart, while
        // saving the same note again replaces its own file.
        if (noteId > 0)
            return base + " (" + noteId + ").md"
        return base + ".md"
    }

    function davUrl(account, path) {
        var base = String(account.url || "").replace(/\/+$/, "")
        var clean = String(path || "/").split("/").map(encodeURIComponent).join("/")
        if (clean.charAt(0) !== "/")
            clean = "/" + clean
        return base + "/remote.php/dav/files/" + encodeURIComponent(account.user) + clean
    }

    function authHeader(account) {
        return "Basic " + Qt.btoa(account.user + ":" + account.password)
    }

    function ensureFolder(account, folder, callback, attempt) {
        send(account, "MKCOL", davUrl(account, "/" + folder), "", "",
             function (status) {
            if (status === 423 && attempt < 2) {
                retryLater(function () {
                    ensureFolder(account, folder, callback, attempt + 1)
                })
                return
            }
            // 201: created. 405: already exists (the normal case).
            callback(status === 201 || status === 405, status)
        })
    }

    // Uploads one note. callback(success, httpStatus).
    function uploadNote(account, folder, name, body, callback) {
        ensureFolder(account, folder, function (folderOk, folderStatus) {
            if (!folderOk) {
                callback(false, folderStatus)
                return
            }
            putNote(account, folder, name, body, callback, 0)
        }, 0)
    }

    function putNote(account, folder, name, body, callback, attempt) {
        send(account, "PUT", davUrl(account, "/" + folder + "/" + name),
             body, "\nContent-Type: text/markdown; charset=utf-8",
             function (status) {
            if (status === 423 && attempt < 2) {
                retryLater(function () {
                    putNote(account, folder, name, body, callback, attempt + 1)
                })
                return
            }
            callback(status === 201 || status === 204, status)
        })
    }

    // "My note (12).md" -> 12, 0 when the name was not created by this app.
    function parseNoteId(name) {
        var match = String(name).match(/ \((\d+)\)\.md$/i)
        return match ? parseInt(match[1]) : 0
    }

    // "My note (12).md" -> "My note".
    function titleFromName(name) {
        return String(name).replace(/\.md$/i, "").replace(/ \(\d+\)$/, "")
    }

    // Lists the Markdown files of the destination folder with their
    // modification date. callback(files, httpStatus); files is null on error.
    function listRemote(account, folder, callback) {
        var body = '<?xml version="1.0" encoding="utf-8" ?>' +
                   '<d:propfind xmlns:d="DAV:">' +
                   '<d:prop><d:resourcetype/><d:getlastmodified/><d:displayname/></d:prop>' +
                   '</d:propfind>'
        send(account, "PROPFIND", davUrl(account, "/" + folder), body,
             "\nDepth: 1\nContent-Type: application/xml; charset=utf-8",
             function (status, text) {
            if (status !== 207 && status !== 200) {
                callback(null, status)
                return
            }
            var files = []
            var blocks = String(text).split(/<[^:>]*:?response[ >]/i).slice(1)
            for (var index = 0; index < blocks.length; index++) {
                var block = blocks[index]
                // Directories (the folder itself and its sub-folders).
                if (/<[^:>]*:?collection\s*\/?>/i.test(block))
                    continue
                var hrefMatch = block.match(/<[^:>]*:?href[^>]*>([^<]*)<\/[^:>]*:?href>/i)
                if (!hrefMatch)
                    continue
                var href = hrefMatch[1]
                try { href = decodeURIComponent(href) } catch (error) { }
                var name = href.split("/").pop()
                if (!/\.md$/i.test(name))
                    continue
                var dateMatch = block.match(/<[^:>]*:?getlastmodified[^>]*>([^<]*)<\/[^:>]*:?getlastmodified>/i)
                var mtime = dateMatch ? new Date(dateMatch[1]).getTime() : 0
                if (isNaN(mtime))
                    mtime = 0
                files.push({ name: name, mtime: mtime })
            }
            callback(files, status)
        })
    }

    // Two-way synchronisation of the Notes folder.
    //
    // For each remote file, the newest side wins: a remote file newer than the
    // local note is downloaded, a local note newer than its remote file is
    // uploaded, and a remote file with no local note creates one. Files are
    // matched by their stored remote name, then by the "(id)" in the file
    // name. progress(phase, done, total) reports the transfers,
    // done(success, summary) ends the sync.
    function syncAll(account, config, progress, done) {
        var folder = folderFor(config)
        var downloaded = 0
        var uploaded = 0
        var firstError = 0

        function finish() {
            done(firstError === 0, { downloaded: downloaded, uploaded: uploaded,
                                     status: firstError })
        }

        function downloadNext(downloads, index, remoteByName) {
            if (index >= downloads.length) {
                uploadPhase(remoteByName)
                return
            }
            var item = downloads[index]
            progress("download", index + 1, downloads.length)
            send(account, "GET",
                 davUrl(account, "/" + folder + "/" + item.remote.name), "", "",
                 function (status, body) {
                if (status === 200) {
                    var title = item.note
                            ? (item.note.title || titleFromName(item.remote.name))
                            : titleFromName(item.remote.name)
                    NotesModel.applyRemote(item.note ? item.note.id : 0, title, body,
                                           item.remote.name, item.remote.mtime)
                    downloaded++
                } else if (status !== 404) {
                    if (firstError === 0)
                        firstError = status
                }
                downloadNext(downloads, index + 1, remoteByName)
            })
        }

        function uploadNext(uploads, index) {
            if (index >= uploads.length) {
                finish()
                return
            }
            var item = uploads[index]
            uploadNote(account, folder, item.name, item.note.body || "",
                       function (ok, status) {
                if (ok) {
                    uploaded++
                    NotesModel.setRemote(item.note.id, item.name)
                } else if (firstError === 0) {
                    firstError = status
                }
                progress("upload", index + 1, uploads.length)
                uploadNext(uploads, index + 1)
            })
        }

        function uploadPhase(remoteByName) {
            var locals = NotesModel.all()
            var uploads = []
            for (var index = 0; index < locals.length; index++) {
                var note = locals[index]
                var title = (note.title && note.title.length > 0)
                        ? note.title : Qt.formatDate(new Date(), "dd/MM/yyyy")
                if ((!note.title || note.title.trim().length === 0)
                        && (!note.body || note.body.trim().length === 0)) {
                    continue
                }
                var name = (note.remoteName && note.remoteName.length > 0)
                        ? note.remoteName : fileName(title, note.id)
                var remote = remoteByName[name]
                if (!remote || note.updatedDate > remote.mtime + 2000)
                    uploads.push({ note: note, name: name })
            }
            uploadNext(uploads, 0)
        }

        ensureFolder(account, folder, function (folderOk, folderStatus) {
            if (!folderOk) {
                firstError = folderStatus
                finish()
                return
            }
            listRemote(account, folder, function (files, listStatus) {
                if (!files) {
                    firstError = listStatus
                    finish()
                    return
                }
                var remoteByName = ({})
                for (var fileIndex = 0; fileIndex < files.length; fileIndex++)
                    remoteByName[files[fileIndex].name] = files[fileIndex]

                var locals = NotesModel.all()
                var localByRemote = ({})
                var localById = ({})
                for (var localIndex = 0; localIndex < locals.length; localIndex++) {
                    var local = locals[localIndex]
                    localById[local.id] = local
                    if (local.remoteName && local.remoteName.length > 0)
                        localByRemote[local.remoteName] = local
                }

                var downloads = []
                for (var index = 0; index < files.length; index++) {
                    var remote = files[index]
                    var note = localByRemote[remote.name]
                    if (!note) {
                        var id = parseNoteId(remote.name)
                        if (id > 0) {
                            var candidate = localById[id]
                            // Adopt a file renamed on the server only when the
                            // note has no other file any more.
                            if (candidate && (!candidate.remoteName
                                    || !remoteByName[candidate.remoteName]))
                                note = candidate
                        }
                    }
                    if (!note) {
                        downloads.push({ remote: remote, note: null })
                        continue
                    }
                    if (!note.remoteName)
                        NotesModel.setRemote(note.id, remote.name)
                    if (remote.mtime > note.updatedDate + 2000)
                        downloads.push({ remote: remote, note: note })
                }

                downloadNext(downloads, 0, remoteByName)
            })
        }, 0)
    }

    function errorText(status) {
        if (status === 0)
            return i18n.tr("Network error. Check the server URL and the connection.")
        if (status === 401 || status === 403)
            return i18n.tr("Authentication failed. Check the username and the app password.")
        if (status === 423)
            return i18n.tr("The note or folder is locked on the server (HTTP 423). Close it in Nextcloud (Text/Office or Notes), then synchronise again.")
        if (status === 409)
            return i18n.tr("The destination folder could not be created (HTTP 409).")
        return i18n.tr("Nextcloud error (HTTP %1).").arg(status)
    }
}
