import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.1
import Lomiri.Thumbnailer 0.1


Item {
    id: musics

    FolderListModel {
        id: musicFileModel
        folder: launchermodular.settings.folderMusic
        showDirs: false
        showFiles: true
        nameFilters: ["*.mp3", "*.aac", "*.ogg", "*.wav", "*.flac", "*.m4a", "*.alac"]
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

                Column {

                    Text {
                        id: fileNameId
                        text: fileName
                        font.pixelSize: units.gu(2)
                        font.bold: musicFileModel.isFolder(index) ? true : false
                        color: "#E95420"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log("try launch 1")
                                console.log("is folder1: " + musicFileModel.isFolder(index))
                                if (!musicFileModel.isFolder(index)) {
                                    console.log("launch1:" + filePath)
                                    onClicked:Qt.openUrlExternally("music://" + filePath)
                                }
                            }
                        }
                    }
                }
            } // Item
        }// delegate Rectangle
    }
}
