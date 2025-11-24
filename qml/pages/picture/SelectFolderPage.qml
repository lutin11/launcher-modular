import QtQuick 2.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12

Page {
    id: folderPicker

    property string rootPath: "/home/phablet"

    property string currentPath: rootPath
    property string parentFolder: "/home/phablet"

    FolderListModel {
        id: folderModel
        folder: "file://" + currentPath
        showDirs: true
        showFiles: true
    }

    header: PageHeader {
        title: currentPath
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                visible: folderModel.folder != "file://" + rootPath

                onTriggered: {
                    var idx = currentPath.lastIndexOf("/")
                    if (idx > 0 && currentPath !== rootPath) {
                        currentPath = currentPath.substring(0, idx)
                    } else {
                        cancel()
                        pageStack.pop()
                    }
                }
            }
        ]
        trailingActionBar.actions: [
            Action {
                iconName: "tick"
                text: i18n.tr("Select")
                onTriggered: {
                    launchermodular.settings.folderImage = currentPath
                    pageStack.pop()
                }
            }
        ]
    }

    Rectangle {
        id:pictureMainSettings
        color: "#111111"
        anchors {
            fill: parent
            topMargin: units.gu(6)
        }

        ListView {
            id: listView
            anchors {
                fill: parent
                topMargin: folderPicker.header.height
            }
            model: folderModel
            delegate: Item {
                width: parent.width
                height: units.gu(5)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: units.gu(1)

                    Icon {
                        name: model.fileIsDir ? "folder-symbolic" : "image-symbolic"
                        height: units.gu(launchermodular.settings.musicFontSize)
                        width: units.gu(launchermodular.settings.musicFontSize)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: fileName
                        color:  "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        folderPicker.currentPath = model.filePath
                    }
                }
            }
        }
    }

    Keys.onBackPressed: {
        var idx = currentPath.lastIndexOf("/")
        if (idx > 0) {
            currentPath = currentPath.substring(0, idx)
        } else {
            cancel()
            pageStack.pop()
        }
    }
}
