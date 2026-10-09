#!/usr/bin/env python3
"""Generate KamiUI bottom HUD arms in the center ring's understated metal style.

Only the two bottom-left TGA files are produced. The right arm is mirrored by
Minimap.lua, and the manually designed center-ring textures remain untouched.
"""

from pathlib import Path
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "KamiUI" / "textures"
WIDTH, HEIGHT = 768, 208
SCALE = 3  # Supersample curved bevels and round the outer cap.


def curve(start, control1, control2, end, steps=24):
    pts = []
    for step in range(1, steps + 1):
        t = step / steps
        u = 1 - t
        pts.append((
            u**3 * start[0] + 3*u*u*t*control1[0] + 3*u*t*t*control2[0] + t**3*end[0],
            u**3 * start[1] + 3*u*u*t*control1[1] + 3*u*t*t*control2[1] + t**3*end[1],
        ))
    return pts


def outline():
    # Rounded outer cap and a soft, curved transition into the minimap rim.
    points = [(93, 16), (531, 16)]
    points += curve(points[-1], (581, 16), (589, 47), (617, 62))
    points += curve(points[-1], (637, 74), (659, 77), (676, 84))
    points += curve(points[-1], (682, 95), (682, 112), (676, 124))
    points += curve(points[-1], (655, 130), (633, 136), (617, 149))
    points += curve(points[-1], (592, 168), (581, 192), (531, 192))
    points += [(93, 192)]
    points += curve(points[-1], (51, 192), (19, 160), (19, 104))
    points += curve(points[-1], (19, 49), (51, 16), (93, 16))
    return points


def make_mask():
    mask = Image.new("L", (WIDTH*SCALE, HEIGHT*SCALE))
    draw = ImageDraw.Draw(mask)
    draw.polygon([(round(x*SCALE), round(y*SCALE)) for x, y in outline()], fill=255)
    return mask.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)


def erode(mask, size):
    return np.asarray(mask.filter(ImageFilter.MinFilter(size)), dtype=np.int16)


def rgba_layer(red, green, blue, alpha):
    result = np.empty((HEIGHT, WIDTH, 4), dtype=np.uint8)
    for i, channel in enumerate((red, green, blue)):
        result[..., i] = np.asarray(channel, dtype=np.uint8)
    result[..., 3] = np.asarray(alpha, dtype=np.uint8)
    return Image.fromarray(result, "RGBA")


def make_textures():
    shape = make_mask()
    outer = np.array(shape, dtype=np.int16)
    edge4 = erode(shape, 5)
    edge9 = erode(shape, 11)
    edge15 = erode(shape, 17)
    edge24 = erode(shape, 25)
    rim_outer = np.clip(outer - edge4, 0, 255) / 255
    rim_bevel = np.clip(edge4 - edge9, 0, 255) / 255
    rim_bronze = np.clip(edge9 - edge15, 0, 255) / 255
    rim_inner = np.clip(edge15 - edge24, 0, 255) / 255

    yy, xx = np.indices((HEIGHT, WIDTH), dtype=np.float32)
    # Must agree with the BOTTOM dimensions/position in Layout.lua:
    # WIDTH=268, HEIGHT=72, X=-186 (left wing), Y=-29.
    map_x = -320 + (268 / WIDTH)*xx
    map_y = -29 + (HEIGHT/2 - yy)*(72 / HEIGHT)
    radial_distance = np.sqrt(map_x**2 + map_y**2)
    join_fade = np.clip((radial_distance - 98) / 13, 0, 1)
    join_fade = join_fade**2 * (3 - 2*join_fade)

    # Matte warm gunmetal, subtle beveled bronze outlines, no silver tips.
    vertical = (HEIGHT - yy) / HEIGHT
    soft_lighting = 7*np.cos((yy - 47)/HEIGHT*math.pi)
    grain = 1.2*np.sin(xx*.075) + .9*np.sin(xx*.19 + yy*.043)
    shade = soft_lighting + grain + 5*vertical
    red = 24 + shade + 37*rim_outer + 42*rim_bevel + 66*rim_bronze + 19*rim_inner
    green = 26 + shade + 29*rim_outer + 31*rim_bevel + 45*rim_bronze + 17*rim_inner
    blue = 28 + shade + 22*rim_outer + 23*rim_bevel + 29*rim_bronze + 13*rim_inner
    # Opaque charcoal body prevents holes behind unused action buttons.
    base_alpha = np.clip(outer * .97 * join_fade, 0, 255)
    base = rgba_layer(red, green, blue, base_alpha)

    # White alpha-only detailing gets its class tint in Minimap.lua.
    thin_edge = .57*rim_bronze + .18*rim_outer + .16*rim_inner
    strokes = Image.new("L", (WIDTH, HEIGHT), 0)
    d = ImageDraw.Draw(strokes)
    d.line([(112, 32), (497, 32), (525, 35)], fill=110, width=2)
    d.line([(112, 176), (497, 176), (525, 173)], fill=85, width=2)
    d.arc((36, 38, 144, 170), 86, 274, fill=95, width=2)
    for x in (125, 475):
        d.line([(x-10, 31), (x, 35), (x+10, 31)], fill=105, width=2)
    ornament = np.array(strokes, dtype=np.float32) * (edge24 / 255)
    accent_alpha = np.clip((thin_edge * 130 + ornament)*join_fade, 0, 170)
    white = np.full((HEIGHT, WIDTH), 255, dtype=np.uint8)
    accent = rgba_layer(white, white, white, accent_alpha)
    return base, accent


def main():
    TEXTURES.mkdir(parents=True, exist_ok=True)
    base, accent = make_textures()
    for name, image in (("base", base), ("accent", accent)):
        output = TEXTURES / f"artwork_HUD_bottom_left_{name}.tga"
        image.save(output, format="TGA")
        print(f"{output.relative_to(ROOT)}: {WIDTH}x{HEIGHT} RGBA")


if __name__ == "__main__":
    main()
