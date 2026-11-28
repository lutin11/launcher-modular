import QtQuick 2.12
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3

// Multi-line counterpart of LauncherTextField, with the same dark style.
QControls.TextArea {
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
    topPadding: units.gu(0.6)
    bottomPadding: units.gu(0.6)

    background: Rectangle {
        radius: units.gu(0.4)
        color: field.flat ? "transparent" : field.fieldBackground
        border.width: field.flat ? 0 : 1
        border.color: field.fieldBorder
    }
}
