import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem
import Ubuntu.Components.Themes 1.3

Page {
    id: musicSettingsPicture

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

                ListItem.Header {
                    id: titleCalendarManagement
                    text: "<font color=\"#ffffff\">"+i18n.tr("Settings for 'Music' page")+"</font>"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter;
                    text: i18n.tr("Exemple")
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
                            pageSettings.visible = false
                            sliderFontSize.visible = true;
                        } else {
                            pageSettings.visible = true;
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
