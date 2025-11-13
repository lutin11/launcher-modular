import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Qt.labs.folderlistmodel 2.1
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import Lomiri.Components.Themes 1.3
import QtQuick.Layouts 1.15

Page {
    id: picturePageSettingsPicture

    header: PageHeader {
        id: headerPictureSettings
        title: i18n.tr("Settings Page")
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: "Back"
                onTriggered: pageStack.pop()
            }
        ]
    }

    Rectangle {
        id: pictureMainSettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: pictureFlickableSettings
            anchors.fill: parent
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: pictureColumnSettings
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: units.gu(2)
                }
                //anchors.fill: parent
                spacing: units.gu(1)

                // --- Image folder path ---
                Row {
                    width: parent.width
                    height: units.gu(4)
                    spacing: units.gu(2)

                    Label {
                        text: i18n.tr("Image folder path:")
                        color: "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        font.weight: Font.Light
                    }
                }

                // --- Path selection bar ---
                Rectangle {
                    id: searchBar
                    width: parent.width
                    height: units.gu(5)
                    color: Theme.name.indexOf("Dark") !== -1 ? "#111111" : "white"
                    radius: 5

                    Row {
                        anchors.fill: parent
                        anchors.margins: units.gu(1)
                        spacing: units.gu(1)

                        TextField {
                            id: imageManualPath
                            text: launchermodular.settings.folderImage
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - iconSearch.width - units.gu(1)
                            verticalAlignment: Text.AlignVCenter
                            onTextChanged: launchermodular.settings.folderImage = text
                        }

                        Icon {
                            id: iconSearch
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: height
                            name: "find"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: pageStack.push(Qt.resolvedUrl("SelectFolderPage.qml"))
                            }
                        }
                    }
                }

                // --- Sorting selector ---
                Row {
                    id: sortingSection
                    width: parent.width
                    spacing: units.gu(2)
                    property var selectorSortingModel: [
                        { value: FolderListModel.Unsorted, label: "Unsorted" },
                        { value: FolderListModel.Name,     label: "Name" },
                        { value: FolderListModel.Time,     label: "Time" },
                        { value: FolderListModel.Size,     label: "Size" },
                        { value: FolderListModel.Type,     label: "Type" }
                    ]
                    property int selectedIndex: 0

                    Text {
                        id: sortLabel
                        text: i18n.tr("Sort type:")
                        color: "#ffffff"
                        verticalAlignment: Text.AlignVCenter
                        height: units.gu(5)
                    }

                    Button {
                        id: openSelectorButton
                        text: sortingSection.selectorSortingModel[sortingSection.selectedIndex].label
                        width: sortingSection.width - sortLabel.width - units.gu(2)
                        height: units.gu(5)
                        anchors.verticalCenter: parent.right
                        onClicked: popupSelector.open()
                    }

                    Popup {
                        id: popupSelector
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        // On positionne la popup juste sous le bouton
                        x: openSelectorButton.mapToItem(null, sortLabel.width + units.gu(2), 0).x
                        y: openSelectorButton.mapToItem(null, 0, openSelectorButton.height).y
                        width: openSelectorButton.width

                        background: Rectangle {
                            color: "#222222"
                            radius: 5
                            border.color: "#555555"
                            border.width: 1
                        }

                        Column {
                            anchors.fill: parent
                            spacing: units.gu(0.5)
                            width: openSelectorButton.width

                            Repeater {
                                model: sortingSection.selectorSortingModel
                                delegate: Button {
                                    text: modelData.label
                                    width: parent.width
                                    onClicked: {
                                        sortingSection.selectedIndex = index
                                        launchermodular.settings.imageSelectedSorting = modelData.value
                                        popupSelector.close()
                                    }
                                }
                            }
                        }

                        enter: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                            NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 150 }
                        }
                        exit: Transition {
                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                        }
                    }

                    Component.onCompleted: {
                        const v = launchermodular.settings.imageSelectedSorting
                        selectedIndex = selectorSortingModel.findIndex(m => m.value === v)
                        if (selectedIndex === -1) selectedIndex = 0
                    }
                }

                // --- Reverse sort toggle ---
                RowLayout {
                    id: choseSortRow
                    width: parent.width
                    spacing: units.gu(1)
                    height: units.gu(5)

                    Label {
                        text: i18n.tr("Reverse sort")
                        color: "white"
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                    }

                    Switch {
                        checked: launchermodular.settings.reverseImagesSort
                        onClicked: launchermodular.settings.reverseImagesSort = checked
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    }
                }
            } // Column
        } // Flickable
    } // Rectangle
}
