import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Lomiri.Thumbnailer 0.1
import MySettings 1.0

import QtQuick.Controls 2.2

Item {
    id: musics

    property string rootMusic: MySettings.getMusicLocation();
    property var musicNameFilters: ["*.mp3", "*.aac", "*.ogg", "*.wav", "*.flac", "*.m4a", "*.alac"];
    property var searchResults: [];
    property var currentFolder: MySettings.getMusicLocation();
    property string searchTerm: ""

    FolderListModel {
        id: musicFileModel
        folder: rootMusic
        showDotAndDotDot: false
        showDirsFirst: true
        showDirs: true
        showFiles: true
        nameFilters: musicNameFilters
        rootFolder: rootMusic

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
        onStatusChanged: if (musicFileModel.status == FolderListModel.Ready) {
            searchFolderTerm(currentFolder, searchTerm)
        }
    }

    ListModel {
        id: musicListModel
    }

    function searchFolder(folderPath, term) {
        searchTerm = term
        if (currentFolder != folderPath) {
            console.log("enter folder: " + folderPath)
            currentFolder = folderPath;
            musicFileModel.folder = folderPath;
        } else {
           // model is ready
           searchFolderTerm(currentFolder, searchTerm)
        }
        console.log("searchFolder " + folderPath + " with term:" + term)
    }

    function searchFolderTerm(folderPath, term) {
        console.log("found " + musicFileModel.count + " items on" + folderPath + " with term:" + term)

        for (let i = 0; i < musicFileModel.count; i++) {
            let filePath = musicFileModel.get(i, "filePath");
            let fileName = musicFileModel.get(i, "fileName");
            let fileIsDir = musicFileModel.get(i, "fileIsDir");

            if (fileIsDir && term.length > 0) {
                searchFolder(filePath, term); // Recurse into subdirectory
            }

            if (fileName.toLowerCase().indexOf(term.toLowerCase()) !== -1) {
                console.log("append file: " + filePath + " -> " + fileName)
                musicListModel.append({filePath : filePath, fileName : fileName, fileIsDir: fileIsDir});
            }
        }
    }

    Component.onCompleted: {
        console.log("model is ready")
        searchFolder(rootMusic, "")
    }

    Rectangle {
        id: search
        height: units.gu(5)
        width: parent.width
        color: "transparent"

        Rectangle {
            id: searchMusicBackground
            color: launchermodular.settings.backgroundColor
            radius: units.gu(1)
            opacity: 0.3
            anchors.fill: parent
        }
        Icon {
            id: iconBack
            visible: currentFolder != rootMusic
            anchors {
                left: search.left
                rightMargin: units.gu(1)
                leftMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }
            height: parent.height*0.5
            width: height
            name: "revert"

            MouseArea {
                anchors.fill: parent
                onClicked:{
                    console.log("back to parent of : " + currentFolder)
                    musicListModel.clear();
                    var pathParts = currentFolder.split("/");
                    var lastPart = pathParts[pathParts.length-1];
                    var parentPath = currentFolder.substring(0, currentFolder.length - lastPart.length - 1);
                    console.log("Parent path: " + parentPath);
                    searchFolder(parentPath, "")
                }
            }
        }

        TextField {
            id: searchField
            anchors {
                left: iconBack.right
                right: iconSearch.left
            }
            height: search.height
            color: launchermodular.settings.textColor
            background: Rectangle {
              height: parent.height
              color: "transparent"
            }

            placeholderText: ""
            // Custom placeholder
            Text {
                anchors.fill: parent
                anchors.leftMargin: units.gu(2)
                verticalAlignment: Text.AlignVCenter
                color: "#aaaaaa" // Light grey color for placeholder
                text: i18n.tr("Search your music")
                visible: searchField.text.length == 0
                font.pixelSize: units.gu(1.5)
            }
            inputMethodHints: Qt.ImhNoPredictiveText
            onVisibleChanged: {
                if (visible) {
                    forceActiveFocus()
                }
            }
            onTextChanged: {
                console.log("Search for: " + text);
                if(text.length > 0) {
                    musicListModel.clear();
                    searchFolder(rootMusic, text)
                } else {
                    searchFolder(rootMusic, "")
                }
            }
        }
        Icon {
            id: iconSearch
            anchors {
                right: search.right
                rightMargin: units.gu(1)
                leftMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }
            height: parent.height*0.5
            width: height
            name: {
                if (searchField.text.length > 0) {
                    "edit-clear"
                } else {
                    "find"
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked:{
                    if(searchField.text.length > 0){
                       searchField.text = ""
                       searchField.focus = false
                       searchFolder(rootMusic, "")
                    }
                }
            }
        }
    }

    ListView {
        id: gviewFile
        model: musicListModel

        width: parent.width
        anchors {
            fill: parent
            rightMargin: units.gu(2)
            leftMargin: units.gu(2)
            topMargin: units.gu(6)
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
                        name: fileIsDir ? "folder-symbolic" : "stock_music"
                        color: "#E95420"
                    }
                    Text {
                        id: fileNameId
                        text: fileName
                        font.pixelSize: units.gu(2)
                        font.bold: fileIsDir ? true : false
                        color: "#E95420"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log("is folder: " + fileIsDir)
                                if (!fileIsDir) {
                                    console.log("launch:" + filePath)
                                    onClicked:Qt.openUrlExternally("music://" + filePath)
                                } else {
                                    console.log("change to :" + filePath)
                                    var tempFilePath = filePath;
                                    musicListModel.clear();
                                    searchFolder(tempFilePath, "")
                                }
                            }
                        }
                    }
                }
            } // Item
        }// delegate Rectangle
    }
}
