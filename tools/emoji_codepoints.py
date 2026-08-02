"""Print every non-ASCII codepoint used in the project's GDScript, as a
comma-separated U+XXXX list suitable for `pyftsubset --unicodes=`.

The UI is built from emoji string literals (reel symbols, dice faces, property
icons, achievement badges). CI bundles an emoji fallback font for the web build,
where the browser gives Godot no system fonts to fall back on -- and a full Noto
Color Emoji is ~10 MB, which is a lot to ship for the ~60 glyphs actually used.
Subsetting to exactly this list keeps the download small and, because the list
is derived from the source, it stays correct as symbols are added or removed.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Always keep these even if absent from source: variation selector-16 (renders a
# glyph in emoji rather than text style) and combining enclosing keycap, which
# emoji like 7 + FE0F + 20E3 are built from.
ALWAYS = {0xFE0F, 0x20E3, 0x200D}


def main() -> int:
    points = set(ALWAYS)
    for path in sorted(ROOT.glob("**/*.gd")):
        for ch in path.read_text(encoding="utf-8"):
            if ord(ch) > 0x7F:
                points.add(ord(ch))

    if not points:
        print("no non-ascii codepoints found", file=sys.stderr)
        return 1

    print(",".join("U+%04X" % cp for cp in sorted(points)))
    print("%d codepoints" % len(points), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
