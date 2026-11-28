import QtQuick 2.12
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3

// Text field of the launcher.
//
// The default QtQuick.Controls style is light; the launcher pages are dark and
// set white labels, which made the field content unreadable or inconsistent.
// This component gives every form field the same dark background, white text
// and orange focus border. Pages that overlay a field on the launcher
// background (search bars) can use `flat: true` or override `background`.
QControls.TextField {
    id: field

    property bool flat: false
    property color fieldColor: "#FFFFFF"
    property color fieldBackground: "#E61A1A1A"
    property color fieldBorder: activeFocus ? "#E95420" : "#4DFFFFFF"

    color: fieldColor
    placeholderTextColor: "#B3FFFFFF"
    selectionColor: "#E95420"
    selectedTextColor: "#FFFFFF"
    selectByMouse: true
    leftPadding: units.gu(1)
    rightPadding: units.gu(1)
    implicitHeight: units.gu(4.5)

    background: Rectangle {
        radius: units.gu(0.4)
        color: field.flat ? "transparent" : field.fieldBackground
        border.width: field.flat ? 0 : 1
        border.color: field.fieldBorder
    }
}
