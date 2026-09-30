#!/usr/bin/env python3
"""Derive the macOS app icon from the source artwork.

The source is a marketing composition: a dark squircle on a white background,
with a baked drop shadow and an "OpenRec" wordmark underneath. macOS wants only
the squircle, laid on Apple's icon grid, with transparent corners and no baked
shadow (the system draws its own).

The squircle is isolated by thresholding its dark fill and filling the holes, so
the light camera glyph enclosed inside it stays opaque while everything outside
the silhouette — background, glow, and shadow — is discarded.

Grid: Apple's macOS template puts the app shape at 824px inside a 1024px canvas.
The source squircle measures 616x581 (6% wider than tall) while its camera lens
is a true circle (115x113), so the outer shape is the loose one. --keep-aspect
preserves the artwork exactly and leaves the shape 6% short; the default squares
it up to match the other icons in the Dock.
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = ROOT / "Resources" / "AppIcon-source.png"
DEFAULT_OUTPUT = ROOT / "Resources" / "AppIcon.icns"

CANVAS = 1024  # Apple's macOS master icon canvas
SQUIRCLE = 824  # ...of which the app shape occupies 824px, centred

# The squircle fill reads ~21; the shadow, glow and background are all above 200.
BODY_LUMINANCE = 180

# (pixel size, filename) for the .iconset iconutil consumes.
ICONSET = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def isolate_squircle(rgb: np.ndarray) -> np.ndarray:
    """Boolean mask of the squircle, camera glyph included, shadow excluded."""
    luminance = rgb.astype(float).sum(axis=2) / 3
    body = luminance < BODY_LUMINANCE

    # The wordmark sits below the squircle as its own components; the squircle is
    # by far the largest, so keeping the biggest one drops the text for free.
    labels, count = ndimage.label(body)
    if count == 0:
        raise SystemExit("no dark region found - is this the right source image?")
    sizes = ndimage.sum(body, labels, range(1, count + 1))
    squircle = labels == int(np.argmax(sizes)) + 1

    # The camera glyph is light and fully enclosed, so filling holes restores it.
    return ndimage.binary_fill_holes(squircle)


def squircle_alpha(mask: np.ndarray, width: int, height: int) -> np.ndarray:
    """Antialiased alpha for the squircle, scaled from its own bounding box."""
    contours, _ = cv2.findContours(
        mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE
    )
    contour = max(contours, key=cv2.contourArea).astype(np.float64)

    rows, cols = np.where(mask)
    src_w = cols.max() - cols.min() + 1
    src_h = rows.max() - rows.min() + 1

    points = np.empty_like(contour)
    points[..., 0] = (contour[..., 0] - cols.min()) * width / src_w
    points[..., 1] = (contour[..., 1] - rows.min()) * height / src_h

    alpha = np.zeros((height, width), np.uint8)
    cv2.fillPoly(alpha, [np.round(points).astype(np.int32)], 255, lineType=cv2.LINE_AA)
    return alpha


def build_icon(source: Path, keep_aspect: bool) -> Image.Image:
    rgb = np.asarray(Image.open(source).convert("RGB"))
    mask = isolate_squircle(rgb)

    rows, cols = np.where(mask)
    box = (int(cols.min()), int(rows.min()), int(cols.max()) + 1, int(rows.max()) + 1)
    src_w = box[2] - box[0]
    src_h = box[3] - box[1]

    width = SQUIRCLE
    height = round(SQUIRCLE * src_h / src_w) if keep_aspect else SQUIRCLE

    artwork = Image.fromarray(rgb).crop(box).resize((width, height), Image.LANCZOS)
    alpha = Image.fromarray(squircle_alpha(mask, width, height))

    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    icon.paste(artwork, ((CANVAS - width) // 2, (CANVAS - height) // 2), alpha)
    return icon


def resize_rgba(image: Image.Image, size: int) -> Image.Image:
    """Downscale without letting transparent pixels bleed into the edges.

    Straight-alpha resampling averages the RGB of fully transparent pixels, which
    on this artwork are black, into the antialiased squircle edge and leaves a
    dark rim. Premultiplying first keeps the edge clean.
    """
    array = np.asarray(image).astype(np.float32) / 255.0
    alpha = array[..., 3:4]
    premultiplied = np.concatenate([array[..., :3] * alpha, alpha], axis=2)
    small = np.asarray(
        Image.fromarray((premultiplied * 255).round().astype(np.uint8)).resize(
            (size, size), Image.LANCZOS
        )
    ).astype(np.float32) / 255.0

    out_alpha = small[..., 3:4]
    rgb = np.clip(small[..., :3] / np.maximum(out_alpha, 1e-6), 0.0, 1.0)
    out = np.concatenate([rgb, out_alpha], axis=2)
    return Image.fromarray((out * 255).round().astype(np.uint8))


def write_icns(icon: Image.Image, output: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for size, name in ICONSET:
            resize_rgba(icon, size).save(iconset / name)
        output.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(output)],
            check=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--preview",
        type=Path,
        help="also write a 1024px PNG next to the .icns for eyeballing",
    )
    parser.add_argument(
        "--keep-aspect",
        action="store_true",
        help="preserve the artwork's 616:581 squircle instead of squaring it up",
    )
    args = parser.parse_args()

    icon = build_icon(args.source, args.keep_aspect)
    write_icns(icon, args.output)
    print(f"wrote {args.output}")

    if args.preview:
        icon.save(args.preview)
        print(f"wrote {args.preview}")


if __name__ == "__main__":
    main()
