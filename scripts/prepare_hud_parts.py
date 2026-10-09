#!/usr/bin/env python3
"""Regenerate only the left lower HUD arm from the original artwork.

The manually edited center and upper unit-frame textures are intentionally
untouched. WoW Forever accepts non-power-of-two 32-bit TGA textures, so keep
the natural crop and the exact source-to-screen aspect ratio.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "KamiUI" / "textures"
WIDTH, HEIGHT = 1916, 821
CENTER_X, CENTER_Y = 958, 446
RADIUS = 232
SPLIT_Y = 384

# Tight crop around the bottom-left arm, including a small overlap with the
# center ring. Use the SAME pixel-to-UI scale as the 512px center asset.
# This is deliberately not a power-of-two size.
BOTTOM_CROP = (128, 416, 984, 612)  # original 856x196 crop
# Shorten the long straight middle of the arm, preserving its tapered end
# and the carefully shaped connector to the center ring.
TRIM_START_X = 380
TRIM_END_X = 500       # removes 120px; output is 736x196



def interior_masks():
    # Straight, transparent interior for unitframes. The beveled outline
    # remains in the original source; no artificial pill-shaped cutouts.
    top = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(top).rectangle((446, 172, 811, 249), fill=255)

    # Actionbars are below the art and need a quiet fill for empty slots.
    bottom = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(bottom).rectangle((177, 462, 705, 551), fill=255)
    return np.array(top, dtype=np.uint8), np.array(bottom, dtype=np.uint8)


def base_pixels():
    source = Image.open(TEXTURES / "artwork_HUD_thin.png").convert("RGBA")
    if source.size != (WIDTH, HEIGHT):
        raise ValueError(f"Unexpected base dimensions: {source.size}")
    pixels = np.array(source)
    top, bottom = interior_masks()
    pixels[top > 0, 3] = 0
    # Keep the original opaque charcoal fill of the lower panel.
    # The previous alpha cap (51) produced a rectangular see-through hole
    # instead of a background behind empty action buttons.

    y, x = np.indices((HEIGHT, WIDTH))
    top_cap = ((x - 475) / 53.0) ** 2 + ((y - 204) / 65.0) ** 2 <= 1
    bottom_cap = ((x - 208) / 62.0) ** 2 + ((y - 501) / 72.0) ** 2 <= 1
    pixels[(x < 474) & ~top_cap & (y < 290), 3] = 0
    pixels[(x < 207) & ~bottom_cap & (y >= SPLIT_Y), 3] = 0

    pixels[pixels[:, :, 3] < 14] = 0
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return pixels


def accent_pixels(base):
    source = Image.open(TEXTURES / "artwork_HUD_thin_accent.png").convert(
        "RGBA"
    )
    if source.size != (WIDTH, HEIGHT):
        raise ValueError(f"Unexpected accent dimensions: {source.size}")

    pixels = np.array(source)
    pixels[:, :, 3] = np.clip(
        pixels[:, :, 3].astype(np.float32) * 1.85, 0, 255
    ).astype(np.uint8)
    pixels[:, :, :3] = 255

    detail = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(detail)
    for x, y in (
        (484, 155), (778, 158),
        (202, 448), (665, 448),
        (738, 267), (684, 553),
    ):
        draw.line(
            ((x - 13, y), (x, y - 5), (x + 13, y),
             (x, y + 5), (x - 13, y)),
            fill=(255, 255, 255, 100), width=3, joint="curve"
        )
        draw.line(
            ((x - 5, y), (x + 5, y)),
            fill=(255, 255, 255, 195), width=3
        )
    for points in (
        [(503, 160), (578, 161), (651, 161), (724, 161)],
        [(226, 449), (313, 448), (405, 448), (504, 448), (608, 447)],
        [(473, 248), (544, 251), (645, 250)],
        [(214, 555), (321, 557), (446, 557), (561, 554)],
    ):
        draw.line(points, fill=(255, 255, 255, 100), width=2)

    pixels = np.array(
        Image.alpha_composite(Image.fromarray(pixels, "RGBA"), detail)
    )
    top, bottom = interior_masks()
    pixels[(top > 0) | (bottom > 0), 3] = 0

    # The accent is confined to the actual outline, not a rectangular
    # crop boundary. An inset metal-edge highlight continues around the
    # natural curves without adding a vertical line at the join.
    metal = Image.fromarray(
        ((base[:, :, 3] > 125) * 255).astype(np.uint8), "L"
    )
    from PIL import ImageFilter
    eroded = metal.filter(ImageFilter.MinFilter(5))
    contour = np.maximum(
        0,
        np.array(metal, dtype=np.int16)
        - np.array(eroded, dtype=np.int16)
    )
    edge = np.clip(contour * 0.15, 0, 255).astype(np.uint8)
    pixels[:, :, 3] = np.maximum(pixels[:, :, 3], edge)
    pixels[(top > 0) | (bottom > 0), 3] = 0
    pixels[base[:, :, 3] == 0, 3] = 0
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return pixels


def shorten_straight_section(sprite):
    """Remove excess length from the flat section, not the beveled ends."""
    start = TRIM_START_X - BOTTOM_CROP[0]
    end = TRIM_END_X - BOTTOM_CROP[0]
    removed = end - start
    result = np.concatenate((sprite[:, :start], sprite[:, end:]), axis=1)

    # Feather the seam inside the flat metal panel. Both source regions
    # have parallel top/bottom edges, so the outer silhouette stays crisp.
    blend_half_width = 16
    for x in range(start - blend_half_width, start + blend_half_width):
        t = (x - start + blend_half_width) / (2 * blend_half_width - 1)
        a = sprite[:, x].astype(np.float32)
        b = sprite[:, x + removed].astype(np.float32)
        result[:, x] = np.clip(a * (1 - t) + b * t, 0, 255).astype(np.uint8)

    return result


def main():
    base = base_pixels()
    accent = accent_pixels(base)

    # Put the lower bar ABOVE the ring and feather its connector into the
    # existing ring border. Keep the inner map opening unobstructed.
    y, x = np.indices((HEIGHT, WIDTH))
    distance = np.sqrt((x - CENTER_X) ** 2 + (y - CENTER_Y) ** 2)
    overlap_alpha = np.clip((distance - (RADIUS - 24)) / 20.0, 0, 1)
    region = (x < CENTER_X + 28) & (y >= SPLIT_Y)
    x0, y0, x1, y1 = BOTTOM_CROP

    for kind, pixels in (("base", base), ("accent", accent)):
        sprite = pixels[y0:y1, x0:x1].copy()
        sprite[~region[y0:y1, x0:x1]] = 0
        sprite[:, :, 3] = (
            sprite[:, :, 3].astype(np.float32)
            * overlap_alpha[y0:y1, x0:x1]
        ).astype(np.uint8)
        sprite = shorten_straight_section(sprite)

        output = TEXTURES / f"artwork_HUD_bottom_left_{kind}.tga"
        Image.fromarray(sprite, "RGBA").save(output, format="TGA")
        print(f"{output.relative_to(ROOT)}: {sprite.shape[1]}x{sprite.shape[0]} RGBA")

if __name__ == "__main__":
    main()
