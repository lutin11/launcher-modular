import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.1

Item {
    id: picture

    GridView {
        id: gview
        anchors.fill: parent
        anchors {
            rightMargin: units.gu(2)
            leftMargin: units.gu(2)
            topMargin: units.gu(2)
        }
        cellHeight: iconbasesize+units.gu(8)
        property real iconbasesize: units.gu(14)
        cellWidth: Math.floor(width/Math.floor(width/iconbasesize))
        clip: true  // To avoid rendering content outside of the visible area

        focus: true
        model: folderModel

        FolderListModel {
            id: folderModel
            nameFilters: ["*.png", "*.jpg", "*.jpeg"]
            folder: launchermodular.settings.folderimage
            showDirs: false
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
                    source: filePath
                    visible: Math.abs(gview.contentY - y) < 2 * gview.cellHeight  // Lazy loading based on proximity to viewport
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true  // To load images without blocking the main UI thread
                    cache: true  // Enable image caching for faster re-display
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
                        onClicked:Qt.openUrlExternally("photo://" + filePath)
                    }
                }
            } // Item
        }// delegate Rectangle
    }
}
