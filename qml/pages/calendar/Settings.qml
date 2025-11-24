import QtQuick 2.4
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem

Page {
    id: pageSettingsCalendar

    property string calendarPageName: i18n.tr("calendar") // do not remove, use pour Po files

    header: PageHeader {
        id: calendarHeaderSettings
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
        id:calendarMainsettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: calendarFlickableSettings
            anchors.fill: parent
            contentHeight: calendarSettingsColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: calendarSettingsColumn
                anchors {
                   fill: parent
                   top: parent.top
                   topMargin: units.gu(2)
                   leftMargin: units.gu(1)
                   rightMargin: units.gu(1)
                }

                Item {
                    id: calendarSettingsRow
                    width: parent.width
                    height: units.gu(4)

                    Label {
                        id: calendarLimitOfDayLabel
                        text: i18n.tr("Limit of days")
                        color:  "#FFFFFF"
                        width: calendarSettingsRow.titleWidth
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        font.weight: Font.Light
                    }

                    Row {
                        id: calendarLimitOfDaySetting
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: calendarLimitOfDayLabel.right
                        anchors.leftMargin: units.gu(2)
                        anchors.right: parent.right
                        spacing: units.gu(2)

                        TextField {
                            objectName: "textfield_standard"
                            placeholderText: i18n.tr("By default 60 days")
                            width: parent.width
                            text: launchermodular.settings.limiteDaysCalendar
                            onTextChanged: launchermodular.settings.limiteDaysCalendar = text
                            inputMethodHints: Qt.ImhDigitsOnly;
                        }
                    }
                }
            } // column
        } //flickable
    } //rectangle settings
}
