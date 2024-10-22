import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem

Page {
    id: widgetSettingsLastmessage

    header: PageHeader {
        id: headerSettings
        title: i18n.tr("Settings Widget");
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

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                ListItem.Header {
                    text: "<font color=\"#ffffff\">"+i18n.tr("Generals")+"</font>"
                }

                Item {
                    id: templateRow
                    width: parent.width
                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: units.gu(2)
                        leftMargin: units.gu(2)
                    }
                    height: units.gu(4)

                    Label {
                        id: label
                        text: i18n.tr("Number of displayed calls :")
                        color:  "white"
                        width: templateRow.titleWidth
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        font.weight: Font.Light
                    }

                    Row {
                        id: contentRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: units.gu(2)
                        anchors.right: parent.right
                        spacing: units.gu(2)
                        TextField {
                            objectName: "textfield_standard"
                            placeholderText: i18n.tr("By default 1")
                            width: parent.width
                            text: launchermodular.settings.numberOfCallWidget
                            onTextChanged: { launchermodular.settings.numberOfCallWidget = text }
                            inputMethodHints: Qt.ImhDigitsOnly;
                        }
                    }
                }

                ListItem.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("View a summary")+"</font>"
                    control: Switch {
                        checked: launchermodular.settings.widgetMessageSummary
                        onClicked: if (launchermodular.settings.widgetMessageSummary === false) {
                                launchermodular.settings.widgetMessageSummary = true;
                            } else {
                                launchermodular.settings.widgetMessageSummary = false;
                            }
                    }
                }

                property var model: [
                  { title: "<font color=\"#ffffff\">"+i18n.tr("Default")+"</font>", descr: "<font color=\"#ffffff\">"+i18n.tr("Open the dialer")+"</font>", style:"default" },
                  { title: "<font color=\"#ffffff\">"+i18n.tr("Call")+"</font>", descr: "<font color=\"#ffffff\">"+i18n.tr("Open the dialer with number")+"</font>", style:"dial" }
                ]

                ListItem.ItemSelector {
                    id: actionWidgetList
                    width: (parent.width-textactionWidgets.width)-units.gu(6)
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(2)
                    anchors.topMargin: units.gu(2)
                    model: settingsColumn.model
                    delegate: OptionSelectorDelegate {
                        property var item: model.modelData ? model.modelData : model
                        text: item.title
                        subText: item.descr
                    }
                    onSelectedIndexChanged: {
                        launchermodular.settings.widgetCallClick = model[selectedIndex].style
                    }
                    Component.onCompleted: {
                        if ("dial" === launchermodular.settings.widgetCallClick){selectedIndex = 1}
                        if ("default" === launchermodular.settings.widgetCallClick){selectedIndex = 0}
                    }

                    Text {
                        id: textactionWidgets
                        text: i18n.tr("When clicked : ")
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
