import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import QtOrganizer 5.0

Page {
    id: widgetSettingsEvent

    OrganizerModel {
        id: calendarsModel
        manager: "eds"
        autoUpdate: true
    }

    function toggleCalendarSelection(collectionId, checked) {
        var allIds = []
        for (var i = 0; i < calendarsModel.collections.length; i++) {
            allIds.push(calendarsModel.collections[i].collectionId)
        }

        var current = launchermodular.settings.selectedCalendarIds
        var ids = (current && current.length > 0) ? current.slice() : allIds.slice()

        var idx = ids.indexOf(collectionId)
        if (checked && idx === -1) {
            ids.push(collectionId)
        } else if (!checked && idx !== -1) {
            ids.splice(idx, 1)
        }

        launchermodular.settings.selectedCalendarIds = (ids.length === allIds.length) ? [] : ids
    }

    function isCalendarSelected(collectionId) {
        var current = launchermodular.settings.selectedCalendarIds
        return !current || current.length === 0 || current.indexOf(collectionId) !== -1
    }

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
        color: "#111111"
        anchors.fill: parent
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
                    topMargin: units.gu(2)
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
                        text: i18n.tr("Limit of days")
                        color:  "#FFFFFF"
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
                            placeholderText: i18n.tr("By default 60 days")
                            width: parent.width
                            text: launchermodular.settings.limiteDaysWidgetEvent
                            onTextChanged: { launchermodular.settings.limiteDaysWidgetEvent = text }
                            inputMethodHints: Qt.ImhDigitsOnly;
                        }
                    }
                }

                Item {
                    id: templateRow2
                    width: parent.width
                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: units.gu(2)
                        leftMargin: units.gu(2)
                        topMargin: units.gu(2)
                    }
                    height: units.gu(4)

                    Label {
                        id: label2
                        text: i18n.tr("Limit of event")
                        color:  "#FFFFFF"
                        width: templateRow2.titleWidth
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        font.weight: Font.Light
                    }

                    Row {
                        id: contentRow2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label2.right
                        anchors.leftMargin: units.gu(2)
                        anchors.right: parent.right
                        spacing: units.gu(2)

                        TextField {
                            objectName: "textfield_standard"
                            placeholderText: i18n.tr("By default 3 event")
                            width: parent.width
                            text: launchermodular.settings.limiteItemWidgetEvent
                            onTextChanged: { launchermodular.settings.limiteItemWidgetEvent = parseInt(text) }
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
                    height: calendarsColumn.height + units.gu(2)

                    Label {
                        id: calendarsLabel
                        text: i18n.tr("Calendars")
                        color: "#FFFFFF"
                        anchors.left: parent.left
                        anchors.top: parent.top
                        elide: Text.ElideRight
                        font.weight: Font.Light
                    }

                    Column {
                        id: calendarsColumn
                        anchors.top: calendarsLabel.bottom
                        anchors.topMargin: units.gu(1)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: units.gu(1)

                        Label {
                            visible: calendarsModel.collections.length === 0
                            text: i18n.tr("No calendar found")
                            color: "#AEA79F"
                            font.pointSize: units.gu(1.2)
                        }

                        Repeater {
                            model: calendarsModel.collections
                            delegate: CheckBox {
                                width: calendarsColumn.width
                                text: modelData.name
                                checked: isCalendarSelected(modelData.collectionId)
                                onCheckedChanged: toggleCalendarSelection(modelData.collectionId, checked)
                            }
                        }
                    }
                }

            } // column
        } //flickable
    } //rectangle settings

}
