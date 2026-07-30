#!/usr/bin/env python3
"""
pixdiff.py — measure how close the rendered clock is to the reference frame.

Rebuilds the reference frame by compositing the reference tiles the way the
layout places them (bg1 at 0,0; flip_up_<d> at y=27 and flip_down_<d> at
y=218, at x = 104 / 269 / 568 / 733), then compares it to our render region by
region.

Both images are flattened over the same solid background first, because the
weather panel is 50% translucent in both and would otherwise compare unfairly.

The digit regions are reported separately and are NOT part of the pass/fail
gate: we substitute a libre typeface, so a residual there is expected
and is tracked by tools/fontscore.py instead.

Usage:
    tools/pixdiff.py <render.png> [--ref <clock-dir>] [--time HHMM]
                     [--write-ref out.png] [--write-diff out.png]
"""

import argparse
import os
import subprocess
import sys

REF_W, REF_H = 996, 566
TILE_X = (104, 269, 568, 733)   # digit tile origins in the reference layout
TILE_UP_Y = 27
TILE_DOWN_Y = 218
FLATTEN = (128, 128, 128)       # neutral grey; both sides get the same

# name -> (box, exclude-box-or-None), in reference units.
#
# The gated card regions exclude the digit tiles: we substitute a libre typeface
# for the reference typeface, so including the glyphs would make the gate unpassable by
# construction. Glyph fidelity is measured by tools/fontscore.py instead, and the
# digit regions below are reported for information only.
REGIONS = {
    "card L frame": ((77, 13, 455, 438), (104, 27, 429, 358)),
    "card R frame": ((541, 13, 919, 438), (568, 27, 893, 358)),
    # Panel-only areas: the strips either side of, between and below the cards.
    # A naive "top half" box would be mostly card and measure the wrong thing.
    "panel margin": ((0, 60, 70, 430), None),
    "panel gap":    ((465, 60, 531, 430), None),
    "panel below":  ((0, 448, 996, 560), None),
    "digits H":     ((104, 27, 429, 358), None),
    "digits M":     ((568, 27, 893, 358), None),
}
GATED = ("card L frame", "card R frame", "panel margin", "panel gap", "panel below")


def load_rgba(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
        capture_output=True, check=True).stdout
    dims = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0", path],
        capture_output=True, check=True).stdout.decode().strip().split(",")
    return int(dims[0]), int(dims[1]), bytearray(raw)


def blank(w, h):
    return bytearray(w * h * 4)


def blit(dst, dw, dh, src, sw, sh, ox, oy):
    """
    Source-over composite of src onto dst at (ox, oy), on STRAIGHT alpha.

    The colour term must be divided back out by the resulting alpha. Skipping
    that (i.e. leaving it premultiplied) silently darkens every translucent
    pixel toward black -- which, over a transparent canvas, turned the 50%
    weather panel from 246 into 123 and made the whole diff meaningless.
    """
    for y in range(sh):
        dy = y + oy
        if not (0 <= dy < dh):
            continue
        row_s = (y * sw) * 4
        row_d = (dy * dw) * 4
        for x in range(sw):
            dx = x + ox
            if not (0 <= dx < dw):
                continue
            si = row_s + x * 4
            di = row_d + dx * 4
            sa = src[si + 3]
            if sa == 0:
                continue
            if sa == 255:
                dst[di:di + 4] = src[si:si + 4]
                continue
            a = sa / 255.0
            da = dst[di + 3] / 255.0
            out_a = a + da * (1 - a)
            if out_a <= 0:
                continue
            for c in range(3):
                num = src[si + c] * a + dst[di + c] * da * (1 - a)
                dst[di + c] = max(0, min(255, int(num / out_a + 0.5)))
            dst[di + 3] = max(0, min(255, int(out_a * 255 + 0.5)))


def flatten(buf, w, h, bg=FLATTEN):
    out = bytearray(w * h * 3)
    for i in range(w * h):
        a = buf[i * 4 + 3] / 255.0
        for c in range(3):
            out[i * 3 + c] = int(buf[i * 4 + c] * a + bg[c] * (1 - a) + 0.5)
    return out


def build_reference(ref_dir, hhmm):
    canvas = blank(REF_W, REF_H)
    bw, bh, bg1 = load_rgba(os.path.join(ref_dir, "bg1.png"))
    blit(canvas, REF_W, REF_H, bg1, bw, bh, 0, 0)
    for i, ch in enumerate(hhmm):
        for name, oy in (("flip_up", TILE_UP_Y), ("flip_down", TILE_DOWN_Y)):
            p = os.path.join(ref_dir, "time", f"{name}_{ch}.png")
            tw, th, tile = load_rgba(p)
            blit(canvas, REF_W, REF_H, tile, tw, th, TILE_X[i], oy)
    return canvas


def mae(a, b, w, region, exclude=None):
    x0, y0, x1, y1 = region
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(w, x1), min(len(a) // (w * 3), y1)
    ex0, ey0, ex1, ey1 = exclude if exclude else (0, 0, 0, 0)
    total = n = 0
    worst = 0
    for y in range(y0, y1):
        base = y * w * 3
        inside_y = exclude and ey0 <= y < ey1
        for x in range(x0, x1):
            if inside_y and ex0 <= x < ex1:
                continue
            i = base + x * 3
            for c in range(3):
                d = abs(a[i + c] - b[i + c])
                total += d
                worst = max(worst, d)
            n += 3
    return (total / n if n else 0.0), worst


def write_png(path, rgb, w, h):
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{w}x{h}", "-i", "-", path],
        input=bytes(rgb), check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("render")
    ap.add_argument("--ref", default="reference/frames/clock")
    ap.add_argument("--time", default="0738")
    ap.add_argument("--write-ref")
    ap.add_argument("--write-diff")
    ap.add_argument("--gate", type=float, default=8.0,
                    help="per-region MAE ceiling; the default is a regression "
                         "guard set just above the current baseline, not a "
                         "claim of pixel-perfection")
    args = ap.parse_args()

    if not os.path.isdir(args.ref):
        sys.exit(f"reference dir not found: {args.ref}")

    ref = flatten(build_reference(args.ref, args.time), REF_W, REF_H)

    rw, rh, rend_rgba = load_rgba(args.render)
    if (rw, rh) != (REF_W, REF_H):
        sys.exit(f"render is {rw}x{rh}, expected {REF_W}x{REF_H}")
    rend = flatten(rend_rgba, rw, rh)

    if args.write_ref:
        write_png(args.write_ref, ref, REF_W, REF_H)
    if args.write_diff:
        d = bytearray(len(ref))
        for i in range(len(ref)):
            d[i] = min(255, abs(ref[i] - rend[i]) * 6)   # amplified
        write_png(args.write_diff, d, REF_W, REF_H)

    whole, _ = mae(ref, rend, REF_W, (0, 0, REF_W, REF_H))
    print(f"{'region':<14} {'MAE':>7} {'max':>5}")
    print(f"{'whole frame':<14} {whole:7.2f}")
    failed = []
    for name, (box, exclude) in REGIONS.items():
        m, worst = mae(ref, rend, REF_W, box, exclude)
        if name in GATED:
            flag = "  ok" if m <= args.gate else "  FAIL"
            if m > args.gate:
                failed.append(name)
        else:
            flag = "  (not gated: font substitution)"
        print(f"{name:<14} {m:7.2f} {worst:5d}{flag}")

    print()
    if failed:
        print(f"GATE FAILED on {', '.join(failed)} (threshold MAE <= {args.gate})")
        return 1
    print(f"GATE PASSED (all gated regions MAE <= {args.gate})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
