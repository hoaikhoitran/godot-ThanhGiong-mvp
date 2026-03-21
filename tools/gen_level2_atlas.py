#!/usr/bin/env python3
"""Generate a simple 32x32-grid tile atlas PNG for Level 2 (no external deps)."""
import struct
import zlib
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "Assets", "level2", "village_atlas.png")

# 8x8 tiles of 32x32 = 256x256
TILE = 32
COLS = 8
ROWS = 8
W = COLS * TILE
H = ROWS * TILE


def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png_rgba(path: str, width: int, height: int, rgba: bytes) -> None:
    assert len(rgba) == width * height * 4
    raw_rows = b""
    for y in range(height):
        raw_rows += b"\x00" + rgba[y * width * 4 : (y + 1) * width * 4]
    compressed = zlib.compress(raw_rows, 9)
    # Color type 6 = RGBA (type 2 is RGB only; mismatch caused corrupt PNGs in Godot).
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += _chunk(b"IHDR", ihdr)
    png += _chunk(b"IDAT", compressed)
    png += _chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def fill_rect(buf: bytearray, w: int, x0: int, y0: int, x1: int, y1: int, r: int, g: int, b: int, a: int = 255) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            i = (y * w + x) * 4
            buf[i : i + 4] = bytes([r, g, b, a])


def main() -> None:
    buf = bytearray(W * H * 4)
    # Default: medium grass
    fill_rect(buf, W, 0, 0, W, H, 58, 120, 62)

    def tile_xy(tx: int, ty: int) -> tuple[int, int, int, int]:
        return tx * TILE, ty * TILE, (tx + 1) * TILE, (ty + 1) * TILE

    # Row 0: grass variants, dirt path, water, mud
    palettes = [
        (tx, ty, r, g, b)
        for tx, ty, r, g, b in [
            (0, 0, 52, 110, 56),
            (1, 0, 64, 130, 68),
            (2, 0, 78, 140, 82),
            (3, 0, 120, 95, 55),  # dirt
            (4, 0, 105, 82, 48),
            (5, 0, 40, 90, 140),  # water (collide)
            (6, 0, 55, 100, 150),
            (7, 0, 30, 70, 120),  # deep water
            (0, 1, 90, 75, 50),  # mud / paddy edge
            (1, 1, 70, 120, 70),
            (2, 1, 45, 100, 50),
            (3, 1, 130, 120, 70),  # sand path
            (4, 1, 95, 85, 60),
            (5, 1, 35, 80, 40),  # dark grass / bamboo floor
            (6, 1, 25, 70, 35),
            (7, 1, 20, 55, 28),  # forest floor
        ]
    ]
    for tx, ty, r, g, b in palettes:
        x0, y0, x1, y1 = tile_xy(tx, ty)
        fill_rect(buf, W, x0, y0, x1, y1, r, g, b)

    # Decorative tiles (row 2+): simple house roof, fence, bamboo stalks
    for tx in range(8):
        x0, y0, x1, y1 = tile_xy(tx, 2)
        fill_rect(buf, W, x0, y0, x1, y1, 80 + tx * 5, 55, 40)  # roof-ish

    # House body row 3
    for tx in range(4):
        x0, y0, x1, y1 = tile_xy(tx, 3)
        fill_rect(buf, W, x0, y0, x1, y1, 140, 110, 85)
    for tx in range(4, 8):
        x0, y0, x1, y1 = tile_xy(tx, 3)
        fill_rect(buf, W, x0, y0, x1, y1, 90, 70, 55)

    # Fence / bamboo row 4
    for tx in range(8):
        x0, y0, x1, y1 = tile_xy(tx, 4)
        fill_rect(buf, W, x0, y0, x1, y1, 60 + tx * 3, 45, 30)

    # Rice paddy stripes row 5
    for tx in range(8):
        x0, y0, x1, y1 = tile_xy(tx, 5)
        c = 50 + (tx % 2) * 25
        fill_rect(buf, W, x0, y0, x1, y1, c, 110 + tx, 70)

    # Empty / sky gradient row 6-7 for parallax reuse
    for ty in (6, 7):
        for tx in range(8):
            x0, y0, x1, y1 = tile_xy(tx, ty)
            fill_rect(buf, W, x0, y0, x1, y1, 120 + tx * 8, 170 + ty * 5, 210)

    out = os.path.normpath(OUT)
    write_png_rgba(out, W, H, bytes(buf))
    print("Wrote", out, W, H)


if __name__ == "__main__":
    main()
