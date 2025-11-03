from __future__ import annotations

import json
import shutil
import subprocess
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


def render_svg_to_png(
    renderer: Literal["rsvg-convert", "inkscape"],
    svg_path: Path,
    size_px: int,
    out_path: Path,
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
            "--background-color=white",
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
            "--export-background=white",
            "--export-background-opacity=1.0",
        ]
    else:
        from typing import Never

        def assert_never(x: Never) -> None:
            raise AssertionError(f"Unhandled renderer: {x}")

        assert_never(renderer)

    subprocess.run(cmd, check=True)


def build_contents_json(specs: list[IconSpec], filenames: list[str]) -> dict[str, object]:
    """
    Build the Contents.json structure for an .appiconset.
    """
    images: list[dict[str, str]] = []
    for spec, filename in zip(specs, filenames, strict=True):
        images.append(
            {
                "idiom": spec.idiom,
                "size": f"{spec.size_pt}x{spec.size_pt}",
                "scale": f"{spec.scale}x",
                "filename": filename,
            }
        )

    return {
        "images": images,
        "info": {"version": 1, "author": "xcode"},
    }


def generate_icons(svg_path: Path, appiconset_dir: Path) -> None:
    """
    Generate all iOS icon PNGs and Contents.json from one SVG.
    """
    renderer = find_renderer()
    appiconset_dir.mkdir(parents=True, exist_ok=True)

    generated_filenames: list[str] = []

    for spec in ICON_SPECS:
        size_px = int(round(spec.size_pt * spec.scale))
        filename = f"icon_{size_px}x{size_px}.png"
        out_path = appiconset_dir / filename

        render_svg_to_png(
            renderer=renderer,
            svg_path=svg_path,
            size_px=size_px,
            out_path=out_path,
        )

        generated_filenames.append(filename)

    contents = build_contents_json(ICON_SPECS, generated_filenames)
    (appiconset_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    svg_path = project_root / "Design" / "AppIcon.svg"
    appiconset_dir = project_root / "wurstfinger" / "Assets.xcassets" / "AppIcon.appiconset"

    generate_icons(svg_path=svg_path, appiconset_dir=appiconset_dir)


if __name__ == "__main__":
    main()
