"""
Generate the Icon Composer app icon bundle (AppIcon.icon) from Design/AppIcon.svg.

iOS 26 renders app icons as Liquid Glass: the system supplies the rounded
container, the specular highlights, the shadow and all four appearances
(default, dark, clear, tinted). The app only supplies flat, transparent
artwork layers plus a background fill described in icon.json.

This script slices the single-path line drawing in Design/AppIcon.svg into
those layers, normalises them onto the 1024x1024 icon canvas and writes the
bundle. Xcode's actool compiles it and additionally emits the legacy raster
icons for pre-iOS-26 devices, so no .appiconset is needed.

Requires Inkscape: the source artwork is stroke-only, and Icon Composer's
renderer fills open paths instead of stroking them, so strokes must be
flattened into filled outlines first.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path
from typing import Final


# Palette, carried over from the pre-Liquid-Glass icon: dark line art on a
# light background.
#
# The dark and tinted appearances are derived from these two colours by the
# system; they cannot be pinned per appearance. Hand-written
# "fill-specializations" entries are accepted by actool without complaint but
# have no effect either in ictool's preview or on device, so they are left out
# rather than shipped as dead configuration.
#
# The derivation lightens the glyph while darkening the background, so this
# pair happens to survive both: measured contrast is 29 points in the default
# appearance and 25 in dark. Lightening the glyph to rescue dark mode collapses
# the default appearance instead (5.8 points at 0.55), so keep it dark.
BACKGROUND_COLOR: Final[str] = "0.90980,0.90980,0.90980"  # #E8E8E8
GLYPH_FILL: Final[str] = "0.23922,0.23922,0.23922"  # #3D3D3D

# Baked into the layer SVGs as a fallback; the per-layer "fill" in icon.json
# is what actually drives the rendered colour.
GLYPH_COLOR: Final[str] = "#3D3D3D"

# Icon Composer canvas. Always 1024x1024 regardless of rendered size.
CANVAS: Final[float] = 1024.0

# Height of the artwork on the canvas. Apple's icon grid wants the glyph
# comfortably inside the container rather than bleeding to the edges.
CONTENT_HEIGHT: Final[float] = 700.0

# Bounding box of the drawing in Design/AppIcon.svg, in SVG user units.
# Obtained via `inkscape --query-all Design/AppIcon.svg` (px / 3.779528).
BBOX_X: Final[float] = 22.2245
BBOX_Y: Final[float] = 12.6862
BBOX_W: Final[float] = 101.6642
BBOX_H: Final[float] = 128.4718

# Transform on the source drawing's <g> wrapper, preserved verbatim so the
# path data below it keeps its original coordinates.
INNER_GROUP_TRANSFORM: Final[str] = "translate(-48.671656,-24.610504)"

# Path ids from Design/AppIcon.svg grouped into icon layers, back to front.
# Splitting hand and fingers gives the icon real parallax depth on the
# Home Screen instead of one flat plate of glass.
LAYERS: Final[dict[str, list[str]]] = {
    "Hand": ["path1", "path6", "path5"],
    "Fingers": ["path2", "path3", "path4"],
}


class ConversionError(RuntimeError):
    """Raised when SVG processing fails."""


def require_inkscape() -> str:
    """Return the Inkscape executable path, or explain how to get it."""
    inkscape = shutil.which("inkscape")
    if inkscape is None:
        raise ConversionError(
            "Inkscape is required to flatten strokes into filled outlines. "
            "Install it with `brew install --cask inkscape`."
        )
    return inkscape


def extract_paths(svg_content: str) -> dict[str, str]:
    """Return {id: <path .../> element} for every path in the source drawing."""
    paths: dict[str, str] = {}
    for match in re.finditer(r"<path\b.*?/>", svg_content, re.DOTALL):
        element = match.group(0)
        id_match = re.search(r'\bid="([^"]+)"', element)
        if id_match is not None:
            paths[id_match.group(1)] = element
    return paths


def build_layer_svg(elements: list[str]) -> str:
    """
    Place the given path elements on the 1024x1024 icon canvas.

    The drawing is scaled to CONTENT_HEIGHT and centred; the background stays
    transparent because the container comes from icon.json, not the artwork.
    """
    scale = CONTENT_HEIGHT / BBOX_H
    offset_x = (CANVAS - BBOX_W * scale) / 2 - BBOX_X * scale
    offset_y = (CANVAS - CONTENT_HEIGHT) / 2 - BBOX_Y * scale
    body = "\n      ".join(
        re.sub(r"stroke:#[0-9a-fA-F]{3,6}", f"stroke:{GLYPH_COLOR}", element)
        for element in elements
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"'
        ' viewBox="0 0 1024 1024">\n'
        f'  <g transform="translate({offset_x:.4f},{offset_y:.4f}) scale({scale:.6f})">\n'
        f'    <g transform="{INNER_GROUP_TRANSFORM}">\n'
        f"      {body}\n"
        "    </g>\n"
        "  </g>\n"
        "</svg>\n"
    )


def flatten_strokes(inkscape: str, svg_path: Path) -> None:
    """Convert strokes to filled outlines in place, then drop editor metadata."""
    try:
        subprocess.run(
            [
                inkscape,
                str(svg_path),
                "--actions=select-all;object-stroke-to-path;export-plain-svg",
                f"--export-filename={svg_path}",
            ],
            check=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as error:
        raise ConversionError(
            f"Inkscape failed to flatten {svg_path.name}: {error.stderr.decode(errors='replace')}"
        ) from error

    # Inkscape keeps sodipodi/inkscape attributes even in plain-SVG mode;
    # Icon Composer's parser warns about them.
    cleaned = re.sub(r"\s+(?:sodipodi|inkscape):[\w-]+=\"[^\"]*\"", "", svg_path.read_text("utf-8"))
    svg_path.write_text(cleaned, encoding="utf-8")


def solid(color: str) -> dict[str, str]:
    """Wrap an "r,g,b" triple as an Icon Composer solid fill."""
    return {"solid": f"extended-srgb:{color},1.00000"}


def gradient(color: str) -> dict[str, str]:
    """Wrap an "r,g,b" triple as an Icon Composer automatic gradient."""
    return {"automatic-gradient": f"extended-srgb:{color},1.00000"}


def build_icon_json() -> dict[str, object]:
    """Describe the layer stack, background fill and glass treatment."""
    return {
        "fill": gradient(BACKGROUND_COLOR),
        "groups": [
            {
                # Front-most layer first. "glass" is a layer property, not a
                # group one — setting it on the group silently does nothing,
                # which is what made the first attempt look flat.
                "layers": [
                    {
                        "image-name": f"{name}.svg",
                        "name": name,
                        "glass": True,
                        "fill": solid(GLYPH_FILL),
                    }
                    for name in reversed(list(LAYERS))
                ],
                "lighting": "individual",
                "shadow": {"kind": "neutral", "opacity": 0.5},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.5},
            }
        ],
        "supported-platforms": {
            "circles": ["watchOS"],
            "squares": ["iOS", "macOS"],
        },
    }


def generate_icon(svg_path: Path, icon_dir: Path) -> None:
    """Write the complete AppIcon.icon bundle."""
    inkscape = require_inkscape()
    paths = extract_paths(svg_path.read_text(encoding="utf-8"))

    missing = [i for ids in LAYERS.values() for i in ids if i not in paths]
    if missing:
        raise ConversionError(
            f"Design/AppIcon.svg is missing expected path ids: {', '.join(missing)}. "
            "Update LAYERS in this script to match the artwork."
        )

    assets_dir = icon_dir / "Assets"
    if assets_dir.exists():
        shutil.rmtree(assets_dir)
    assets_dir.mkdir(parents=True)

    for name, path_ids in LAYERS.items():
        layer_path = assets_dir / f"{name}.svg"
        layer_path.write_text(
            build_layer_svg([paths[i] for i in path_ids]), encoding="utf-8"
        )
        flatten_strokes(inkscape, layer_path)

    (icon_dir / "icon.json").write_text(
        json.dumps(build_icon_json(), indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    generate_icon(
        svg_path=project_root / "Design" / "AppIcon.svg",
        icon_dir=project_root / "wurstfinger" / "AppIcon.icon",
    )
    print("✓ Generated wurstfinger/AppIcon.icon (Liquid Glass, all appearances)")


if __name__ == "__main__":
    main()
