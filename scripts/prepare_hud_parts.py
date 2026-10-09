#!/usr/bin/env python3
"""Split the original HUD into seamless, power-of-two base/accent TGAs."""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TEXTURES = ROOT / "KamiUI" / "textures"
WIDTH, HEIGHT = 1916, 821
CENTER_X, CENTER_Y = 958, 446
CIRCLE_RADIUS = 246
DIVIDE_Y = 380

CROPS = {
    "center": (702, 190, 1214, 702),       # 512 x 512
    "top_left": (384, 128, 896, 384),     # 512 x 256
    "bottom_left": (64, 384, 1088, 640),  # 1024 x 256
}


def main():
    y, x = np.indices((HEIGHT, WIDTH))
    radius_sq = (x - CENTER_X) ** 2 + (y - CENTER_Y) ** 2
    center = radius_sq <= CIRCLE_RADIUS ** 2
    top_left = (x < CENTER_X) & ~center & (y < DIVIDE_Y)
    bottom_left = (x < CENTER_X) & ~center & ~top_left
    regions = {
        "center": center,
        "top_left": top_left,
        "bottom_left": bottom_left,
    }

    for suffix, filename in (
        ("base", "artwork_HUD_thin.png"),
        ("accent", "artwork_HUD_thin_accent.png"),
    ):
        source = Image.open(TEXTURES / filename).convert("RGBA")
        if source.size != (WIDTH, HEIGHT):
            raise ValueError(f"{filename}: unexpected dimensions {source.size}")
        pixels = np.array(source)
        pixels[pixels[:, :, 3] <= 3, :] = 0

        for name, rect in CROPS.items():
            region = regions[name]
            if name == "center":
                source_x = np.where(x < CENTER_X, x, 2 * CENTER_X - 1 - x)
                channels = pixels[y, source_x]
            else:
                channels = pixels

            x0, y0, x1, y1 = rect
            crop_mask = np.zeros((HEIGHT, WIDTH), dtype=bool)
            crop_mask[y0:y1, x0:x1] = True
            missing = region & (channels[:, :, 3] > 0) & ~crop_mask
            if missing.any():
                raise ValueError(f"{filename}/{name}: crop loses visible pixels")

            sprite = channels[y0:y1, x0:x1].copy()
            sprite[~region[y0:y1, x0:x1]] = 0
            output = TEXTURES / f"artwork_HUD_{name}_{suffix}.tga"
            Image.fromarray(sprite, "RGBA").save(output, format="TGA")
            print(f"{output.relative_to(ROOT)}: {x1 - x0}x{y1 - y0}")


if __name__ == "__main__":
    main()
