#!/usr/bin/env python3
"""
fontscore.py — pick the digit font for the flip clock, by measurement.

The reference digits are a condensed, medium-weight grotesque. We ship a libre
typeface chosen to match three measured properties of the reference glyphs:

    ink aspect (width/height)  = 0.563
    stroke thickness / height  = 0.130
    glyph shape                = maximise IoU after normalising both to a grid

Because we condense the candidate horizontally in QML to force the aspect to
match exactly, the number that actually matters for weight is the stroke ratio
*after* condensing. This tool reports that directly.

It also emits the two calibration constants the QML needs:

    FONT_INK_RATIO  ink height / font.pixelSize   -> pixelSize = 270*u / ratio
    FONT_CONDENSE   horizontal squeeze factor     -> Scale { xScale: ... }

Usage:
    tools/fontscore.py <font-dir> [--ref <clock_2x4-dir>] [--top N]

Reference glyphs are read from local analysis assets only.
"""

import argparse
import os
import subprocess
import sys
import tempfile


def _isolated_fontconfig(font_dir):
    """A fontconfig that sees the candidate dir on top of the system fonts."""
    conf = tempfile.NamedTemporaryFile("w", suffix=".conf", delete=False)
    conf.write(f"""<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <dir>{font_dir}</dir>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <cachedir>{font_dir}/.fccache</cachedir>
</fontconfig>
""")
    conf.close()
    return conf.name


# fontconfig is initialised the first time Pango is imported, so FONTCONFIG_FILE
# has to be in the environment *before* that. Set it and re-exec ourselves.
if "FLIPCLOCK_FC_READY" not in os.environ:
    _dir = next((os.path.abspath(a) for a in sys.argv[1:] if not a.startswith("-")), None)
    if _dir and os.path.isdir(_dir):
        os.environ["FONTCONFIG_FILE"] = _isolated_fontconfig(_dir)
        os.environ["FLIPCLOCK_FC_READY"] = "1"
        os.execv(sys.executable, [sys.executable] + sys.argv)

import gi  # noqa: E402
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
from gi.repository import Pango, PangoCairo  # noqa: E402
import cairo  # noqa: E402

DIGITS_FOR_METRICS = (0, 2, 3, 5, 8)   # '1' is naturally narrow, skip for aspect
TARGET_ASPECT = 0.563
TARGET_STROKE = 0.130
NORM_W, NORM_H = 64, 110
RENDER_PX = 400.0


# ----------------------------------------------------------------- reference

def _load_png(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
        capture_output=True, check=True).stdout
    dims = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0", path],
        capture_output=True, check=True).stdout.decode().strip().split(",")
    w, h = int(dims[0]), int(dims[1])
    return w, h, raw


def reference_masks(ref_dir):
    """Rebuild each digit as a full-height binary mask from its two half-tiles."""
    masks = {}
    for d in range(10):
        wu, hu, bu = _load_png(os.path.join(ref_dir, "time", f"flip_up_{d}.png"))
        wd, hd, bd = _load_png(os.path.join(ref_dir, "time", f"flip_down_{d}.png"))
        rows = [[bu[(y * wu + x) * 4] for x in range(wu)] for y in range(hu)]
        rows += [[bd[(y * wd + x) * 4] for x in range(wd)] for y in range(hd)]
        m = []
        for y, r in enumerate(rows):
            if 185 <= y <= 194:          # crease hairline, not ink
                m.append([0] * len(r))
                continue
            bg = max(r)
            m.append([1 if bg - v > 60 else 0 for v in r])
        masks[d] = m
    return masks


# ------------------------------------------------------------------ geometry

