"""crop_avatars.py — Strip lavender ring from voice avatar source images.

Each source PNG (937×1136) contains the same face rendered into two
circles surrounded by a lavender ring/glow:
  * SMALL circle (left)  — center=(171, 520), inner-face radius=81
  * BIG   circle (right) — center=(628, 354), inner-face radius=182

The runtime Flutter widget paints a theme-adaptive ring around the
avatar (Paper Light blue / Rose Salmon pink / Beige Gold navy /
Dark variant), so the source-image ring must be discarded — output is
the FACE ONLY inside a circular alpha mask, transparent outside.

Anti-aliased mask via 2× supersampling: build the mask at 2× the
crop resolution, then downscale with LANCZOS so the circle edge
gets ~1px alpha gradient instead of stair-stepping.

Usage:
    python scripts/voice_avatars/crop_avatars.py            # all .png
    python scripts/voice_avatars/crop_avatars.py Adam       # one voice
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

# Hardcoded inner-face circle coordinates (verified consistent across
# all 12 source images via pixel-level scans on Adam, Bella, Rachel,
# Arnold, Sam, Clyde, Glinda, Antoni, Domi, Josh).
#
# Big-circle center y was originally estimated from a horizontal scan
# at y=350 (eyes level) which is NOT the circle's true vertical
# center; that produced a crop with visible lavender residue at the
# top arc. Refined via per-row ring-boundary detection: at each row,
# find the last lavender pixel before center and the first after —
# the row with maximum inter-distance is the true vertical center
# (y=445 for Adam, half-width 211 = inner-face radius).
SMALL_CENTER = (185, 520)
SMALL_RADIUS = 105

BIG_CENTER = (630, 445)
BIG_RADIUS = 211

# Per-voice overrides for sources whose circle position differs from
# the canonical Adam-derived coordinates. Arnold's big circle is
# offset by dx=5, dy=2 (and r=212 vs 211) — leaving the default
# coords would catch a faint lavender sliver on the left edge.
# Detected via per-row ring-boundary scan; verified by visual
# inspection of the re-cropped output.
PER_VOICE_BIG: dict[str, tuple[tuple[int, int], int]] = {
    # ElevenLabs template (default cx=630, cy=445, r=211)
    "Arnold": ((635, 447), 212),  # ElevenLabs outlier — existing
    "Aria":   ((631, 439), 211),  # ElevenLabs template, dy offset
    # Azure neural template (cx≈636, dy varies per voice)
    "Ryan":   ((637, 437), 209),
    "Davis":  ((637, 442), 209),
    "Guy":    ((636, 442), 210),
    "Sonia":  ((636, 450), 210),
    "Jenny":  ((636, 436), 211),
}

SMALL_OUTPUT_SIZE = 128
BIG_OUTPUT_SIZE = 512

# 2× supersampled mask for anti-aliased circle edges
MASK_SUPERSAMPLE = 2

SOURCE_DIR = Path(r"C:/Users/Admin/OneDrive/_Psitta/Images/Voices")
OUTPUT_DIR = Path("apps/desktop/assets/branding/voice_avatars")


def crop_circle(
    src: Image.Image,
    center: tuple[int, int],
    radius: int,
    output_size: int,
) -> Image.Image:
    """Crop a circular region from ``src`` and return an RGBA image at
    ``output_size`` × ``output_size`` with transparent pixels outside
    the circle.

    The alpha mask is rendered at 2× the cropped resolution and
    downscaled with LANCZOS, producing a ~1px anti-aliased edge that
    blends with whatever the runtime renders behind it.
    """
    cx, cy = center
    bbox = (cx - radius, cy - radius, cx + radius, cy + radius)
    crop = src.crop(bbox).convert("RGBA")  # (2*radius) × (2*radius)

    # Build supersampled mask, then downscale to crop dimensions
    super_size = (crop.size[0] * MASK_SUPERSAMPLE, crop.size[1] * MASK_SUPERSAMPLE)
    mask_super = Image.new("L", super_size, 0)
    ImageDraw.Draw(mask_super).ellipse(
        (0, 0, super_size[0] - 1, super_size[1] - 1), fill=255
    )
    mask = mask_super.resize(crop.size, Image.LANCZOS)

    # Apply mask as the alpha channel — discards lavender ring (which
    # sits OUTSIDE this radius) AND any background pixels caught by
    # the square crop.
    crop.putalpha(mask)

    # Final resize to target output dimensions with anti-aliasing
    return crop.resize((output_size, output_size), Image.LANCZOS)


def process_voice(name: str) -> tuple[Path, Path]:
    """Crop both small and big avatars for one voice. Returns the two
    output paths."""
    src_path = SOURCE_DIR / f"{name}.png"
    if not src_path.exists():
        raise FileNotFoundError(f"Source not found: {src_path}")

    src = Image.open(src_path).convert("RGBA")
    if src.size != (937, 1136):
        raise ValueError(
            f"{name}: expected source 937×1136, got {src.size}"
        )

    lower = name.lower()
    small_path = OUTPUT_DIR / f"small-{lower}.png"
    big_path = OUTPUT_DIR / f"big-{lower}.png"

    small_img = crop_circle(
        src, SMALL_CENTER, SMALL_RADIUS, SMALL_OUTPUT_SIZE
    )
    small_img.save(small_path, "PNG")

    big_center, big_radius = PER_VOICE_BIG.get(name, (BIG_CENTER, BIG_RADIUS))
    big_img = crop_circle(
        src, big_center, big_radius, BIG_OUTPUT_SIZE
    )
    big_img.save(big_path, "PNG")

    return small_path, big_path


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    if len(sys.argv) > 1:
        targets = sys.argv[1:]
    else:
        targets = [p.stem for p in sorted(SOURCE_DIR.glob("*.png"))]

    for name in targets:
        small, big = process_voice(name)
        print(f"  {name:10} -> {small.name}  +  {big.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
