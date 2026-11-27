import QtQuick 2.12
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "."
import "markdown.js" as Markdown

// Editor of a note.
//
// The title lives in the header, next to the back arrow, so the whole page
// below is available for the text. An existing note is opened in its rendered
// Markdown form (read only); the header action switches to the editor. Leaving
// the page saves: a note saved a bit early is better than a note lost.
Page {
    id: editor
    property int noteId: 0
    property bool preview: false
    property bool startInPreview: false
    property bool dirty: false
    property string noteTitle: ""

    function save() {
        if (!dirty)
            return
        // Without a title, the date is used: the list stays readable and the
        // note can still be found later.
        var title = noteTitle.trim().length > 0
                ? noteTitle.trim()
                : Qt.formatDate(new Date(), "dd/MM/yyyy")
        noteId = NotesModel.save(noteId, title, bodyField.text)
        dirty = false
    }

    function close() {
        save()
        pageStack.pop()
    }

    Component.onCompleted: {
        if (noteId > 0) {
            var note = NotesModel.load(noteId)
            noteTitle = note.title
            bodyField.text = note.body
        }
        preview = startInPreview
        dirty = false
    }

    // Header: back, editable title, preview/edit, delete.
    header: Rectangle {
        id: editorHeader
        width: parent.width
        height: units.gu(6)
        color: "#111111"

        Rectangle {
            id: backButton
            width: units.gu(5)
            height: parent.height
            color: "transparent"

            Icon {
                anchors.centerIn: parent
                name: "back"
                width: units.gu(2)
                height: units.gu(2)
                color: launchermodular.settings.textColor
            }
            MouseArea {
                anchors.fill: parent
                onClicked: editor.close()
            }
        }

        QControls.TextField {
            id: titleField
            anchors {
                left: backButton.right
                right: headerActions.left
                verticalCenter: parent.verticalCenter
            }
            height: parent.height
            text: editor.noteTitle
            placeholderText: i18n.tr("Note title")
            color: launchermodular.settings.textColor
            font.pixelSize: units.gu(2)
            background: Rectangle {
                color: "transparent"
                height: parent.height
            }
            onTextChanged: {
                editor.noteTitle = text
                editor.dirty = true
            }
        }

        Row {
            id: headerActions
            anchors.right: parent.right
            height: parent.height

            Rectangle {
                width: units.gu(5)
                height: parent.height
                color: "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: editor.preview ? "edit" : "view-expand"
                    width: units.gu(2)
                    height: units.gu(2)
                    color: launchermodular.settings.textColor
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: editor.preview = !editor.preview
                }
            }
            Rectangle {
                width: units.gu(5)
                height: parent.height
                color: "transparent"
                visible: editor.noteId > 0

                Icon {
                    anchors.centerIn: parent
                    name: "delete"
                    width: units.gu(2)
                    height: units.gu(2)
                    color: launchermodular.settings.textColor
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: PopupUtils.open(confirmDelete)
                }
            }
        }
    }

    // Opaque background: a pushed page must not show the list behind it.
    Rectangle {
        anchors.fill: parent
        z: -1
        color: "#111111"
    }

    // Editor or rendering, same text, full height below the header.
    Flickable {
        id: editArea
        anchors.fill: parent
        anchors.topMargin: units.gu(6)
        anchors.leftMargin: units.gu(1)
        anchors.rightMargin: units.gu(1)
        visible: !editor.preview
        contentHeight: bodyField.height
        clip: true

        QControls.TextArea {
            id: bodyField
            width: editArea.width
            // implicitHeight depends on the width and the text, never on the
            // height: binding the height to contentHeight made a binding loop.
            height: Math.max(implicitHeight, editArea.height)
            placeholderText: i18n.tr("Write in Markdown…")
            wrapMode: TextArea.Wrap
            font.pixelSize: units.gu(1.8)
            onTextChanged: editor.dirty = true
        }
    }

    Flickable {
        id: previewArea
        anchors.fill: editArea
        visible: editor.preview
        contentHeight: previewText.height
        clip: true

        Text {
            id: previewText
            width: previewArea.width
            textFormat: Text.RichText
            text: Markdown.toRichText(bodyField.text)
            color: launchermodular.settings.textColor
            wrapMode: Text.WordWrap
            font.pixelSize: units.gu(1.8)
            onLinkActivated: {
                if (/^(https?|mailto):/i.test(link))
                    Qt.openUrlExternally(link)
            }
        }
    }

    Keys.onBackPressed: {
        editor.close()
        event.accepted = true
    }

    Component {
        id: confirmDelete
        Dialog {
            id: confirmDeleteDialog
            title: i18n.tr("Delete note")
            text: i18n.tr("The note will be removed from this device. Continue?")

            Button {
                text: i18n.tr("Delete")
                onClicked: {
                    NotesModel.remove(editor.noteId)
                    editor.dirty = false
                    PopupUtils.close(confirmDeleteDialog)
                    pageStack.pop()
                }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(confirmDeleteDialog)
            }
        }
    }
}
