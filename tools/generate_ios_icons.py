from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Final, Literal


@dataclass(slots=True, kw_only=True, frozen=True)
class IconSpec:
    size_pt: float
    scale: int
    idiom: Literal["iphone", "ipad", "ios-marketing"]


ICON_SPECS: Final[list[IconSpec]] = [
    IconSpec(size_pt=20,   scale=2, idiom="iphone"),
    IconSpec(size_pt=20,   scale=3, idiom="iphone"),
    IconSpec(size_pt=29,   scale=2, idiom="iphone"),
    IconSpec(size_pt=29,   scale=3, idiom="iphone"),
    IconSpec(size_pt=40,   scale=2, idiom="iphone"),
    IconSpec(size_pt=40,   scale=3, idiom="iphone"),
    IconSpec(size_pt=60,   scale=2, idiom="iphone"),
    IconSpec(size_pt=60,   scale=3, idiom="iphone"),

    IconSpec(size_pt=20,   scale=1, idiom="ipad"),
    IconSpec(size_pt=20,   scale=2, idiom="ipad"),
    IconSpec(size_pt=29,   scale=1, idiom="ipad"),
    IconSpec(size_pt=29,   scale=2, idiom="ipad"),
    IconSpec(size_pt=40,   scale=1, idiom="ipad"),
    IconSpec(size_pt=40,   scale=2, idiom="ipad"),
    IconSpec(size_pt=76,   scale=1, idiom="ipad"),
    IconSpec(size_pt=76,   scale=2, idiom="ipad"),
    IconSpec(size_pt=83.5, scale=2, idiom="ipad"),

    IconSpec(size_pt=1024, scale=1, idiom="ios-marketing"),
]


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


def build_contents_json(specs: list[IconSpec], light_filenames: list[str], dark_filenames: list[str]) -> dict[str, object]:
    """
    Build the Contents.json structure for an .appiconset with light and dark variants.
    iOS 18+ supports automatic dark mode switching via appearances.
    """
    images: list[dict[str, object]] = []

    for spec, light_filename, dark_filename in zip(specs, light_filenames, dark_filenames, strict=True):
        # Light mode icon (default, no appearances specified)
        images.append(
            {
                "idiom": spec.idiom,
                "size": f"{spec.size_pt}x{spec.size_pt}",
                "scale": f"{spec.scale}x",
                "filename": light_filename,
            }
        )

        # Dark mode icon
        images.append(
            {
                "appearances": [
                    {"appearance": "luminosity", "value": "dark"}
                ],
                "idiom": spec.idiom,
                "size": f"{spec.size_pt}x{spec.size_pt}",
                "scale": f"{spec.scale}x",
                "filename": dark_filename,
            }
        )

    return {
        "images": images,
        "info": {"version": 1, "author": "xcode"},
    }


def generate_icons(svg_path: Path, appiconset_dir: Path) -> None:
    """
    Generate all iOS icon PNGs (light and dark) and Contents.json from one SVG.
    """
    renderer = find_renderer()
    appiconset_dir.mkdir(parents=True, exist_ok=True)

    # Read original SVG
    svg_content = svg_path.read_text(encoding="utf-8")

    light_filenames: list[str] = []
    dark_filenames: list[str] = []

    for mode in ["light", "dark"]:
        colors = COLORS[mode]

        # Create modified SVG with new stroke color
        modified_svg = modify_svg_colors(svg_content, colors["stroke"])

        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode="w", suffix=".svg", delete=False, encoding="utf-8") as tmp:
            tmp.write(modified_svg)
            tmp_svg_path = Path(tmp.name)

        try:
            for spec in ICON_SPECS:
                size_px = int(round(spec.size_pt * spec.scale))
                filename = f"icon_{mode}_{size_px}x{size_px}.png"
                out_path = appiconset_dir / filename

                render_svg_to_png(
                    renderer=renderer,
                    svg_path=tmp_svg_path,
                    size_px=size_px,
                    out_path=out_path,
                    background_color=colors["background"],
                )

                if mode == "light":
                    light_filenames.append(filename)
                else:
                    dark_filenames.append(filename)
        finally:
            tmp_svg_path.unlink()

    contents = build_contents_json(ICON_SPECS, light_filenames, dark_filenames)
    (appiconset_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    svg_path = project_root / "Design" / "AppIcon.svg"
    appiconset_dir = project_root / "wurstfinger" / "Assets.xcassets" / "AppIcon.appiconset"

    generate_icons(svg_path=svg_path, appiconset_dir=appiconset_dir)
    print(f"✓ Generated light and dark icons in {appiconset_dir}")


if __name__ == "__main__":
    main()
