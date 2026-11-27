import QtQuick 2.12
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import "."

// Settings of one "Nextcloud calendar" page.
//
// A page can hold several Nextcloud accounts (page data "nextcloudAccounts").
// The selected account has its own connection fields and its own calendar; all
// the accounts of the page are displayed together on the calendar page.
Page {
    id: pageSettingsCalendar

    property string nextcloudCalendarPageName: i18n.tr("nextcloud calendar") // used by the po files
    property int pageIndex: -1
    property string pageName: ""

    property var accounts: []
    property int selectedAccount: 0
    property string statusText: ""

    function pageConfig() {
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = launchermodular.pageModel.get(pageIndex).data
            if (data && typeof data === "object")
                return data
        }
        return ({})
    }

    function loadAccounts() {
        var config = pageConfig()
        if (config.nextcloudAccounts && config.nextcloudAccounts.length > 0) {
            accounts = JSON.parse(JSON.stringify(config.nextcloudAccounts))
        } else {
            accounts = [{
                url: config.nextcloudUrl || launchermodular.settings.nextcloudUrl || "",
                user: config.nextcloudUser || launchermodular.settings.nextcloudUser || "",
                password: config.nextcloudPassword || launchermodular.settings.nextcloudPassword || "",
                href: config.nextcloudCalendarHref || launchermodular.settings.nextcloudCalendarHref || "",
                name: ""
            }]
        }
        selectedAccount = 0
        loadFields()
    }

    function loadFields() {
        var account = accounts[selectedAccount]
        serverUrlField.text = account ? (account.url || "") : ""
        usernameField.text = account ? (account.user || "") : ""
        appPasswordField.text = account ? (account.password || "") : ""
        NextcloudCalendarModel.calendars = []
    }

    // Writes the fields back into the selected account, keeping its calendar.
    function storeFields() {
        if (selectedAccount < 0 || selectedAccount >= accounts.length)
            return
        var account = accounts[selectedAccount]
        accounts[selectedAccount] = {
            url: serverUrlField.text,
            user: usernameField.text,
            password: appPasswordField.text,
            href: account.href || "",
            name: account.name || ""
        }
    }

    function persist() {
        // Global copy: the page data is not serialised by the settings backend,
        // a string is. It also feeds the Event widget.
        launchermodular.settings.nextcloudAccountsJson = JSON.stringify(accounts)
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = pageConfig()
            var copy = {}
            for (var key in data)
                copy[key] = data[key]
            // Nested lists/maps are lost by the settings backend: the list is
            // stored as a JSON string, which serialises reliably.
            copy.nextcloudAccountsJson = JSON.stringify(accounts)
            launchermodular.pageModel.setProperty(pageIndex, "data", copy)
        } else {
            launchermodular.settings.nextcloudUrl = serverUrlField.text
            launchermodular.settings.nextcloudUser = usernameField.text
            launchermodular.settings.nextcloudPassword = appPasswordField.text
        }
    }

    function saveAndList() {
        if (serverUrlField.text.trim().length === 0 || usernameField.text.trim().length === 0
                || appPasswordField.text.length === 0) {
            statusText = i18n.tr("Complete the server URL, the username and the app password")
            return
        }
        storeFields()
        persist()
        NextcloudCalendarModel.configureAccounts(accounts)
        NextcloudCalendarModel.listCalendars(selectedAccount, function (list) {
            pageSettingsCalendar.statusText = list.length > 0
                    ? i18n.tr("%1 calendar(s) found").arg(list.length)
                    : i18n.tr("No calendar found")
        })
    }

    function selectCalendar(href, name) {
        var account = accounts[selectedAccount]
        accounts[selectedAccount] = { url: account.url, user: account.user,
                                      password: account.password, href: href, name: name }
        persist()
        NextcloudCalendarModel.configureAccounts(accounts)
        statusText = name
    }

    function addAccount() {
        storeFields()
        accounts.push({ url: "", user: "", password: "", href: "", name: "" })
        selectedAccount = accounts.length - 1
        loadFields()
    }

    function removeAccount() {
        if (accounts.length <= 1)
            return
        accounts.splice(selectedAccount, 1)
        selectedAccount = Math.min(selectedAccount, accounts.length - 1)
        persist()
        NextcloudCalendarModel.configureAccounts(accounts)
        loadFields()
    }

    Component.onCompleted: loadAccounts()

    header: PageHeader {
        id: headerCalendarSettings
        title: i18n.tr("Nextcloud calendar")
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: i18n.tr("Back")
                onTriggered: {
                    pageSettingsCalendar.storeFields()
                    pageSettingsCalendar.persist()
                    pageStack.pop()
                }
            }
        ]
    }

    Rectangle {
        id: calendarSettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: calendarSettingsFlickable
            anchors.fill: parent
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: settingsColumn
                width: parent.width
                anchors.topMargin: units.gu(2)
                spacing: units.gu(2)

                ListItemHeader.Header {
                    text: "<font color=\"#ffffff\">"
                          + i18n.tr("Account %1 of %2").arg(pageSettingsCalendar.selectedAccount + 1)
                                                    .arg(pageSettingsCalendar.accounts.length)
                          + "</font>"
                }

                Row {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Button {
                        height: units.gu(4)
                        width: (parent.width / 2) - units.gu(2)
                        text: i18n.tr("Add an account")
                        onClicked: pageSettingsCalendar.addAccount()
                    }
                    Button {
                        height: units.gu(4)
                        width: (parent.width / 2) - units.gu(2)
                        text: i18n.tr("Remove this account")
                        enabled: pageSettingsCalendar.accounts.length > 1
                        onClicked: pageSettingsCalendar.removeAccount()
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("Server URL")
                        color: "#FFFFFF"
                    }
                    QControls.TextField {
                        id: serverUrlField
                        width: parent.width
                        placeholderText: "https://cloud.example.com"
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                        onTextChanged: pageSettingsCalendar.storeFields()
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("Username")
                        color: "#FFFFFF"
                    }
                    QControls.TextField {
                        id: usernameField
                        width: parent.width
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        onTextChanged: pageSettingsCalendar.storeFields()
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Label {
                        text: i18n.tr("App password")
                        color: "#FFFFFF"
                    }
                    QControls.TextField {
                        id: appPasswordField
                        width: parent.width
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                        onTextChanged: pageSettingsCalendar.storeFields()
                    }
                    Label {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: "#AEA79F"
                        text: i18n.tr("Use a dedicated app password (Nextcloud Settings → Security → Devices & sessions), not your main account password. It can be revoked independently at any time.")
                    }
                }

                Row {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Button {
                        height: units.gu(4)
                        width: (parent.width / 2) - units.gu(2)
                        color: "#0E8420"
                        text: i18n.tr("Save and list the calendars")
                        onClicked: pageSettingsCalendar.saveAndList()
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width / 2
                        wrapMode: Text.WordWrap
                        color: NextcloudCalendarModel.lastError.length > 0 ? "#ED3146" : "#FFFFFF"
                        text: NextcloudCalendarModel.lastError.length > 0
                              ? NextcloudCalendarModel.lastError
                              : pageSettingsCalendar.statusText
                    }
                }

                ListItemHeader.Header {
                    text: "<font color=\"#ffffff\">" + i18n.tr("Calendar of this account") + "</font>"
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    color: "#FFFFFF"
                    visible: NextcloudCalendarModel.calendars.length === 0
                    text: i18n.tr("No calendar listed yet. Use the button above.")
                }

                Repeater {
                    model: NextcloudCalendarModel.calendars
                    ListItemHeader.Standard {
                        text: modelData.displayName.length > 0 ? modelData.displayName : modelData.href
                        selected: pageSettingsCalendar.accounts.length > pageSettingsCalendar.selectedAccount
                                  && pageSettingsCalendar.accounts[pageSettingsCalendar.selectedAccount].href === modelData.href
                        onClicked: pageSettingsCalendar.selectCalendar(modelData.href, modelData.displayName)
                    }
                }

                ListItemHeader.Header {
                    text: "<font color=\"#ffffff\">" + i18n.tr("Events of the page") + "</font>"
                }

                Row {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)

                    Button {
                        height: units.gu(4)
                        width: (parent.width / 2) - units.gu(2)
                        color: "#0E8420"
                        text: i18n.tr("Synchronise now")
                        onClicked: NextcloudCalendarModel.refresh(60, 180)
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width / 2
                        wrapMode: Text.WordWrap
                        color: "#FFFFFF"
                        text: i18n.tr("%1 events loaded").arg(NextcloudCalendarModel.events.count)
                    }
                }
            }
        }
    }
}
