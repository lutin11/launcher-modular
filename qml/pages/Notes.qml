import QtQuick 2.12
import Lomiri.Components 1.3
import "notes"

// List of the notes stored on the device. Tapping a note opens the editor
// (notes/NoteEditor.qml); the first row creates a new one.
Item {
    id: notesPage
    anchors.fill: parent
    property var model: NotesModel.itemModel
    // Injected by Main.qml: the settings of this page (Nextcloud export) are
    // stored by stable uid.
    property int pageIndex: -1
    property string pageUid: ""
    // Nextcloud export, triggered by the sync button or a downward pull.
    property bool syncing: false
    property string syncStatus: ""
    property bool syncError: false
    property bool pullTriggered: false

    NextcloudNotes { id: nextcloud }

    function pageConfig() {
        if (pageUid.length > 0) {
            var stored = launchermodular.getPageConfig(pageUid)
            if (stored && typeof stored === "object")
                return stored
        }
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = launchermodular.pageModel.get(pageIndex).data
            if (data && typeof data === "object")
                return data
        }
        return ({})
    }

    function showSyncStatus(message, isError) {
        syncStatus = message
        syncError = isError === true
        // During a transfer the banner must stay: the timer only starts once
        // the synchronisation is over.
        if (!syncing)
            statusTimer.restart()
    }

    // Two-way synchronisation with the destination chosen in the settings:
    // newer remote files are received, newer local notes are sent.
    function syncAll() {
        if (syncing)
            return
        var config = pageConfig()
        var account = nextcloud.accountFor(config)
        if (!account) {
            showSyncStatus(i18n.tr("Choose a Nextcloud destination in the settings of the Notes page."), true)
            return
        }
        syncing = true
        showSyncStatus(i18n.tr("Synchronising…"), false)
        nextcloud.syncAll(account, config, function (phase, done, total) {
            notesPage.showSyncStatus(phase === "download"
                    ? i18n.tr("Downloading %1/%2…").arg(done).arg(total)
                    : i18n.tr("Uploading %1/%2…").arg(done).arg(total), false)
        }, function (ok, summary) {
            notesPage.syncing = false
            if (ok)
                notesPage.showSyncStatus(i18n.tr("%1 note(s) received, %2 sent")
                                                 .arg(summary.downloaded).arg(summary.uploaded), false)
            else
                notesPage.showSyncStatus(nextcloud.errorText(summary.status), true)
        })
    }

    Component.onCompleted: {
        NotesModel.dbInit()
        NotesModel.buildModel()
    }

    function openNote(noteId) {
        // An existing note opens rendered (read only); a new one opens in the
        // editor. The header action switches between the two modes.
        pageStack.push(Qt.resolvedUrl("notes/NoteEditor.qml"),
                       { noteId: noteId, startInPreview: noteId > 0,
                         pageIndex: notesPage.pageIndex, pageUid: notesPage.pageUid })
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
        // A downward pull at the top starts the Nextcloud synchronisation.
        // The drag is handled by the list itself, so scrolling stays intact.
        boundsBehavior: Flickable.DragAndOvershootBounds
        onContentYChanged: {
            if (dragging && contentY < -units.gu(5) && !notesPage.pullTriggered) {
                notesPage.pullTriggered = true
                notesPage.syncAll()
            }
        }
        onMovementEnded: notesPage.pullTriggered = false

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

    // Sync button, and the status of the synchronisation.
    Icon {
        id: syncIcon
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: units.gu(1)
        width: units.gu(3)
        height: width
        name: "sync"
        color: launchermodular.settings.textColor
        opacity: notesPage.syncing ? 0.4 : 0.9
        z: 2

        MouseArea {
            anchors.fill: parent
            anchors.margins: units.gu(-0.8)
            onClicked: notesPage.syncAll()
        }
    }

    Rectangle {
        id: syncBanner
        anchors.top: parent.top
        anchors.topMargin: units.gu(6.5)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(notesPage.width - units.gu(4), units.gu(32))
        height: syncBannerLabel.height + units.gu(1.2)
        radius: units.gu(0.5)
        color: "#E0111111"
        visible: notesPage.syncStatus.length > 0
        z: 3

        Label {
            id: syncBannerLabel
            anchors.centerIn: parent
            width: parent.width - units.gu(2)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: notesPage.syncStatus
            color: notesPage.syncError ? "#ED3146" : "#FFFFFF"
        }
    }

    Timer {
        id: statusTimer
        interval: 5000
        running: notesPage.syncStatus.length > 0 && !notesPage.syncing
        onTriggered: notesPage.syncStatus = ""
    }
}
