import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import Lomiri.Components.Themes 1.3
import QtQuick.Window 2.10
import QtSensors 5.12

Page {
    id: clockSettingsPicture

    property string clockPageName: i18n.tr("clock") // do not remove, use pour Po files
    property int pixelDensityFactor: Screen.pixelDensity.toFixed(2) / 5.51

    function updateTime() {
        const date = new Date();
        let hours = date.getHours();
        let minutes = date.getMinutes();
        let seconds = date.getSeconds();

        // Format as hh:mm:ss
        digitalClock.text = launchermodular.settings.clockHHMMSS
                ? `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
                : `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    }

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
        id:clocksettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: flickableClockSettings
            anchors.fill: parent
            contentHeight: settingsColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                anchors.fill: parent

                ListItemHeader.Header {
                    id: titleCalendarManagement
                    text: "<font color=\"#ffffff\">"+i18n.tr("Settings for 'Clock' page")+"</font>"
                }

                Text {
                    id: digitalClock
                    anchors.top: titleCalendarManagement.bottom
                    anchors.topMargin: units.gu(2)
                    anchors.horizontalCenter: parent.horizontalCenter;
                    anchors.leftMargin: units.gu(1)
                    anchors.rightMargin: units.gu(1)
                    font.family: launchermodular.settings.clockFontFamily
                    font.pixelSize: launchermodular.settings.clockFontSize * pixelDensityFactor
                    font.italic: launchermodular.settings.clockFontItalic
                    font.weight: launchermodular.settings.clockFontWeight
                    color: launchermodular.settings.clockFontColor
                    maximumLineCount: 1
                    elide: Text.ElideMiddle
                    wrapMode: Text.WrapAnywhere
                    text: if(launchermodular.settings.clockHHMMSS) {"88:88:88"} else {"88:88"}
                }
                Timer {
                    id: timer
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        updateTime();
                    }
                }
                
                Slider {
                    id: sliderFontSize
                    function formatValue(v) { return v.toFixed(2) }
                    anchors.top: digitalClock.bottom
                    anchors.topMargin: units.gu(2)
                    anchors.horizontalCenter: parent.horizontalCenter;
                    value: launchermodular.settings.clockFontSize
                    minimumValue: 10.0
                    maximumValue: 100.0
                    live: true
                    onValueChanged: { launchermodular.settings.clockFontSize = sliderFontSize.value}
                    onPressedChanged: {
                        if (pressed) {
                            sliderFontSize.visible = true;
                        }
                    }
                }

                Grid {
                    id: colorSelection
                    anchors.top: sliderFontSize.bottom
                    anchors.topMargin: units.gu(2)
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
                            onClicked: launchermodular.settings.clockFontColor = modelData
                        }
                    }
                }

                ListItemHeader.ItemSelector {
                    id: fontTypeList
                    width: (clocksettings.width - fontTypeLabel.width) - units.gu(8)
                    anchors.top: colorSelection.bottom
                    anchors.topMargin: units.gu(2)
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(1)
                    model: [
                        { name: "<font color=\"#ffffff\">"+i18n.tr("Bold")+"</font>", value: "DSEG7Classic-Bold"},
                        { name: "<font color=\"#ffffff\">"+i18n.tr("BoldItalic")+"</font>", value: "DSEG7Classic-BoldItalic"},
                        { name: "<font color=\"#ffffff\">"+i18n.tr("Regular")+"</font>", value: "DSEG7Classic-Regular"},
                        { name: "<font color=\"#ffffff\">"+i18n.tr("Italic")+"</font>", value: "DSEG7Classic-Italic"},
                        { name: "<font color=\"#ffffff\">"+i18n.tr("Light")+"</font>", value: "DSEG7Classic-Light"},
                        { name: "<font color=\"#ffffff\">"+i18n.tr("LightItalic")+"</font>", value: "DSEG7Classic-LightItalic"}
                    ]
                    delegate: OptionSelectorDelegate {
                        property var item: model.modelData ? model.modelData : model
                        text: item.name
                    }
                    onSelectedIndexChanged: {
                        console.log("selectedIndex :"+selectedIndex);
                        var typeChoice = model[selectedIndex].value
                        if (selectedIndex === 0) {
                            launchermodular.settings.clockFontWeight = Font.Bold
                            launchermodular.settings.clockFontItalic = false
                        } else if (selectedIndex === 1) {
                            launchermodular.settings.clockFontWeight = Font.Bold
                            launchermodular.settings.clockFontItalic = true
                        } else if (selectedIndex === 2) {
                            launchermodular.settings.clockFontWeight = Font.Normal
                            launchermodular.settings.clockFontItalic = false
                        } else if (selectedIndex === 3) {
                            launchermodular.settings.clockFontWeight = Font.Normal
                            launchermodular.settings.clockFontItalic = true
                        } else if (selectedIndex === 4) {
                            launchermodular.settings.clockFontWeight = Font.Light
                            launchermodular.settings.clockFontItalic = false
                        } else if (selectedIndex === 5) {
                            launchermodular.settings.clockFontWeight = Font.Light
                            launchermodular.settings.clockFontItalic = true
                        }
                    }
                    Component.onCompleted: {
                        if (launchermodular.settings.clockFontWeight == Font.Bold &&
                            launchermodular.settings.clockFontItalic == false) {
                            selectedIndex = 0
                        } else if (launchermodular.settings.clockFontWeight == Font.Bold &&
                            launchermodular.settings.clockFontItalic == true) {
                            selectedIndex = 1
                        } else if (launchermodular.settings.clockFontWeight == Font.Normal &&
                            launchermodular.settings.clockFontItalic == false) {
                            selectedIndex = 2
                        }  else if (
                            launchermodular.settings.clockFontWeight == Font.Normal &&
                            launchermodular.settings.clockFontItalic == true) {
                            selectedIndex = 3
                        } else if (launchermodular.settings.clockFontWeight == Font.Light &&
                            launchermodular.settings.clockFontItalic == false) {
                            selectedIndex = 4
                        } else if (launchermodular.settings.clockFontWeight == Font.Light &&
                            launchermodular.settings.clockFontItalic == false) {
                            selectedIndex = 5
                        }
                    }

                    Text {
                        id: fontTypeLabel
                        text: i18n.tr("Font type : ")
                        height: units.gu(5)
                        anchors.right: parent.left
                        anchors.rightMargin: units.gu(2)
                        color: "#ffffff"
                        verticalAlignment: Text.AlignVCenter
                    }

                }

                ListItemHeader.ItemSelector {
                    id: clockFormat
                    width: (clocksettings.width - fontTypeLabel.width) - units.gu(8)
                    anchors.top: fontTypeList.bottom
                    anchors.topMargin: units.gu(2)
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(1)
                    model: [
                    { name: "<font color=\"#ffffff\">88:88:88</font>", value: "hh:mm:ss"},
                    { name: "<font color=\"#ffffff\">88:88</font>", value: "hh:mm"},
                    ]
                    delegate: OptionSelectorDelegate {
                        property var item: model.modelData ? model.modelData : model
                        text: item.name
                    }
                    onSelectedIndexChanged: {
                        var typeChoice = model[selectedIndex].value
                        if (typeChoice == "hh:mm:ss") {
                            launchermodular.settings.clockHHMMSS = true
                        } else {
                            launchermodular.settings.clockHHMMSS = false
                        }
                        updateTime();
                    }
                    Component.onCompleted: {
                        if (launchermodular.settings.clockHHMMSS == true) {
                            selectedIndex = 0
                        } else {
                            selectedIndex = 1
                        }
                    }

                    Text {
                        id: clockFormatLabel
                        text: i18n.tr("Format : ")
                        height: units.gu(5)
                        anchors.right: parent.left
                        anchors.rightMargin: units.gu(2)
                        color: "#ffffff"
                        verticalAlignment: Text.AlignVCenter
                    }

                }

            } // column
        } //flickable
    } //rectangle settings
}
