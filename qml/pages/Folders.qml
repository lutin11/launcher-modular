import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Lomiri.Components 1.3
import Qt.labs.folderlistmodel 2.12
import Lomiri.Thumbnailer 0.1
import MySettings 1.0

import QtQuick.Controls 2.2
import Lomiri.Content 1.3

Item {
    id: lomiriFolders

    property string lomiriRootFolder: MySettings.getHomeLocation()
    property var folderNameFilters: ["*"]
    property string searchTerm: ""
    property var folders: []
    property bool initialParsingDone: false
    property string parentFolder: MySettings.getHomeLocation()
    property string pendingSearch: ""
    property string selectedFilePath: ""

    ListModel {
        id: searchModel
    }

    ListModel {
        id: searchResults
    }

    Timer {
        id: searchDebounce
        interval: 200
        repeat: false
        onTriggered: searchFile(pendingSearch)
    }

    Component {
        id: contentItemComponent
        ContentItem {}
    }

    // Display ("Send to...")
    ContentPeerPicker {
        id: exportPeerPicker
        visible: false
        anchors.fill: parent
        z: 10
        handler: ContentHandler.Destination
        contentType: ContentType.All

        onPeerSelected: {
            if (selectedFilePath !== "") {
                var items = []
                items.push(contentItemComponent.createObject(lomiriFolders, {
                    "url": "file://" + selectedFilePath
                }))

                var transfer = peer.request()
                transfer.items = items
                transfer.state = ContentTransfer.Charged
                exportPeerPicker.visible = false
                selectedFilePath = ""
            }

        }

        onCancelPressed: {
            exportPeerPicker.visible = false
            selectedFilePath = ""
        }
    }

    FolderListModel {
        id: lomiriFileModel
        folder: lomiriRootFolder
        showDotAndDotDot: false
        showDirsFirst: true
        showDirs: true
        showFiles: true
        //nameFilters: folderNameFilters
        rootFolder: lomiriRootFolder

        onFolderChanged: {
            if (!String(folder).startsWith("file://" + lomiriRootFolder)) {
                lomiriFileModel.folder = lomiriRootFolder; // Revenir à la racine
            }
        }
        // Display current folder
        onStatusChanged: if (lomiriFileModel.status == FolderListModel.Ready) {
            initSearchModel()
        }
    }

    // Model used for search
    FolderListModel {
        id: searchIndexModel
        showDotAndDotDot: false
        showDirs: true
        showFiles: true

        onStatusChanged: if (searchIndexModel.status == FolderListModel.Ready) {
            parseForder()
        }
    }

    Component.onCompleted: {
        searchIndexModel.folder = lomiriRootFolder
    }

    function initSearchModel() {
        searchResults.clear()
        for (var i = 0; i < lomiriFileModel.count; i++) {
            let filePath = lomiriFileModel.get(i, "filePath")
            let fileName = lomiriFileModel.get(i, "fileName")
            let fileIsDir = lomiriFileModel.get(i, "fileIsDir")
            parentFolder = lomiriFileModel.parentFolder
            searchResults.append({filePath : filePath, fileName : fileName, fileIsDir: fileIsDir});
        }
    }

    function parseForder() {
        for (var i = 0; i < searchIndexModel.count; i++) {
            let filePath = searchIndexModel.get(i, "filePath")
            let fileName = searchIndexModel.get(i, "fileName")
            let fileIsDir = searchIndexModel.get(i, "fileIsDir")

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
            searchIndexModel.folder = aFolder;
        } else {
            initialParsingDone = true;
            if (DEBUG_MODE) console.log("searching model complet")
        }
    }

    function searchFile(term) {
        if (DEBUG_MODE) console.log("search file with term:" + term)
        searchTerm = term
        var results = []
        var termLower = term.toLowerCase()
        for (var i = 0; i < searchModel.count; i++) {
            var item = searchModel.get(i);
            if (item.fileName.toLowerCase().indexOf(termLower) !== -1) {
                results.push({filePath: item.filePath, fileName: item.fileName, fileIsDir: item.fileIsDir});
            }
        }
        searchResults.clear()
        for (var j = 0; j < results.length; j++) {
            searchResults.append(results[j]);
        }
    }

    Rectangle {
        id: searchBar
        height: units.gu(5)
        width: parent.width
        color: "transparent"

        Rectangle {
            id: searchFileBackground
            color: launchermodular.settings.backgroundColor
            radius: units.gu(1)
            opacity: 0.3
            anchors.fill: parent
        }
        Icon {
            id: iconBack
            visible: lomiriFileModel.folder != "file://" + lomiriRootFolder && searchField.text.length === 0
            anchors {
                left: searchBar.left
                rightMargin: units.gu(launchermodular.settings.folderFontSize)
                leftMargin: units.gu(launchermodular.settings.folderFontSize)
                verticalCenter: parent.verticalCenter
            }
            height: parent.height*0.5
            width: height
            name: "revert"

            MouseArea {
                anchors.fill: parent
                onClicked:{
                    lomiriFileModel.folder = lomiriFileModel.parentFolder
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
                text: i18n.tr("Search a file")
                visible: searchField.text.length == 0
                font.pixelSize: units.gu(launchermodular.settings.folderFontSize)
            }
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextChanged: {
                if(text.length > 0) {
                    pendingSearch = text
                    searchDebounce.restart()
                } else {
                    searchDebounce.stop()
                    searchResults.clear()
                    if(lomiriFileModel.folder == "file://" + lomiriRootFolder) {
                        lomiriFileModel.folder = ""; // force refresh
                    }
                    lomiriFileModel.folder = lomiriRootFolder
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
                    } else if(lomiriFileModel.folder == "file://" + lomiriRootFolder) {
                        lomiriFileModel.folder = ""; // force refresh
                    }
                    lomiriFileModel.folder = lomiriRootFolder
                }
            }
        }
    }

    ListView {
        id: searchFileView
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
            width: searchFileView.cellWidth
            height: searchFileViewName.implicitHeight

            Rectangle {
                id: searchFileRectangle
                opacity: 0.9
                color: "#111111"
                height: searchFileViewName.implicitHeight
                width: parent.width

                Row {
                    spacing: units.gu(1)
                    Icon {
                        id: searchFileViewItem
                        visible: true
                        height: units.gu(launchermodular.settings.folderFontSize)
                        width: units.gu(launchermodular.settings.folderFontSize)
                        name: fileIsDir ? "folder-symbolic" : "text-x-generic-symbolic"
                        color: launchermodular.settings.folderFontColor
                    }
                    Text {
                        id: searchFileViewName
                        text: fileName
                        font.pixelSize: units.gu(launchermodular.settings.folderFontSize)
                        color: launchermodular.settings.folderFontColor

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!fileIsDir) {
                                    selectedFilePath = model.filePath
                                    exportPeerPicker.visible = true
                                    //Qt.openUrlExternally("video://" + model.filePath)
                                } else {
                                    searchTerm = ""
                                    lomiriFileModel.folder = model.filePath
                                }
                            }
                        }
                    }
                }
            } // Item
        }// delegate Rectangle
    }
}
