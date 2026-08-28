import QtQuick 2.4
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem
import QtOrganizer 5.0


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

    OrganizerModel {
        id: calendarsPageModel
        manager: "eds"
        autoUpdate: true
    }

    function toggleCalendarSelection(collectionId, checked) {
        var allIds = []
        for (var i = 0; i < calendarsPageModel.collections.length; i++) {
            allIds.push(calendarsPageModel.collections[i].collectionId)
        }

        var current = launchermodular.settings.selectedCalendarPageIds
        var ids = (current && current.length > 0) ? current.slice() : allIds.slice()

        var idx = ids.indexOf(collectionId)
        if (checked && idx === -1) {
            ids.push(collectionId)
        } else if (!checked && idx !== -1) {
            ids.splice(idx, 1)
        }

        launchermodular.settings.selectedCalendarPageIds = (ids.length === allIds.length) ? [] : ids
    }

    function isCalendarSelected(collectionId) {
        var current = launchermodular.settings.selectedCalendarPageIds
        return !current || current.length === 0 || current.indexOf(collectionId) !== -1
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
                spacing: units.gu(2)
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                   topMargin: units.gu(2)
                }

                Item {
                    id: calendarSettingsRow
                    width: parent.width
                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: units.gu(2)
                        leftMargin: units.gu(2)
                    }
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

                Item {
                    id: calendarsFilterRow
                    width: parent.width
                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: units.gu(2)
                        leftMargin: units.gu(2)
                        topMargin: units.gu(2)
                    }
                    height: calendarsLabel.height + units.gu(1) + calendarsListView.height + units.gu(2)

                    Label {
                        id: calendarsLabel
                        text: i18n.tr("Calendars")
                        color: "#FFFFFF"
                        anchors.left: parent.left
                        anchors.top: parent.top
                        elide: Text.ElideRight
                        font.weight: Font.Light
                    }

                    Label {
                        visible: calendarsPageModel.collections.length === 0
                        anchors.top: calendarsLabel.bottom
                        anchors.topMargin: units.gu(1)
                        anchors.left: parent.left
                        text: i18n.tr("No calendar found")
                        color: "#AEA79F"
                        font.pointSize: units.gu(1.2)
                    }

                    ListView {
                        id: calendarsListView
                        model: calendarsPageModel.collections
                        anchors.top: calendarsLabel.bottom
                        anchors.topMargin: units.gu(1)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: calendarsPageModel.collections.length > 0
                        height: contentHeight
                        clip: true
                        interactive: contentHeight > height
                        spacing: units.gu(1)
                        delegate: CheckBox {
                            width: calendarsListView.width
                            text: modelData.name
                            checked: isCalendarSelected(modelData.collectionId)
                            onCheckedChanged: toggleCalendarSelection(modelData.collectionId, checked)
                        }
                    }
                }

            } // column
        } //flickable
    } //rectangle settings
}
