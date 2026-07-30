# Flip Clock for KDE Plasma 6

A skeuomorphic flip-clock widget for KDE Plasma 6, inspired by the classic HTC Sense
clock. Man, things used to have class back in the day.

![Flip Clock](docs/screenshot.png)

## Install

```bash
kpackagetool6 --type Plasma/Applet --install ./package
```

Add **Flip Clock** as a desktop widget. To update an existing installation:

```bash
kpackagetool6 --type Plasma/Applet --upgrade ./package
```

## Features

- Animated two-phase hour and minute card flips
- 12-hour and 24-hour time formats
- Optional date and custom text strips
- Configurable time zone and animation settings
- Measurement and rendering tools for development

## Development

```bash
export PATH=/usr/lib/qt6/bin:$PATH
qmllint -I /usr/lib/qt6/qml -I package/contents/ui package/contents/ui/*.qml
```

Render a fixed scene and compare it with the project’s pixel-diff tooling:

```bash
tools/snap.sh DiffProbe.qml 996 566 tools/out/render.png
tools/pixdiff.py tools/out/render.png --write-diff tools/out/diff.png
```

The weather display and animated weather sprites are not implemented yet.

## License

GPL-3.0-or-later. The bundled Roboto Condensed font is licensed under the SIL
Open Font License 1.1; see [LICENSE.txt](package/contents/fonts/LICENSE.txt).
