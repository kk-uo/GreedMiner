#!/usr/bin/env python3
"""Rebuild the Chinese fallback font subset used by the UI theme.

The full Noto Serif CJK SC font is ~24.5 MB; shipping it would add that much
to every export. Instead the game ships a subset that only contains the
Chinese characters the project actually uses (translations, scripts, scenes,
resources) plus the common characters listed in common_chars.txt.

Run it again whenever new Chinese text is added (e.g. after editing
Translations/zh_CN.po):

    pip install fonttools
    python3 tools/fonts/subset_cjk_font.py

Output: Assets/Fonts/NotoSerifSC-Subset.otf (referenced by
Resources/UI/greedminer_theme.tres). Tests/FontCoverageTest checks that every
character in the translations is covered.
"""
import pathlib
import re
import sys

try:
    from fontTools import subset
except ImportError:
    sys.exit("fontTools is missing: pip install fonttools")

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
SOURCE = HERE / "source" / "NotoSerifCJKsc-Regular.otf"
OUTPUT = ROOT / "Assets" / "Fonts" / "NotoSerifSC-Subset.otf"
SCAN_DIRS = ["Translations", "Scripts", "Scenes", "Resources"]
SCAN_SUFFIXES = {".po", ".csv", ".gd", ".tscn", ".tres"}
# CJK ideographs, CJK punctuation, full-width forms, general punctuation,
# arrows and geometric shapes (◆ ● ▲ …).
CJK = re.compile(r"[\u2e80-\u9fff\u3000-\u303f\uff00-\uffef\u2010-\u2027\u2030-\u205e\u2190-\u27bf]")
EXTRA = "，。！？：；、“”‘’（）《》【】…—·～"


def collect() -> set:
    chars = set(EXTRA)
    chars |= set((HERE / "common_chars.txt").read_text(encoding="utf-8").strip())
    for folder in SCAN_DIRS:
        for path in (ROOT / folder).rglob("*"):
            if path.suffix in SCAN_SUFFIXES and path.is_file():
                chars |= set(CJK.findall(path.read_text(encoding="utf-8", errors="ignore")))
    return chars


def main() -> None:
    chars = collect()
    options = subset.Options()
    options.layout_features = ["*"]
    options.hinting = False
    options.desubroutinize = True
    font = subset.load_font(str(SOURCE), options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(text="".join(sorted(chars)))
    subsetter.subset(font)
    subset.save_font(font, str(OUTPUT), options)
    print(f"{len(chars)} characters -> {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()

