import QtQuick 2.12
import Lomiri.Components 1.3

// Empty state shown instead of a page that cannot be loaded, most of the time
// because an external QML module is not installed on the machine. Without this
// screen the page shows up completely blank and the problem looks like a bug in
// the application.
Page {
    id: pageUnavailable

    // Name of the page concerned, with its extension ("Videos.qml").
    property string pageName: ""
    // Names of the missing modules ("Lomiri.Thumbnailer"), empty when unknown.
    property var dependencies: []

    Column {
        anchors.centerIn: parent
        width: parent.width - units.gu(8)
        spacing: units.gu(2)

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: i18n.tr("This page is not available")
            font.pixelSize: units.gu(3)
            color: launchermodular.settings.textColor
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: launchermodular.settings.textColor
            // Wording kept in the plural: it also reads correctly for a single
            // module, and the project does not use the plural form of gettext.
            // %1: module names, never translated
            text: pageUnavailable.dependencies.length > 0
                  // i18n.tr() does not substitute positional arguments: use
                  // .arg(), like the other messages of the project. Without it
                  // the placeholder was displayed literally.
                  ? i18n.tr("It requires a module that is not installed on this system: %1")
                        .arg(pageUnavailable.dependencies.join(", "))
                  : i18n.tr("One of its components is missing on this system.")
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            opacity: 0.7
            color: launchermodular.settings.textColor
            text: i18n.tr("You can remove this page in the configuration bar.")
        }
    }
}
