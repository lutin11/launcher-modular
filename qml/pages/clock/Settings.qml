import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import Lomiri.Components.Themes 1.3
import QtQuick.Window 2.10

Page {
    id: clockSettingsPicture

    property int maxFontPixelSize: 10 // Default, will be updated dynamically

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
                    text: "<font color=\"#ffffff\">"+i18n.tr("Settings for 'Music' page")+"</font>"
                }

                Text {
                    id: digitalClock
                    anchors.top: titleCalendarManagement.bottom
                    anchors.topMargin: units.gu(2)
                    anchors.horizontalCenter: parent.horizontalCenter;
                    anchors.leftMargin: units.gu(1)
                    anchors.rightMargin: units.gu(1)
                    font.family: launchermodular.settings.clockFontFamily
                    font.pixelSize: launchermodular.settings.clockFontSize
                    font.bold: launchermodular.settings.clockFontBold
                    font.italic: launchermodular.settings.clockFontItalic
                    color: launchermodular.settings.clockFontColor
                    maximumLineCount: 1
                    elide: Text.ElideMiddle
                    wrapMode: Text.WrapAnywhere
                    text: if(launchermodular.settings.clockHHMMSS) {"88:88:88"} else {"88:88"}
                }
                Timer {
                    interval: if(launchermodular.settings.clockHHMMSS) {1000} else {60000}
                    running: true
                    repeat: true
                    onTriggered: {
                        // Update the time
                        const date = new Date();
                        let hours = date.getHours();
                        let minutes = date.getMinutes();
                        let seconds = date.getSeconds();

                        // Format as hh:mm:ss
                        digitalClock.text = launchermodular.settings.clockHHMMSS
                                ? `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
                                : `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
                    }
                }
                
                Slider {
                    id: sliderFontSize
                    function formatValue(v) { return v.toFixed(2) }
                    anchors.top: digitalClock.bottom
                    anchors.topMargin: units.gu(2)
                    anchors.horizontalCenter: parent.horizontalCenter;
                    value: (launchermodular.settings.clockFontSize-24)/2.4
                    minimumValue: 10.0
                    maximumValue: 70.0
                    live: true
                    onPressedChanged: {
                        if (pressed) {
                            sliderFontSize.visible = true;
                        }
                    }
                }

                TextMetrics {
                    id: textMetrics
                    font: digitalClock.font
                    text: digitalClock.text
                    onWidthChanged: {
                        launchermodular.settings.clockFontSize = (2.4 * sliderFontSize.value) + 24
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
                
                property var fontTypeModel: [
                    { name: "<font color=\"#ffffff\">i18n.tr('Bold')</font>", value: "#DSEG7Classic-Bold"},
                    { name: "<font color=\"#ffffff\">18n.tr('BoldItalic')</font>", value: "DSEG7Classic-BoldItalic"},
                    { name: "<font color=\"#ffffff\">18n.tr('Italic')</font>", value: "DSEG7Classic-Italic"},
                    { name: "<font color=\"#ffffff\">18n.tr('Regular')</font>", value: "DSEG7Classic-Regular"}
                ]

                ListItemHeader.ItemSelector {
                    id: fontTypeList
                    width: clocksettings.width - (fontTypeLabel.width + units.gu(4))
                    anchors.top: colorSelection.bottom
                    anchors.topMargin: units.gu(2)
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(1)
                    model: [
                    { name: "<font color=\"#ffffff\">i18n.tr('Bold')</font>", value: "#DSEG7Classic-Bold"},
                    { name: "<font color=\"#ffffff\">18n.tr('BoldItalic')</font>", value: "DSEG7Classic-BoldItalic"},
                    { name: "<font color=\"#ffffff\">18n.tr('Italic')</font>", value: "DSEG7Classic-Italic"},
                    { name: "<font color=\"#ffffff\">18n.tr('Regular')</font>", value: "DSEG7Classic-Regular"}
                    ]
                    delegate: OptionSelectorDelegate {
                        property var item: model.modelData ? model.modelData : model
                        text: item.name
                    }
                    onSelectedIndexChanged: {
                        var typeChoice = model[selectedIndex].value
                        if (typeChoice === "#DSEG7Classic-Bold") {
                            launchermodular.settings.clockFontBold = true
                            launchermodular.settings.clockFontItalic = false
                        } else if (typeChoice === "DSEG7Classic-BoldItalic") {
                            launchermodular.settings.clockFontBold = true
                            launchermodular.settings.clockFontItalic = true
                        } else if (typeChoice === "DSEG7Classic-Italic") {
                             launchermodular.settings.clockFontBold = false
                             launchermodular.settings.clockFontItalic = true
                        } else if (typeChoice === "DSEG7Classic-Regular") {
                              launchermodular.settings.clockFontBold = false
                              launchermodular.settings.clockFontItalic = false
                        }
                    }
                    Component.onCompleted: {
                        if (launchermodular.settings.clockFontBold == true &&
                            launchermodular.settings.clockFontItalic == false) {
                            selectedIndex = 0
                        } else if (launchermodular.settings.clockFontBold == true &&
                            launchermodular.settings.clockFontItalic == true) {
                            selectedIndex = 1
                        } else if (
                            launchermodular.settings.clockFontBold == false &&
                            launchermodular.settings.clockFontItalic == true) {
                            selectedIndex = 2
                        } else if (launchermodular.settings.clockFontBold == false &&
                                launchermodular.settings.clockFontItalic == false) {
                            selectedIndex = 3
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
                    width: clocksettings.width - (clockFormatLabel.width + units.gu(4))
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
