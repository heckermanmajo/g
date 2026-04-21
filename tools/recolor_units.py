#!/usr/bin/env python3
"""Erzeugt purple/ aus red/ und green/ aus blue/ durch Hue-Shift.

Graue/schwarze Pixel (niedrige Sättigung) bleiben unverändert — nur die
farbigen Team-Pixel werden verschoben. Ausgelegt für die Unit-Sprites
in res/units/{tank,inf,art,truck}/{red,blue}/.
"""
import colorsys
import os
import sys
from PIL import Image

RES_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "res", "units")
CATEGORIES = ["tank", "inf", "art", "truck"]

# Nur Pixel mit genug Sättigung werden verschoben — so bleiben Ketten/Outlines grau/schwarz.
SAT_THRESHOLD = 0.15


def shift_hue(img: Image.Image, delta_deg: float) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    delta = delta_deg / 360.0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if ss < SAT_THRESHOLD:
                continue
            hh = (hh + delta) % 1.0
            nr, ng, nb = colorsys.hsv_to_rgb(hh, ss, vv)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return img


def convert_folder(src_dir: str, dst_dir: str, delta_deg: float) -> int:
    os.makedirs(dst_dir, exist_ok=True)
    count = 0
    for name in os.listdir(src_dir):
        if not name.lower().endswith(".png"):
            continue
        src = os.path.join(src_dir, name)
        dst = os.path.join(dst_dir, name)
        shift_hue(Image.open(src), delta_deg).save(dst)
        count += 1
    return count


def main() -> None:
    total = 0
    for cat in CATEGORIES:
        red_dir = os.path.join(RES_ROOT, cat, "red")
        blue_dir = os.path.join(RES_ROOT, cat, "blue")
        purple_dir = os.path.join(RES_ROOT, cat, "purple")
        green_dir = os.path.join(RES_ROOT, cat, "green")
        if os.path.isdir(red_dir):
            n = convert_folder(red_dir, purple_dir, 280.0)
            print(f"{cat}/red -> purple: {n}")
            total += n
        if os.path.isdir(blue_dir):
            n = convert_folder(blue_dir, green_dir, -90.0)
            print(f"{cat}/blue -> green: {n}")
            total += n
    print(f"Gesamt: {total} Dateien")


if __name__ == "__main__":
    sys.exit(main())
