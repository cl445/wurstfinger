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
- AppIcon.icon/icon.json is written once and then left alone, so that edits
  made in Icon Composer (Xcode > Open Developer Tool > Icon Composer) survive.
  Re-running this script keeps the file and only checks that it still
  references the generated layers. Pass --reset-icon-json to rewrite it from
  the constants below, which reproduces what Icon Composer saves byte for
  byte — including the per-appearance dark fill.

Beware when editing icon.json by hand: most plausible spellings of the
per-appearance keys are dropped without any diagnostic, and some crash actool
outright. The shape recorded below is the one Icon Composer itself writes.

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
from typing import Final, NamedTuple

# Palette, carried over from the pre-Liquid-Glass icon: dark line art on a
# light background.
#
# The glass treatment washes the glyph colour out heavily — a fill of 0.0
# still renders as roughly 31% grey rather than black — so the glyph fill is
# plain black to keep the line art legible at icon size.
#
# The dark appearance needs its own fill or the dark glyph sinks into the dark
# background.
#
# Writing that per-appearance fill by hand only works in one exact shape:
# "fill-specializations" REPLACES "fill" — leaving both in place makes the
# parser take "fill" and drop the specializations without a word. The base
# value is the entry with no "appearance" key. Valid appearance names are
# base, light, dark and tinted.
BACKGROUND_COLOR: Final[str] = "0.90980,0.90980,0.90980"  # #E8E8E8
GLYPH_FILL: Final[str] = "0.00000,0.00000,0.00000"
GLYPH_FILL_DARK: Final[str] = "0.90980,0.90980,0.90980"  # #E8E8E8

# Background transparency is not something the icon can ask for: the default
# appearance always renders an opaque container. An alpha below 1.0 on the
# background fill — including 0.0 — changes nothing on device. Letting the
# wallpaper through is the "Clear" appearance, which the user picks on the
# Home Screen and the system renders from this same artwork.

# Baked into the layer SVGs as a fallback; the per-layer "fill" in icon.json
# is what actually drives the rendered colour.
GLYPH_COLOR: Final[str] = "#3D3D3D"

# Icon Composer canvas. Always 1024x1024 regardless of rendered size.
CANVAS: Final[float] = 1024.0

# Height of the artwork on the canvas. Apple's icon grid wants the glyph
# comfortably inside the container rather than bleeding to the edges.
CONTENT_HEIGHT: Final[float] = 780.0

# Path ids from Design/AppIcon.svg grouped into icon layers, back to front.
# Splitting hand and fingers gives the icon parallax depth on the Home Screen.
LAYERS: Final[dict[str, list[str]]] = {
    "Hand": ["path1", "path6", "path5"],
    "Fingers": ["path2", "path3", "path4"],
}


class ConversionError(RuntimeError):
    """Raised when SVG processing fails."""


class BoundingBox(NamedTuple):
    """A rectangle in SVG user units."""

    x: float
    y: float
    width: float
    height: float


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
    """Return {id: <path> element} for every path in the source drawing."""
    paths: dict[str, str] = {}
    for match in re.finditer(r"<path\b.*?(?:/>|</path>)", svg_content, re.DOTALL):
        element = match.group(0)
        id_match = re.search(r'\bid="([^"]+)"', element)
        if id_match is not None:
            paths[id_match.group(1)] = element
    return paths


def extract_group_transform(svg_content: str) -> str:
    """
    Return the transform of the <g> wrapper around the source drawing.

    The generated layers reproduce it verbatim, so the path data below it
    keeps its original coordinates.
    """
    transforms = re.findall(r'<g\b[^>]*?\btransform="([^"]+)"', svg_content, re.DOTALL)
    if len(transforms) != 1:
        raise ConversionError(
            f"Expected exactly one transformed <g> wrapper in the source drawing, "
            f"found {len(transforms)}."
        )
    return transforms[0]


