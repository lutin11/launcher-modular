.pragma library

// CalDAV helpers for the Nextcloud calendar page.
//
// Pure functions only (no XMLHttpRequest): the request bodies, the parsing of
// the little iCalendar subset the page needs, and the generation of the .ics
// file sent back on create/update. Keeping them separate makes them testable
// outside QML (see the node harness used during development).

function pad(number) {
    return number < 10 ? "0" + number : "" + number
}

// 20261127T101500Z
function formatUtc(date) {
    return date.getUTCFullYear() + pad(date.getUTCMonth() + 1) + pad(date.getUTCDate())
            + "T" + pad(date.getUTCHours()) + pad(date.getUTCMinutes()) + pad(date.getUTCSeconds()) + "Z"
}

// 20261127
function formatDate(date) {
    return date.getFullYear() + pad(date.getMonth() + 1) + pad(date.getDate())
}

// Parses the three forms found in the calendars of Nextcloud. A local time
// (TZID or floating) is read as the local time of the device: the page shows
// the calendar in the user's timezone.
function parseDate(value) {
    if (!value)
        return null
    var match = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/)
    if (!match)
        return null
    var year = parseInt(match[1]), month = parseInt(match[2]) - 1, day = parseInt(match[3])
    if (match[4] === undefined)
        return new Date(year, month, day)
    var hours = parseInt(match[4]), minutes = parseInt(match[5]), seconds = parseInt(match[6])
    if (match[7] === "Z")
        return new Date(Date.UTC(year, month, day, hours, minutes, seconds))
    return new Date(year, month, day, hours, minutes, seconds)
}

function unescapeText(value) {
    return value.replace(/\\n/gi, "\n")
                .replace(/\\,/g, ",")
                .replace(/\\;/g, ";")
                .replace(/\\\\/g, "\\")
}

function escapeText(value) {
    return String(value || "")
            .replace(/\\/g, "\\\\")
            .replace(/\n/g, "\\n")
            .replace(/,/g, "\\,")
            .replace(/;/g, "\\;")
}

// RFC 5545 line folding is removed before parsing: a long line continues on
// the next one, which starts with a space or a tab.
function unfold(ics) {
    return String(ics).replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "")
}

function propertyValue(lines, name) {
    var prefix = name + ":"
    var withParameters = new RegExp("^" + name + "([;:])")
    for (var index = 0; index < lines.length; index++) {
        if (lines[index].indexOf(prefix) === 0)
            return lines[index].substring(prefix.length)
        if (withParameters.test(lines[index])) {
            var colon = lines[index].indexOf(":")
            if (colon >= 0)
                return lines[index].substring(colon + 1)
        }
    }
    return ""
}

// Returns one object per VEVENT of the calendar data:
//   uid, summary, description, location, start (Date), end (Date), allDay
function parseCalendarData(ics) {
    var lines = unfold(ics).split("\n")
    var events = []
    var current = null
    for (var index = 0; index < lines.length; index++) {
        var line = lines[index]
        if (line === "BEGIN:VEVENT") {
            current = []
        } else if (line === "END:VEVENT") {
            if (current) {
                var start = parseDate(propertyValue(current, "DTSTART"))
                var end = parseDate(propertyValue(current, "DTEND"))
                var duration = propertyValue(current, "DURATION")
                if (start && !end) {
                    // One-hour default, as RFC 5545 recommends when no end and
                    // no duration are given.
                    end = new Date(start.getTime() + 3600000)
                }
                var dtstartLine = ""
                for (var j = 0; j < current.length; j++) {
                    if (current[j].indexOf("DTSTART") === 0) {
                        dtstartLine = current[j]
                        break
                    }
                }
                if (start) {
                    events.push({
                        uid: propertyValue(current, "UID"),
                        summary: unescapeText(propertyValue(current, "SUMMARY")),
                        description: unescapeText(propertyValue(current, "DESCRIPTION")),
                        location: unescapeText(propertyValue(current, "LOCATION")),
                        start: start,
                        end: end,
                        allDay: dtstartLine.indexOf("VALUE=DATE") >= 0 || dtstartLine.indexOf("T") < 0
                    })
                }
                current = null
            }
        } else if (current) {
            current.push(line)
        }
    }
    return events
}

