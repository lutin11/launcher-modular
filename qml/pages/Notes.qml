import QtQuick 2.12
import Lomiri.Components 1.3
import QtQuick.Controls 2.2
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
        pageStack.push(Qt.resolvedUrl("notes/NoteEditor.qml"), { noteId: noteId })
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

        delegate: ListItem {
            height: layout.height + divider.height
            ListItemLayout {
                id: layout
                title.text: model.title.length > 0 ? model.title : i18n.tr("Untitled")
                title.color: launchermodular.settings.textColor
                subtitle.text: Qt.formatDateTime(new Date(model.updatedDate), "dd/MM/yyyy hh:mm")
                subtitle.color: launchermodular.settings.textColor
                Icon {
                    name: "note"
                    color: launchermodular.settings.textColor
                    SlotsLayout.position: SlotsLayout.Leading
                }
            }
            onClicked: notesPage.openNote(model.id)
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
