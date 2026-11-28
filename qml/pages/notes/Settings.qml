import QtQuick 2.12
// Aliased: Lomiri.Components also exports a TextField, which has no
// editingFinished/textChanged from QtQuick.Controls.
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "."

Page {
    id: pageSettingsNotes

    // Injected by Pagemanagement: the settings entry of a page knows which
    // page it configures (pageIndex is kept for compatibility, pageUid is the
    // stable identifier used by the per-page configuration).
    property int pageIndex: -1
    property string pageName: ""
    property string pageUid: ""
    property string notesPageName: i18n.tr("notes") // do not remove, used by the po files

    // Nextcloud export of the notes. The destination is chosen here, not
    // deduced: the global account or the account of a "Nextcloud folders"
    // page.
    property var syncSources: []
    property string syncSourceId: ""
    property string syncStatus: ""
    property bool syncIsError: false
    property bool syncing: false
    property int syncedCount: 0
    property int totalCount: 0
    // The fields are filled from the configuration at creation; persisting on
    // each text change must not overwrite it before loading is finished.
    property bool loadingSync: true

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

    function persistSync() {
        if (loadingSync)
            return
        var config = pageConfig()
        config.notesSyncSource = syncSourceId
        config.notesSyncFolder = syncFolderField.text
        config.notesSyncAuto = autoSwitch.checked
        if (pageUid.length > 0)
            launchermodular.setPageConfig(pageUid, config)
        else if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count)
            launchermodular.pageModel.setProperty(pageIndex, "data", config)
    }

    function syncSelected() {
        persistSync()
        var config = pageConfig()
        var account = nextcloud.accountFor(config)
        if (!account) {
            syncStatus = i18n.tr("Choose a Nextcloud account first.")
            syncIsError = true
            return
        }
        syncing = true
        syncedCount = 0
        totalCount = 0
        syncIsError = false
        syncStatus = i18n.tr("Synchronising…")
        nextcloud.syncAll(account, config, function (phase, done, total) {
            pageSettingsNotes.totalCount = total
            pageSettingsNotes.syncedCount = done
            pageSettingsNotes.syncStatus = phase === "download"
                    ? i18n.tr("Downloading %1/%2…").arg(done).arg(total)
                    : i18n.tr("Uploading %1/%2…").arg(done).arg(total)
        }, function (ok, summary) {
            pageSettingsNotes.syncing = false
            if (ok) {
                pageSettingsNotes.syncStatus = i18n.tr("%1 note(s) received, %2 sent")
                        .arg(summary.downloaded).arg(summary.uploaded)
                pageSettingsNotes.syncIsError = false
            } else {
                pageSettingsNotes.syncStatus = nextcloud.errorText(summary.status)
                pageSettingsNotes.syncIsError = true
            }
        })
    }

    Component.onCompleted: {
        syncSources = [{ id: "", label: i18n.tr("None") }]
                .concat(nextcloud.availableSources())
        var config = pageConfig()
        syncSourceId = config.notesSyncSource || ""
        syncFolderField.text = config.notesSyncFolder || "Notes"
        autoSwitch.checked = config.notesSyncAuto === true
        loadingSync = false
    }

    header: PageHeader {
        id: headerSettings
        title: i18n.tr("Notes settings")
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
            contentHeight: settingsColumn.height + units.gu(4)
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                width: parent.width
                anchors.topMargin: units.gu(2)
                spacing: units.gu(2)

                // ----------------------------------------------------------
                // Notes
                // ----------------------------------------------------------
                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Notes")
                    color: "#FFFFFF"
                    font.pixelSize: units.gu(2.2)
                    font.bold: true
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    color: "#AEA79F"
                    font.pixelSize: units.gu(1.4)
                    text: i18n.tr("Notes are stored on this device. The editor accepts Markdown: headings, lists, bold, italic, code and links are rendered by the preview.")
                }

                // ----------------------------------------------------------
                // Nextcloud
                // ----------------------------------------------------------
                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Nextcloud")
                    color: "#FFFFFF"
                    font.pixelSize: units.gu(2.2)
                    font.bold: true
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    color: "#AEA79F"
                    font.pixelSize: units.gu(1.4)
                    text: i18n.tr("Choose where the notes are synchronised. The account is the global Nextcloud account or the one of a 'Nextcloud folders' page; configure that page first if needed.")
                }

                Repeater {
                    model: pageSettingsNotes.syncSources
                    Rectangle {
                        id: sourceRow
                        property bool selected: pageSettingsNotes.syncSourceId === modelData.id

                        width: settingsColumn.width - units.gu(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: units.gu(6)
                        radius: units.gu(0.5)
                        color: selected ? "#26E95420" : "#10FFFFFF"
                        border.width: 1
                        border.color: selected ? "#E95420" : "#22FFFFFF"

                        Rectangle {
                            id: sourceCheck
                            anchors.left: parent.left
                            anchors.leftMargin: units.gu(1.5)
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(2.2)
                            height: width
                            radius: units.gu(0.3)
                            color: sourceRow.selected ? "#E95420" : "transparent"
                            border.width: 1
                            border.color: "#80FFFFFF"

                            Label {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: "#FFFFFF"
                                visible: sourceRow.selected
                            }
                        }

                        Label {
                            anchors.left: sourceCheck.right
                            anchors.leftMargin: units.gu(1.5)
                            anchors.right: parent.right
                            anchors.rightMargin: units.gu(1.5)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            color: "#FFFFFF"
                            text: (modelData.label && modelData.label.length > 0)
                                  ? modelData.label : i18n.tr("None")
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                pageSettingsNotes.syncSourceId = modelData.id
                                pageSettingsNotes.persistSync()
                            }
                        }
                    }
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: pageSettingsNotes.syncSources.length <= 1
                    wrapMode: Text.WordWrap
                    color: "#AEA79F"
                    font.pixelSize: units.gu(1.4)
                    text: i18n.tr("No Nextcloud account found. Add a 'Nextcloud folders' page and configure its account, or set the global Nextcloud account.")
                }

                // Folder of the account, in the same framed panel as the
                // connection fields of the calendar settings.
                Rectangle {
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: folderColumn.height + units.gu(3)
                    radius: units.gu(0.6)
                    color: "#1A1A1A"
                    border.width: 1
                    border.color: "#33FFFFFF"

                    Column {
                        id: folderColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: units.gu(1.5)
                        spacing: units.gu(1)

                        Label {
                            text: i18n.tr("Folder")
                            color: "#FFFFFF"
                            font.pixelSize: units.gu(1.4)
                        }

                        QControls.TextField {
                            id: syncFolderField
                            width: parent.width
                            placeholderText: "Notes"
                            onTextChanged: pageSettingsNotes.persistSync()
                        }
                    }
                }

                // Automatic send after the Save button of the editor.
                Rectangle {
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: autoSyncLabel.height + units.gu(2.4)
                    radius: units.gu(0.6)
                    color: "#14FFFFFF"
                    border.width: 1
                    border.color: "#26FFFFFF"

                    Label {
                        id: autoSyncLabel
                        anchors.left: parent.left
                        anchors.leftMargin: units.gu(1.5)
                        anchors.right: autoSwitch.left
                        anchors.rightMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        color: "#FFFFFF"
                        text: i18n.tr("Send the note automatically when Save is pressed")
                    }

                    Switch {
                        id: autoSwitch
                        anchors.right: parent.right
                        anchors.rightMargin: units.gu(1.5)
                        anchors.verticalCenter: parent.verticalCenter
                        checked: false
                        onClicked: pageSettingsNotes.persistSync()
                    }
                }

                Button {
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.gu(4.5)
                    text: i18n.tr("Synchronise now")
                    enabled: !pageSettingsNotes.syncing
                    onClicked: pageSettingsNotes.syncSelected()
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: pageSettingsNotes.syncStatus.length > 0
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: pageSettingsNotes.syncIsError ? "#ED3146" : "#AEA79F"
                    text: pageSettingsNotes.syncStatus
                }

                // ----------------------------------------------------------
                // Local notes
                // ----------------------------------------------------------
                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Local notes")
                    color: "#FFFFFF"
                    font.pixelSize: units.gu(2.2)
                    font.bold: true
                }

                Button {
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.gu(4)
                    color: "#C7162B"
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
