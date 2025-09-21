import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Ubuntu.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Ubuntu.Thumbnailer 0.1
import MySettings 1.0

import QtQuick.Controls 2.2

Item {
    id: videos

    property string rootVideo: MySettings.getVideoLocation()
    property var videoNameFilters: ["*.mp4", "*.m4v", "*.webm", "*.mkv", "*.avi", "*.3gp", "*.ogv", "*.flv"]
    property string searchTerm: ""
    property var folders: []
    property bool initialParsingDone: false
    property string parentFolder: MySettings.getVideoLocation()

    ListModel {
        id: searchModel
    }

    ListModel {
        id: searchResults
    }

    FolderListModel {
        id: videoFileModel
        folder: rootVideo
        showDotAndDotDot: false
        showDirsFirst: true
        showDirs: true
        showFiles: true
        nameFilters: videoNameFilters
        rootFolder: rootVideo

        onFolderChanged: {
            if (!String(folder).startsWith("file://" + rootVideo)) {
                videoFileModel.folder = rootVideo; // Revenir à la racine
            } else {
                videoFileModel.folder = folder
            }
        }
        onStatusChanged: if (videoFileModel.status == FolderListModel.Ready) {
            if (!initialParsingDone) {
                parseForder()
            } else {
                initSearchModel()
            }
        }
    }

    function initSearchModel() {
        searchResults.clear()
        for (var i = 0; i < videoFileModel.count; i++) {
            let filePath = videoFileModel.get(i, "filePath")
            let fileName = videoFileModel.get(i, "fileName")
            let fileIsDir = videoFileModel.get(i, "fileIsDir")
            parentFolder = videoFileModel.parentFolder
            searchResults.append({filePath : filePath, fileName : fileName, fileIsDir: fileIsDir});
        }
    }

    function parseForder() {
        for (var i = 0; i < videoFileModel.count; i++) {
            let filePath = videoFileModel.get(i, "filePath")
            let fileName = videoFileModel.get(i, "fileName")
            let fileIsDir = videoFileModel.get(i, "fileIsDir")

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
            videoFileModel.folder = aFolder;
        } else {
            initialParsingDone = true;
            videoFileModel.folder = rootVideo;
            if (DEBUG_MODE) console.log("searching model complet")
        }
    }

    function searchVideo(term) {
        if (DEBUG_MODE) console.log("searchVideo with term:" + term)
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
            id: searchVideoBackground
            color: launchermodular.settings.backgroundColor
            radius: units.gu(1)
            opacity: 0.3
            anchors.fill: parent
        }
        Icon {
            id: iconBack
            visible: videoFileModel.folder != "file://" + rootVideo && searchField.text.length === 0
            anchors {
                left: searchBar.left
                rightMargin: units.gu(launchermodular.settings.videoFontSize)
                leftMargin: units.gu(launchermodular.settings.videoFontSize)
                verticalCenter: parent.verticalCenter
            }
            height: parent.height*0.5
            width: height
            name: "revert"

            MouseArea {
                anchors.fill: parent
                onClicked:{
                    videoFileModel.folder = videoFileModel.parentFolder
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
                text: i18n.tr("Search your video")
                visible: searchField.text.length == 0
                font.pixelSize: units.gu(launchermodular.settings.videoFontSize)
            }
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextChanged: {
                if(text.length > 0) {
                    searchVideo(text)
                } else {
                    if(videoFileModel.folder == "file://" + rootVideo) {
                        videoFileModel.folder = ""; // force refresh
                    }
                    videoFileModel.folder = rootVideo
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
                    } else if(videoFileModel.folder == "file://" + rootVideo) {
                            videoFileModel.folder = ""; // force refresh
                    }
                    videoFileModel.folder = rootVideo
                }
            }
        }
    }

    ListView {
        id: searchVideoView
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
            width: searchVideoView.cellWidth
            height: searchVideoViewName.implicitHeight

            Rectangle {
                id: searchVideoRectangle
                opacity: 0.9
                color: "#111111"
                height: searchVideoViewName.implicitHeight
                width: parent.width

                Row {
                    spacing: units.gu(1)
                    Icon {
                        id: searchVideoViewItem
                        visible: true
                        height: units.gu(launchermodular.settings.videoFontSize)
                        width: units.gu(launchermodular.settings.videoFontSize)
                        name: fileIsDir ? "folder-symbolic" : "stock_video"
                        color: "#E95420"
                    }
                    Text {
                        id: searchVideoViewName
                        text: fileName
                        font.pixelSize: units.gu(launchermodular.settings.videoFontSize)
                        font.bold: fileIsDir ? true : false
                        color: "#E95420"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!fileIsDir) {
                                    onClicked:Qt.openUrlExternally("video://" + model.filePath)
                                } else {
                                     searchTerm = ""
                                     videoFileModel.folder = model.filePath
                                }
                            }
                        }
                    }
                }
            } // Item
        }// delegate Rectangle
    }
}
