import QtQuick 2.12
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem

Page {
    id: pageSettingsTodo

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

                ListItem.Header {
                    id: titleCalendarManagement
                    text: "<font color=\"#ffffff\">"+i18n.tr("No settings for 'TODO' page")+"</font>"
                }

                anchors {
                   fill: parent
                   top: parent.top
                   topMargin: units.gu(2)
                   leftMargin: units.gu(1)
                   rightMargin: units.gu(1)
                }
            } // column
        } //flickable
    } //rectangle settings



}
