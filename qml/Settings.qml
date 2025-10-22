import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import "pages"
import Lomiri.Components.Popups 1.3

Page {
    id: pageSettings

    header: PageHeader {
        id: headerSettings
        title: i18n.tr("Settings");
        leadingActionBar.actions:
            Action {
                iconName: "back"
                text: "Back"
                onTriggered: {
                    pageStack.pop();
                }
            }
    }

    Rectangle {
        id:mainsettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: flickableSettings
            anchors.fill: parent
            contentHeight: settingsColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                spacing: units.gu(2)
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                ListItem.Header {
                    text: "<font color=\"#ffffff\">"+i18n.tr("General")+"</font>"
                }

                ListItem.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Dark background")+"</font>"
                    control: Switch {
                        checked:  if (launchermodular.settings.backgroundColor == "#000000"){ true; }else{ false;}
                        onClicked: {
                            if (launchermodular.settings.backgroundColor == "#000000"){
                                launchermodular.settings.backgroundColor = "#ffffff";
                                launchermodular.settings.textColor = "#000000"; }
                            else{
                                launchermodular.settings.backgroundColor = "#000000";
                                launchermodular.settings.textColor = "#ffffff"; }
                            }
                    }
                }

                Slider {
                    id: slideOpacity
                    anchors.horizontalCenter: parent.horizontalCenter;
                    value: launchermodular.settings.backgroundOpacity * 100
                    maximumValue: 100
                    minimumValue: 0
                    live: true
                    onValueChanged: {
                        launchermodular.settings.backgroundOpacity = slideOpacity.value/100
                    } onPressedChanged: {
                        if (pressed) {
                            pageSettings.opacity = 0
                            slideOpacity.opacity = 1 }
                        else {
                            launchermodular.settings.backgroundOpacity = slideOpacity.value/100
                            pageSettings.opacity = 1 }
                    }
                }

                ListItem.Standard {
                    id: blurSwitch
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Background blur effect")+"</font>"
                    control: Switch {
                        checked:  if (launchermodular.settings.backgroundBlur == 32){ true; }else{ false;}
                        onClicked: {if (launchermodular.settings.backgroundBlur == 32){ launchermodular.settings.backgroundBlur = 0; } else { launchermodular.settings.backgroundBlur = 32; }}
                    }
                }

            } // column
        } //flickable
    } //rectangle settings
}
