#!/usr/bin/env python3
"""XTEST helpers for the launchermodular window (no argtypes: pass explicit ctypes values)."""
import ctypes, ctypes.util, os, sys, time

WID = int(os.environ.get("WIN_ID", "0x2000016"), 0)
x11 = ctypes.CDLL(ctypes.util.find_library("X11"))
xtst = ctypes.CDLL(ctypes.util.find_library("Xtst"))
x11.XOpenDisplay.restype = ctypes.c_void_p
_d = x11.XOpenDisplay(None)
if not _d:
    sys.exit("no display")
DPY = ctypes.c_void_p(_d)
C = ctypes


def _root():
    return x11.XDefaultRootWindow(DPY) & 0xFFFFFFFF


def origin():
    rx, ry = C.c_int(0), C.c_int(0)
    child = C.c_ulong(0)
    x11.XTranslateCoordinates(DPY, C.c_ulong(WID), C.c_ulong(_root()),
                              C.c_int(0), C.c_int(0), C.byref(rx), C.byref(ry), C.byref(child))
    return rx.value, ry.value


OX, OY = origin()


# --- XSendEvent-based synthetic input (XTEST is not honored under Xwayland) ---
class XBtn(C.Structure):
    _fields_ = [("type", C.c_int), ("_p0", C.c_int), ("serial", C.c_ulong),
                ("send_event", C.c_int), ("_p1", C.c_int), ("display", C.c_void_p),
                ("window", C.c_ulong), ("root", C.c_ulong), ("subwindow", C.c_ulong),
                ("time", C.c_ulong), ("x", C.c_int), ("y", C.c_int),
                ("x_root", C.c_int), ("y_root", C.c_int),
                ("state", C.c_uint), ("button", C.c_uint), ("same_screen", C.c_int),
                ("_pad", C.c_char * (96 - 88))]

class XMotion(C.Structure):
    _fields_ = [("type", C.c_int), ("_p0", C.c_int), ("serial", C.c_ulong),
                ("send_event", C.c_int), ("_p1", C.c_int), ("display", C.c_void_p),
                ("window", C.c_ulong), ("root", C.c_ulong), ("subwindow", C.c_ulong),
                ("time", C.c_ulong), ("x", C.c_int), ("y", C.c_int),
                ("x_root", C.c_int), ("y_root", C.c_int),
                ("state", C.c_uint), ("is_visible", C.c_int),
                ("_pad", C.c_char * (96 - 88))]

KEY = 0x200  # 2^9? no: ButtonPressMask=2^4? See below
ButtonMotionMask = 1 << 3
ButtonPressMask = 1 << 4
ButtonReleaseMask = 1 << 5
STRUCTURE_NOTIFY = 22
ENTER_NOTIFY = 9


def _win_root():
    rx, ry = C.c_int(0), C.c_int(0)
    child = C.c_ulong(0)
    x11.XTranslateCoordinates(DPY, C.c_ulong(WID), C.c_ulong(_root()),
                              C.c_int(0), C.c_int(0), C.byref(rx), C.byref(ry), C.byref(child))
    return rx.value, ry.value


def _send(evt, mask):
    x11.XSendEvent(DPY, C.c_ulong(WID), C.c_int(False), C.c_long(mask), C.byref(evt))
    xtst.XFlush(DPY)


def s_motion(x, y, state=0):
    m = XMotion()
    m.type = 6  # MotionNotify
    m.send_event = 1
    m.display = _d
    m.window = WID
    m.root = _root()
    m.subwindow = 0
    m.time = 0
    m.x, m.y = x, y
    rx, ry = _win_root()
    m.x_root, m.y_root = rx + x, ry + y
    m.state = state
    m.is_visible = 1
    _send(m, ButtonMotionMask)


