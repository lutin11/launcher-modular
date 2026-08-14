import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Lomiri.Thumbnailer 0.1


Item {
    id: picture

    property string selectedImageFilePath: ""
    property real iconbasesize: units.gu(14)

    Image {
        id: img
        source:  selectedImageFilePath;
        visible: selectedImageFilePath !== ""
        fillMode: Image.PreserveAspectFit
        anchors.fill: parent

        sourceSize {
            width: parent.width
            height: parent.height
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                selectedImageFilePath = ""
                launchermodular.settings.fullScreen = !launchermodular.settings.fullScreen;
                WindowController.toggleFullScreen();
            }
        }
    }

    GridView {
        id: gview
        visible: selectedImageFilePath === ""
        anchors.fill: parent
        anchors {
            rightMargin: units.gu(2)
            leftMargin: units.gu(2)
            topMargin: units.gu(2)
        }
        cellHeight: iconbasesize+units.gu(8)
        cellWidth: Math.floor(width/Math.floor(width/iconbasesize))
        clip: true
        cacheBuffer: height * 2
        flickDeceleration: 1500
        maximumFlickVelocity: 2500

        focus: true
        model: folderModel

        FolderListModel {
            id: folderModel
            nameFilters: ["*.png", "*.jpg", "*.jpeg"]
            folder: launchermodular.settings.folderImage
            showDirs: false
            sortReversed: launchermodular.settings.reverseImagesSort
            sortField: launchermodular.settings.imageSelectedSorting
        }

        delegate: Rectangle {
            width: gview.cellWidth
            height: gview.iconbasesize
            color: "transparent"

            Item {
                width: units.gu(12)
                height: units.gu(20)
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    id: imgIcons
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: parent.height
                    source:  "image://thumbnailer/" + filePath;
                    sourceSize {
                        width: parent.width
                        height: parent.height
                    }
                    visible: true
                    fillMode: Image.PreserveAspectCrop
                    smooth: !gview.moving
                    asynchronous: true
                    cache: true
                }

                LomiriShape {
                    source: imgIcons
                    width: parent.width
                    height: parent.height
                    radius : "medium"
                    sourceFillMode: LomiriShape.PreserveAspectCrop
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        launchermodular.settings.fullScreen = !launchermodular.settings.fullScreen;
                        WindowController.toggleFullScreen();
                        selectedImageFilePath = "image://thumbnailer/" + filePath
                    } //Qt.openUrlExternally("photo://" + filePath)
                }
            } // Item
        }// delegate Rectangle
    }
}
