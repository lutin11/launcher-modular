import QtQuick 2.12
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "."
import "markdown.js" as Markdown
import "../../components"

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
    // Configuration of the Notes page (injected when the editor is opened), so
    // the Nextcloud destination chosen in the settings is available here.
    property int pageIndex: -1
    property string pageUid: ""
    property var syncConfig: ({})
    property bool autoSync: false
    property bool syncConfigured: false
    property string statusMessage: ""
    property bool statusIsError: false

    NextcloudNotes { id: nextcloud }

    function pageConfig() {
        if (pageUid.length > 0) {
            var stored = launchermodular.getPageConfig(pageUid)
            if (stored && typeof stored === "object")
                return stored
        }
        // Legacy: pages created before the uid stored their data here.
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = launchermodular.pageModel.get(pageIndex).data
            if (data && typeof data === "object")
                return data
        }
        return ({})
    }

    function showStatus(message, isError) {
        statusMessage = message
        statusIsError = isError === true
        statusTimer.restart()
    }

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

    // Explicit save: the note is stored locally, then sent when the automatic
    // export is enabled in the settings.
    function saveAndMaybeSync() {
        save()
        showStatus(i18n.tr("Note saved"), false)
        if (autoSync)
            uploadCurrentNote()
    }

    function uploadCurrentNote() {
        if (bodyField.text.trim().length === 0 && noteTitle.trim().length === 0) {
            showStatus(i18n.tr("Write something before sending the note."), true)
            return
        }
        syncConfig = pageConfig()
        var account = nextcloud.accountFor(syncConfig)
        if (!account) {
            showStatus(i18n.tr("Choose a Nextcloud destination in the settings of the Notes page."), true)
            return
        }
        save()
        var title = noteTitle.trim().length > 0
                ? noteTitle.trim()
                : Qt.formatDate(new Date(), "dd/MM/yyyy")
        var folder = nextcloud.folderFor(syncConfig)
        var name = nextcloud.fileName(title, noteId)
        nextcloud.busy = true
        showStatus(i18n.tr("Sending to Nextcloud…"), false)
        nextcloud.uploadNote(account, folder, name, bodyField.text, function (ok, status) {
            nextcloud.busy = false
            if (ok) {
                NotesModel.setRemote(editor.noteId, name)
                showStatus(i18n.tr("Sent to Nextcloud: %1/%2").arg(folder).arg(name), false)
            } else {
                showStatus(nextcloud.errorText(status), true)
            }
        })
    }

    function close() {
        // Only the local save here: leaving the page destroys the editor and
        // would abort a request started by the automatic export.
        save()
        pageStack.pop()
    }

    Component.onCompleted: {
        syncConfig = pageConfig()
        autoSync = syncConfig.notesSyncAuto === true
        syncConfigured = nextcloud.accountFor(syncConfig) !== null
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

        LauncherTextField {
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
                    name: "save"
                    width: units.gu(2)
                    height: units.gu(2)
                    color: launchermodular.settings.textColor
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: editor.saveAndMaybeSync()
                }
            }
            Rectangle {
                width: units.gu(5)
                height: parent.height
                color: "transparent"
                visible: editor.syncConfigured

                Icon {
                    anchors.centerIn: parent
                    name: "sync"
                    width: units.gu(2)
                    height: units.gu(2)
                    color: launchermodular.settings.textColor
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: editor.uploadCurrentNote()
                }
            }
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

    // Short feedback for the save and Nextcloud actions.
    Rectangle {
        id: statusBanner
        anchors.top: parent.top
        anchors.topMargin: units.gu(6.5)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(editor.width - units.gu(4), units.gu(32))
        height: statusLabel.height + units.gu(1.2)
        radius: units.gu(0.5)
        color: "#E0111111"
        visible: editor.statusMessage.length > 0
        z: 3

        Label {
            id: statusLabel
            anchors.centerIn: parent
            width: parent.width - units.gu(2)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: editor.statusMessage
            color: editor.statusIsError ? "#E95420" : "#FFFFFF"
        }
    }

    Timer {
        id: statusTimer
        interval: 4000
        running: editor.statusMessage.length > 0
        onTriggered: editor.statusMessage = ""
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

        LauncherTextArea {
            id: bodyField
            flat: true
            width: editArea.width
            // implicitHeight depends on the width and the text, never on the
            // height: binding the height to contentHeight made a binding loop.
            height: Math.max(implicitHeight, editArea.height)
            placeholderText: i18n.tr("Write in Markdown…")
            // Default control colour is a light grey, hard to read on black.
            color: launchermodular.settings.textColor
            // TextArea is imported through the QControls alias: the enum
            // belongs to TextInput (QtQuick) and must be named explicitly.
            wrapMode: TextInput.Wrap
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
