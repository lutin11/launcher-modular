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
    // Stable page identifier (injected by Pagemanagement).
    property string pageUid: ""
    property string pageName: ""

    property var accounts: []
    property int selectedAccount: 0
    // The connection fields are shown only while an account is being edited
    // (or when no usable account exists yet).
    property bool editingAccount: false
    property string statusText: ""

    function pageConfig() {
        if (pageUid.length > 0) {
            var stored = launchermodular.getPageConfig(pageUid)
            if (stored && typeof stored === "object")
                return stored
        }
        // Legacy: pages created before the uid stored their account here.
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = launchermodular.pageModel.get(pageIndex).data
            if (data && typeof data === "object")
                return data
        }
        return ({})
    }

    function loadAccounts() {
        var config = pageConfig()
        var loaded = null
        // The list of accounts is stored as a JSON string: the settings
        // backend does not serialise nested lists. Without this parse, leaving
        // and reopening the page showed only one account.
        if (config.nextcloudAccountsJson && config.nextcloudAccountsJson.length > 0) {
            try {
                loaded = JSON.parse(config.nextcloudAccountsJson)
            } catch (error) {
                loaded = null
            }
        }
        if (!loaded && config.nextcloudAccounts && config.nextcloudAccounts.length > 0) {
            loaded = JSON.parse(JSON.stringify(config.nextcloudAccounts))
        }
        if (!loaded || loaded.length === 0) {
            loaded = [{
                url: config.nextcloudUrl || launchermodular.settings.nextcloudUrl || "",
                user: config.nextcloudUser || launchermodular.settings.nextcloudUser || "",
                password: config.nextcloudPassword || launchermodular.settings.nextcloudPassword || "",
                href: config.nextcloudCalendarHref || launchermodular.settings.nextcloudCalendarHref || "",
                name: ""
            }]
        }
        var normalized = []
        for (var index = 0; index < loaded.length; index++)
            normalized.push(normalizeAccount(loaded[index]))
        accounts = normalized
        selectedAccount = 0
        loadFields()
        // No usable account: show the form directly so the page is not empty.
        editingAccount = !hasConfiguredAccount()
    }

    function hasConfiguredAccount() {
        for (var index = 0; index < accounts.length; index++) {
            var account = accounts[index]
            if (account && account.url && account.user && account.password)
                return true
        }
        return false
    }

    // One Nextcloud account can expose several calendars. The legacy single
    // href is turned into a one-element list.
    function normalizeAccount(account) {
        var copy = {
            url: account.url || "",
            user: account.user || "",
            password: account.password || "",
            href: account.href || "",
            name: account.name || "",
            calendars: []
        }
        var stored = account.calendars
        if (stored && stored.length > 0) {
            for (var index = 0; index < stored.length; index++) {
                if (stored[index] && stored[index].href)
                    copy.calendars.push({ href: stored[index].href,
                                          name: stored[index].name || "" })
            }
        } else if (copy.href) {
            copy.calendars.push({ href: copy.href, name: copy.name })
        }
        return copy
    }

    // The model expects one entry per calendar: an account can subscribe to
    // several calendars, and each of them is queried separately.
    function expandedAccounts() {
        var result = []
        for (var index = 0; index < accounts.length; index++) {
            var account = accounts[index]
            var calendars = account.calendars || []
            var expanded = false
            for (var calendarIndex = 0; calendarIndex < calendars.length; calendarIndex++) {
                if (!calendars[calendarIndex] || !calendars[calendarIndex].href)
                    continue
                result.push({ url: account.url, user: account.user,
                              password: account.password,
                              href: calendars[calendarIndex].href,
                              name: calendars[calendarIndex].name || "" })
                expanded = true
            }
            if (!expanded && account.href)
                result.push({ url: account.url, user: account.user,
                              password: account.password,
                              href: account.href, name: account.name || "" })
        }
        return result
    }

    function loadFields() {
        var account = accounts[selectedAccount]
        serverUrlField.text = account ? (account.url || "") : ""
        usernameField.text = account ? (account.user || "") : ""
        appPasswordField.text = account ? (account.password || "") : ""
        // Show the calendars already selected for this account; "Save and list
        // the calendars" replaces them with the full list from the server.
        var list = []
        var calendars = account ? (account.calendars || []) : []
        for (var index = 0; index < calendars.length; index++) {
            if (!calendars[index] || !calendars[index].href)
                continue
            list.push({ href: calendars[index].href,
                        displayName: calendars[index].name || calendars[index].href })
        }
        NextcloudCalendarModel.calendars = list
    }

    // Writes the fields back into the selected account, keeping its calendar.
    function storeFields() {
        if (selectedAccount < 0 || selectedAccount >= accounts.length)
            return
        var account = accounts[selectedAccount]
        // Accept either https://cloud.example.com, a sub-path install or a
        // pasted CalDAV address: keep only the server base.
        var url = serverUrlField.text.trim().replace(/\/+$/, "")
        var dav = url.indexOf("/remote.php/dav")
        if (dav >= 0)
            url = url.substring(0, dav)
        accounts[selectedAccount] = {
            url: url,
            user: usernameField.text,
            password: appPasswordField.text,
            href: account.href || "",
            name: account.name || "",
            calendars: account.calendars || []
        }
    }

    function persist() {
        // Global copy: the page data is not serialised by the settings backend,
        // a string is. It also feeds the Event widget.
        launchermodular.settings.nextcloudAccountsJson = JSON.stringify(accounts)
        if (pageUid.length > 0) {
            var config = pageConfig()
            config.nextcloudAccountsJson = JSON.stringify(accounts)
            launchermodular.setPageConfig(pageUid, config)
        }
        if (pageIndex >= 0 && pageIndex < launchermodular.pageModel.count) {
            var data = pageConfig()
            var copy = {}
            for (var key in data)
                copy[key] = data[key]
            // Nested lists/maps are lost by the settings backend: the list is
            // stored as a JSON string, which serialises reliably.
            copy.nextcloudAccountsJson = JSON.stringify(accounts)
            launchermodular.pageModel.setProperty(pageIndex, "data", copy)
        } else if (pageUid.length === 0) {
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
        NextcloudCalendarModel.configureAccounts(expandedAccounts())
        // The account is valid: fold the edition back to the account list, the
        // calendars are then listed in the background.
        editingAccount = false
        NextcloudCalendarModel.listCalendarsOf(accounts[selectedAccount], function (list) {
            pageSettingsCalendar.statusText = list.length > 0
                    ? i18n.tr("%1 calendar(s) found").arg(list.length)
                    : i18n.tr("No calendar found")
        })
    }

    function toggleCalendar(href, name) {
        if (selectedAccount < 0 || selectedAccount >= accounts.length)
            return
        storeFields()
        var account = accounts[selectedAccount]
        var calendars = (account.calendars || []).slice()
        var found = -1
        for (var index = 0; index < calendars.length; index++) {
            if (calendars[index].href === href) {
                found = index
                break
            }
        }
        if (found >= 0)
            calendars.splice(found, 1)
        else
            calendars.push({ href: href, name: name || "" })

        var first = calendars.length > 0 ? calendars[0] : { href: "", name: "" }
        // Copy the array before changing it: mutating a property in place does
        // not notify the list of accounts (and its selection marks).
        var copy = accounts.slice()
        copy[selectedAccount] = { url: account.url, user: account.user,
                                  password: account.password,
                                  href: first.href, name: first.name,
                                  calendars: calendars }
        accounts = copy
        persist()
        NextcloudCalendarModel.configureAccounts(expandedAccounts())
        statusText = calendars.length > 0
                ? i18n.tr("%1 calendar(s) selected").arg(calendars.length)
                : i18n.tr("No calendar selected")
    }

    function addAccount() {
        storeFields()
        var copy = accounts.slice()
        copy.push({ url: "", user: "", password: "", href: "", name: "", calendars: [] })
        accounts = copy
        selectedAccount = accounts.length - 1
        loadFields()
        editingAccount = true
    }

    function removeAccount() {
        if (accounts.length <= 1)
            return
        var copy = accounts.slice()
        copy.splice(selectedAccount, 1)
        accounts = copy
        selectedAccount = Math.min(selectedAccount, accounts.length - 1)
        persist()
        NextcloudCalendarModel.configureAccounts(expandedAccounts())
        loadFields()
        editingAccount = !hasConfiguredAccount()
    }

    Component.onCompleted: loadAccounts()

    header: PageHeader {
        id: headerCalendarSettings
        title: i18n.tr("Settings Page")
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
            // Without an explicit content height a long list of calendars
            // could not be scrolled: the Flickable only followed its own
            // height.
            contentHeight: settingsColumn.height + units.gu(4)
            contentWidth: width
            clip: true

            Column {
                id: settingsColumn
                width: parent.width
                anchors.topMargin: units.gu(2)
                spacing: units.gu(2)

                ListItemHeader.Header {
                    width: parent.width
                    text: "<font color=\"#ffffff\">"
                          + i18n.tr("Settings for 'Nextcloud calendar' page")
                          + "</font>"
                }

                ListItemHeader.Header {
                    width: parent.width
                    text: "<font color=\"#ffffff\">"
                          + i18n.tr("Accounts")
                          + "</font>"
                }

                // One row per account: touch a row to edit its connection
                // fields below, use "Remove this account" to delete it.
                Repeater {
                    model: pageSettingsCalendar.accounts
                    ListItemHeader.Standard {
                        width: parent.width
                        __foregroundColor: "#FFFFFF"
                        text: (modelData.user && modelData.user.length > 0
                               ? modelData.user
                               : i18n.tr("New account"))
                              + (modelData.url && modelData.url.length > 0
                                 ? " — " + modelData.url : "")
                        selected: index === pageSettingsCalendar.selectedAccount
                        onClicked: {
                            if (pageSettingsCalendar.editingAccount
                                    && index === pageSettingsCalendar.selectedAccount) {
                                pageSettingsCalendar.editingAccount = false
                                return
                            }
                            pageSettingsCalendar.storeFields()
                            pageSettingsCalendar.selectedAccount = index
                            pageSettingsCalendar.loadFields()
                            pageSettingsCalendar.editingAccount = true
                        }
                    }
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

                ListItemHeader.Header {
                    width: parent.width
                    visible: pageSettingsCalendar.editingAccount
                    text: "<font color=\"#ffffff\">"
                          + i18n.tr("Connection of the selected account")
                          + "</font>"
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)
                    visible: pageSettingsCalendar.editingAccount

                    Label {
                        text: i18n.tr("Server URL or CalDAV address")
                        color: "#FFFFFF"
                    }
                    Row {
                        width: parent.width
                        spacing: units.gu(1)
                        QControls.TextField {
                            id: serverUrlField
                            width: parent.width - pasteUrlButton.width - clearUrlButton.width - units.gu(2)
                            placeholderText: "https://cloud.example.com (or …/remote.php/dav)"
                            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                            selectByMouse: true
                            onTextChanged: pageSettingsCalendar.storeFields()
                        }
                        Button {
                            id: pasteUrlButton
                            width: units.gu(6)
                            height: units.gu(4)
                            text: i18n.tr("Paste")
                            onClicked: serverUrlField.paste()
                        }
                        Icon {
                            id: clearUrlButton
                            width: units.gu(2)
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                            name: "edit-clear"
                            color: "#FFFFFF"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: units.gu(-1)
                                onClicked: serverUrlField.text = ""
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)
                    visible: pageSettingsCalendar.editingAccount

                    Label {
                        text: i18n.tr("Username")
                        color: "#FFFFFF"
                    }
                    Row {
                        width: parent.width
                        spacing: units.gu(1)
                        QControls.TextField {
                            id: usernameField
                            width: parent.width - pasteUserButton.width - clearUserButton.width - units.gu(2)
                            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            selectByMouse: true
                            onTextChanged: pageSettingsCalendar.storeFields()
                        }
                        Button {
                            id: pasteUserButton
                            width: units.gu(6)
                            height: units.gu(4)
                            text: i18n.tr("Paste")
                            onClicked: usernameField.paste()
                        }
                        Icon {
                            id: clearUserButton
                            width: units.gu(2)
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                            name: "edit-clear"
                            color: "#FFFFFF"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: units.gu(-1)
                                onClicked: usernameField.text = ""
                            }
                        }
                    }
                }

                Column {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(1)
                    visible: pageSettingsCalendar.editingAccount

                    Label {
                        text: i18n.tr("App password")
                        color: "#FFFFFF"
                    }
                    Row {
                        width: parent.width
                        spacing: units.gu(1)
                        QControls.TextField {
                            id: appPasswordField
                            width: parent.width - pastePasswordButton.width - clearPasswordButton.width - units.gu(2)
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                            selectByMouse: true
                            onTextChanged: pageSettingsCalendar.storeFields()
                        }
                        Button {
                            id: pastePasswordButton
                            width: units.gu(6)
                            height: units.gu(4)
                            text: i18n.tr("Paste")
                            onClicked: appPasswordField.paste()
                        }
                        Icon {
                            id: clearPasswordButton
                            width: units.gu(2)
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                            name: "edit-clear"
                            color: "#FFFFFF"
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: units.gu(-1)
                                onClicked: appPasswordField.text = ""
                            }
                        }
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
                    text: "<font color=\"#ffffff\">" + i18n.tr("Calendars of this account (select one or more)") + "</font>"
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
                        __foregroundColor: "#FFFFFF"
                        text: (modelData.displayName.length > 0 ? modelData.displayName : modelData.href)
                              + (selected ? "  ✓" : "")
                        selected: {
                            if (pageSettingsCalendar.accounts.length <= pageSettingsCalendar.selectedAccount)
                                return false
                            var calendars = pageSettingsCalendar.accounts[pageSettingsCalendar.selectedAccount].calendars || []
                            for (var index = 0; index < calendars.length; index++)
                                if (calendars[index].href === modelData.href)
                                    return true
                            return false
                        }
                        onClicked: pageSettingsCalendar.toggleCalendar(modelData.href, modelData.displayName)
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
