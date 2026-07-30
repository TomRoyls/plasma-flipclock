pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: page

    // cfg_<name> must match the <entry name="..."> in config/main.xml exactly.
    property alias cfg_use24hFormat: use24h.checked
    property alias cfg_showLeadingZero: leadingZero.checked
    property alias cfg_timeZone: timeZone.text
    property alias cfg_animationsEnabled: animations.checked
    property alias cfg_showPanel: showPanel.checked
    property alias cfg_showDateStrip: showDate.checked
    property alias cfg_showWeather: showWeather.checked
    property alias cfg_weatherUseAutomaticSource: automaticWeather.checked
    property alias cfg_weatherSource: weatherSource.text
    property alias cfg_weatherLocation: weatherLocation.text
    property alias cfg_dateFormat: dateFormat.text
    property alias cfg_rightStripText: rightStrip.text

    // Plasma supplies cfg_<entry>Default initial properties to KCM pages.
    // Declare them so configuration initialization cannot leave controls stale.
    property bool cfg_use24hFormatDefault: true
    property bool cfg_showLeadingZeroDefault: true
    property string cfg_timeZoneDefault: ""
    property bool cfg_animationsEnabledDefault: true
    property bool cfg_showPanelDefault: true
    property bool cfg_showDateStripDefault: true
    property bool cfg_showWeatherDefault: true
    property bool cfg_weatherUseAutomaticSourceDefault: true
    property string cfg_weatherSourceDefault: ""
    property string cfg_weatherLocationDefault: ""
    property string cfg_dateFormatDefault: "ddd, MMM d"
    property string cfg_rightStripTextDefault: ""

    property var searchResults: []
    property var searchRequests: []
    property string searchTerm: ""
    property int pendingSearchReplies: 0
    property bool searching: false

    function providerIds() {
        const ions = weatherEngine.data["ions"]
        const ids = []
        if (ions) {
            for (const pluginId of Object.keys(ions)) {
                const parts = String(ions[pluginId]).split("|")
                if (parts.length > 1 && ids.indexOf(parts[1]) === -1)
                    ids.push(parts[1])
            }
        }
        // The engine reports this list on supported Plasma systems. The fallback
        // lets the first search wake providers on older engine implementations.
        return ids.length > 0 ? ids : ["bbcukmet", "dwd", "envcan", "noaa", "wettercom"]
    }

    function searchLocations() {
        const query = locationSearch.text.trim()
        if (query.length === 0)
            return

        searchTerm = query
        searchResults = []
        searchRequests = providerIds().map(provider => provider + "|validate|" + query)
        pendingSearchReplies = searchRequests.length
        searching = pendingSearchReplies > 0
        searchTimeout.restart()
    }

    function addValidationResults(sourceName, data) {
        if (sourceName.indexOf("|validate|" + searchTerm) === -1 || !data)
            return

        pendingSearchReplies = Math.max(0, pendingSearchReplies - 1)
        searching = pendingSearchReplies > 0

        const response = String(data.validate || "")
        const fields = response.split("|")
        if (fields.length < 4 || fields[1] !== "valid")
            return

        const provider = fields[0]
        const rows = searchResults.slice()
        let index = 3
        while (index < fields.length) {
            let place = ""
            let extra = ""
            if (fields[index] === "place") {
                place = fields[index + 1] || ""
                index += 2
                if (fields[index] === "extra") {
                    extra = fields[index + 1] || ""
                    index += 2
                }
            } else {
                // NOAA and older providers return a plain list of place names.
                place = fields[index++]
            }
            if (place.length === 0)
                continue

            const source = provider + "|weather|" + place
                           + (extra.length > 0 ? "|" + extra : "")
            if (!rows.some(row => row.source === source))
                rows.push({ label: place + " — " + provider, place: place, source: source })
        }
        searchResults = rows.slice(0, 12)
    }

    Plasma5Support.DataSource {
        id: weatherEngine
        engine: "weather"
        connectedSources: ["ions"].concat(page.searchRequests)
        onNewData: function(sourceName, data) {
            page.addValidationResults(sourceName, data)
        }
    }

    // A provider can be offline or unsupported. Do not leave the dialog
    // claiming to search forever when it never sends a validation response.
    Timer {
        id: searchTimeout
        interval: 12000
        onTriggered: {
            page.pendingSearchReplies = 0
            page.searching = false
        }
    }

    Kirigami.FormLayout {

        QQC2.CheckBox {
            id: use24h
            Kirigami.FormData.label: i18n("Time:")
            text: i18n("24-hour format")
        }

        QQC2.CheckBox {
            id: leadingZero
            text: i18n("Leading zero on the hour")
        }

        QQC2.TextField {
            id: timeZone
            Kirigami.FormData.label: i18n("Time zone:")
            placeholderText: i18n("System time zone")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: animations
            Kirigami.FormData.label: i18n("Appearance:")
            text: i18n("Animate the flip")
        }

        QQC2.CheckBox {
            id: showPanel
            text: i18n("Show the panel behind the cards")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showDate
            Kirigami.FormData.label: i18n("Card strips:")
            text: i18n("Show the date")
        }

        QQC2.TextField {
            id: dateFormat
            enabled: showDate.checked
            Kirigami.FormData.label: i18n("Date format:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showWeather
            Kirigami.FormData.label: i18n("Weather:")
            text: i18n("Show weather")
        }

        QQC2.CheckBox {
            id: automaticWeather
            enabled: showWeather.checked
            text: i18n("Automatically reuse an active Plasma weather source")
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Selected location:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            text: weatherLocation.text.length > 0
                  ? weatherLocation.text : i18n("None selected")
            opacity: weatherLocation.text.length > 0 ? 1 : 0.65
            elide: Text.ElideRight
        }

        QQC2.TextField {
            id: locationSearch
            enabled: showWeather.checked
            Kirigami.FormData.label: i18n("Find location:")
            placeholderText: i18n("City or weather station")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            onAccepted: page.searchLocations()
        }

        QQC2.Button {
            enabled: showWeather.checked && locationSearch.text.trim().length > 0
            text: i18n("Search")
            onClicked: page.searchLocations()
        }

        ColumnLayout {
            Kirigami.FormData.label: i18n("Results:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 28
            spacing: 0

            QQC2.Label {
                visible: page.searching && page.searchResults.length === 0
                text: i18n("Searching installed Plasma weather providers…")
                opacity: 0.65
            }

            QQC2.Label {
                visible: !page.searching && page.searchTerm.length > 0
                         && page.searchResults.length === 0
                text: i18n("No matching location was returned by the installed weather providers.")
                wrapMode: Text.Wrap
                opacity: 0.65
            }

            Repeater {
                model: page.searchResults

                delegate: QQC2.ItemDelegate {
                    required property var modelData

                    Layout.fillWidth: true
                    text: modelData.label
                    onClicked: {
                        weatherSource.text = modelData.source
                        weatherLocation.text = modelData.place
                        // A chosen location should win over another applet's
                        // active source, which may refer to a different city.
                        automaticWeather.checked = false
                    }
                }
            }
        }

        // Kept as state, rather than exposed to ordinary users. This exact
        // canonical source is what the weather engine expects after selection.
        QQC2.TextField {
            id: weatherSource
            visible: false
        }

        QQC2.TextField {
            id: weatherLocation
            visible: false
        }

        QQC2.TextField {
            id: rightStrip
            Kirigami.FormData.label: i18n("Minute card text:")
            placeholderText: i18n("Empty")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        }
    }
}
