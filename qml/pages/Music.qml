import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.1
import Lomiri.Thumbnailer 0.1
import MySettings 1.0

Item {
    id: musics

    property string rootMusic: MySettings.getMusicLocation()

    FolderListModel {
        id: musicFileModel
        folder: rootMusic
        //showDotAndDotDot: true
        showDirsFirst: true
        showDirs: true
        showFiles: true
        nameFilters: ["*.mp3", "*.aac", "*.ogg", "*.wav", "*.flac", "*.m4a", "*.alac"]

        onFolderChanged: {
            console.log("ref root: " + rootMusic)
            console.log("root change: " + String(folder))
            if (!String(folder).startsWith("file://" + rootMusic)) {
                musicFileModel.folder = rootMusic; // Revenir à la racine
                console.log("back to default: " + rootMusic)
            } else {
                musicFileModel.folder = folder
                console.log("root is changing to: " + folder)
            }
        }
    }

    Rectangle {
        height: units.gu(2)
        anchors.leftMargin: units.gu(2)
        Icon {
            id: iconBack
            visible: true
            height: units.gu(2)
            width: units.gu(2)
            name: "revert"
            color: "#E95420"

            MouseArea {
                anchors.fill: parent
                onClicked:{
                     musicFileModel.folder = musicFileModel.parentFolder;
                }
            }
        }
    }

    ListView {
        id: gviewFile
        model: musicFileModel
        width: parent.width
        //height: fileNameId.implicitHeight
        anchors {
            fill: parent
            rightMargin: units.gu(2)
            leftMargin: units.gu(2)
            topMargin: units.gu(2)
        }
        clip: true  // To avoid rendering content outside of the visible area

        focus: true

        delegate: Item {
            id: fileDelegate
            width: gviewFile.cellWidth
            height: fileNameId.implicitHeight

            Rectangle {
                id: fileDelegateRectangle
                opacity: 0.9
                color: "#111111"
                height: fileNameId.implicitHeight
                width: parent.width

                Row {
                    spacing: units.gu(1)
                    Icon {
                        id: itemIcon
                        visible: true
                        height: units.gu(2)
                        width: units.gu(2)
                        name: musicFileModel.isFolder(index) ? "folder-symbolic" : "stock_music"
                        color: "#E95420"

                        MouseArea {
                            anchors.fill: parent
                            onClicked:{
                                 musicFileModel.folder = musicFileModel.parentFolder;
                            }
                        }
                    }
                    Text {
                        id: fileNameId
                        text: fileName
                        font.pixelSize: units.gu(2)
                        font.bold: musicFileModel.isFolder(index) ? true : false
                        color: "#E95420"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log("is folder1: " + musicFileModel.isFolder(index))
                                if (!musicFileModel.isFolder(index)) {
                                    console.log("launch1:" + filePath)
                                    onClicked:Qt.openUrlExternally("music://" + filePath)
                                } else {
                                    console.log("change to :" + filePath)
                                    musicFileModel.folder = filePath;
                                }
                            }
                        }
                    }
                }
            } // Item
        }// delegate Rectangle
    }
}