def query_object_boxes(inkscape: str, svg_path: Path) -> dict[str, BoundingBox]:
    """Measure every object in the drawing via Inkscape, in px."""
    try:
        result = subprocess.run(
            [inkscape, "--query-all", str(svg_path)],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as error:
        raise ConversionError(
            f"Inkscape failed to measure {svg_path.name}: {error.stderr}"
        ) from error

    boxes: dict[str, BoundingBox] = {}
    for line in result.stdout.splitlines():
        object_id, _, values = line.partition(",")
        parts = values.split(",")
        if len(parts) == 4:
            boxes[object_id] = BoundingBox(*(float(part) for part in parts))
    return boxes


def px_per_user_unit(svg_content: str) -> float:
    """
    Return how many px one SVG user unit of the source drawing covers.

    Inkscape's --query-all measures in px, while the path data lives in user
    units; the document's width attribute against its viewBox width gives the
    conversion. The root <svg> line of --query-all cannot — it reports the
    bounding box of the drawing, not the page size.
    """
    width = re.search(r'<svg\b[^>]*?\bwidth="([\d.]+)([a-z%]*)"', svg_content, re.DOTALL)
    viewbox = re.search(
        r'\bviewBox="\s*[-\d.eE]+[\s,]+[-\d.eE]+[\s,]+([-\d.eE]+)[\s,]+[-\d.eE]+\s*"',
        svg_content,
    )
    unit_to_px = {"": 1.0, "px": 1.0, "in": 96.0, "pt": 96.0 / 72.0, "pc": 16.0,
                  "mm": 96.0 / 25.4, "cm": 96.0 / 2.54}
    if width is None or viewbox is None or width.group(2) not in unit_to_px:
        raise ConversionError(
            "Cannot derive the px-per-user-unit ratio: the source drawing needs "
            "a width attribute in absolute units and a numeric viewBox."
        )
    return float(width.group(1)) * unit_to_px[width.group(2)] / float(viewbox.group(1))


def drawing_bounding_box(svg_content: str, boxes: dict[str, BoundingBox]) -> BoundingBox:
    """Return the union box of the layered paths, in SVG user units."""
    px_per_unit = px_per_user_unit(svg_content)

    path_ids = [path_id for ids in LAYERS.values() for path_id in ids]
    if missing := [path_id for path_id in path_ids if path_id not in boxes]:
        raise ConversionError(
            f"Inkscape did not report a bounding box for: {', '.join(missing)}."
        )

    left = min(boxes[i].x for i in path_ids)
    top = min(boxes[i].y for i in path_ids)
    right = max(boxes[i].x + boxes[i].width for i in path_ids)
    bottom = max(boxes[i].y + boxes[i].height for i in path_ids)
    return BoundingBox(
        left / px_per_unit,
        top / px_per_unit,
        (right - left) / px_per_unit,
        (bottom - top) / px_per_unit,
    )


def build_layer_svg(elements: list[str], bbox: BoundingBox, group_transform: str) -> str:
    """
    Place the given path elements on the 1024x1024 icon canvas.

    The drawing is scaled to CONTENT_HEIGHT and centred; the background stays
    transparent because the container comes from icon.json, not the artwork.
    """
    scale = CONTENT_HEIGHT / bbox.height
    offset_x = (CANVAS - bbox.width * scale) / 2 - bbox.x * scale
    offset_y = (CANVAS - CONTENT_HEIGHT) / 2 - bbox.y * scale
    body = "\n      ".join(
        re.sub(
            r"stroke:#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b",
            f"stroke:{GLYPH_COLOR}",
            element,
        )
        for element in elements
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024"'
        ' viewBox="0 0 1024 1024">\n'
        f'  <g transform="translate({offset_x:.4f},{offset_y:.4f}) scale({scale:.6f})">\n'
        f'    <g transform="{group_transform}">\n'
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


def solid(color: str, space: str = "extended-srgb") -> dict[str, str]:
    """Wrap an "r,g,b" triple as an Icon Composer solid fill."""
    return {"solid": f"{space}:{color},1.00000"}


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
                # group one — setting it on the group silently does nothing.
                "layers": [
                    {
                        "image-name": f"{name}.svg",
                        "name": name,
                        "glass": True,
                        # No sibling "fill" key — see the note on the palette.
                        "fill-specializations": [
                            {"value": solid(GLYPH_FILL)},
                            {"appearance": "dark", "value": solid(GLYPH_FILL_DARK, "srgb")},
                        ],
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
    svg_content = svg_path.read_text(encoding="utf-8")
    paths = extract_paths(svg_content)

    missing = [i for ids in LAYERS.values() for i in ids if i not in paths]
    if missing:
        raise ConversionError(
            f"Design/AppIcon.svg is missing expected path ids: {', '.join(missing)}. "
            "Update LAYERS in this script to match the artwork."
        )

    group_transform = extract_group_transform(svg_content)
    bbox = drawing_bounding_box(svg_content, query_object_boxes(inkscape, svg_path))

    assets_dir = icon_dir / "Assets"
    if assets_dir.exists():
        shutil.rmtree(assets_dir)
    assets_dir.mkdir(parents=True)

    for name, path_ids in LAYERS.items():
        layer_path = assets_dir / f"{name}.svg"
        layer_path.write_text(
            build_layer_svg([paths[i] for i in path_ids], bbox, group_transform),
            encoding="utf-8",
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
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
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
