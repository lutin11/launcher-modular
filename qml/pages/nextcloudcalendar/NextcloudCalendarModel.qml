pragma Singleton
import QtQuick 2.12
import NetworkHelper 1.0
import "CalDav.js" as CalDav

// Events of the Nextcloud calendars used by the launcher.
//
// Several accounts are supported: each page can hold its own list of accounts
// (page data), and the events of all of them are merged in one model. Every
// event keeps the index of its account, so updating or deleting it reaches the
// right server.
QtObject {
    id: model

    // {url, user, password, href, name}
    property var accounts: []
    // Calendars of the account last listed (settings page).
    property var calendars: []
    property int calendarsAccount: -1

    property bool syncing: false
    property bool ready: false
    property string lastError: ""

    // uid, etag, href, summary, description, location, start, end, allDay, account
    property ListModel events: ListModel {}

    property var callbacks: ({})
    property int requestCounter: 0
    property var collected: []

    readonly property bool configured: accounts.length > 0

    signal updated()

    property var network: Connections {
        target: NetworkHelper
        function onRequestFinished(tag, status, body) {
            var callback = model.callbacks[tag]
            if (callback) {
                delete model.callbacks[tag]
                callback(status, body)
            }
        }
    }

    function accountAt(index) {
        return (index >= 0 && index < accounts.length) ? accounts[index]
                                                       : ({ url: "", user: "", password: "", href: "", name: "" })
    }

    function configure(url, login, secret, href) {
        configureAccounts([{ url: url, user: login, password: secret, href: href || "", name: "" }])
    }

    function configureAccounts(list) {
        var clean = []
        for (var index = 0; list && index < list.length; index++) {
            var account = list[index]
            if (account && account.url && account.user && account.password)
                clean.push({ url: account.url, user: account.user, password: account.password,
                             href: account.href || "", name: account.name || "" })
        }
        if (JSON.stringify(clean) === JSON.stringify(accounts))
            return
        accounts = clean
        events.clear()
        ready = false
    }

    function setAccountHref(index, href, name) {
        if (index < 0 || index >= accounts.length)
            return
        var copy = accounts.slice()
        var account = copy[index]
        copy[index] = { url: account.url, user: account.user, password: account.password,
                        href: href, name: name || account.name }
        accounts = copy
        calendarSelected(href, name)
    }

    signal calendarSelected(string href, string name)

    function origin(account) {
        var match = account.url.match(/^(https?:\/\/[^\/]+)/)
        return match ? match[1] : ""
    }

    // Nextcloud may be installed under a sub-path, and the user may paste the
    // CalDAV address instead of the server URL. Keep the sub-path, drop the
    // /remote.php/dav… suffix.
    function baseUrl(account) {
        var url = String(account.url || "").replace(/\/+$/, "")
        var dav = url.indexOf("/remote.php/dav")
        if (dav >= 0)
            url = url.substring(0, dav)
        return url
    }

    function request(account, method, path, body, extraHeaders, callback) {
        requestCounter++
        var tag = method + ":" + requestCounter
        callbacks[tag] = callback
        var headers = "Authorization: Basic " + Qt.btoa(account.user + ":" + account.password)
        if (extraHeaders)
            headers += "\n" + extraHeaders
        var target
        if (/^https?:\/\//.test(path))
            target = path
        else if (path.indexOf("/remote.php/") === 0)
            target = baseUrl(account) + path
        else
            target = origin(account) + path
        NetworkHelper.sendRequest(tag, method, target, body ? body : "", headers)
    }

    // Sequential sync: one account after the other, then a single model fill.
    function refresh(daysBack, daysForward) {
        if (accounts.length === 0 || syncing)
            return
        syncing = true
        lastError = ""
        collected = []
        syncAccount(0, daysBack, daysForward)
    }

    function syncAccount(index, daysBack, daysForward) {
        if (index >= accounts.length) {
            fill(collected)
            collected = []
            syncing = false
            return
        }
        var account = accounts[index]
        var next = function () { syncAccount(index + 1, daysBack, daysForward) }

        if (account.href && account.href.length > 0) {
            queryEvents(index, daysBack, daysForward, next)
            return
        }
        request(account, "PROPFIND",
                "/remote.php/dav/calendars/" + encodeURIComponent(account.user) + "/",
                CalDav.calendarListBody(),
                "Depth: 1\nContent-Type: application/xml; charset=utf-8",
                function (status, text) {
                    if (status !== 207 && status !== 200) {
                        lastError = i18n.tr("Cannot list the calendars (HTTP %1)").arg(status)
                        next()
                        return
                    }
                    var list = CalDav.parseCalendarList(text)
                    if (list.length === 0) {
                        lastError = i18n.tr("No calendar found on this account")
                        next()
                        return
                    }
                    setAccountHref(index, list[0].href, list[0].displayName)
                    queryEvents(index, daysBack, daysForward, next)
                })
    }

    function queryEvents(index, daysBack, daysForward, done) {
        var account = accounts[index]
        var start = new Date()
        start.setDate(start.getDate() - (daysBack || 30))
        start.setHours(0, 0, 0, 0)
        var end = new Date()
        end.setDate(end.getDate() + (daysForward || 90))
        end.setHours(23, 59, 59, 0)

        request(account, "REPORT", account.href, CalDav.calendarQueryBody(start, end),
                "Depth: 1\nContent-Type: application/xml; charset=utf-8",
                function (status, text) {
                    if (status === 207 || status === 200) {
                        var parsed = CalDav.parseEventResponses(text)
                        for (var eventIndex = 0; eventIndex < parsed.length; eventIndex++)
                            parsed[eventIndex].account = index
                        collected = collected.concat(parsed)
                    } else if (lastError.length === 0) {
                        lastError = i18n.tr("Cannot read the calendar (HTTP %1)").arg(status)
                    }
                    done()
                })
    }

    function fill(parsed) {
        parsed.sort(function (first, second) { return first.start.getTime() - second.start.getTime() })
        events.clear()
        for (var index = 0; index < parsed.length; index++) {
            var event = parsed[index]
            events.append({
                uid: event.uid,
                etag: event.etag,
                href: event.href,
                summary: event.summary,
                description: event.description,
                location: event.location,
                start: event.start.getTime(),
                end: event.end.getTime(),
                allDay: event.allDay,
                account: event.account
            })
        }
        ready = true
        updated()
    }

    // Lists the calendars of one account (settings page).
    function listCalendars(index, callback) {
        listCalendarsOf(accountAt(index), callback)
    }

    // The settings page holds one entry per Nextcloud account (with a list of
    // selected calendars), while the model works with one entry per calendar:
    // it therefore passes the account object itself, not an index.
    function listCalendarsOf(account, callback) {
        if (!account || !account.url) {
            callback([])
            return
        }
        request(account, "PROPFIND",
                "/remote.php/dav/calendars/" + encodeURIComponent(account.user) + "/",
                CalDav.calendarListBody(),
                "Depth: 1\nContent-Type: application/xml; charset=utf-8",
                function (status, text) {
                    if (status !== 207 && status !== 200) {
                        lastError = i18n.tr("Cannot list the calendars (HTTP %1)").arg(status)
                        callback([])
                        return
                    }
                    calendars = CalDav.parseCalendarList(text)
                    callback(calendars)
                })
    }

    function createEvent(fields, callback) {
        createEventIn(0, fields, callback)
    }

    function createEventIn(index, fields, callback) {
        var account = accountAt(index)
        if (!account.url || !account.href) {
            callback(false, -1)
            return
        }
        var built = CalDav.buildEventIcs(fields)
        var path = account.href.replace(/\/$/, "") + "/" + encodeURIComponent(built.uid) + ".ics"
        request(account, "PUT", path, built.ics,
                "Content-Type: text/calendar; charset=utf-8\nIf-None-Match: *",
                function (status) { callback(status === 201 || status === 204, status) })
    }

    function updateEvent(index, fields, callback) {
        var event = events.get(index)
        if (!event) {
            callback(false, -1)
            return
        }
        fields.uid = event.uid
        var built = CalDav.buildEventIcs(fields)
        request(accountAt(event.account), "PUT", event.href, built.ics,
                "Content-Type: text/calendar; charset=utf-8\nIf-Match: " + event.etag,
                function (status) { callback(status === 201 || status === 204, status) })
    }

    function deleteEvent(index, callback) {
        var event = events.get(index)
        if (!event) {
            callback(false, -1)
            return
        }
        request(accountAt(event.account), "DELETE", event.href, null,
                "If-Match: " + event.etag,
                function (status) { callback(status === 200 || status === 204, status) })
    }

    // Entries for the Event widget, sorted, from 'from' (a Date) to 'days'.
    function upcoming(days, from) {
        var result = []
        if (accounts.length === 0 || events.count === 0)
            return result
        var limit = from.getTime() + days * 86400000
        for (var index = 0; index < events.count; index++) {
            var event = events.get(index)
            if (event.start < from.getTime() || event.start > limit)
                continue
            result.push({
                summary: event.summary,
                description: event.description,
                location: event.location,
                start: event.start,
                end: event.end,
                allDay: event.allDay
            })
        }
        return result
    }
}
