import QtQuick 2.12
import Lomiri.Components 1.3
import "notes"

// List of the notes stored on the device. Tapping a note opens the editor
// (notes/NoteEditor.qml); the first row creates a new one.
Item {
    id: notesPage
    anchors.fill: parent
    property var model: NotesModel.itemModel

    Component.onCompleted: {
        NotesModel.dbInit()
        NotesModel.buildModel()
    }

    function openNote(noteId) {
        // An existing note opens rendered (read only); a new one opens in the
        // editor. The header action switches between the two modes.
        pageStack.push(Qt.resolvedUrl("notes/NoteEditor.qml"),
                       { noteId: noteId, startInPreview: noteId > 0 })
    }

    ListView {
        id: notesList
        anchors.fill: parent
        anchors {
            leftMargin: units.gu(2)
            rightMargin: units.gu(2)
            topMargin: units.gu(2)
        }
        clip: true
        spacing: units.gu(0.5)
        model: notesPage.model

        header: Rectangle {
            height: units.gu(5)
            width: notesList.width
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: units.gu(1)
                color: launchermodular.settings.backgroundColor
                opacity: 0.3
            }

            Icon {
                id: addIcon
                anchors {
                    left: parent.left
                    leftMargin: units.gu(1)
                }
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height * 0.5
                width: height
                name: "add"
                color: launchermodular.settings.textColor
            }

            Label {
                anchors {
                    left: addIcon.right
                    leftMargin: units.gu(1)
                    right: parent.right
                    rightMargin: units.gu(1)
                }
                anchors.verticalCenter: parent.verticalCenter
                text: i18n.tr("New note")
                color: launchermodular.settings.textColor
                elide: Text.ElideRight
            }

            MouseArea {
                anchors.fill: parent
                onClicked: notesPage.openNote(0)
            }
        }

        // One line per note: a ListItem with a title and a subtitle is taller
        // than needed for a list of notes.
        delegate: Item {
            width: notesList.width
            height: units.gu(6)

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: units.gu(0.1)
                color: "#22ffffff"
            }
            Label {
                anchors {
                    left: parent.left
                    right: dateLabel.left
                    rightMargin: units.gu(1)
                    verticalCenter: parent.verticalCenter
                }
                elide: Text.ElideRight
                text: model.title.length > 0 ? model.title : i18n.tr("Untitled")
                color: launchermodular.settings.textColor
            }
            Label {
                id: dateLabel
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                fontSize: "small"
                color: "#AEA79F"
                text: Qt.formatDateTime(new Date(model.updatedDate), "dd/MM/yyyy")
            }
            MouseArea {
                anchors.fill: parent
                onClicked: notesPage.openNote(model.id)
            }
        }
    }

    Label {
        anchors.centerIn: parent
        width: parent.width - units.gu(4)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: notesPage.model.count === 0
        text: i18n.tr("No notes yet. Tap 'New note' to write one.")
        color: launchermodular.settings.textColor
    }
}
