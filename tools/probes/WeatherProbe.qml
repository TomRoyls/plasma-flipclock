pragma ComponentBehavior: Bound

// Fixed weather state for checking the Sense-style lower-panel composition.
import QtQuick
import "../../package/contents/ui"

FlipClock {
    hours: "10"
    minutes: "08"
    animate: false
    showStrips: true
    dateText: "Wed, Jun 24"
    hasWeather: true
    wxLocation: "London"
    wxCondition: "Mostly Sunny"
    wxTemperature: "23°"
    wxRange: "H: 25°\nL: 18°"
    wxIcon: "weather-few-clouds"
    wxVariationKey: "2026-07-30|London"
}
