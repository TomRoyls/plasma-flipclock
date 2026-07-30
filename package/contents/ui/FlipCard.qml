pragma ComponentBehavior: Bound

/*
 * FlipCard.qml — one two-digit card (HH or MM) and its flip.
 *
 * The original flips the WHOLE card as one panel, not each digit separately:
 * both hour digits live on one panel and both minute digits on another, so the
 * hour card turns on the hour and the minute card on the minute.
 *
 * Four layers, exactly as the original composes them:
 *   static upper   NEW digits, revealed as the flap falls away
 *   static lower   OLD digits, covered as the new flap lands
 *   falling upper  OLD digits, 0 -> -90 about its bottom edge (the crease)
 *   arriving lower NEW digits, +90 -> 0 about its top edge (the crease)
 *
 * Timing is the original's: two equal phases, Easing.OutBounce on both, the
 * second flap held at +90 through phase one.
 */
import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import "Style.js" as S

Item {
    id: card

    property real u: 1
    /* target value; assigning a new one triggers the flip */
    property string digits: "00"
    property int flipMs: S.FLIP_MS_MINUTES
    property bool animate: true
    property string fontFamily: S.FONT_FAMILY

    implicitWidth: S.CARD_W * u
    implicitHeight: S.CARD_H * u
    width: implicitWidth
    height: implicitHeight

    // ---- flip state
    property string newDigits: "00"      // what the upper half shows
    property string oldDigits: "00"      // what the lower half shows until it lands
    property real upperAngle: 0
    property real lowerAngle: 0
    property bool flipping: false

    // The crease must land on a whole device pixel, and BOTH halves must use the
    // same number, or the glyph gains or loses a row where they meet.
    readonly property real dpr: Screen.devicePixelRatio
    readonly property real creaseY: Math.round(S.CREASE_Y * u * dpr) / dpr
    readonly property real cameraDist: height * 2.2

    // Projective term: w = 1 + k*z with k = -1/d, so nearer (z>0) renders larger.
    // Applied on the card so both flaps share one vanishing point; z==0 children
    // (the static halves and the shadow) come out untouched.
    function perspective(cx, cy, d) {
        const k = -1.0 / d
        return Qt.matrix4x4(1, 0, cx * k, 0,
                            0, 1, cy * k, 0,
                            0, 0, 1, 0,
                            0, 0, k, 1)
    }

    transform: Matrix4x4 {
        matrix: card.perspective(card.width / 2, card.creaseY, card.cameraDist)
    }

    onDigitsChanged: flipTo(digits)

    Component.onCompleted: {
        newDigits = digits
        oldDigits = digits
    }

    function flipTo(next) {
        if (next === newDigits)
            return
        if (!animate) {
            newDigits = next
            oldDigits = next
            return
        }
        if (flipAnim.running) {          // catch up if we are still mid-flip
            flipAnim.complete()
            oldDigits = newDigits
        }
        newDigits = next
        upperAngle = 0
        lowerAngle = 90
        flipAnim.restart()
    }

    // ---- the shadow. One blur cannot be strong below, weaker at the sides and
    // faint above, so stack three analytic glows. cached: true is free here
    // because the card body never moves, only the flaps rotate.
    // NB: cornerRadius must NOT be inflated by glowRadius. RectangularGlow
    // expands its own bounds by glowRadius*2 + cornerRadius*2, so adding the two
    // together made each glow reach ~156 units past the card -- dark haze filled
    // the gap between the cards, where the original has none at all.
    readonly property real shadowCorner: S.CARD_RADIUS * u

    RectangularGlow {                       // tight contact shadow at the edges
        z: -10
        x: 0; y: 3 * card.u
        width: card.width; height: card.height
        glowRadius: 8 * card.u
        spread: 0.35
        color: Qt.rgba(0, 0, 0, 0.42)
        cornerRadius: card.shadowCorner
        cached: true
    }
    RectangularGlow {                       // the drop, pushed down
        z: -10
        x: 0; y: S.SHADOW_Y_OFFSET * card.u
        width: card.width; height: card.height
        glowRadius: 16 * card.u
        spread: 0.10
        color: Qt.rgba(0, 0, 0, S.SHADOW_OPACITY)
        cornerRadius: card.shadowCorner
        cached: true
    }

    // ---- layer 1: static upper, NEW digits
    CardFace {
        u: card.u
        upper: true
        digits: card.newDigits
        fontFamily: card.fontFamily
        width: card.width
        height: card.creaseY
        z: 0
    }

    // ---- layer 2: static lower, OLD digits
    CardFace {
        u: card.u
        upper: false
        digits: card.oldDigits
        fontFamily: card.fontFamily
        y: card.creaseY
        width: card.width
        height: card.height - card.creaseY
        z: 0
    }

    // ---- layer 3: the falling upper flap, OLD digits
    CardFace {
        id: fallingUpper
        u: card.u
        upper: true
        digits: card.oldDigits
        fontFamily: card.fontFamily
        width: card.width
        height: card.creaseY
        z: 2
        // Qt Quick does no back-face culling: past -90 this would render mirrored.
        visible: card.flipping && card.upperAngle > -89.9
        layer.enabled: card.flipping
        layer.smooth: true
        layer.mipmap: true

        transform: Rotation {
            axis { x: 1; y: 0; z: 0 }
            origin.x: fallingUpper.width / 2
            origin.y: fallingUpper.height      // bottom edge == the crease
            angle: card.upperAngle
        }
    }

    // ---- layer 4: the arriving lower flap, NEW digits
    CardFace {
        id: arrivingLower
        u: card.u
        upper: false
        digits: card.newDigits
        fontFamily: card.fontFamily
        y: card.creaseY
        width: card.width
        height: card.height - card.creaseY
        z: 2
        visible: card.flipping && card.lowerAngle < 89.9
        layer.enabled: card.flipping
        layer.smooth: true
        layer.mipmap: true

        transform: Rotation {
            axis { x: 1; y: 0; z: 0 }
            origin.x: arrivingLower.width / 2
            origin.y: 0                        // top edge == the crease
            angle: card.lowerAngle
        }
    }

    // ---- the flip. Both variables run in parallel; the second is simply held
    // through phase one, which is how the original expresses it.
    ParallelAnimation {
        id: flipAnim

        onStarted: card.flipping = true
        onFinished: {
            card.flipping = false
            card.oldDigits = card.newDigits
            card.upperAngle = 0
            card.lowerAngle = 0
        }

        NumberAnimation {
            target: card
            property: "upperAngle"
            from: 0; to: -90
            duration: card.flipMs / 2
            easing.type: Easing.OutBounce
        }

        SequentialAnimation {
            PauseAnimation { duration: card.flipMs / 2 }
            NumberAnimation {
                target: card
                property: "lowerAngle"
                from: 90; to: 0
                duration: card.flipMs / 2
                easing.type: Easing.OutBounce
            }
        }
    }
}
