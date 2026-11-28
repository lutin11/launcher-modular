import QtQuick 2.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12
import MySettings 1.0

// Folder picker shared by the page settings (pictures, music, videos).
// The caller gives the setting to update, the folder shown first and the
// folder the navigation stops at:
//
//   pageStack.push(Qt.resolvedUrl("../picture/SelectFolderPage.qml"), {
//       settingName: "folderMusic",
//       rootPath: MySettings.getHomeLocation(),
//       startPath: launchermodular.settings.folderMusic
//   })
Page {
    id: folderPicker

    /// Settings property receiving the chosen folder.
    property string settingName: "folderImage"
    /// Folder the user cannot go above.
    property string rootPath: MySettings.getHomeLocation()
    /// Folder shown when the page opens.
    property string startPath: ""

    property string currentPath: startPath.length > 0 ? startPath : rootPath

    function goUp() {
        var idx = currentPath.lastIndexOf("/")
        if (idx > 0 && currentPath !== rootPath)
            currentPath = currentPath.substring(0, idx)
        else
            pageStack.pop()
    }

    function applySelection() {
        if (settingName === "folderMusic")
            launchermodular.settings.folderMusic = currentPath
        else if (settingName === "folderVideo")
            launchermodular.settings.folderVideo = currentPath
        else
            launchermodular.settings.folderImage = currentPath
        pageStack.pop()
    }

    // Only folders are listed: choosing an image or a music file as the
    // "folder" made no sense and left the page empty.
    FolderListModel {
        id: folderModel
        folder: "file://" + currentPath
        showDirs: true
        showFiles: false
    }

    header: PageHeader {
        title: currentPath
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: folderPicker.goUp()
            }
        ]
        trailingActionBar.actions: [
            Action {
                iconName: "tick"
                text: i18n.tr("Select")
                onTriggered: folderPicker.applySelection()
            }
        ]
    }

    Rectangle {
        id: folderPickerBackground
        color: "#111111"
        anchors {
            fill: parent
            topMargin: units.gu(6)
        }

        ListView {
            id: listView
            anchors.fill: parent
            model: folderModel
            delegate: Item {
                width: parent.width
                height: units.gu(5)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(1)

                    Icon {
                        name: "folder-symbolic"
                        height: units.gu(3)
                        width: height
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: fileName
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: folderPicker.currentPath = model.filePath
                }
            }
        }

        Label {
            anchors.centerIn: parent
            width: parent.width - units.gu(4)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#FFFFFF"
            visible: folderModel.status === FolderListModel.Ready && folderModel.count === 0
            text: i18n.tr("This folder contains no sub-folder.")
        }
    }

    Keys.onBackPressed: folderPicker.goUp()
}
