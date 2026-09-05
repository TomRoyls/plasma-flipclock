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

    // Initial default size only — the desktop containment owns the actual
    // geometry and persists user resizes in plasma-org.kde.plasma.desktop-
    // appletsrc under per-resolution ItemGeometries-<W>x<H> keys.
    //
    // That keying is the reboot trap: at a cold boot the screen scale factor
    // can be applied by kscreen only after plasmashell has already read the
    // layout, so the containment looks up a key from a different logical
    // resolution, finds nothing, and drops the widget back to its default
    // size (KDE bugs 413645 / 425368 describe the same class of failure).
    // A warm plasmashell restart keeps a stable geometry, which is why the
    // size survives restarts but not reboots.
    //
    // Mitigation: remember the last size in the plasmoid's own config, which
    // is not keyed by resolution, and feed it back as the default here. The
    // containment's own restore still wins whenever it works because it sizes
    // the container directly. The gridUnit expression is only evaluated
    // before the first resize is saved; once a config value exists, QML's
    // dynamic dependency tracking no longer watches gridUnit, so a late
    // font-metric change at boot cannot re-fire these bindings and clobber
    // the restored geometry either.
    width: Plasmoid.configuration.widgetWidth > 0
            ? Plasmoid.configuration.widgetWidth
            : Kirigami.Units.gridUnit * 28
    height: Plasmoid.configuration.widgetHeight > 0
             ? Plasmoid.configuration.widgetHeight
             : Kirigami.Units.gridUnit * 28 * S.REF_H / S.REF_W

    // --- remember user resizes in the applet config -------------------------
    // The containment resizes the applet root to whatever it lays out, so
    // watching width/height here records the user's final size.
    //
    // Two hazards this code must survive:
    // 1. The startup window: the containment's restore (and any boot-time
    //    relayout caused by a late kscreen scale change) lands in the first
    //    seconds. Changes inside the guard window are observed but not saved;
    //    when the guard expires the settled size is recorded once.
    // 2. Corruption feedback: if the boot race resets the widget to the
    //    pristine default size, blindly saving that value would overwrite the
    //    remembered good size and make every subsequent boot start from the
    //    default. A size that matches the default within a few pixels is
    //    therefore never persisted as a "remembered" size.
    //
    // Everything is logged with the FLIPCLOCK: prefix so a failing boot can
    // be diagnosed from the journal:
    //   journalctl --user -u plasma-plasmashell.service -b --no-pager | grep FLIPCLOCK
    readonly property string logTag: "FLIPCLOCK:"
    readonly property real pristineWidth: Kirigami.Units.gridUnit * 28
    readonly property real pristineHeight: pristineWidth * S.REF_H / S.REF_W
    property bool sizeRestoreGuard: true
    property real lastLoggedW: -1
    property real lastLoggedH: -1

    function logSize(what) {
        if (Math.abs(width - lastLoggedW) > 0.5 || Math.abs(height - lastLoggedH) > 0.5) {
            print(logTag, what + ":",
                  lastLoggedW.toFixed(1) + "x" + lastLoggedH.toFixed(1),
                  "->",
                  width.toFixed(1) + "x" + height.toFixed(1))
            lastLoggedW = width
            lastLoggedH = height
        }
    }

    Component.onCompleted: {
        lastLoggedW = width
        lastLoggedH = height
        print(logTag, "boot; config:",
              Plasmoid.configuration.widgetWidth + "x" + Plasmoid.configuration.widgetHeight,
              "| root:", width.toFixed(1) + "x" + height.toFixed(1),
              "| gridUnit:", Kirigami.Units.gridUnit)
    }

    Timer {
        id: sizeRestoreGuardTimer
        interval: 15000
        running: true
        repeat: false
        onTriggered: {
            root.sizeRestoreGuard = false
            root.logSize("guard expired")
            root.sizeSelfHeal("guard")
            sizeSaveTimer.restart()
        }
    }

    // The containment sizes the applet root imperatively, which destroys the
    // declarative width/height bindings. When a boot-time relayout drops the
    // widget back to the pristine default even though a real user size is
    // remembered, nothing in the declarative layer can win it back — so this
    // watchdog re-asserts the remembered size imperatively, at guard expiry
    // and periodically afterwards. Every heal is logged: on a machine where
    // the containment keeps resetting the widget, the journal will show the
    // resets happening (and their timing) even if the re-assert does not
    // visually stick, which is itself the diagnosis.
    //
    // Trade-off: a user who deliberately resizes back to the default and
    // expects THAT to persist will be snapped to the remembered size again,
    // because a pristine size is never recorded (see isPristineish). Remove
    // the remembered size by resetting the widget instead.
    function sizeSelfHeal(why) {
        const cw = Plasmoid.configuration.widgetWidth
        const ch = Plasmoid.configuration.widgetHeight
        if (cw <= 0 || ch <= 0)
            return
        if (!isPristineish(width, height))
            return
        if (Math.abs(width - cw) <= 2 && Math.abs(height - ch) <= 2)
            return
        print(logTag, "self-heal (" + why + "): default " +
              width.toFixed(1) + "x" + height.toFixed(1) +
              " -> remembered " + cw + "x" + ch)
        width = cw
        height = ch
    }

    Timer {
        id: sizeWatchdogTimer
        interval: 20000
        running: false
        repeat: true
        triggeredOnStart: false
        onTriggered: root.sizeSelfHeal("watchdog")
    }

    // The containment grid-snaps the pristine default (e.g. 504x286 ->
    // 512x288), so the reset signature must be matched with a tolerance,
    // not exact equality: a couple of percent or one snap-grid step,
    // whichever is larger.
    function isPristineish(w, h) {
        const tolW = Math.max(8, pristineWidth * 0.02)
        const tolH = Math.max(8, pristineHeight * 0.02)
        return Math.abs(w - pristineWidth) <= tolW
                && Math.abs(h - pristineHeight) <= tolH
    }

    Timer {
        id: sizeSaveTimer
        interval: 800
        repeat: false
        onTriggered: {
            const w = Math.round(root.width)
            const h = Math.round(root.height)
            if (w <= 0 || h <= 0)
                return
            if (root.isPristineish(root.width, root.height)) {
                print(root.logTag, "NOT saving: size is the pristine default",
                      root.pristineWidth.toFixed(1) + "x" + root.pristineHeight.toFixed(1),
                      "(kept config:",
                      Plasmoid.configuration.widgetWidth + "x" + Plasmoid.configuration.widgetHeight + ")")
                return
            }
            if (Plasmoid.configuration.widgetWidth !== w
                    || Plasmoid.configuration.widgetHeight !== h) {
                print(root.logTag, "saving config:", w + "x" + h)
                Plasmoid.configuration.widgetWidth = w
                Plasmoid.configuration.widgetHeight = h
            }
        }
    }

    onWidthChanged: {
        logSize("resize")
        if (!sizeRestoreGuard)
            sizeSaveTimer.restart()
    }
    onHeightChanged: {
        logSize("resize")
        if (!sizeRestoreGuard)
            sizeSaveTimer.restart()
    }

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

    // Plasma 6.7's weather engine publishes a structured Forecast object
    // alongside the legacy flat-string keys. Different ions populate
    // different parts of the structure: wettercom only provides forecast
    // (currentDay), BBC only provides observations (lastObservation), and
    // DWD may provide both or neither depending on the location. Walk a
    // dot-separated path through the object tree so we can reach whichever
    // branch the ion actually filled.
    function weatherNested(path) {
        if (!weatherData)
            return ""
        let val = weatherData
        for (const part of path.split(".")) {
            if (val === null || val === undefined)
                return ""
            val = val[part]
        }
        if (val === undefined || val === null)
            return ""
        const s = String(val)
        return s.length > 0 ? s : ""
    }

    function degreeText(value) {
        const text = value === undefined || value === null
                   ? "" : String(value).trim()
        if (text.length === 0 || text.indexOf("°") !== -1
                || !/[0-9]/.test(text))
            return text
        // Some ions (notably DWD) expose observations as floating-point
        // values. Stringifying one directly leaks its binary representation
        // into the UI (for example 18.79999237060547°). Keep one meaningful
        // decimal place, matching the forecast values supplied by the engine.
        const number = Number(value)
        if (isFinite(number)) {
            const rounded = Math.round(number * 10) / 10
            const precision = Math.abs(rounded - Math.round(rounded)) < 0.00001
                              ? 0 : 1
            return Qt.locale().toString(rounded, "f", precision) + "°"
        }
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
        if (direct.length > 0) return direct
        const structured = weatherNested("currentDay.normalHighTemp")
        if (structured.length > 0) return structured
        const lastDay = weatherNested("lastDay.normalHighTemp")
        if (lastDay.length > 0) return lastDay
        return weatherToday.length > 3 ? weatherToday[3] : ""
    }
    readonly property string weatherLowRaw: {
        const direct = weatherText("Low Temperature")
        if (direct.length > 0) return direct
        const structured = weatherNested("currentDay.normalLowTemp")
        if (structured.length > 0) return structured
        const lastDay = weatherNested("lastDay.normalLowTemp")
        if (lastDay.length > 0) return lastDay
        return weatherToday.length > 4 ? weatherToday[4] : ""
    }
    readonly property string weatherHigh: degreeText(weatherHighRaw) || "--"
    readonly property string weatherLow: degreeText(weatherLowRaw) || "--"
    readonly property string weatherRange: "H: " + weatherHigh + "\nL: " + weatherLow
    // Current temperature: ions without an observation endpoint (wettercom)
    // never populate this. Try the legacy flat key, the structured property,
    // and finally fall back to today's forecast high — a "best available"
    // number that is more useful than a bare placeholder.
    readonly property string weatherTempRaw: {
        const direct = weatherText("Temperature")
        if (direct.length > 0) return direct
        const structured = weatherNested("lastObservation.temperature")
        if (structured.length > 0) return structured
        return weatherHighRaw
    }
    // Wettercom may publish only its day-zero forecast summary/icon, rather
    // than a current-observation field. The legacy forecast contract supplies
    // both, so use it before showing an unavailable placeholder.
    readonly property string weatherCondition: {
        const current = weatherText("Current Conditions")
        if (current.length > 0) return current
        const structured = weatherNested("lastObservation.currentConditions")
        if (structured.length > 0) return structured
        return weatherToday.length > 2 ? weatherToday[2] : "--"
    }
    readonly property string weatherIcon: {
        const current = weatherText("Condition Icon")
        if (current.length > 0) return current
        const structured = weatherNested("lastObservation.conditionIcon")
        if (structured.length > 0) return structured
        return weatherToday.length > 1 && weatherToday[1].length > 0
               ? weatherToday[1] : "weather-clear-night"
    }

    function refreshWeather() {
        const source = root.weatherSource
        if (source.length === 0)
            return

        // Reconnecting a DataEngine source causes the provider to publish its
        // current data immediately instead of waiting for the 30-minute poll.
        weather.disconnectSource(source)
        weather.connectSource(source)
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
        // Independent, config-driven bindings (see root width/height comment).
        // The desktop containment reads these as size hints through
        // BasicAppletContainer when no saved geometry exists. Each dimension
        // reads its own config key — never the sibling property.
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10 * S.REF_H / S.REF_W
        Layout.preferredWidth: Plasmoid.configuration.widgetWidth > 0
                ? Plasmoid.configuration.widgetWidth
                : Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Plasmoid.configuration.widgetHeight > 0
                ? Plasmoid.configuration.widgetHeight
                : Kirigami.Units.gridUnit * 28 * S.REF_H / S.REF_W

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

            // Weather remains visible even before a location is selected or a
            // provider responds. This makes the enabled state explicit and
            // gives every missing provider field a stable, intentional value.
            hasWeather: Plasmoid.configuration.showWeather
            // Some ions omit Place from otherwise valid weather updates. Keep
            // the selected location visible instead of rendering a blank slot;
            // an unconfigured widget gets an equally clear placeholder.
            wxLocation: root.shortPlace(root.weatherText("Place").length > 0
                        ? root.weatherText("Place")
                        : Plasmoid.configuration.weatherLocation) || i18n("Unknown City")
            wxCondition: root.weatherCondition
            wxTemperature: root.degreeText(root.weatherTempRaw) || "--"
            wxRange: root.weatherRange
            wxIcon: root.weatherIcon
            wxVariationKey: Qt.formatDate(clock.dateTime, "yyyy-MM-dd")
                            + "|" + wxLocation

            onWeatherRefreshRequested: root.refreshWeather()
        }
    }
}
