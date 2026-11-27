import QtQuick 2.12
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import "."

Page {
    id: pageSettingsCalendar

    property string nextcloudCalendarPageName: i18n.tr("nextcloud calendar") // used by the po files

    header: PageHeader {
        title: i18n.tr("Settings Page")
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: pageStack.pop()
            }
        ]
    }

    function saveAccount() {
        launchermodular.settings.nextcloudUrl = urlField.text
        launchermodular.settings.nextcloudUser = userField.text
        launchermodular.settings.nextcloudPassword = passwordField.text
        NextcloudCalendarModel.configure(urlField.text, userField.text, passwordField.text,
                                         launchermodular.settings.nextcloudCalendarHref)
        NextcloudCalendarModel.listCalendars(function () {})
    }

    Rectangle {
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            anchors.fill: parent
            contentHeight: settingsColumn.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                width: parent.width
                spacing: units.gu(1)

                ListItem.Header {
                    text: "<font color=\"#ffffff\">" + i18n.tr("Nextcloud account") + "</font>"
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    wrapMode: Text.WordWrap
                    color: "#ffffff"
                    text: i18n.tr("The same account as the Nextcloud folders page. The password is stored in clear text in the settings of the launcher.")
                }

                QControls.TextField {
                    id: urlField
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    placeholderText: i18n.tr("https://cloud.example.org")
                    text: launchermodular.settings.nextcloudUrl
                    inputMethodHints: Qt.ImhUrlCharactersOnly
                }
                QControls.TextField {
                    id: userField
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    placeholderText: i18n.tr("User")
                    text: launchermodular.settings.nextcloudUser
                }
                QControls.TextField {
                    id: passwordField
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    placeholderText: i18n.tr("Password")
                    text: launchermodular.settings.nextcloudPassword
                    echoMode: TextInput.Password
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Save and list the calendars")
                    onClicked: pageSettingsCalendar.saveAccount()
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    wrapMode: Text.WordWrap
                    color: "#ED3146"
                    text: NextcloudCalendarModel.lastError
                    visible: text.length > 0
                }

                ListItem.Header {
                    text: "<font color=\"#ffffff\">" + i18n.tr("Calendar") + "</font>"
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    wrapMode: Text.WordWrap
                    color: "#ffffff"
                    visible: NextcloudCalendarModel.calendars.length === 0
                    text: i18n.tr("No calendar listed yet. Use the button above.")
                }

                Repeater {
                    model: NextcloudCalendarModel.calendars
                    ListItem.Standard {
                        text: modelData.displayName.length > 0 ? modelData.displayName : modelData.href
                        selected: launchermodular.settings.nextcloudCalendarHref === modelData.href
                        onClicked: {
                            launchermodular.settings.nextcloudCalendarHref = modelData.href
                            launchermodular.settings.nextcloudCalendarName = modelData.displayName
                            NextcloudCalendarModel.selectCalendar(modelData.href, modelData.displayName)
                            NextcloudCalendarModel.refresh(60, 180)
                        }
                    }
                }

                ListItem.Header {
                    text: "<font color=\"#ffffff\">" + i18n.tr("Events") + "</font>"
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Synchronise now")
                    onClicked: NextcloudCalendarModel.refresh(60, 180)
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        margins: units.gu(2)
                    }
                    wrapMode: Text.WordWrap
                    color: "#ffffff"
                    text: i18n.tr("%1 events loaded").arg(NextcloudCalendarModel.events.count)
                }
            }
        }
    }
}
