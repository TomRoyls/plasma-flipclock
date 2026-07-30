pragma ComponentBehavior: Bound

/*
 * GlossyDigits.qml — the two digits of one card, filled with the gloss gradient,
 * cropped to a single flap.
 *
 * Instantiated twice per card (upper flap, lower flap). Both instances lay the
 * glyphs out in the SAME card-local coordinate space and merely shift them by
 * the flap's top, so the two halves of a digit line up exactly across the crease.
 *
 * Cropping is done by the ShaderEffectSource texture bound that OpacityMask's
 * SourceProxy creates, NOT by clip:true — a clip ancestor would silently chop
 * the RectangularGlow card shadows.
 *
 * Masking uses Qt5Compat OpacityMask because it is an exact alpha multiply
 * (As * Am). MultiEffect's maskSource runs the mask through a smoothstep band,
 * which hard-steps glyph edges and destroys text antialiasing.
 */
import QtQuick
import Qt5Compat.GraphicalEffects
import "Style.js" as S

Item {
    id: root

    property real u: 1
    property string digits: "00"
    property bool upper: true
    /* card-local y of this flap's top edge */
    property real flapTop: 0
    property string fontFamily: S.FONT_FAMILY

    // ---- the alpha mask: glyphs in card-local space, shifted into flap space.
    // Anything outside this Item is discarded by the proxy texture -> the crease cut.
    Item {
        id: glyphMask
        anchors.fill: parent
        visible: false

        Repeater {
            model: 2

            Text {
                required property int index

                readonly property real tileW: S.TILE_W * root.u

                x: (index === 0 ? S.TILE1_X : S.TILE2_X) * root.u
                y: (S.FONT_Y - root.flapTop) * root.u
                width: tileW
                horizontalAlignment: Text.AlignHCenter

                text: root.digits.charAt(index)
                color: "white"            // only the alpha is sampled

                // CurveRendering rasterises the true outline per fragment. The
                // default distance-field path is cached at a small base size and
                // magnified, which visibly rounds corners at this glyph size.
                renderType: Text.CurveRendering
                antialiasing: true

                font.family: root.fontFamily
                font.pixelSize: Math.round(S.FONT_PIXEL * root.u)   // pixelSize is an int
                font.variableAxes: ({ "wght": S.FONT_WGHT })

                // Stretch each digit about its own centre to hit the original's
                // 0.563 ink aspect. Scaling the whole row instead would move the
                // two tiles apart.
            transform: Scale {
                id: digitScale
                origin.x: S.TILE_W * root.u / 2
                    xScale: S.FONT_CONDENSE
                }
            }
        }
    }

    // ---- the paint: the gloss ramp, spanning THIS flap only, so it restarts at
    // the crease for free. Stops are measured from the reference frame.
    Rectangle {
        id: glossFill
        anchors.fill: parent
        visible: false
        gradient: root.upper ? root.upperGloss : root.lowerGloss
    }

    // Upper flap, card-local 20..202 (h 182): ramp anchored at the glyph top
    // (y=71 -> 0.280) reaching pure black at y=172 (-> 0.835).
    property Gradient upperGloss: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0000; color: "#9e9e9e" }
        GradientStop { position: 0.2802; color: "#9e9e9e" }
        GradientStop { position: 0.3407; color: "#8e8e8e" }
        GradientStop { position: 0.4066; color: "#767676" }
        GradientStop { position: 0.4725; color: "#5b5b5b" }
        GradientStop { position: 0.5385; color: "#404040" }
        GradientStop { position: 0.6044; color: "#292929" }
        GradientStop { position: 0.6703; color: "#1a1a1a" }
        GradientStop { position: 0.7363; color: "#0c0c0c" }
        GradientStop { position: 0.8022; color: "#010101" }
        GradientStop { position: 0.8352; color: "#000000" }
        GradientStop { position: 1.0000; color: "#000000" }
    }

    // Lower flap, card-local 202..406 (h 204): restarts at the crease, black by y=337.
    property Gradient lowerGloss: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0000; color: "#a2a2a2" }
        GradientStop { position: 0.0147; color: "#a0a0a0" }
        GradientStop { position: 0.0735; color: "#939393" }
        GradientStop { position: 0.1324; color: "#797979" }
        GradientStop { position: 0.1912; color: "#595959" }
        GradientStop { position: 0.2500; color: "#3a3a3a" }
        GradientStop { position: 0.3088; color: "#232323" }
        GradientStop { position: 0.3676; color: "#161616" }
        GradientStop { position: 0.4265; color: "#0e0e0e" }
        GradientStop { position: 0.4853; color: "#080808" }
        GradientStop { position: 0.5441; color: "#050505" }
        GradientStop { position: 0.6029; color: "#020202" }
        GradientStop { position: 0.6618; color: "#000000" }
        GradientStop { position: 1.0000; color: "#000000" }
    }

    // ---- paint x glyph alpha. All three items are anchors.fill of the same
    // parent: Qt5Compat effects sample source and mask in the EFFECT's normalised
    // coordinates, so a size mismatch would silently stretch the mask.
    OpacityMask {
        anchors.fill: parent
        source: glossFill
        maskSource: glyphMask
        cached: false           // digits change; caching would freeze them
    }
}
