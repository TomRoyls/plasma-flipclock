.pragma library

/*
 * Style.js — every geometric and colour constant for the flip clock.
 *
 * All lengths are in REFERENCE UNITS: the 996 x 566 design space. Consumers
 * multiply by the unit scalar `u = min(width/996, height/566)`.
 *
 * These numbers were measured with an ffmpeg -> raw RGBA -> pixel-probe pass.
 */

// ---------------------------------------------------------------- content box
var REF_W = 996
var REF_H = 566
var ASPECT = REF_W / REF_H

// -------------------------------------------------------------- weather panel
// Full-width translucent slab the cards sit on. Uniform 50% alpha; the gradient
// runs near-white at the top, through pure black, back up to a dark grey.
var PANEL_X = 0
var PANEL_Y = 51
var PANEL_W = 996
var PANEL_H = 515           // 51 .. 566
var PANEL_RADIUS = 33
var PANEL_OPACITY = 0.50
var PANEL_TOP_HILITE = "#ffffff"
var PANEL_TOP_HILITE_ALPHA = 0.855   // 1px line at y=53

// The lift toward the bottom of the panel is a wide elliptical glow, not part
// of the vertical ramp. Centre is at the panel's bottom centre; the radii were
// solved from the measured iso-value points (0,186) and (298,96).
var PANEL_GLOW_CX = 498     // panel-local
var PANEL_GLOW_CY = 515     // panel-local, i.e. on the bottom edge
var PANEL_GLOW_RX = 374
var PANEL_GLOW_RY = 200

// ------------------------------------------------------------------- the cards
var CARD_W = 378
var CARD_H = 425
var CARD_Y = 13
var CARD_L_X = 77
var CARD_R_X = 541          // pitch 464
var CARD_RADIUS = 30

// Card-local geometry -------------------------------------------------------
var FACE_INSET_X = 4
var FACE_TOP = 20
var FACE_BOTTOM = 406
var CREASE_Y = 202          // centre of the 2px dark hairline

var UPPER_TOP = FACE_TOP            // 20
var UPPER_H = CREASE_Y - FACE_TOP   // 182
var LOWER_TOP = CREASE_Y            // 202
var LOWER_H = FACE_BOTTOM - CREASE_Y // 204

// Digit tiles: two per card, 160 wide, 5 apart.
var TILE_W = 160
var TILE_GAP = 5
var TILE1_X = 27
var TILE2_X = 192

// Glyph ink box within the card.
var GLYPH_TOP = 71
var GLYPH_BOTTOM = 341
var GLYPH_H = 270           // cap height

// Target glyph metrics measured off the original typeface.
var GLYPH_ASPECT = 0.563    // ink width / ink height
var GLYPH_STROKE = 0.130    // stroke thickness / ink height

// ------------------------------------------------------------------- the font
// Bundled Roboto Condensed (SIL OFL, see contents/fonts/LICENSE.txt), chosen by
// tools/fontscore.py: shape IoU 0.794 against the original glyphs, and once
// stretched by FONT_CONDENSE its stroke ratio lands on 0.133 vs the 0.130 target.
// Calibration constants are per 1.0 of font.pixelSize.
var FONT_FAMILY = "Roboto Condensed"
var FONT_WGHT = 400
var FONT_INK_RATIO = 0.7260   // ink height / pixelSize
var FONT_INK_TOP = 0.2142     // ink top, below the text origin / pixelSize
var FONT_CONDENSE = 1.0574    // horizontal stretch to reach GLYPH_ASPECT

// Derived, in reference units. pixelSize is an int in Qt, so round at use.
var FONT_PIXEL = GLYPH_H / FONT_INK_RATIO                 // ~371.9
var FONT_Y = GLYPH_TOP - FONT_INK_TOP * FONT_PIXEL        // ~-8.6, card-local

// ------------------------------------------------------------- face gradients
// Upper face: pure white at the top easing to light grey at the crease.
var UPPER_FACE_STOPS = [
    [0.0000, "#ffffff"],
    [1.0000, "#e1e1e1"]
]

// Lower face: near-white just under the crease, darkening, then a "bounce
// light" lift at the very bottom lip where the card catches reflected light.
var LOWER_FACE_STOPS = [
    [0.0000, "#fefefe"],
    [0.0294, "#fefefe"],
    [0.9412, "#c3c3c3"],
    [1.0000, "#efefef"]
]

