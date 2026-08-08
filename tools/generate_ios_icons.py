"""
Generate the Icon Composer app icon bundle (AppIcon.icon) from Design/AppIcon.svg.

iOS 26 renders app icons as Liquid Glass: the system supplies the rounded
container, the specular highlights, the shadow and all four appearances
(default, dark, clear, tinted). The app only supplies flat, transparent
artwork layers plus a background fill described in icon.json.

This script slices the single-path line drawing in Design/AppIcon.svg into
those layers and normalises them onto the 1024x1024 icon canvas. Xcode's
actool compiles the bundle and additionally emits the legacy raster icons for
pre-iOS-26 devices, so no .appiconset is needed.

Division of labour:

- The layer SVGs under AppIcon.icon/Assets are generated, and are overwritten
  on every run. Edit Design/AppIcon.svg, not them.
- AppIcon.icon/icon.json is written once and then hand-maintained in Icon
  Composer (Xcode > Open Developer Tool > Icon Composer). Per-appearance
  settings — most usefully a lighter glyph fill for the dark appearance —
  can only be authored there; hand-writing them into the JSON is silently
  dropped or crashes actool. Re-running this script keeps the file and only
  checks that it still references the generated layers. Pass
  --reset-icon-json to deliberately throw those edits away.

Requires Inkscape: the source artwork is stroke-only, and Icon Composer's
renderer fills open paths instead of stroking them, so strokes must be
flattened into filled outlines first.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path
from typing import Final


# Palette, carried over from the pre-Liquid-Glass icon: dark line art on a
# light background.
#
# As long as a single fill drives every appearance, dark-appearance contrast
# measures ~7 points whatever the glyph colour, so the glyph reads there
# through its glass edges rather than through colour. In the default
# appearance the colour matters a lot, and the glass treatment washes it out
# heavily — a fill of 0.0 still renders as roughly 31% grey rather than black.
# So the glyph is pushed to black to buy back the contrast lost when the
# artwork was scaled down onto the icon grid: measured 57 points in the default
# appearance, against 40 at the original #3D3D3D.
#
# Per-appearance fills are a real Icon Composer feature (WWDC25 session 361:
# fill, opacity and blend mode apply per appearance; appearance names are
# base, light, dark and tinted). They are the proper fix for the dark
# appearance. They are not used here because hand-writing them into icon.json
# does not work: every spelling and placement tried was dropped without even
# an "Unknown appearance name" complaint from the parser. Authoring them means
# opening AppIcon.icon in Icon Composer and setting the dark fill there — at
# which point this script must stop rewriting icon.json and generate only the
# layer SVGs, or it will overwrite that work.
BACKGROUND_COLOR: Final[str] = "0.90980,0.90980,0.90980"  # #E8E8E8
GLYPH_FILL: Final[str] = "0.00000,0.00000,0.00000"

# Background transparency is not something the icon can ask for: the default
# appearance always renders an opaque container. An alpha below 1.0 on the
# background fill — including 0.0 — changes nothing on device. Letting the
# wallpaper through is the "Clear" appearance, which the user picks on the
# Home Screen and the system renders from this same artwork.

# Thin strokes are the other half of perceived contrast. Scaling the artwork
# down to the icon grid thinned them, so this scales them back up
# independently of the drawing size. 1.0 keeps the source weight.
STROKE_WIDTH_SCALE: Final[float] = 1.0

# Baked into the layer SVGs as a fallback; the per-layer "fill" in icon.json
# is what actually drives the rendered colour.
GLYPH_COLOR: Final[str] = "#3D3D3D"

# Icon Composer canvas. Always 1024x1024 regardless of rendered size.
CANVAS: Final[float] = 1024.0

# Height of the artwork on the canvas. Apple's icon grid wants the glyph
# comfortably inside the container rather than bleeding to the edges.
CONTENT_HEIGHT: Final[float] = 780.0

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
    def restyle(element: str) -> str:
        element = re.sub(r"stroke:#[0-9a-fA-F]{3,6}", f"stroke:{GLYPH_COLOR}", element)
        return re.sub(
            r"stroke-width:([0-9.]+)",
            lambda m: f"stroke-width:{float(m.group(1)) * STROKE_WIDTH_SCALE:.5f}",
            element,
        )

    body = "\n      ".join(restyle(element) for element in elements)
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


def check_icon_json(icon_dir: Path) -> None:
    """
    Verify a hand-maintained icon.json still matches the generated layers.

    icon.json is not rewritten once it exists, so it can drift away from the
    artwork — a renamed layer would leave the icon silently missing a piece.
    """
    try:
        document = json.loads((icon_dir / "icon.json").read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ConversionError(f"{icon_dir.name}/icon.json is not valid JSON: {error}") from error

    referenced = {
        layer.get("image-name")
        for group in document.get("groups", [])
        for layer in group.get("layers", [])
    }
    expected = {f"{name}.svg" for name in LAYERS}

    if missing := expected - referenced:
        raise ConversionError(
            f"icon.json does not reference generated layer(s): {', '.join(sorted(missing))}. "
            "Add them in Icon Composer, or delete icon.json to regenerate a default one."
        )
    if stale := referenced - expected:
        raise ConversionError(
            f"icon.json references layer(s) this script no longer generates: "
            f"{', '.join(sorted(str(s) for s in stale))}. "
            "Update LAYERS here or fix the layer in Icon Composer."
        )


def generate_icon(svg_path: Path, icon_dir: Path, reset: bool = False) -> str:
    """
    Regenerate the layer artwork, and describe what happened to icon.json.

    Only the layer SVGs are derived from Design/AppIcon.svg. icon.json is
    written once and then left alone, because per-appearance settings — the
    dark fill above all — can only be authored in Icon Composer, and
    rewriting the file would throw that work away on every run.
    """
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

    icon_json = icon_dir / "icon.json"
    if icon_json.exists() and not reset:
        check_icon_json(icon_dir)
        return "kept existing icon.json (edit it in Icon Composer)"

    write_icon_json(icon_dir)
    return "wrote a fresh icon.json" if reset else "created icon.json"


def write_icon_json(icon_dir: Path) -> None:
    """Write the default icon.json. Overwrites any Icon Composer edits."""
    (icon_dir / "icon.json").write_text(
        json.dumps(build_icon_json(), indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reset-icon-json",
        action="store_true",
        help="discard icon.json and write a fresh default, losing Icon Composer edits",
    )
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    try:
        outcome = generate_icon(
            svg_path=project_root / "Design" / "AppIcon.svg",
            icon_dir=project_root / "wurstfinger" / "AppIcon.icon",
            reset=args.reset_icon_json,
        )
    except ConversionError as error:
        raise SystemExit(f"✗ {error}") from None
    print(f"✓ Regenerated layer artwork; {outcome}")


if __name__ == "__main__":
    main()
