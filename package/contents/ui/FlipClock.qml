pragma ComponentBehavior: Bound

/*
 * FlipClock.qml — the whole 996 x 566 scene.
 *
 * Deliberately free of any org.kde.plasma import, so tools/Snap.qml can load it
 * under a bare qml6 for pixel-diffing. All Plasma coupling lives in main.qml.
 *
 * Everything is laid out in reference units (the 996x566 design space) scaled
 * by `u`. Nothing uses Item.scale: that would rasterise the text
 * once at base size and then magnify it.
 */
import QtQuick
import Qt5Compat.GraphicalEffects
import "Style.js" as S

Item {
    id: scene

    // ---- inputs
    property string hours: "00"
    property string minutes: "00"
    property string dateText: ""
    property string alarmText: ""
    property bool animate: true

    property bool showPanel: true
    property bool showStrips: true

    // Read-only handles for the deterministic documentation capture harness.
    // They do not participate in normal applet operation.
    property alias hourCardItem: hourCard
    property alias minuteCardItem: minuteCard

    // weather (fed by the Plasma wrapper in main.qml)
    property bool hasWeather: false
    property string wxLocation: ""
    property string wxCondition: ""
    property string wxTemperature: ""
    property string wxRange: ""
    property string wxIcon: ""
    property string wxVariationKey: ""

    implicitWidth: S.REF_W
    implicitHeight: S.REF_H

    readonly property real u: Math.min(width / S.REF_W, height / S.REF_H)
    readonly property string digitFamily:
        fontLoader.status === FontLoader.Ready ? fontLoader.name : S.FONT_FAMILY

    FontLoader {
        id: fontLoader
        source: Qt.resolvedUrl("../fonts/RobotoCondensed-Variable.ttf")
    }

    // The reference box, centred in whatever we are given. No clip anywhere:
    // a clipping ancestor would chop the cards' RectangularGlow shadows.
    Item {
        id: stage

        width: S.REF_W * scene.u
        height: S.REF_H * scene.u
        anchors.centerIn: parent

        // ---- the translucent weather slab the cards sit on
        Item {
            id: panel

            visible: scene.showPanel
            x: S.PANEL_X * scene.u
            y: S.PANEL_Y * scene.u
            width: S.PANEL_W * scene.u
            height: S.PANEL_H * scene.u

            // The body is a flat 50% wash made of two parts.
            //
            // 1. A purely VERTICAL ramp: measured, it is identical at x=5 and
            //    x=960, and falls almost perfectly linearly from #FCFCFC at y=58
            //    to #3F3F3F at y=257, then off a cliff to black over four units.
            //    Curving it earlier (as a naive read of the midtones suggests)
            //    makes the whole upper panel visibly too dark.
            //
            // 2. Below that it stays black at the left and right edges, and the
            //    familiar lift toward the bottom is NOT part of the vertical ramp
            //    at all -- it is a wide elliptical glow centred on the panel's
            //    bottom centre. At y=470 the original runs 0 / 27 / 39 / 26 / 0
            //    across x = 120 / 300 / 500 / 700 / 900.
            Item {
                anchors.fill: parent
                opacity: S.PANEL_OPACITY

                Rectangle {
                    anchors.fill: parent
                    radius: S.PANEL_RADIUS * scene.u
                    antialiasing: true
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0000; color: "#fefefe" }
                        GradientStop { position: 0.0136; color: "#fcfcfc" }
                        GradientStop { position: 0.4000; color: "#3f3f3f" }
                        GradientStop { position: 0.4078; color: "#000000" }
                        GradientStop { position: 1.0000; color: "#000000" }
                    }
                }

                RadialGradient {
                    anchors.fill: parent
                    horizontalOffset: (S.PANEL_GLOW_CX - S.PANEL_W / 2) * scene.u
                    verticalOffset: (S.PANEL_GLOW_CY - S.PANEL_H / 2) * scene.u
                    horizontalRadius: S.PANEL_GLOW_RX * scene.u
                    verticalRadius: S.PANEL_GLOW_RY * scene.u
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.212) }
                        GradientStop { position: 0.30; color: Qt.rgba(1, 1, 1, 0.190) }
                        GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.150) }
                        GradientStop { position: 0.70; color: Qt.rgba(1, 1, 1, 0.095) }
                        GradientStop { position: 0.85; color: Qt.rgba(1, 1, 1, 0.045) }
                        GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0.000) }
                    }
                }
            }

            // The body supplies the panel edge.  A second opaque white "lip"
            // looked like a stray horizontal rule on translucent desktop
            // backgrounds, particularly when the widget is scaled down.
        }

        // ---- hours
        FlipCard {
            id: hourCard
            u: scene.u
            x: S.CARD_L_X * scene.u
            y: S.CARD_Y * scene.u
            digits: scene.hours
            flipMs: S.FLIP_MS_HOURS
            animate: scene.animate
            fontFamily: scene.digitFamily
        }

        // ---- minutes
        FlipCard {
            id: minuteCard
            u: scene.u
            x: S.CARD_R_X * scene.u
            y: S.CARD_Y * scene.u
            digits: scene.minutes
            flipMs: S.FLIP_MS_MINUTES
            animate: scene.animate
            fontFamily: scene.digitFamily
        }

        // ---- the strips printed on the blank lower third of each card.
        // These are drawn over the cards and deliberately do NOT flip, which is
        // how the original does it too.
        Text {
            visible: scene.showStrips && !scene.hasWeather && text.length > 0
            x: S.DATE_X * scene.u
            y: S.DATE_Y * scene.u
            text: scene.dateText
            color: S.grey(S.STRIP_COLOR, S.STRIP_ALPHA)
            font.pixelSize: Math.round(S.DATE_SIZE * scene.u)
            renderType: Text.CurveRendering
        }

        Text {
            visible: scene.showStrips && !scene.hasWeather && text.length > 0
            x: 0
            y: S.ALARM_Y * scene.u
            width: S.ALARM_X * scene.u
            horizontalAlignment: Text.AlignRight
            text: scene.alarmText
            color: S.grey(S.STRIP_COLOR, S.STRIP_ALPHA)
            font.pixelSize: Math.round(S.DATE_SIZE * scene.u)
            renderType: Text.CurveRendering
        }

        // ---- weather readout on the panel
        Item {
            anchors.fill: parent
            visible: scene.hasWeather

            WeatherIcon {
                x: (S.WX_ICON_CX - S.WX_ICON_W / 2) * scene.u
                y: (S.WX_ICON_CY - S.WX_ICON_H / 2) * scene.u
                width: S.WX_ICON_W * scene.u
                height: S.WX_ICON_H * scene.u
                conditionIcon: scene.wxIcon
                variationKey: scene.wxVariationKey
                animate: scene.animate
            }

            Text {
                x: S.WX_LOCATION_X * scene.u
                y: S.WX_LOCATION_Y * scene.u
                width: S.WX_LEFT_W * scene.u
                elide: Text.ElideRight
                text: scene.wxLocation
                color: S.grey(S.WX_TEXT_COLOR, S.WX_TEXT_ALPHA)
                font.pixelSize: Math.round(S.WX_LOCATION_SIZE * scene.u)
                renderType: Text.CurveRendering
            }

            Text {
                x: S.WX_CONDITION_X * scene.u
                y: S.WX_CONDITION_Y * scene.u
                width: S.WX_LEFT_W * scene.u
                elide: Text.ElideRight
                text: scene.wxCondition
                color: S.grey(S.WX_TEXT_COLOR, S.WX_TEXT_ALPHA)
                font.pixelSize: Math.round(S.WX_CONDITION_SIZE * scene.u)
                renderType: Text.CurveRendering
            }

            Text {
                x: 0
                y: S.WX_TEMP_Y * scene.u
                width: S.WX_TEMP_X * scene.u
                horizontalAlignment: Text.AlignRight
                text: scene.wxTemperature
                color: S.grey(S.WX_TEXT_COLOR, S.WX_TEXT_ALPHA)
                font.pixelSize: Math.round(S.WX_TEMP_SIZE * scene.u)
                renderType: Text.CurveRendering
            }

            Text {
                x: 0
                y: S.WX_RANGE_Y * scene.u
                width: S.WX_RANGE_X * scene.u
                horizontalAlignment: Text.AlignRight
                text: scene.wxRange
                color: S.grey(S.WX_TEXT_COLOR, S.WX_TEXT_ALPHA)
                font.pixelSize: Math.round(S.WX_RANGE_SIZE * scene.u)
                lineHeight: 1.0
                renderType: Text.CurveRendering
            }
        }
    }
}
