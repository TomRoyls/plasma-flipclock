pragma ComponentBehavior: Bound

/*
 * WeatherIcon.qml — Sense-style weather assembled from independent textures.
 *
 * The original widget did not swap one monolithic icon for another. It layered
 * a sun or moon, several different cloud textures, and precipitation. Keeping
 * those parts separate also lets cloud count and placement vary from day to
 * day while staying stable for the whole day.
 */
import QtQuick
import "Style.js" as S

Item {
    id: root

    property string conditionIcon: ""
    property string variationKey: ""
    property bool animate: true

    readonly property string normalizedIcon: conditionIcon.toLowerCase()
    readonly property int weatherKind: {
        const name = normalizedIcon
        const night = name.indexOf("night") !== -1
                         || name.indexOf("moon") !== -1
        if (name.indexOf("dust") !== -1 || name.indexOf("sand") !== -1
                || name.indexOf("haze") !== -1)
            return 11
        if (name.indexOf("hail") !== -1 || name.indexOf("freezing") !== -1
                || name.indexOf("sleet") !== -1 || name.indexOf("mix") !== -1)
            return 10
        if (name.indexOf("wind") !== -1)
            return 9
        if (name.indexOf("fog") !== -1 || name.indexOf("mist") !== -1)
            return 8
        if (name.indexOf("storm") !== -1 || name.indexOf("thunder") !== -1)
            return 5
        if (name.indexOf("snow") !== -1)
            return 4
        if (name.indexOf("rain") !== -1 || name.indexOf("shower") !== -1)
            return 3
        if (night && (name.indexOf("few-cloud") !== -1
                      || name.indexOf("partly") !== -1
                      || name.indexOf("cloud") !== -1))
            return 7
        if (night && (name.indexOf("clear") !== -1
                      || name.indexOf("fair") !== -1))
            return 6
        if (name.indexOf("few-cloud") !== -1 || name.indexOf("partly") !== -1)
            return 1
        if (name.indexOf("clear") !== -1 || name.indexOf("sun") !== -1)
            return 0
        // Unknown and unavailable icons use the quiet cloud rather than a
        // visually unrelated high-drama substitute.
        return 2
    }

    function hashString(value) {
        let hash = 2166136261
        for (let i = 0; i < value.length; ++i) {
            hash ^= value.charCodeAt(i)
            hash = Math.imul(hash, 16777619)
        }
        return hash >>> 0
    }

    readonly property int variation:
        hashString(variationKey + "|" + normalizedIcon)
    readonly property real jitterA: variation % 29 - 14
    readonly property real jitterB: (variation >>> 5) % 35 - 17
    readonly property bool alternateCloud: ((variation >>> 11) & 1) !== 0
    readonly property real iu: Math.min(width / 440, height / 320)

    property real reveal: 1.0
    property real drift: 0.0

    function revealIcon() {
        if (!animate) {
            reveal = 1
            drift = 0
            return
        }
        revealAnimation.restart()
    }

    onConditionIconChanged: revealIcon()
    Component.onCompleted: revealIcon()

    component AtlasPart: Image {
        required property int cell

        source: Qt.resolvedUrl("../images/weather-parts-v2.png")
        sourceClipRect: Qt.rect((cell % 3) * 418,
                                Math.floor(cell / 3) * 418,
                                418, 418)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Item {
        id: composition

        width: 440 * root.iu
        height: 320 * root.iu
        anchors.centerIn: parent
        y: (parent.height - height) / 2 + root.drift * root.iu
        opacity: root.reveal

        // Celestial body. It sits behind every cloud layer.
        AtlasPart {
            cell: 0
            visible: root.weatherKind === 0 || root.weatherKind === 1
            x: ((root.weatherKind === 1 ? 52 : 91)
                + root.jitterA * 0.35) * root.iu
            y: (root.weatherKind === 1 ? -18 : 44) * root.iu
            width: (root.weatherKind === 1 ? 252 : 278) * root.iu
            height: width
        }

        AtlasPart {
            cell: 1
            visible: root.weatherKind === 6 || root.weatherKind === 7
            x: ((root.weatherKind === 7 ? 55 : 96)
                + root.jitterA * 0.3) * root.iu
            y: (root.weatherKind === 7 ? -20 : 35) * root.iu
            width: (root.weatherKind === 7 ? 245 : 270) * root.iu
            height: width
        }

        // A small rear cloud makes partly-cloudy states less symmetrical.
        AtlasPart {
            cell: 2
            visible: root.weatherKind === 1 || root.weatherKind === 7
                     || root.weatherKind === 2 || root.weatherKind === 8
            x: (118 + root.jitterB) * root.iu
            y: (63 + (root.alternateCloud ? 7 : -5)) * root.iu
            width: 276 * root.iu
            height: width
            opacity: root.weatherKind === 8 ? 0.58 : 0.86
        }

        // Wisps are an independent texture and get a second offset copy for
        // fog, wind, and fully overcast conditions.
        AtlasPart {
            cell: 4
            visible: root.weatherKind === 2 || root.weatherKind === 8
                     || root.weatherKind === 9
            x: (24 + root.jitterA) * root.iu
            y: (30 + root.jitterB * 0.3) * root.iu
            width: 368 * root.iu
            height: width
            opacity: root.weatherKind === 9 ? 0.60 : 0.72
        }

        AtlasPart {
            cell: 4
            visible: root.weatherKind === 8 || root.weatherKind === 9
            x: (72 - root.jitterB) * root.iu
            y: (75 - root.jitterA * 0.25) * root.iu
            width: 330 * root.iu
            height: width
            opacity: root.weatherKind === 8 ? 0.54 : 0.38
        }

        // The front cloud changes from bright layered cotton to a denser storm
        // texture. Day-keyed jitter changes the overlap without looking random
        // on every data refresh.
        AtlasPart {
            cell: root.weatherKind === 5 || root.weatherKind === 10 ? 5 : 3
            visible: root.weatherKind === 1 || root.weatherKind === 2
                     || root.weatherKind === 3 || root.weatherKind === 4
                     || root.weatherKind === 5 || root.weatherKind === 7
                     || root.weatherKind === 10
            x: (38 + root.jitterA * 0.65) * root.iu
            y: root.jitterB * 0.12 * root.iu
            width: 365 * root.iu
            height: width
        }

        AtlasPart {
            cell: 6
            visible: root.weatherKind === 3 || root.weatherKind === 5
            x: (70 + root.jitterB * 0.25) * root.iu
            y: 92 * root.iu
            width: 300 * root.iu
            height: width
            opacity: root.weatherKind === 5 ? 0.78 : 0.92
        }

        AtlasPart {
            cell: 7
            visible: root.weatherKind === 4 || root.weatherKind === 10
            x: (73 + root.jitterB * 0.25) * root.iu
            y: 89 * root.iu
            width: 294 * root.iu
            height: width
        }

        AtlasPart {
            cell: 8
            visible: root.weatherKind === 5
            x: (101 + root.jitterA * 0.25) * root.iu
            y: 76 * root.iu
            width: 255 * root.iu
            height: width
        }

        // Dust is the one state that does not share the cloud/celestial parts.
        Image {
            visible: root.weatherKind === 11
            anchors.fill: parent
            source: Qt.resolvedUrl("../images/weather/dust.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
    }

    ParallelAnimation {
        id: revealAnimation

        NumberAnimation {
            target: root
            property: "reveal"
            from: 0
            to: 1
            duration: S.WX_ENTRY_MS
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "drift"
            from: 12
            to: 0
            duration: S.WX_ENTRY_MS
            easing.type: Easing.OutCubic
        }
    }
}
