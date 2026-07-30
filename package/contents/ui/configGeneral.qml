pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    // cfg_<name> must match the <entry name="..."> in config/main.xml exactly.
    property alias cfg_use24hFormat: use24h.checked
    property alias cfg_showLeadingZero: leadingZero.checked
    property alias cfg_timeZone: timeZone.text
    property alias cfg_animationsEnabled: animations.checked
    property alias cfg_showPanel: showPanel.checked
    property alias cfg_showDateStrip: showDate.checked
    property alias cfg_dateFormat: dateFormat.text
    property alias cfg_rightStripText: rightStrip.text

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
            text: i18n("Show the date on the hour card")
        }

        QQC2.TextField {
            id: dateFormat
            enabled: showDate.checked
            Kirigami.FormData.label: i18n("Date format:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        }

        QQC2.TextField {
            id: rightStrip
            Kirigami.FormData.label: i18n("Minute card text:")
            placeholderText: i18n("Empty")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        }
    }
}
