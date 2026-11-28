import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import Lomiri.Components.Themes 1.3
import MySettings 1.0
import "../../components"

Page {
    id: musicSettingsPicture

    // Injected by Pagemanagement: the settings entry of a page knows which
    // page it configures (pageIndex is kept for compatibility, pageUid is the
    // stable identifier used by the per-page configuration).
    property int pageIndex: -1
    property string pageName: ""
    property string pageUid: ""
    property string musicPageName: i18n.tr("music") // do not remove, use pour Po files

    header: PageHeader {
        id: headerSettings
        title: i18n.tr("Settings Page");
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: "Back"
                onTriggered: {
                    pageStack.pop();
                }
            }
        ]
    }
    Rectangle {
        id:musicsettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: flickableMusicSettings
            anchors.fill: parent
            contentHeight: settingsColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                width: parent.width

                ListItem.Header {
                    id: titleMusicSettings
                    text: "<font color=\"#ffffff\">"+i18n.tr("Settings for 'Music' page")+"</font>"
                }

                Label {
                    text: i18n.tr("Music folder path:")
                    color: "#FFFFFF"
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: units.gu(1.4)
                }

                Row {
                    width: settingsColumn.width - units.gu(4)
                    height: units.gu(4.5)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    LauncherTextField {
                        id: musicFolderField
                        width: parent.width - iconMusicFolder.width - iconMusicReset.width - units.gu(2)
                        height: parent.height
                        placeholderText: i18n.tr("Folder containing the music")
                        text: launchermodular.settings.folderMusic
                        onTextChanged: launchermodular.settings.folderMusic = text
                    }

                    Icon {
                        id: iconMusicFolder
                        height: parent.height
                        width: height
                        name: "find"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: pageStack.push(Qt.resolvedUrl("../picture/SelectFolderPage.qml"), {
                                settingName: "folderMusic",
                                rootPath: MySettings.getHomeLocation(),
                                startPath: launchermodular.settings.folderMusic
                            })
                        }
                    }

                    Icon {
                        id: iconMusicReset
                        height: parent.height
                        width: height
                        name: "undo"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: launchermodular.settings.folderMusic = MySettings.getMusicLocation()
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter;
                    text: i18n.tr("Example")
                    font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
                    color: launchermodular.settings.musicFontColor
                }
                
                Slider {
                    id: sliderFontSize
                    function formatValue(v) { return v.toFixed(2) }
                    anchors.horizontalCenter: parent.horizontalCenter;
                    value: launchermodular.settings.musicFontSize
                    maximumValue: 5.0
                    minimumValue: 1.0
                    live: true
                    onValueChanged: { launchermodular.settings.musicFontSize = sliderFontSize.value }
                    onPressedChanged: {
                        if (pressed) {
                            sliderFontSize.visible = true;
                        }
                    }
                }

                Grid {
                    spacing: units.gu(1)
                    columns: 7
                    rows: 1
                    Repeater {
                        model: ["#FFFFFF", "#111111", "#5D5D5D", "#888888", "#19B6EE", "#0E8420", "#E95420"]
                        Button {
                            width: units.gu(5)
                            height: units.gu(5)
                            text: ""
                            color: modelData // Set the button color
                            onClicked: launchermodular.settings.musicFontColor = modelData
                        }
                    }
                }



            } // column
        } //flickable
    } //rectangle settings
}
