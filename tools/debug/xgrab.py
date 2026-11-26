#!/usr/bin/env python3
"""Capture an X11 window by id to a PNG via XGetImage (ctypes, no python-xlib)."""
import ctypes, ctypes.util, struct, sys, zlib, os

wid = int(sys.argv[1], 0) if len(sys.argv) > 1 else int(os.environ.get("WIN_ID", "0"), 0)
out = sys.argv[2] if len(sys.argv) > 2 else "/home/david/tmp/opencode/win.png"

x11 = ctypes.CDLL(ctypes.util.find_library("X11"))
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
dpy = x11.XOpenDisplay(None)
if not dpy:
    sys.exit("cannot open display")

class XWindowAttributes(ctypes.Structure):
    _fields_ = [("x", ctypes.c_int), ("y", ctypes.c_int),
                ("width", ctypes.c_int), ("height", ctypes.c_int),
                ("border_width", ctypes.c_int), ("depth", ctypes.c_int),
                ("visual", ctypes.c_void_p), ("root", ctypes.c_ulong),
                ("class", ctypes.c_int), ("bit_gravity", ctypes.c_int),
                ("win_gravity", ctypes.c_int), ("backing_store", ctypes.c_int),
                ("backing_planes", ctypes.c_ulong), ("backing_pixel", ctypes.c_ulong),
                ("save_under", ctypes.c_int), ("colormap", ctypes.c_ulong),
                ("map_installed", ctypes.c_int), ("map_state", ctypes.c_int),
                ("all_event_masks", ctypes.c_long), ("your_event_mask", ctypes.c_long),
                ("do_not_propagate_mask", ctypes.c_short),
                ("override_redirect", ctypes.c_int), ("pad", ctypes.c_int)]

class XImage(ctypes.Structure):
    _fields_ = [("width", ctypes.c_int), ("height", ctypes.c_int),
                ("xoffset", ctypes.c_int), ("format", ctypes.c_int),
                ("data", ctypes.c_char_p), ("byte_order", ctypes.c_int),
                ("bitmap_unit", ctypes.c_int), ("bitmap_bit_order", ctypes.c_int),
                ("bitmap_pad", ctypes.c_int), ("depth", ctypes.c_int),
                ("bytes_per_line", ctypes.c_int), ("bits_per_pixel", ctypes.c_int),
                ("red_mask", ctypes.c_ulong), ("green_mask", ctypes.c_ulong),
                ("blue_mask", ctypes.c_ulong)]

attr = XWindowAttributes()
x11.XGetWindowAttributes.restype = ctypes.c_int
x11.XGetWindowAttributes.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(XWindowAttributes)]
x11.XDestroyImage.argtypes = [ctypes.POINTER(XImage)]
if not x11.XGetWindowAttributes(dpy, ctypes.c_ulong(wid), ctypes.byref(attr)):
    sys.exit("XGetWindowAttributes failed")
print(f"window 0x{wid:x} {attr.width}x{attr.height} map_state={attr.map_state} depth={attr.depth}")
if attr.map_state != 2:
    print("WARNING: window not mapped (map_state != 2)")

x11.XGetImage.restype = ctypes.POINTER(XImage)
x11.XGetImage.argtypes = [ctypes.c_void_p, ctypes.c_ulong,
                          ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint,
                          ctypes.c_ulong, ctypes.c_int]
ZPixmap = 2
img = x11.XGetImage(dpy, ctypes.c_ulong(wid), 0, 0,
                    attr.width, attr.height, ~0, ZPixmap)
if not img:
    sys.exit("XGetImage failed")
im = img.contents
print(f"image {im.width}x{im.height} bpp={im.bits_per_pixel} bpl={im.bytes_per_line} "
      f"masks={im.red_mask:#x},{im.green_mask:#x},{im.blue_mask:#x}")
buf = ctypes.string_at(im.data, im.bytes_per_line * im.height)

# convert to RGB (BGRA assumed for 32bpp with standard masks)
rs, gs, bs = 16, 8, 0  # derived from masks below
def shift(mask):
    s = 0
    while mask and not (mask & 1):
        mask >>= 1; s += 1
    return s
rs, gs, bs = shift(im.red_mask), shift(im.green_mask), shift(im.blue_mask)
raw = bytearray()
bpl = im.bytes_per_line
for y in range(im.height):
    row = buf[y*bpl:(y+1)*bpl]
    for x in range(im.width):
        v = struct.unpack_from("<I", row, x*4)[0] if im.byte_order == 0 else struct.unpack_from(">I", row, x*4)[0]
        raw += bytes(((v & im.red_mask) >> rs, (v & im.green_mask) >> gs, (v & im.blue_mask) >> bs))

def chunk(tag, data):
    c = struct.pack(">I", len(data)) + tag + data
    return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

w, h = im.width, im.height
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
scanlines = b"".join(b"\x00" + bytes(raw[y*w*3:(y+1)*w*3]) for y in range(h))
png += chunk(b"IDAT", zlib.compress(scanlines, 6))
png += chunk(b"IEND", b"")
open(out, "wb").write(png)
print("saved", out)
