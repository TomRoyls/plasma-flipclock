# CLAUDE.md

**Read `AGENTS.md` first.** It holds the full context, architecture and rules for
this repo, and is kept tool-agnostic so it does not drift from this file. Nothing
substantive is duplicated here.

A KDE Plasma 6 skeuomorphic flip-clock plasmoid, rebuilt from measured geometry.
Plasma 6.7 / Qt 6.11 on Arch.

## The five rules most easily broken

Repeated here because each one fails *silently* and costs an afternoon:

1. **Never ship anything from `reference/`** — local-only reference assets,
   gitignored. Measuring them to derive constants is the intended workflow;
   copying assets or tracing glyph outlines is not.
2. **`QT_QPA_PLATFORM=offscreen` cannot render this project.** It exits 0 and
   writes a valid PNG, but every `ShaderEffect` renders nothing, so the digits and
   card shadows vanish. Use `tools/snap.sh`, which renders on the live session.
   Never "fix" a blank render by changing the backend.
3. **No `clip: true` in the card hierarchy** — it silently eats the
   `RectangularGlow` shadows, which draw outside their own bounds by design.
4. **`FlipClock.qml` must stay free of `org.kde.plasma` imports** so the render
   harness can load it under bare `qml6`.
5. **Measure, don't eyeball.** Verify visual changes with `tools/pixdiff.py`.
   Do not raise its `--gate` to make a change pass.

## Quick commands

```bash
export PATH=/usr/lib/qt6/bin:$PATH        # Arch does not symlink qmllint
qmllint -I /usr/lib/qt6/qml -I package/contents/ui package/contents/ui/*.qml
kpackagetool6 --type Plasma/Applet --upgrade ./package
tools/snap.sh DiffProbe.qml 996 566 tools/out/render.png
tools/pixdiff.py tools/out/render.png --write-diff tools/out/diff.png
```

## Working notes

- Prefer `Read`/`Edit` over shell `sed` for QML and Python edits here — several
  files contain regex-hostile characters (gradient hex literals, `[wght]` in font
  filenames, QML binding braces).
- `tools/out/` and `reference/` are gitignored. A committed screenshot lives at
  `docs/screenshot.png`.
- The user is direct and technical, wants honest reporting of residual error, and
  wants honest reporting of residual error. State what is approximated and why
  rather than rounding up to "pixel-perfect".
