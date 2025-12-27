from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Final, Literal


# Color definitions for light and dark modes
# Softer, lower contrast colors for a refined, gentle look
COLORS = {
    "light": {
        "stroke": "#3D3D3D",      # Soft dark gray for strokes
        "background": "#E8E8E8",  # Warm light gray background
    },
    "dark": {
        "stroke": "#E8E8E8",      # Bright chalky off-white for strokes
        "background": "#252525",  # Slightly darker warm gray background
    },
}

# iOS 18+ uses single 1024x1024 icons that Xcode auto-scales
ICON_SIZE: Final[int] = 1024


class ConversionError(RuntimeError):
    """Raised when SVG->PNG conversion fails."""


def find_renderer() -> Literal["rsvg-convert", "inkscape"]:
    """
    Return the first available SVG renderer.
    Preference order: rsvg-convert, then inkscape.
    """
    if shutil.which("rsvg-convert"):
        return "rsvg-convert"
    if shutil.which("inkscape"):
        return "inkscape"
    raise ConversionError(
        "No renderer found. Install either 'librsvg' (rsvg-convert) or 'inkscape'."
    )


def modify_svg_colors(svg_content: str, stroke_color: str) -> str:
    """
    Replace stroke colors in SVG content with the specified color.
    """
    # Replace stroke:#000000 or stroke:#000 with new color
    modified = re.sub(
        r'stroke:#0{3,6}',
        f'stroke:{stroke_color}',
        svg_content
    )
    return modified


def render_svg_to_png(
    renderer: Literal["rsvg-convert", "inkscape"],
    svg_path: Path,
    size_px: int,
    out_path: Path,
    background_color: str,
) -> None:
    """
    Render the given SVG to a square PNG of size_px×size_px.
    """
    if renderer == "rsvg-convert":
        cmd = [
            "rsvg-convert",
            "-w",
            str(size_px),
            "-h",
            str(size_px),
            f"--background-color={background_color}",
            "-o",
            str(out_path),
            str(svg_path),
        ]
    elif renderer == "inkscape":
        cmd = [
            "inkscape",
            str(svg_path),
            f"--export-filename={out_path}",
            f"--export-width={size_px}",
            f"--export-height={size_px}",
            f"--export-background={background_color}",
            "--export-background-opacity=1.0",
        ]
    else:
        from typing import Never

        def assert_never(x: Never) -> None:
            raise AssertionError(f"Unhandled renderer: {x}")

        assert_never(renderer)

    subprocess.run(cmd, check=True)


def build_contents_json() -> dict[str, object]:
    """
    Build the Contents.json structure for iOS 18+ app icons.
    Uses simplified universal format with automatic scaling.
    """
    return {
        "images": [
            {
                "filename": "AppIcon.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            {
                "appearances": [
                    {"appearance": "luminosity", "value": "dark"}
                ],
                "filename": "AppIcon-Dark.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            {
                "appearances": [
                    {"appearance": "luminosity", "value": "tinted"}
                ],
                "filename": "AppIcon-Tinted.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            }
        ],
        "info": {"version": 1, "author": "xcode"},
    }


def generate_icons(svg_path: Path, appiconset_dir: Path) -> None:
    """
    Generate iOS 18+ app icon PNGs (light, dark, tinted) and Contents.json.
    """
    renderer = find_renderer()
    appiconset_dir.mkdir(parents=True, exist_ok=True)

    # Read original SVG
    svg_content = svg_path.read_text(encoding="utf-8")

    # Generate light icon (default/any appearance)
    light_svg = modify_svg_colors(svg_content, COLORS["light"]["stroke"])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".svg", delete=False, encoding="utf-8") as tmp:
        tmp.write(light_svg)
        tmp_path = Path(tmp.name)
    try:
        render_svg_to_png(
            renderer=renderer,
            svg_path=tmp_path,
            size_px=ICON_SIZE,
            out_path=appiconset_dir / "AppIcon.png",
            background_color=COLORS["light"]["background"],
        )
    finally:
        tmp_path.unlink()

    # Generate dark icon
    dark_svg = modify_svg_colors(svg_content, COLORS["dark"]["stroke"])
    with tempfile.NamedTemporaryFile(mode="w", suffix=".svg", delete=False, encoding="utf-8") as tmp:
        tmp.write(dark_svg)
        tmp_path = Path(tmp.name)
    try:
        render_svg_to_png(
            renderer=renderer,
            svg_path=tmp_path,
            size_px=ICON_SIZE,
            out_path=appiconset_dir / "AppIcon-Dark.png",
            background_color=COLORS["dark"]["background"],
        )
    finally:
        tmp_path.unlink()

    # Generate tinted icon (same as dark for now - monochrome works best)
    render_svg_to_png(
        renderer=renderer,
        svg_path=appiconset_dir.parent.parent.parent / "Design" / "AppIcon.svg",
        size_px=ICON_SIZE,
        out_path=appiconset_dir / "AppIcon-Tinted.png",
        background_color="#FFFFFF",
    )

    # Write Contents.json
    contents = build_contents_json()
    (appiconset_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    svg_path = project_root / "Design" / "AppIcon.svg"
    appiconset_dir = project_root / "wurstfinger" / "Assets.xcassets" / "AppIcon.appiconset"

    # Clean old icons
    for f in appiconset_dir.glob("icon_*.png"):
        f.unlink()

    generate_icons(svg_path=svg_path, appiconset_dir=appiconset_dir)
    print(f"✓ Generated iOS 18+ icons (light, dark, tinted) in {appiconset_dir}")


if __name__ == "__main__":
    main()
