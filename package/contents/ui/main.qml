pragma ComponentBehavior: Bound

/*
 * main.qml — the Plasma applet wrapper.
 *
 * This is the only file that knows about Plasma. It sources the time and feeds
 * strings to FlipClock.qml, which is plain QtQuick so the render harness can
 * load it standalone.
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.clock
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

import "Style.js" as S

PlasmoidItem {
    id: root

    width: Kirigami.Units.gridUnit * 28
    height: width * S.REF_H / S.REF_W

    // The widget draws its own skeuomorphic body, so no Plasma frame behind it;
    // ConfigurableBackground still lets the user switch one back on.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: fullRepresentation

    toolTipMainText: Qt.formatTime(clock.dateTime, Qt.locale().timeFormat(Locale.ShortFormat))
    toolTipSubText: Qt.formatDate(clock.dateTime, Qt.locale().dateFormat(Locale.LongFormat))

    // Plasma 6.7's native clock. trackSeconds:false gives minute-resolution
    // updates aligned to the minute boundary by the C++ side -- exactly what a
    // flip clock wants, since the flip should fire ON the boundary.
    Clock {
        id: clock
        trackSeconds: false
    }

    // Leaving timeZone unset makes Clock follow the system zone, so only bind it
    // when the user has actually chosen one.
    Binding {
        target: clock
        property: "timeZone"
        value: Plasmoid.configuration.timeZone
        when: Plasmoid.configuration.timeZone !== ""
        restoreMode: Binding.RestoreBindingOrValue
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n
    }

    readonly property string hourString: {
        let h = clock.dateTime.getHours()
        if (!Plasmoid.configuration.use24hFormat) {
            h = h % 12
            if (h === 0)
                h = 12
        }
        // A blank leading tile reads better than a zero on a physical flip clock,
        // but the original padded, so it stays the default.
        return Plasmoid.configuration.showLeadingZero ? pad(h) : (h < 10 ? " " + h : "" + h)
    }

    readonly property string minuteString: pad(clock.dateTime.getMinutes())

    // Plasma5Support is part of a normal Plasma Desktop install. Its weather
    // engine lets us use the providers distributed by the system without a
    // dependency on KWeather or an external web API.
    readonly property string configuredWeatherSource: Plasmoid.configuration.weatherSource.trim()
    readonly property string discoveredWeatherSource: {
        for (const source of weather.sources) {
            if (source.indexOf("|weather|") !== -1)
                return source
        }
        return ""
    }
    readonly property string weatherSource: {
        if (Plasmoid.configuration.weatherUseAutomaticSource
                && discoveredWeatherSource.length > 0)
            return discoveredWeatherSource
        return configuredWeatherSource
    }
    // DataSource.valid is not a bindable Qt property in Plasma 6.  Do not use
    // it in this expression: it would evaluate false at startup and prevent the
    // weather UI from ever seeing the first provider update.  The revision is
    // advanced by newData below, which makes this binding reliably reactive.
    property int weatherRevision: 0
    readonly property var weatherData: {
        const revision = weatherRevision
        return weatherSource.length > 0 ? weather.data[weatherSource] : null
    }

    function weatherText(field) {
        if (!weatherData || weatherData[field] === undefined || weatherData[field] === null)
            return ""
        return String(weatherData[field])
    }

    function degreeText(value) {
        const text = value === undefined || value === null
                   ? "" : String(value).trim()
        if (text.length === 0 || text.indexOf("°") !== -1
                || !/[0-9]/.test(text))
            return text
        return text + "°"
    }

    function shortPlace(value) {
        const text = value === undefined || value === null
                   ? "" : String(value).trim()
        const comma = text.indexOf(",")
        return comma === -1 ? text : text.substring(0, comma).trim()
    }

    // The legacy engine's forecast contract is
    // period|icon|summary|high|low|precipitation. A few ions also publish
    // convenient top-level high/low fields, so prefer those and fall back to
    // day zero. Empty slots are significant (for example Tonight has no high).
    readonly property var weatherToday: weatherText("Short Forecast Day 0").split("|")
    readonly property string weatherHighRaw: {
        const direct = weatherText("High Temperature")
        return direct.length > 0 ? direct
                                 : (weatherToday.length > 3 ? weatherToday[3] : "")
    }
    readonly property string weatherLowRaw: {
        const direct = weatherText("Low Temperature")
        return direct.length > 0 ? direct
                                 : (weatherToday.length > 4 ? weatherToday[4] : "")
    }
    readonly property string weatherHigh: degreeText(weatherHighRaw)
    readonly property string weatherLow: degreeText(weatherLowRaw)
    readonly property string weatherRange: {
        if (weatherHigh.length === 0)
            return weatherLow.length > 0 ? "L: " + weatherLow : ""
        if (weatherLow.length === 0)
            return "H: " + weatherHigh
        return "H: " + weatherHigh + "\nL: " + weatherLow
    }

    Plasma5Support.DataSource {
        id: weather
        engine: "weather"
        // "ions" reports the locally installed providers. It also keeps the
        // engine alive so an already-active compatible source can be found.
        connectedSources: root.weatherSource.length > 0 ? ["ions", root.weatherSource] : ["ions"]
        interval: 30 * 60 * 1000
        onNewData: function(sourceName, data) {
            ++root.weatherRevision
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        Layout.minimumHeight: Layout.minimumWidth * S.REF_H / S.REF_W
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Layout.preferredWidth * S.REF_H / S.REF_W

        FlipClock {
            anchors.fill: parent

            hours: root.hourString
            minutes: root.minuteString
            animate: Plasmoid.configuration.animationsEnabled

            showPanel: Plasmoid.configuration.showPanel
            showStrips: Plasmoid.configuration.showDateStrip

            dateText: Plasmoid.configuration.showDateStrip
                      ? Qt.formatDate(clock.dateTime, Plasmoid.configuration.dateFormat)
                      : ""
            alarmText: Plasmoid.configuration.rightStripText

            // Show the selected place and a neutral icon immediately. Weather
            // ions can take a moment to fetch their first update; hiding the
            // whole lower panel until then makes a successful selection look
            // indistinguishable from a broken one.
            hasWeather: Plasmoid.configuration.showWeather
                        && root.weatherSource.length > 0
            // Some ions omit Place from otherwise valid weather updates. Keep
            // the selected location visible instead of rendering a blank slot.
            wxLocation: root.shortPlace(root.weatherText("Place").length > 0
                        ? root.weatherText("Place")
                        : Plasmoid.configuration.weatherLocation)
            wxCondition: root.weatherText("Current Conditions").length > 0
                         ? root.weatherText("Current Conditions")
                         : (root.weatherData ? "" : i18n("Loading weather…"))
            wxTemperature: root.degreeText(root.weatherText("Temperature"))
            wxRange: root.weatherRange
            wxIcon: root.weatherText("Condition Icon")
            wxVariationKey: Qt.formatDate(clock.dateTime, "yyyy-MM-dd")
                            + "|" + wxLocation
        }
    }
}