// Builds the .ics file for one event. start and end are Date objects; the
// identifier is kept for an update so that the server sees the same resource.
function buildEventIcs(event) {
    var now = formatUtc(new Date())
    var uid = event.uid && event.uid.length > 0 ? event.uid : (now + "-" + Math.floor(Math.random() * 100000) + "@launchermodular")
    var lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//launchermodular//Nextcloud calendar//EN",
        "BEGIN:VEVENT",
        "UID:" + uid,
        "DTSTAMP:" + now
    ]
    if (event.allDay) {
        lines.push("DTSTART;VALUE=DATE:" + formatDate(event.start))
        lines.push("DTEND;VALUE=DATE:" + formatDate(event.end))
    } else {
        lines.push("DTSTART:" + formatUtc(event.start))
        lines.push("DTEND:" + formatUtc(event.end))
    }
    lines.push("SUMMARY:" + escapeText(event.summary))
    if (event.location)
        lines.push("LOCATION:" + escapeText(event.location))
    if (event.description)
        lines.push("DESCRIPTION:" + escapeText(event.description))
    lines.push("END:VEVENT", "END:VCALENDAR", "")
    return { uid: uid, ics: lines.join("\r\n") }
}

// Request bodies.

function calendarQueryBody(start, end) {
    var range = "<c:time-range start=\"" + formatUtc(start) + "\" end=\"" + formatUtc(end) + "\"/>"
    return "<?xml version=\"1.0\" encoding=\"utf-8\" ?>"
            + "<c:calendar-query xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">"
            + "<d:prop><d:getetag/><c:calendar-data/></d:prop>"
            + "<c:filter><c:comp-filter name=\"VCALENDAR\"><c:comp-filter name=\"VEVENT\">"
            + range
            + "</c:comp-filter></c:comp-filter></c:filter>"
            + "</c:calendar-query>"
}

function calendarListBody() {
    return "<?xml version=\"1.0\" encoding=\"utf-8\" ?>"
            + "<d:propfind xmlns:d=\"DAV:\" xmlns:c=\"urn:ietf:params:xml:ns:caldav\">"
            + "<d:prop><d:displayname/><d:resourcetype/></d:prop>"
            + "</d:propfind>"
}

function decodeXml(value) {
    return String(value)
            .replace(/&#x([0-9a-f]+);/gi, function (match, code) {
                return String.fromCharCode(parseInt(code, 16))
            })
            .replace(/&#(\d+);/g, function (match, code) {
                return String.fromCharCode(parseInt(code, 10))
            })
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"").replace(/&apos;/g, "'")
            .replace(/&amp;/g, "&")
}

// Extracts the calendar collections of a PROPFIND response. href is the path
// returned by the server (absolute), displayName its label.
function parseCalendarList(xmlText) {
    var calendars = []
    var responsePattern = /<([a-z0-9]+:)?response[\s>][\s\S]*?<\/\1response>/gi
    var responses = xmlText.match(responsePattern) || []
    for (var index = 0; index < responses.length; index++) {
        var response = responses[index]
        // A calendar is a collection whose resourcetype holds a calendar
        // element, whatever prefix the server used (<d:calendar>, <cal:calendar>…).
        if (!/<([a-z0-9]+:)?calendar[\s\/>]/i.test(response))
            continue
        var href = (response.match(/<([a-z0-9]+:)?href>([\s\S]*?)<\/\1href>/i) || [])[2] || ""
        var name = (response.match(/<([a-z0-9]+:)?displayname>([\s\S]*?)<\/\1displayname>/i) || [])[2] || ""
        if (!href)
            continue
        try {
            href = decodeURIComponent(href)
        } catch (error) {
            // keep the encoded form
        }
        calendars.push({ href: href, displayName: decodeXml(name) })
    }
    return calendars
}

// Extracts the events of a calendar-query response: the calendar-data blocks,
// with the etag and the path of the resource they belong to.
function parseEventResponses(xmlText) {
    var results = []
    var responsePattern = /<([a-z0-9]+:)?response[\s>][\s\S]*?<\/\1response>/gi
    var responses = xmlText.match(responsePattern) || []
    for (var index = 0; index < responses.length; index++) {
        var response = responses[index]
        var href = (response.match(/<([a-z0-9]+:)?href>([\s\S]*?)<\/\1href>/i) || [])[2] || ""
        var etag = (response.match(/<([a-z0-9]+:)?getetag>([\s\S]*?)<\/\1getetag>/i) || [])[2] || ""
        var data = (response.match(/<([a-z0-9]+:)?calendar-data[^>]*>([\s\S]*?)<\/\1calendar-data>/i) || [])[2] || ""
        if (!data)
            continue
        data = decodeXml(data)
        var events = parseCalendarData(data)
        for (var eventIndex = 0; eventIndex < events.length; eventIndex++) {
            events[eventIndex].href = href
            events[eventIndex].etag = etag
            results.push(events[eventIndex])
        }
    }
    return results
}
