import QtQuick 2.12
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import Lomiri.Components.Popups 1.3
import "."

Page {
    id: pageSettingsNotes

    property string notesPageName: i18n.tr("notes") // do not remove, used by the po files

    header: PageHeader {
        id: headerSettings
        title: i18n.tr("Settings Page")
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
            }
        ]
    }

    Rectangle {
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            anchors.fill: parent
            contentHeight: settingsColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                width: parent.width
                spacing: units.gu(2)

                ListItem.Header {
                    text: "<font color=\"#ffffff\">" + i18n.tr("Notes") + "</font>"
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    wrapMode: Text.WordWrap
                    color: "#ffffff"
                    text: i18n.tr("Notes are stored only on this device. The editor accepts Markdown: headings, lists, bold, italic, code and links are rendered by the preview.")
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Delete all notes")
                    onClicked: PopupUtils.open(confirmDeleteAll)
                }
            }
        }
    }

    Component {
        id: confirmDeleteAll
        Dialog {
            id: confirmDeleteAllDialog
            title: i18n.tr("Delete all notes")
            text: i18n.tr("Every note stored on this device will be removed. This cannot be undone.")

            Button {
                text: i18n.tr("Delete all")
                onClicked: {
                    NotesModel.removeAll()
                    PopupUtils.close(confirmDeleteAllDialog)
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(confirmDeleteAllDialog)
            }
        }
    }
}
