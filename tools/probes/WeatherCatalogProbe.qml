pragma ComponentBehavior: Bound

// All freedesktop-name mappings in one fixed scene. This is development-only;
// the package ships the illustrations and WeatherIcon, not this probe.
import QtQuick
import "../../package/contents/ui"

Rectangle {
    width: 1200
    height: 900
    color: "#525665"
    property bool animate: false

    Grid {
        anchors.centerIn: parent
        columns: 4
        spacing: 0

        Repeater {
            model: [
                "weather-clear",
                "weather-few-clouds",
                "weather-clouds",
                "weather-showers",
                "weather-snow",
                "weather-storm",
                "weather-clear-night",
                "weather-few-clouds-night",
                "weather-fog",
                "weather-windy",
                "weather-freezing-rain",
                "weather-dust"
            ]

            Item {
                id: cell
                required property string modelData
                width: 290
                height: 285

                WeatherIcon {
                    x: 0
                    y: 0
                    width: 290
                    height: 235
                    conditionIcon: cell.modelData
                    animate: false
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 244
                    text: cell.modelData
                    color: "white"
                    font.pixelSize: 18
                }
            }
        }
    }
}
