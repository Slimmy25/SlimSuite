#!/usr/bin/env python3
"""Turn an in-game screenshot into a Quick setup picture the 1.12 client can show.

The client only reads .tga/.blp textures with power-of-two sizes, so the screenshot is cropped to 2:1
around the given centre, resized to 256x128 and saved as an uncompressed 32-bit TGA.

    python3 tools/quick-image.py screenshot.jpg q1_2            # question 1, answer 2 (RPG look)
    python3 tools/quick-image.py screenshot.jpg preset1 --center 0.5 0.8

Names: q<question>_<answer> for the questions (numbered as in SlimSuiteQuickSetup.lua) and preset<n>
for the presets (numbered as in SlimSuitePresets.lua). Files go to SlimSuite/textures/quick/.
"""
import argparse, os
from PIL import Image

W, H = 256, 128
OUT = os.path.join(os.path.dirname(__file__), "..", "SlimSuite", "textures", "quick")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("screenshot")
    ap.add_argument("name", help="q<question>_<answer> or preset<n>")
    ap.add_argument("--center", nargs=2, type=float, default=(0.5, 0.5),
                    help="centre of the crop as fractions of width and height (default: middle)")
    ap.add_argument("--zoom", type=float, default=1.0, help="above 1 crops tighter around the centre")
    a = ap.parse_args()
    img = Image.open(a.screenshot).convert("RGBA")
    iw, ih = img.size
    cw = min(iw, ih * 2) / a.zoom
    ch = cw / 2
    cx, cy = a.center[0] * iw, a.center[1] * ih
    left = min(max(0, cx - cw / 2), iw - cw)
    top = min(max(0, cy - ch / 2), ih - ch)
    img = img.crop((int(left), int(top), int(left + cw), int(top + ch))).resize((W, H), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, a.name + ".tga")
    img.save(path, compression=None)
    print("saved", os.path.normpath(path))

if __name__ == "__main__":
    main()
