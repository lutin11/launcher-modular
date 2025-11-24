import QtQuick 2.4
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.0
import Ubuntu.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Ubuntu.Thumbnailer 0.1
import MySettings 1.0

import QtQuick.Controls 2.2

Item {
    id: musics

    property string rootMusic: MySettings.getMusicLocation()
    property var musicNameFilters: ["*.mp3", "*.aac", "*.ogg", "*.wav", "*.flac", "*.m4a", "*.alac"]
    property string searchTerm: ""
    property var folders: []
    property bool initialParsingDone: false
    property string parentFolder: MySettings.getMusicLocation()

    ListModel {
        id: searchModel
    }

    ListModel {
        id: searchResults
    }

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
            if (!String(folder).startsWith("file://" + rootMusic)) {
                musicFileModel.folder = rootMusic; // Revenir à la racine
            } else {
                musicFileModel.folder = folder
            }
        }
        onStatusChanged: if (musicFileModel.status == FolderListModel.Ready) {
            if (!initialParsingDone) {
                parseForder()
            } else {
                initSearchModel()
            }
        }
    }

    function initSearchModel() {
        searchResults.clear()
        for (var i = 0; i < musicFileModel.count; i++) {
            let filePath = musicFileModel.get(i, "filePath")
            let fileName = musicFileModel.get(i, "fileName")
            let fileIsDir = musicFileModel.get(i, "fileIsDir")
            parentFolder = musicFileModel.parentFolder
            searchResults.append({filePath : filePath, fileName : fileName, fileIsDir: fileIsDir});
        }
    }

    function parseForder() {
        for (var i = 0; i < musicFileModel.count; i++) {
            let filePath = musicFileModel.get(i, "filePath")
            let fileName = musicFileModel.get(i, "fileName")
            let fileIsDir = musicFileModel.get(i, "fileIsDir")

            if (!fileIsDir) {
                searchModel.append({filePath : filePath, fileName : fileName, fileIsDir: fileIsDir});
            } else {
                folders.push(filePath)
            }
        }
        parseNextFolder()
    }

    function parseNextFolder() {
        if(folders.length > 0) {
            let aFolder = folders.pop();
            musicFileModel.folder = aFolder;
        } else {
            initialParsingDone = true;
            musicFileModel.folder = rootMusic;
            if (DEBUG_MODE) console.log("searching model complet")
        }
    }

    function searchMusic(term) {
        if (DEBUG_MODE) console.log("searchMusic with term:" + term)
        searchTerm = term
        searchResults.clear()
        for (var i = 0; i < searchModel.count; i++) {
            var item = searchModel.get(i);
            if (item.fileName.toLowerCase().indexOf(term.toLowerCase()) !== -1) {
                searchResults.append(item);
            }
        }
    }

    Rectangle {
        id: searchBar
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
            visible: musicFileModel.folder != "file://" + rootMusic && searchField.text.length === 0
            anchors {
                left: searchBar.left
                rightMargin: units.gu(launchermodular.settings.musicFontSize)
                leftMargin: units.gu(launchermodular.settings.musicFontSize)
                verticalCenter: parent.verticalCenter
            }
            height: parent.height*0.5
            width: height
            name: "revert"

            MouseArea {
                anchors.fill: parent
                onClicked:{
                    musicFileModel.folder = musicFileModel.parentFolder
                }
            }
        }

        TextField {
            id: searchField
            focus: false
            anchors {
                left: iconBack.right
                right: iconSearch.left
            }
            height: searchBar.height
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
                font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
            }
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextChanged: {
                if(text.length > 0) {
                    searchMusic(text)
                } else {
                    if(musicFileModel.folder == "file://" + rootMusic) {
                        musicFileModel.folder = ""; // force refresh
                    }
                    musicFileModel.folder = rootMusic
                }
            }
        }

        Icon {
            id: iconSearch
            anchors {
                right: searchBar.right
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
                    } else if(musicFileModel.folder == "file://" + rootMusic) {
                            musicFileModel.folder = ""; // force refresh
                    }
                    musicFileModel.folder = rootMusic
                }
            }
        }
    }

    ListView {
        id: searchMusicView
        model: searchResults

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
            width: searchMusicView.cellWidth
            height: searchMusicViewName.implicitHeight

            Rectangle {
                id: searchMusicRectangle
                opacity: 0.9
                color: "#111111"
                height: searchMusicViewName.implicitHeight
                width: parent.width

                Row {
                    spacing: units.gu(1)
                    Icon {
                        id: searchMusicViewItem
                        visible: true
                        height: units.gu(launchermodular.settings.musicFontSize)
                        width: units.gu(launchermodular.settings.musicFontSize)
                        name: fileIsDir ? "folder-symbolic" : "stock_music"
                        color: launchermodular.settings.musicFontColor
                    }
                    Text {
                        id: searchMusicViewName
                        text: fileName
                        font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
                        font.bold: fileIsDir ? true : false
                        color: launchermodular.settings.musicFontColor

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!fileIsDir) {
                                    onClicked:Qt.openUrlExternally("music://" + model.filePath)
                                } else {
                                     searchTerm = ""
                                     musicFileModel.folder = model.filePath
                                }
                            }
                        }
                    }
                }
            } // Item
        }// delegate Rectangle
    }
}
