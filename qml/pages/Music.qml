import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.1
import Lomiri.Thumbnailer 0.1


Item {
    id: musics

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
        model: musicFolderModel

        FolderListModel {
            id: musicFolderModel
            folder: QStandardPaths.writableLocation(QStandardPaths.MusicLocation)

            // Optionally, you can filter to show only music files by checking extensions
            onFolderLoaded: {
                console.log("Music folder loaded:", folder)
            }

            // Optional: You can use filters like `filter` to only show certain file types (e.g., .mp3, .flac)
            filter: "*.mp3, *.aac, *.ogg, *.wav, *.flac, *.m4a, *.alac"

            // This will show a list of files from the folder
            ListView {
                width: parent.width
                height: parent.height

                model: musicFolderModel

                delegate: Item {
                    width: parent.width
                    height: 50

                    Rectangle {
                        width: parent.width
                        height: 50
                        color: "lightgray"
                        border.color: "gray"
                        radius: 5
                        padding: 10

                        Text {
                            anchors.centerIn: parent
                            text: model.fileName
                            font.pixelSize: 16
                        }
                    }
                }
            }
        }
    }
}
