pragma ComponentBehavior: Bound

// Visual check of the flip: rest, mid phase 1 (upper flap falling),
// and mid phase 2 (lower flap arriving). Angles are driven directly.
import QtQuick
import "Style.js" as S

Item {
    width: 1200; height: 470
    property bool animate: false
    Rectangle { anchors.fill: parent; color: "#5a6472" }

    Row {
        y: 15; x: 15; spacing: 18
        Repeater {
            model: [
                { up:   0, low:  0, flip: false, lbl: "rest" },
                { up: -38, low: 90, flip: true,  lbl: "phase 1" },
                { up: -90, low: 42, flip: true,  lbl: "phase 2" }
            ]
            FlipCard {
                required property var modelData
                u: 1.0
                fontFamily: fl.status === FontLoader.Ready ? fl.name : S.FONT_FAMILY
                Component.onCompleted: {
                    oldDigits = "07"
                    newDigits = "08"
                    upperAngle = modelData.up
                    lowerAngle = modelData.low
                    flipping   = modelData.flip
                }
            }
        }
    }
    FontLoader { id: fl; source: Qt.resolvedUrl("../fonts/RobotoCondensed-Variable.ttf") }
}
