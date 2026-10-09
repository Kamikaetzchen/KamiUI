#!/usr/bin/env python3
"""Generate mirrored power-of-two HUD textures from the original artwork.

The center holds ONLY the ring; the top arms belong to the unit frames.
Panel interiors have 0 alpha. The source PNGs are intentionally preserved.
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

CROPS = {
    "center": (702, 190, 1214, 702),       # 512x512
    "top_left": (384, 128, 896, 384),     # 512x256
    "bottom_left": (64, 384, 1088, 640),  # 1024x256
}


def interior_mask():
    holes = Image.new("L", (WIDTH, HEIGHT), 0)
    draw = ImageDraw.Draw(holes)
    # Leave the beveled metallic perimeter, remove the solid inner fill.
    draw.rounded_rectangle((444, 169, 818, 252), radius=37, fill=255)
    draw.rounded_rectangle((168, 457, 712, 559), radius=48, fill=255)
    return np.array(holes, dtype=np.uint8)


def base_pixels():
    source = Image.open(TEXTURES / "artwork_HUD_thin.png").convert("RGBA")
    if source.size != (WIDTH, HEIGHT):
        raise ValueError(f"Unexpected base dimensions: {source.size}")
    pixels = np.array(source)
    holes = interior_mask()
    pixels[:, :, 3] = np.minimum(pixels[:, :, 3], 255 - holes)

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
    pixels[interior_mask() > 0, 3] = 0
    pixels[base[:, :, 3] == 0, 3] = 0
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return pixels


def main():
    base = base_pixels()
    accent = accent_pixels(base)
    y, x = np.indices((HEIGHT, WIDTH))
    center = (x - CENTER_X) ** 2 + (y - CENTER_Y) ** 2 <= RADIUS ** 2
    regions = {
        "center": center,
        "top_left": (x < CENTER_X) & ~center & (y < SPLIT_Y),
        "bottom_left": (x < CENTER_X) & ~center & (y >= SPLIT_Y),
    }

    for kind, pixels in (("base", base), ("accent", accent)):
        for section, (x0, y0, x1, y1) in CROPS.items():
            region = regions[section]
            if section == "center":
                mirror_x = np.where(
                    x < CENTER_X, x, 2 * CENTER_X - 1 - x
                )
                full_image = pixels[y, mirror_x]
            else:
                full_image = pixels

            sprite = full_image[y0:y1, x0:x1].copy()
            sprite[~region[y0:y1, x0:x1]] = 0

            width, height = x1 - x0, y1 - y0
            if width & (width - 1) or height & (height - 1):
                raise ValueError("Texture dimensions must be powers of two")

            output = TEXTURES / f"artwork_HUD_{section}_{kind}.tga"
            Image.fromarray(sprite, "RGBA").save(output, format="TGA")
            print(f"{output.relative_to(ROOT)}: {width}x{height}")


if __name__ == "__main__":
    main()
