pragma ComponentBehavior: Bound

// Fixed-state scene used only by tools/pixdiff.py. Strips and weather off, so
// it matches what the original bg1.png + digit tiles actually contain.
import QtQuick
FlipClock {
    hours: "07"; minutes: "38"
    animate: false
    showStrips: false
    hasWeather: false
}
