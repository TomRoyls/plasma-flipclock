pragma ComponentBehavior: Bound

/*
 * CardFace.qml — one flap of a card (the half above or below the crease).
 *
 * Card-local reference geometry (378 x 425, crease at y=202):
 *   upper flap  y   0..202   face inset to  4..374 x  20..202
 *   lower flap  y 202..425   face inset to  4..374 x 202..406
 *
 * The "stacked deck" edge at the top/bottom of each card is reproduced as what
 * the measured design shows: concentric rounded rects, each inset ~2
 * units horizontally and offset ~10 vertically, so only a thin band of each one
 * peeks out. Measured band at the card top is 4px white / 6px dark, twice over.
 *
 * The crease shading is folded into the face gradient rather than overlaid, so
 * there is no seam to align.
 */
import QtQuick
import "Style.js" as S

Item {
    id: face

    property real u: 1
    property bool upper: true
    property string digits: "00"
    property string fontFamily: S.FONT_FAMILY

    readonly property real radius: S.CARD_RADIUS * u
    // Deck slivers grow upward from an upper flap, downward from a lower one.
    readonly property int dir: upper ? -1 : 1

    // ---- the stacked deck.
    //
    // These live entirely INSIDE the card outline: the card's outermost edge is
    // its own top (or bottom), and the two slivers are progressively inset from
    // it, so only a ~10-unit band of each peeks out. Letting them overhang would
    // put white above the card where the original has only a faint shadow.
    //
    // Measured at the card top: 4 units white, 6 dark, 4 white, 6 dark, then the
    // face. At the sides the same rings show, but only ~1 unit wide each, so the
    // sliver body has to stay light -- a dark body would draw a heavy border
    // down the whole flank.
    Repeater {
        model: 2

        Rectangle {
            id: sliver
            required property int index

            readonly property real inset: index * 2 * face.u
            readonly property real shift: index * 10 * face.u

            z: -2 + index      // inner slivers must sit ON TOP of outer ones
            x: inset
            width: face.width - inset * 2
            y: face.upper ? shift : 0
            height: face.height - shift
            antialiasing: true

            topLeftRadius: face.upper ? face.radius - inset : 0
            topRightRadius: face.upper ? face.radius - inset : 0
            bottomLeftRadius: face.upper ? 0 : face.radius - inset
            bottomRightRadius: face.upper ? 0 : face.radius - inset

            // Seen edge-on down the flanks, each sliver shows a 1-unit white
            // highlight and then its darker body -- measured 255/230 then
            // 255/215 across x = 77..80. Without this the flanks lose the
            // stacked-card ring entirely.
            border.width: 1 * face.u
            border.color: "#ffffff"

            // Each visible band is 10 units: ~4 of white lip, a dark roll
            // bottoming out at ~#C1C1C1 around unit 5, then back to white by 10,
            // where the next sliver's own lip takes over.
            //
            // NB: a GradientStop's `parent` is the Gradient, not the Rectangle,
            // so these must be addressed through the delegate's id.
            function at(units) {
                const p = units * face.u / Math.max(1, height)
                return face.upper ? p : 1.0 - p
            }

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: sliver.at(0); color: "#ffffff" }
                GradientStop { position: sliver.at(3); color: "#fdfdfd" }
                GradientStop { position: sliver.at(5); color: "#c1c1c1" }
                GradientStop { position: sliver.at(7); color: "#cecece" }
                GradientStop { position: sliver.at(9); color: "#e2e2e2" }
                GradientStop { position: sliver.at(10.5); color: "#f4f4f4" }
                GradientStop { position: face.upper ? 1.0 : 0.0; color: "#ececec" }
            }
        }
    }

    // ---- the face plate: a pure vertical gradient, crease shading included
    Rectangle {
        id: plate

        x: S.FACE_INSET_X * face.u
        width: face.width - S.FACE_INSET_X * 2 * face.u
        y: face.upper ? S.FACE_TOP * face.u : 0
        height: face.upper
                ? (S.CREASE_Y - S.FACE_TOP) * face.u
                : (S.FACE_BOTTOM - S.CREASE_Y) * face.u
        antialiasing: true

        topLeftRadius: face.upper ? face.radius - S.FACE_INSET_X * face.u : 0
        topRightRadius: face.upper ? face.radius - S.FACE_INSET_X * face.u : 0
        bottomLeftRadius: face.upper ? 0 : face.radius - S.FACE_INSET_X * face.u
        bottomRightRadius: face.upper ? 0 : face.radius - S.FACE_INSET_X * face.u

        gradient: face.upper ? face.upperFace : face.lowerFace

        GlossyDigits {
            anchors.fill: parent
            u: face.u
            digits: face.digits
            upper: face.upper
            fontFamily: face.fontFamily
            // card-local y of this plate's top edge
            flapTop: face.upper ? S.FACE_TOP : S.CREASE_Y
        }
    }

    // Upper face, card-local 20..202. White at the top, easing to #E1E1E1, then
    // a 1px highlight lip and the dark crease core in the last two rows.
    property Gradient upperFace: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0000; color: "#ffffff" }
        GradientStop { position: 0.4000; color: "#f4f4f4" }
        GradientStop { position: 0.9835; color: "#e1e1e1" }
        GradientStop { position: 0.9890; color: "#ececec" }
        GradientStop { position: 0.9945; color: "#a1a1a1" }
        GradientStop { position: 1.0000; color: "#767676" }
    }

    // Lower face, card-local 202..406. Opens on the dark crease core, recovers to
    // white within ~7 units, darkens to #C3C3C3, then the bounce-light lift at
    // the bottom lip where the card catches reflected light.
    property Gradient lowerFace: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0000; color: "#767676" }
        GradientStop { position: 0.0049; color: "#a2a2a2" }
        GradientStop { position: 0.0098; color: "#c3c3c3" }
        GradientStop { position: 0.0147; color: "#d0d0d0" }
        GradientStop { position: 0.0196; color: "#dbdbdb" }
        GradientStop { position: 0.0245; color: "#e6e6e6" }
        GradientStop { position: 0.0294; color: "#f7f7f7" }
        GradientStop { position: 0.0343; color: "#fefefe" }
        GradientStop { position: 0.5000; color: "#e3e3e3" }
        GradientStop { position: 0.9412; color: "#c3c3c3" }
        GradientStop { position: 1.0000; color: "#efefef" }
    }
}
