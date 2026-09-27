#!/usr/bin/env python3
"""
Process sigil source PNG into app icon variants and template image.

Input:  sigils/Sigil for NADI (1).png  (black strokes on white, 3024x1498)

Output:
  nadi/Assets.xcassets/AppIcon.appiconset/icon-light.png   (black on white, opaque)
  nadi/Assets.xcassets/AppIcon.appiconset/icon-dark.png    (#4A7CFF on #0A0A0F, opaque)
  nadi/Assets.xcassets/AppIcon.appiconset/icon-tinted.png  (grayscale, opaque)
  nadi/Assets.xcassets/sigil.imageset/sigil.png            (black on transparent, RGBA)

Usage:
  /tmp/nadi-venv/bin/python3 Scripts/process_sigil.py
"""

import os
import numpy as np
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(SCRIPT_DIR, "..")
SOURCE = os.path.join(ROOT, "sigils", "Sigil for NADI (1).png")
ICON_DIR = os.path.join(ROOT, "nadi", "Assets.xcassets", "AppIcon.appiconset")
SIGIL_DIR = os.path.join(ROOT, "nadi", "Assets.xcassets", "sigil.imageset")
SIZE = 1024


def load_and_prepare(path):
    """Load source, center-crop to square, resize to 1024, return grayscale + alpha mask."""
    img = Image.open(path).convert("L")  # grayscale
    w, h = img.size

    # Center-crop to square (min dimension)
    sq = min(w, h)
    left = (w - sq) // 2
    top = (h - sq) // 2
    img = img.crop((left, top, left + sq, top + sq))

    # Resize to target
    img = img.resize((SIZE, SIZE), Image.LANCZOS)

    gray = np.array(img, dtype=np.float32)

    # Alpha = 255 - gray (black strokes → full alpha, white bg → zero alpha)
    # Preserves anti-aliased edges without any threshold
    alpha = (255.0 - gray).clip(0, 255).astype(np.uint8)

    return gray, alpha


def composite_opaque(alpha, stroke_rgb, bg_rgb):
    """Composite stroke color onto background using alpha mask. Returns opaque RGB image."""
    a = alpha.astype(np.float32) / 255.0
    a = a[:, :, np.newaxis]

    fg = np.full((SIZE, SIZE, 3), stroke_rgb, dtype=np.float32)
    bg = np.full((SIZE, SIZE, 3), bg_rgb, dtype=np.float32)

    result = (fg * a + bg * (1.0 - a)).clip(0, 255).astype(np.uint8)
    return Image.fromarray(result, "RGB")


def make_template(alpha, stroke_rgb=(0, 0, 0)):
    """Create RGBA template image (stroke color on transparent background)."""
    rgba = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    rgba[:, :, 0] = stroke_rgb[0]
    rgba[:, :, 1] = stroke_rgb[1]
    rgba[:, :, 2] = stroke_rgb[2]
    rgba[:, :, 3] = alpha
    return Image.fromarray(rgba, "RGBA")


def main():
    print("Processing sigil source image...")
    gray, alpha = load_and_prepare(SOURCE)

    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(SIGIL_DIR, exist_ok=True)

    # 1. Light icon: black sigil on white (fully opaque)
    light = composite_opaque(alpha, (0, 0, 0), (255, 255, 255))
    light.save(os.path.join(ICON_DIR, "icon-light.png"))
    print(f"  icon-light.png ({SIZE}x{SIZE}, RGB)")

    # 2. Dark icon: #4A7CFF sigil on #0A0A0F (fully opaque)
    dark = composite_opaque(alpha, (0x4A, 0x7C, 0xFF), (0x0A, 0x0A, 0x0F))
    dark.save(os.path.join(ICON_DIR, "icon-dark.png"))
    print(f"  icon-dark.png ({SIZE}x{SIZE}, RGB)")

    # 3. Tinted icon: white sigil on dark bg, converted to grayscale (fully opaque)
    tinted = composite_opaque(alpha, (255, 255, 255), (20, 20, 25))
    tinted = tinted.convert("L")  # grayscale for iOS tinting
    tinted.save(os.path.join(ICON_DIR, "icon-tinted.png"))
    print(f"  icon-tinted.png ({SIZE}x{SIZE}, Grayscale)")

    # 4. Template image: black on transparent (for SwiftUI .foregroundStyle tinting)
    template = make_template(alpha, stroke_rgb=(0, 0, 0))
    template.save(os.path.join(SIGIL_DIR, "sigil.png"))
    print(f"  sigil.png ({SIZE}x{SIZE}, RGBA)")

    print("Done.")


if __name__ == "__main__":
    main()
