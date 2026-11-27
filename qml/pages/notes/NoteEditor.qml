import QtQuick 2.12
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "."
import "markdown.js" as Markdown

// Editor of a note: a raw text area and a Markdown preview, switched from the
// header. The content is saved when leaving the page, and on demand.
Page {
    id: editor
    property int noteId: 0
    property bool preview: false
    property bool dirty: false

    function save() {
        if (!dirty)
            return
        var title = titleField.text.length > 0 ? titleField.text : i18n.tr("Untitled")
        noteId = NotesModel.save(noteId, title, bodyField.text)
        dirty = false
    }

    function close() {
        save()
        pageStack.pop()
    }

    header: PageHeader {
        id: editorHeader
        title: editor.noteId > 0 ? i18n.tr("Edit note") : i18n.tr("New note")

        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: editor.close()
            }
        ]

        trailingActionBar.actions: [
            Action {
                iconName: editor.preview ? "edit" : "view-expand"
                text: editor.preview ? i18n.tr("Edit") : i18n.tr("Preview")
                onTriggered: editor.preview = !editor.preview
            },
            Action {
                iconName: "delete"
                text: i18n.tr("Delete")
                enabled: editor.noteId > 0
                onTriggered: PopupUtils.open(confirmDelete)
            }
        ]
    }

    Component.onCompleted: {
        if (noteId > 0) {
            var note = NotesModel.load(noteId)
            titleField.text = note.title
            bodyField.text = note.body
        }
        dirty = false
    }

    Column {
        anchors.fill: parent
        anchors {
            topMargin: units.gu(6)
            leftMargin: units.gu(1)
            rightMargin: units.gu(1)
        }
        spacing: units.gu(1)

        TextField {
            id: titleField
            width: parent.width
            height: units.gu(5)
            placeholderText: i18n.tr("Title")
            font.pixelSize: units.gu(2)
            onTextChanged: editor.dirty = true
        }

        // Raw Markdown, or its rendering. The two views share the same text,
        // so switching never loses anything.
        Flickable {
            id: editorArea
            width: parent.width
            height: parent.height - titleField.height - units.gu(2)
            visible: !editor.preview
            contentHeight: bodyField.height
            clip: true

            TextArea {
                id: bodyField
                width: editorArea.width
                // implicitHeight depends on the width and the text, never on
                // the height: binding the height to contentHeight here made a
                // binding loop (Diagnostics in the journal showed it).
                height: Math.max(implicitHeight, editorArea.height)
                placeholderText: i18n.tr("Write in Markdown…")
                wrapMode: TextArea.Wrap
                font.pixelSize: units.gu(1.8)
                onTextChanged: editor.dirty = true
            }
        }

        Flickable {
            width: parent.width
            height: editorArea.height
            visible: editor.preview
            contentHeight: previewText.height
            clip: true

            Text {
                id: previewText
                width: parent.width
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
    }

    // Leaving the page saves: the phone has no "cancel" habit, and a note lost
    // by a swipe would be worse than a note saved a bit early.
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