def bbox(m):
    ys = [y for y, r in enumerate(m) if any(r)]
    xs = [x for x in range(len(m[0])) if any(r[x] for r in m)]
    if not ys or not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def stroke_ratio(m):
    """Median horizontal ink run divided by ink height."""
    b = bbox(m)
    if not b:
        return 0.0
    x0, y0, x1, y1 = b
    h = y1 - y0 + 1
    runs = []
    for y in range(y0, y1 + 1):
        c = 0
        for v in m[y]:
            if v:
                c += 1
            elif c:
                runs.append(c)
                c = 0
        if c:
            runs.append(c)
    if not runs:
        return 0.0
    runs.sort()
    return runs[len(runs) // 2] / h


def normalise(m):
    """Stretch the ink bbox onto a fixed grid so shape can be compared free of size."""
    b = bbox(m)
    x0, y0, x1, y1 = b
    w, h = x1 - x0 + 1, y1 - y0 + 1
    return [[m[y0 + int(j * h / NORM_H)][x0 + int(i * w / NORM_W)]
             for i in range(NORM_W)] for j in range(NORM_H)]


def iou(a, b):
    inter = sum(1 for j in range(NORM_H) for i in range(NORM_W) if a[j][i] and b[j][i])
    union = sum(1 for j in range(NORM_H) for i in range(NORM_W) if a[j][i] or b[j][i])
    return inter / union if union else 0.0


# ------------------------------------------------------------------ rendering

def render_digit(family, digit, px, variations=None):
    surf = cairo.ImageSurface(cairo.FORMAT_A8, 700, 800)
    cr = cairo.Context(surf)
    layout = PangoCairo.create_layout(cr)
    # NB: never use Pango.FontDescription("Some Family Name") here. Pango parses
    # trailing style words out of the string, so "Roboto Condensed" becomes
    # family="Roboto" + stretch=Condensed and silently falls back. Set the family
    # explicitly instead.
    desc = Pango.FontDescription()
    desc.set_family(family)
    desc.set_absolute_size(px * Pango.SCALE)
    if variations:
        # The variable-weight axis is driven purely through variations;
        # Pango.Weight only accepts canonical enum values, so it is no use here.
        desc.set_variations(variations)
    layout.set_font_description(desc)
    layout.set_text(str(digit), -1)
    cr.move_to(40, 40)
    PangoCairo.show_layout(cr, layout)
    surf.flush()
    data, stride = surf.get_data(), surf.get_stride()
    m = [[1 if data[y * stride + x] > 128 else 0 for x in range(700)] for y in range(800)]
    return m if any(any(r) for r in m) else None


def families_in(font_dir):
    """
    Map each font file to (family, style, is_variable).

    fc-query prints one line per named instance, so a variable font yields many
    lines. Take the family/style from the first, and treat the file as variable
    if *any* line reports it so.
    """
    out = {}
    for fn in sorted(os.listdir(font_dir)):
        if not fn.lower().endswith((".ttf", ".otf")):
            continue
        path = os.path.join(font_dir, fn)
        r = subprocess.run(["fc-query", "-f", "%{family[0]}|%{style[0]}|%{variable}\n", path],
                           capture_output=True)
        if r.returncode != 0 or not r.stdout.strip():
            continue
        lines = [ln for ln in r.stdout.decode().splitlines() if ln.strip()]
        fam, style, _ = (lines[0].split("|") + ["", ""])[:3]
        variable = any(ln.rsplit("|", 1)[-1].strip() == "True" for ln in lines)
        out[fn] = (fam.strip(), style.strip(), variable)
    return out


# ---------------------------------------------------------------------- main

def evaluate(family, ref_norm, ref_masks, variations=None):
    shapes, aspects, strokes, ink_ratios = [], [], [], []
    for d in range(10):
        m = render_digit(family, d, RENDER_PX, variations)
        if m is None:
            return None
        b = bbox(m)
        if not b:
            return None
        x0, y0, x1, y1 = b
        w, h = x1 - x0 + 1, y1 - y0 + 1
        shapes.append(iou(normalise(m), ref_norm[d]))
        if d in DIGITS_FOR_METRICS:
            aspects.append(w / h)
            strokes.append(stroke_ratio(m))
            ink_ratios.append(h / RENDER_PX)
    aspect = sum(aspects) / len(aspects)
    stroke = sum(strokes) / len(strokes)
    condense = TARGET_ASPECT / aspect
    return {
        "iou": sum(shapes) / len(shapes),
        "aspect": aspect,
        "stroke": stroke,
        "condense": condense,
        "stroke_condensed": stroke * condense,
        "ink_ratio": sum(ink_ratios) / len(ink_ratios),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("font_dir")
    ap.add_argument("--ref", default="reference/mtz-extractor/extracted/HTC/clock_2x4")
    ap.add_argument("--top", type=int, default=12)
    ap.add_argument("--weights", default="300,350,400,450,500,550,600",
                    help="wght axis values to sweep on variable fonts")
    args = ap.parse_args()

    if not os.path.isdir(args.ref):
        sys.exit(f"reference dir not found: {args.ref}")

    print("reading reference glyphs ...", file=sys.stderr)
    ref_masks = reference_masks(args.ref)
    ref_norm = {d: normalise(ref_masks[d]) for d in range(10)}
    ref_aspect = sum((lambda b: (b[2] - b[0] + 1) / (b[3] - b[1] + 1))(bbox(ref_masks[d]))
                     for d in DIGITS_FOR_METRICS) / len(DIGITS_FOR_METRICS)
    ref_stroke = sum(stroke_ratio(ref_masks[d]) for d in DIGITS_FOR_METRICS) / len(DIGITS_FOR_METRICS)
    print(f"REFERENCE  aspect={ref_aspect:.3f}  stroke/height={ref_stroke:.3f}\n")

    fams = families_in(args.font_dir)
    if not fams:
        sys.exit(f"no fonts found in {args.font_dir}")

    weights = [w.strip() for w in args.weights.split(",") if w.strip()]
    results = []
    for fn, (fam, style, variable) in fams.items():
        # Sanity-check that fontconfig actually resolves the family to THIS file;
        # otherwise Pango silently falls back and we'd score the wrong typeface.
        matched = subprocess.run(["fc-match", f"{fam}:file", "file"],
                                 capture_output=True).stdout.decode().strip()
        # fc escapes commas in filenames; unescape before comparing.
        matched = os.path.basename(matched.strip('"').replace("\\", ""))
        if matched != fn:
            print(f"  !! {fam!r} resolves to {matched}, not {fn} — skipping", file=sys.stderr)
            continue
        if variable:
            trials = [(f"wght={w}", f"wght={w}") for w in weights]
        else:
            trials = [(style, None)]
        for label, var in trials:
            r = evaluate(fam, ref_norm, ref_masks, var)
            if r:
                r["name"] = f"{fam} [{label}]"
                results.append(r)

    # Rank by how well the condensed stroke lands, then by shape.
    results.sort(key=lambda r: (abs(r["stroke_condensed"] - TARGET_STROKE) / TARGET_STROKE) * 2.0
                 - r["iou"])

    print(f"{'IoU':>6} {'aspect':>7} {'strk':>6} {'cond':>6} {'strk*cond':>10} {'inkRatio':>9}  font")
    print(f"{'':>6} {'':>7} {'':>6} {'':>6} {'(→0.130)':>10} {'':>9}")
    for r in results[: args.top]:
        print(f"{r['iou']:6.3f} {r['aspect']:7.3f} {r['stroke']:6.3f} {r['condense']:6.3f} "
              f"{r['stroke_condensed']:10.3f} {r['ink_ratio']:9.3f}  {r['name']}")

    if results:
        b = results[0]
        print(f"\nWINNER: {b['name']}")
        print(f"  FONT_INK_RATIO = {b['ink_ratio']:.4f}   // pixelSize = 270*u / this")
        print(f"  FONT_CONDENSE  = {b['condense']:.4f}   // Scale.xScale")
        print(f"  shape IoU {b['iou']:.3f}, stroke after condensing "
              f"{b['stroke_condensed']:.3f} vs target {TARGET_STROKE}")


if __name__ == "__main__":
    main()