// The crease: a hairline core with a fast dark ramp above and a soft ~7px
// recovery to white below. Values are card-local y -> grey.
var CREASE_BAND = [
    [200, "#ececec"],
    [201, "#a1a1a1"],
    [202, "#767676"],
    [203, "#a2a2a2"],
    [204, "#c3c3c3"],
    [205, "#d0d0d0"],
    [206, "#dbdbdb"],
    [207, "#e6e6e6"],
    [208, "#f7f7f7"],
    [209, "#fefefe"]
]

// ------------------------------------------------------------------ the bezel
// Sides are a tight 4px light/dark/light/dark ring. Top and bottom spread the
// same rings over ~20px, which reads as a stack of cards seen edge-on.
var BEZEL_RINGS = ["#ffffff", "#e6e6e6", "#ffffff", "#d8d8d8"]
var BEZEL_SIDE = 4
var BEZEL_TOPBOTTOM = 20

// ------------------------------------------------------------------ the shadow
var SHADOW_COLOR = "#000000"
var SHADOW_OPACITY = 0.45
var SHADOW_BLUR = 24
var SHADOW_Y_OFFSET = 6

// -------------------------------------------------------------- digit "gloss"
// The signature detail: the glyph fill is a vertical gradient that RESTARTS at
// the crease, so each half looks independently lit. The measured ramps live as
// literal GradientStops in GlossyDigits.qml (paint belongs with the painting);
// these are the anchor points they are built from, in card-local units.
var GLOSS_UPPER_FROM = GLYPH_TOP    // 71  — gradient starts at the glyph top
var GLOSS_UPPER_TO = 172            //     — pure black from here down
var GLOSS_LOWER_FROM = CREASE_Y     // 202 — restarts right at the crease
var GLOSS_LOWER_TO = 337

// ------------------------------------------------------------------ animation
// Two-phase flip, OutBounce on both phases. The whole two-digit card flips as
// one panel — hours on the hour, minutes on the minute.
var FLIP_MS_HOURS = 1000
var FLIP_MS_MINUTES = 800
// Perspective strength for the Matrix4x4 term; larger denominator = flatter.
var PERSPECTIVE = 1400

// ---------------------------------------------------------------- static text
// Printed on the blank strip below the digits. These do NOT flip.
var DATE_X = 102            // absolute, left-aligned
var DATE_Y = 374
var DATE_SIZE = 38
var STRIP_COLOR = "#000000"
var STRIP_ALPHA = 0.588

var ALARM_X = 894           // absolute, right-aligned
var ALARM_Y = 374

// -------------------------------------------------------------- weather text
var WX_TEXT_COLOR = "#ffffff"
var WX_TEXT_ALPHA = 0.98

// These four text anchors come directly from the 996x566 theme manifest. Keep
// them in reference space: the deliberately oversized temperature is part of
// the original lower-panel hierarchy.
var WX_LOCATION_X = 55
var WX_LOCATION_Y = 452
var WX_LOCATION_SIZE = 36

var WX_CONDITION_X = 55
var WX_CONDITION_Y = 502
var WX_CONDITION_SIZE = 36
var WX_LEFT_W = 360

var WX_TEMP_X = 815         // right-aligned, leaving room for the H/L stack
var WX_TEMP_Y = 446
var WX_TEMP_SIZE = 92

var WX_RANGE_X = 940        // right-aligned
var WX_RANGE_Y = 453
var WX_RANGE_SIZE = 30

// WeatherIcon composes independently cropped textures inside this slot. Its
// centre is slightly above the text baseline, as in the Sense reference.
var WX_ICON_CX = 498
var WX_ICON_CY = 425
var WX_ICON_W = 440
var WX_ICON_H = 320
var WX_ENTRY_MS = 750       // drift-in + fade for every sprite

// ------------------------------------------------------------------- helpers
function grey(hex, alpha) {
    // "#rrggbb" + alpha -> "#aarrggbb" for QML colour strings.
    var a = Math.round(Math.max(0, Math.min(1, alpha)) * 255)
    var ah = (a < 16 ? "0" : "") + a.toString(16)
    return "#" + ah + hex.substring(1)
}
