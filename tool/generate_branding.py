"""Render native icon and splash inputs from assets/branding/logo.svg.

Install the renderer: python -m pip install -r tool/branding-requirements.txt
Regenerate: python tool/generate_branding.py
Then run: dart run flutter_launcher_icons
          dart run flutter_native_splash:create

Only logo.svg is bundled by Flutter. PNGs are inputs for the native generators.
"""

from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".dart_tool" / "branding_tools"))

import resvg_py

BRANDING = ROOT / "assets" / "branding"
BACKGROUND = "#0A665E"
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


def render(size: int, logo_size: int, background: bool = False) -> str:
    svg = ET.Element(
        f"{{{SVG_NS}}}svg",
        width=str(size),
        height=str(size),
        viewBox=f"0 0 {size} {size}",
    )
    if background:
        ET.SubElement(
            svg,
            f"{{{SVG_NS}}}rect",
            width=str(size),
            height=str(size),
            fill=BACKGROUND,
        )
    logo = ET.parse(BRANDING / "logo.svg").getroot()
    offset = (size - logo_size) / 2
    logo.set("x", str(offset))
    logo.set("y", str(offset))
    logo.set("width", str(logo_size))
    logo.set("height", str(logo_size))
    svg.append(logo)
    return ET.tostring(svg, encoding="unicode")


def main() -> None:
    outputs = {
        "app_icon": render(1024, 760, background=True),
        "logo_foreground": render(1024, 1024),
        "splash": render(736, 736),
        "splash_android12": render(1152, 736),
    }
    for name, svg in outputs.items():
        (BRANDING / f"{name}.png").write_bytes(resvg_py.svg_to_bytes(svg_string=svg))
        print(f"Rendered assets/branding/{name}.png")
    (BRANDING / "app_icon.svg").write_text(outputs["app_icon"] + "\n", encoding="utf-8")
    print("Rendered assets/branding/app_icon.svg")


if __name__ == "__main__":
    main()
