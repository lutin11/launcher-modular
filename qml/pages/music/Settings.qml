import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem

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

                anchors {
                   fill: parent
                   top: parent.top
                   topMargin: units.gu(2)
                   leftMargin: units.gu(1)
                   rightMargin: units.gu(1)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter;
                    text: i18n.tr("Exemple")
                    font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
                    color: "#aaaaaa" // Light grey color for placeholder
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

            } // column
        } //flickable
    } //rectangle settings
}
