pragma Singleton
import QtQuick 2.12
import NetworkHelper 1.0
import "CalDav.js" as CalDav

// Events of the Nextcloud calendar chosen by the user.
//
// The page and the Event widget both call configure() with the settings of the
// launcher, then refresh(); the model is shared, so a single request serves
// both views. Requests are plain XMLHttpRequest with Basic authentication,
// like the Nextcloud folders page: no credential is stored anywhere else.
QtObject {
    id: model

    property string baseUrl: ""
    property string user: ""
    property string password: ""
    property string calendarHref: ""
    property string calendarName: ""

    readonly property bool configured: baseUrl.length > 0 && user.length > 0 && password.length > 0
    property bool syncing: false
    // Pending requests, by tag: NetworkHelper answers with the same tag.
    property var callbacks: ({})
    property int requestCounter: 0

    // QML's XMLHttpRequest refuses the REPORT verb ("Unsupported HTTP method
    // type"), so the requests go through NetworkHelper (QNetworkAccessManager).
    property var network: Connections {
        target: NetworkHelper
        onRequestFinished: function (tag, status, body) {
            var callback = model.callbacks[tag]
            if (callback) {
                delete model.callbacks[tag]
                callback(status, body)
            }
        }
    }
    property bool ready: false
    property string lastError: ""

    // uid, etag, href, summary, description, location, start, end (ms), allDay
    property ListModel events: ListModel {}
    // Calendars found on the account: [{href, displayName}]
    property var calendars: []

    signal updated()
    signal calendarSelected(string href, string name)

    function origin() {
        var match = baseUrl.match(/^(https?:\/\/[^\/]+)/)
        return match ? match[1] : ""
    }

    function configure(url, login, secret, href) {
        var changed = baseUrl !== url || user !== login || password !== secret
        baseUrl = url || ""
        user = login || ""
        password = secret || ""
        calendarHref = href || ""
        if (changed) {
            events.clear()
            ready = false
        }
    }

    // extraHeaders is "Name: value" lines separated by \n.
    function request(method, path, body, extraHeaders, callback) {
        requestCounter++
        var tag = method + ":" + requestCounter
        callbacks[tag] = callback
        var headers = "Authorization: Basic " + Qt.btoa(user + ":" + password)
        if (extraHeaders)
            headers += "\n" + extraHeaders
        NetworkHelper.sendRequest(tag, method, origin() + path, body ? body : "", headers)
    }

    // Finds the calendars of the account, then keeps the one already chosen or
    // the first one, and scans it.
    function refresh(daysBack, daysForward) {
        if (!configured || syncing)
            return
        syncing = true
        lastError = ""
        if (calendarHref.length > 0) {
            queryEvents(daysBack, daysForward)
            return
        }
        listCalendars(function (list) {
            if (list.length === 0) {
                syncing = false
                return
            }
            selectCalendar(list[0].href, list[0].displayName)
            queryEvents(daysBack, daysForward)
        })
    }

    // Lists the calendars and keeps them for the settings page.
    function listCalendars(callback) {
        if (!configured) {
            callback([])
            return
        }
        request("PROPFIND", "/remote.php/dav/calendars/" + encodeURIComponent(user) + "/",
                CalDav.calendarListBody(),
                "Depth: 1\nContent-Type: application/xml; charset=utf-8",
                function (status, text) {
                    if (status !== 207 && status !== 200) {
                        lastError = i18n.tr("Cannot list the calendars (HTTP %1)").arg(status)
                        syncing = false
                        callback([])
                        return
                    }
                    calendars = CalDav.parseCalendarList(text)
                    if (calendars.length === 0)
                        lastError = i18n.tr("No calendar found on this account")
                    callback(calendars)
                })
    }

    function selectCalendar(href, name) {
        calendarHref = href
        calendarName = name || ""
        events.clear()
        ready = false
        calendarSelected(href, calendarName)
    }

    function queryEvents(daysBack, daysForward) {
        var start = new Date()
        start.setDate(start.getDate() - (daysBack || 30))
        start.setHours(0, 0, 0, 0)
        var end = new Date()
        end.setDate(end.getDate() + (daysForward || 90))
        end.setHours(23, 59, 59, 0)

        request("REPORT", calendarHref,
                CalDav.calendarQueryBody(start, end),
                "Depth: 1\nContent-Type: application/xml; charset=utf-8",
                function (status, text) {
                    syncing = false
                    if (status !== 207 && status !== 200) {
                        lastError = i18n.tr("Cannot read the calendar (HTTP %1)").arg(status)
                        return
                    }
                    var parsed = CalDav.parseEventResponses(text)
                    fill(parsed)
                })
    }

    function fill(parsed) {
        parsed.sort(function (a, b) { return a.start.getTime() - b.start.getTime() })
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
                allDay: event.allDay
            })
        }
        ready = true
        updated()
    }

    function createEvent(fields, callback) {
        if (!configured || calendarHref.length === 0) {
            callback(false, i18n.tr("The calendar is not configured"))
            return
        }
        var built = CalDav.buildEventIcs(fields)
        var path = calendarHref.replace(/\/$/, "") + "/" + encodeURIComponent(built.uid) + ".ics"
        request("PUT", path, built.ics,
                "Content-Type: text/calendar; charset=utf-8\nIf-None-Match: *",
                function (status) {
                    callback(status === 201 || status === 204, status)
                })
    }

    function updateEvent(index, fields, callback) {
        var event = events.get(index)
        if (!event) {
            callback(false, i18n.tr("Event not found"))
            return
        }
        fields.uid = event.uid
        var built = CalDav.buildEventIcs(fields)
        request("PUT", event.href, built.ics,
                "Content-Type: text/calendar; charset=utf-8\nIf-Match: " + event.etag,
                function (status) {
                    callback(status === 201 || status === 204, status)
                })
    }

    function deleteEvent(index, callback) {
        var event = events.get(index)
        if (!event) {
            callback(false, i18n.tr("Event not found"))
            return
        }
        request("DELETE", event.href, null, "If-Match: " + event.etag,
                function (status) {
                    callback(status === 200 || status === 204, status)
                })
    }

    // Entries for the Event widget: the next events from 'from' (a Date) to
    // 'days' later, sorted. Plain objects so the caller owns its own model.
    function upcoming(days, from) {
        var result = []
        if (!configured || events.count === 0)
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
