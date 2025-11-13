import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Qt.labs.folderlistmodel 2.1
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import Lomiri.Components.Popups 1.3
import Lomiri.Components.Themes 1.3

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
            contentHeight: pictureColumnSettings.height
            flickableDirection: Flickable.VerticalFlick
            clip: true   // important pour le calcul du popup
            interactive: true

            Column {
                id: pictureColumnSettings
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: units.gu(2)
                }
                spacing: units.gu(2)

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

                // --- Sorting type selector ---
                Column {
                    id: sortingSection
                    width: parent.width
                    spacing: units.gu(1)

                    property var selectorSortingModel: [
                        { value: FolderListModel.Unsorted, label: "Unsorted" },
                        { value: FolderListModel.Name,     label: "Name" },
                        { value: FolderListModel.Time,     label: "Time" },
                        { value: FolderListModel.Size,     label: "Size" },
                        { value: FolderListModel.Type,     label: "Type" }
                    ]

                    Text {
                        id: textStyleIcons
                        text: i18n.tr("Sort type:")
                        color: "#ffffff"
                        verticalAlignment: Text.AlignVCenter
                        height: units.gu(5)
                    }

                    ListItemHeader.ItemSelector {
                        id: selectorSorting
                        width: parent.width
                        model: sortingSection.selectorSortingModel
                        colourImage: true

                        delegate: OptionSelectorDelegate {
                            property var item: model.modelData ? model.modelData : model
                            text: item.label
                            //color: "#ffffff"
                        }

                        onSelectedIndexChanged: {
                            launchermodular.settings.imageSelectedSorting = model[selectedIndex].value
                        }

                        Component.onCompleted: {
                            const v = launchermodular.settings.imageSelectedSorting
                            selectedIndex = model.findIndex(m => m.value === v)
                            if (selectedIndex === -1) selectedIndex = 0
                        }
                    }
                }

                // --- Reverse sort toggle ---
                Row {
                    id: choseSortRow
                    width: parent.width
                    spacing: units.gu(2)

                    Text {
                        text: i18n.tr("Reverse sort:")
                        color: "#ffffff"
                        verticalAlignment: Text.AlignVCenter
                        height: units.gu(5)
                    }

                    ListItemHeader.Standard {
                        width: parent.width / 2
                        showDivider: false
                        control: Switch {
                            checked: launchermodular.settings.reverseImagesSort
                            onClicked: launchermodular.settings.reverseImagesSort = !checked
                        }
                    }
                }
            } // Column
        } // Flickable
    } // Rectangle
}
