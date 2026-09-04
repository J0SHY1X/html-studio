#!/usr/bin/env python3

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def transparent_master(source_path: Path) -> Image.Image:
    image = Image.open(source_path).convert("RGBA")
    square = min(image.size)
    left = (image.width - square) // 2
    top = (image.height - square) // 2
    image = image.crop((left, top, left + square, top + square))
    image = image.resize((1024, 1024), Image.Resampling.LANCZOS)

    # Clip just inside the generated squircle. A supersampled alpha mask keeps
    # the edge smooth at macOS Retina sizes and Windows taskbar sizes while
    # removing the white canvas around the icon.
    mask_scale = 4
    mask_size = 1024 * mask_scale
    mask = Image.new("L", (mask_size, mask_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (0, 0, mask_size - 1, mask_size - 1),
        radius=188 * mask_scale,
        fill=255,
    )
    image.putalpha(mask.resize((1024, 1024), Image.Resampling.LANCZOS))
    return image


def main() -> None:
    parser = argparse.ArgumentParser(description="Build HTML Studio app icons")
    parser.add_argument("source", type=Path)
    parser.add_argument("--mac-icns", type=Path, required=True)
    parser.add_argument("--windows-ico", type=Path, required=True)
    parser.add_argument("--windows-png", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    args = parser.parse_args()

    master = transparent_master(args.source)
    for output in (
        args.mac_icns,
        args.windows_ico,
        args.windows_png,
        args.preview,
    ):
        output.parent.mkdir(parents=True, exist_ok=True)

    master.save(args.mac_icns, format="ICNS")
    master.save(
        args.windows_ico,
        format="ICO",
        sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    master.save(args.windows_png, format="PNG", optimize=True)
    master.resize((256, 256), Image.Resampling.LANCZOS).save(
        args.preview,
        format="PNG",
        optimize=True,
    )


if __name__ == "__main__":
    main()