def s_press(x, y, button=1):
    e = XBtn()
    e.type = STRUCTURE_NOTIFY  # placeholder fixed below
    e.type = 4  # ButtonPress
    e.send_event = 1
    e.display = _d
    e.window = WID
    e.root = _root()
    m_time = 0
    e.time = m_time
    e.x, e.y = x, y
    rx, ry = _win_root()
    e.x_root, e.y_root = rx + x, ry + y
    e.state = 0x100 if button == 1 else 0
    e.button = button
    e.same_screen = 1
    _send(e, ButtonPressMask)


def s_release(x, y, button=1):
    e = XBtn()
    e.type = 5  # ButtonRelease
    e.send_event = 1
    e.display = _d
    e.window = WID
    e.root = _root()
    e.time = 0
    e.x, e.y = x, y
    rx, ry = _win_root()
    e.x_root, e.y_root = rx + x, ry + y
    e.state = 0
    e.button = button
    e.same_screen = 1
    _send(e, ButtonReleaseMask)


def sclick(x, y, pause=0.4):
    s_motion(x, y)
    s_press(x, y)
    time.sleep(0.08)
    s_release(x, y)
    time.sleep(pause)


def sdrag(x1, y1, x2, y2, steps=20, pause=0.6):
    s_motion(x1, y1)
    s_press(x1, y1)
    for i in range(1, steps + 1):
        s_motion(x1 + (x2 - x1) * i // steps, y1 + (y2 - y1) * i // steps, state=0x100)
        time.sleep(0.02)
    s_release(x2, y2)
    time.sleep(pause)


def move(x, y):
    xtst.XTestFakeMotionEvent(DPY, C.c_int(-1), C.c_int(OX + x), C.c_int(OY + y), C.c_ulong(0))
    xtst.XFlush(DPY)


def click(x, y, pause=0.35):
    move(x, y); time.sleep(0.1)
    xtst.XTestFakeButtonEvent(DPY, C.c_uint(1), C.c_int(True), C.c_ulong(0)); xtst.XFlush(DPY)
    time.sleep(0.08)
    xtst.XTestFakeButtonEvent(DPY, C.c_uint(1), C.c_int(False), C.c_ulong(0)); xtst.XFlush(DPY)
    time.sleep(pause)


def drag(x1, y1, x2, y2, steps=25, hold=0.05, pause=0.5):
    move(x1, y1); time.sleep(0.15)
    xtst.XTestFakeButtonEvent(DPY, C.c_uint(1), C.c_int(True), C.c_ulong(0)); xtst.XFlush(DPY)
    time.sleep(hold)
    for i in range(1, steps + 1):
        move(x1 + (x2 - x1) * i // steps, y1 + (y2 - y1) * i // steps)
        xtst.XFlush(DPY)
        time.sleep(0.012)
    xtst.XTestFakeButtonEvent(DPY, C.c_uint(1), C.c_int(False), C.c_ulong(0)); xtst.XFlush(DPY)
    time.sleep(pause)


def resize(w, h):
    x11.XResizeWindow(DPY, C.c_ulong(WID), C.c_uint(w), C.c_uint(h))
    x11.XSync(DPY, C.c_int(False))
    time.sleep(0.6)


def size():
    rroot = C.c_ulong(0)
    dx, dy = C.c_int(0), C.c_int(0)
    w, h, bw, d = C.c_uint(0), C.c_uint(0), C.c_uint(0), C.c_uint(0)
    x11.XGetGeometry(DPY, C.c_ulong(WID), C.byref(rroot), C.byref(dx), C.byref(dy),
                     C.byref(w), C.byref(h), C.byref(bw), C.byref(d))
    return w.value, h.value


if __name__ == "__main__":
    cmd = sys.argv[1]
    print(f"origin=({OX},{OY})", flush=True)
    if cmd == "click":
        click(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "sclick":
        sclick(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "sdrag":
        sdrag(*[int(v) for v in sys.argv[2:6]])
    elif cmd == "drag":
        drag(*[int(v) for v in sys.argv[2:6]])
    elif cmd == "resize":
        resize(int(sys.argv[2]), int(sys.argv[3]))
    print("size=", size(), flush=True)
