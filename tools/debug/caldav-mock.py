#!/usr/bin/env python3
"""Minimal CalDAV server used to test the Nextcloud calendar page.

Not a real server: enough answers for the PROPFIND / REPORT / PUT / DELETE
sequence of the application, and a log of every request on stdout.

    python3 tools/debug/caldav-mock.py 8080
    # settings: nextcloudUrl=http://127.0.0.1:8080, user=user, password=pass

The QML of a running app is cached: restart the application after a change.
"""
import base64
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

CALENDARS = """<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>/remote.php/dav/calendars/user/</d:href>
    <d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/calendars/user/personal/</d:href>
    <d:propstat><d:prop>
      <d:displayname>Personnel</d:displayname>
      <d:resourcetype><d:collection/><cal:calendar/></d:resourcetype>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>"""

EVENT = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//mock//caldav//EN
BEGIN:VEVENT
UID:mock-event-1
DTSTART:20261127T140000Z
DTEND:20261127T150000Z
SUMMARY:Réunion de test
LOCATION:Bureau
DESCRIPTION:Événement servi par le serveur CalDAV de test.
END:VEVENT
END:VCALENDAR
"""

EVENTS = """<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>/remote.php/dav/calendars/user/personal/mock-event-1.ics</d:href>
    <d:propstat><d:prop>
      <d:getetag>\"etag-1\"</d:getetag>
      <cal:calendar-data>%s</cal:calendar-data>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>""" % EVENT.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# Resources written by the application: path -> iCalendar body. Served back in
# the REPORT answer so that a PUT/DELETE round trip can be checked.
STORE = {}


def stored_events_xml():
    parts = []
    for path, body in sorted(STORE.items()):
        escaped = body.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        parts.append("""  <d:response>
    <d:href>%s</d:href>
    <d:propstat><d:prop>
      <d:getetag>\"stored-%s\"</d:getetag>
      <cal:calendar-data>%s</cal:calendar-data>
    </d:prop></d:propstat>
  </d:response>""" % (path, abs(hash(path)), escaped))
    return "".join(parts)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("%s - %s" % (self.command, fmt % args), flush=True)

    def _auth(self):
        header = self.headers.get("Authorization", "")
        ok = header.startswith("Basic ")
        if ok:
            try:
                print("  auth:", base64.b64decode(header[6:]).decode(), flush=True)
            except Exception:
                pass
        return ok

    def _send(self, status, body=b"", content_type="application/xml; charset=utf-8"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_PROPFIND(self):
        print("PROPFIND", self.path, "depth=", self.headers.get("Depth"), flush=True)
        if not self._auth():
            self._send(401)
            return
        self._send(207, CALENDARS.encode())

    def do_REPORT(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode(errors="replace")
        print("REPORT", self.path, "body:", " ".join(body.split())[:200], flush=True)
        if not self._auth():
            self._send(401)
            return
        body = EVENTS.replace("</d:multistatus>", stored_events_xml() + "</d:multistatus>")
        self._send(207, body.encode())

    def do_PUT(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length).decode(errors="replace")
        print("PUT", self.path, "if-none-match=", self.headers.get("If-None-Match"),
              "if-match=", self.headers.get("If-Match"), flush=True)
        print("  body:", " ".join(body.split())[:300], flush=True)
        if not self._auth():
            self._send(401)
            return
        STORE[self.path] = body
        self._send(201)

    def do_DELETE(self):
        print("DELETE", self.path, "if-match=", self.headers.get("If-Match"), flush=True)
        if not self._auth():
            self._send(401)
            return
        STORE.pop(self.path, None)
        self._send(204)


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    HTTPServer(("127.0.0.1", port), Handler).serve_forever()
