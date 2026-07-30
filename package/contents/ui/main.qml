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

            // Weather stays blank until the data source lands; the clock is fully
            // usable without it.
            hasWeather: false
        }
    }
}
