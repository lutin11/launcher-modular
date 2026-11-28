import QtQuick 2.12
import QtQuick.Controls 2.2 as QControls
import Lomiri.Components 1.3
import "."
import "../../components"

// Settings of one "Nextcloud calendar" page.
//
// A page can hold several Nextcloud accounts (stored as JSON in the page
// configuration). The layout shows one section at a time of the same story:
// the accounts, the connection of the selected account, its calendars, then
// the synchronisation.
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
    property bool statusIsError: false

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
        // backend does not serialise nested lists.
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
        statusText = ""
        statusIsError = false
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

    function selectedAccountConfigured() {
        var account = accounts[selectedAccount]
        return !!(account && account.url && account.user && account.password)
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
        // Show the calendars already selected for this account; "Load
        // calendars" replaces them with the full list from the server.
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

    // Writes the fields back into the selected account, keeping its calendars.
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

    // Reassign the array so the account list (labels, selection) is refreshed
    // after the fields were changed in place.
    function notifyAccounts() {
        accounts = accounts.slice()
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

    function selectAccount(index) {
        if (editingAccount && index === selectedAccount) {
            closeForm()
            return
        }
        storeFields()
        selectedAccount = index
        statusText = ""
        statusIsError = false
        loadFields()
        editingAccount = true
    }

    function closeForm() {
        storeFields()
        notifyAccounts()
        persist()
        editingAccount = false
    }

    function saveAndList() {
        if (serverUrlField.text.trim().length === 0 || usernameField.text.trim().length === 0
                || appPasswordField.text.length === 0) {
            statusText = i18n.tr("Complete the server URL, the username and the app password")
            statusIsError = true
            return
        }
        storeFields()
        notifyAccounts()
        persist()
        NextcloudCalendarModel.configureAccounts(expandedAccounts())
        // The account is valid: fold the edition back to the account list, the
        // calendars are then listed in the background.
        editingAccount = false
        loadCalendars()
    }

    function loadCalendars() {
        if (selectedAccount < 0 || selectedAccount >= accounts.length)
            return
        storeFields()
        notifyAccounts()
        persist()
        NextcloudCalendarModel.configureAccounts(expandedAccounts())
        NextcloudCalendarModel.lastError = ""
        statusText = i18n.tr("Loading the calendars…")
        statusIsError = false
        NextcloudCalendarModel.listCalendarsOf(accounts[selectedAccount], function (list) {
            pageSettingsCalendar.statusText = list.length > 0
                    ? i18n.tr("%1 calendar(s) found").arg(list.length)
                    : i18n.tr("No calendar found")
            // A server error is displayed from lastError; an empty account is
            // not an error.
            pageSettingsCalendar.statusIsError = false
        })
    }

    function isCalendarSelected(href) {
        var account = accounts[selectedAccount]
        if (!account)
            return false
        var calendars = account.calendars || []
        for (var index = 0; index < calendars.length; index++) {
            if (calendars[index].href === href)
                return true
        }
        return false
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
        statusIsError = false
    }

    function addAccount() {
        storeFields()
        var copy = accounts.slice()
        copy.push({ url: "", user: "", password: "", href: "", name: "", calendars: [] })
        accounts = copy
        selectedAccount = accounts.length - 1
        statusText = ""
        statusIsError = false
        loadFields()
        editingAccount = true
    }

    function removeAccount() {
        if (accounts.length <= 1) {
            statusText = i18n.tr("The last account cannot be removed")
            statusIsError = true
            return
        }
        var copy = accounts.slice()
        copy.splice(selectedAccount, 1)
        accounts = copy
        selectedAccount = Math.min(selectedAccount, accounts.length - 1)
        persist()
        NextcloudCalendarModel.configureAccounts(expandedAccounts())
        loadFields()
        editingAccount = !hasConfiguredAccount()
        statusText = ""
        statusIsError = false
    }

    Component.onCompleted: loadAccounts()

    header: PageHeader {
        id: headerCalendarSettings
        title: i18n.tr("Calendar settings")
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
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: settingsFlickable
            anchors.fill: parent
            flickableDirection: Flickable.VerticalFlick
            contentHeight: settingsColumn.height + units.gu(4)
            contentWidth: width
            clip: true

            Column {
                id: settingsColumn
                width: parent.width
                anchors.topMargin: units.gu(2)
                spacing: units.gu(2)

                // ----------------------------------------------------------
                // Accounts
                // ----------------------------------------------------------
                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Accounts")
                    color: "#FFFFFF"
                    font.pixelSize: units.gu(2.2)
                    font.bold: true
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    color: "#AEA79F"
                    font.pixelSize: units.gu(1.4)
                    text: i18n.tr("Choose an account to edit its connection, or add a new one.")
                }

                Repeater {
                    model: pageSettingsCalendar.accounts
                    Rectangle {
                        width: settingsColumn.width - units.gu(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: units.gu(7)
                        radius: units.gu(0.6)
                        color: index === pageSettingsCalendar.selectedAccount ? "#26E95420" : "#14FFFFFF"
                        border.width: 1
                        border.color: index === pageSettingsCalendar.selectedAccount ? "#E95420" : "#26FFFFFF"

                        Icon {
                            id: accountIcon
                            anchors.left: parent.left
                            anchors.leftMargin: units.gu(1.5)
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(2.5)
                            height: width
                            name: "contact"
                            color: "#FFFFFF"
                            opacity: 0.8
                        }

                        Column {
                            anchors.left: accountIcon.right
                            anchors.leftMargin: units.gu(1.5)
                            anchors.right: accountChevron.left
                            anchors.rightMargin: units.gu(1)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: units.gu(0.2)

                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                color: "#FFFFFF"
                                font.pixelSize: units.gu(1.6)
                                text: (modelData.user && modelData.user.length > 0)
                                      ? modelData.user : i18n.tr("New account")
                            }
                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                color: "#AEA79F"
                                font.pixelSize: units.gu(1.2)
                                text: (modelData.url && modelData.url.length > 0)
                                      ? modelData.url : i18n.tr("Not configured")
                            }
                        }

                        Icon {
                            id: accountChevron
                            anchors.right: parent.right
                            anchors.rightMargin: units.gu(1.5)
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(2)
                            height: width
                            name: "go-next"
                            color: "#AEA79F"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: pageSettingsCalendar.selectAccount(index)
                        }
                    }
                }

                Button {
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.gu(4.5)
                    text: i18n.tr("Add an account")
                    onClicked: pageSettingsCalendar.addAccount()
                }

                // ----------------------------------------------------------
                // Connection of the selected account
                // ----------------------------------------------------------
                Column {
                    width: settingsColumn.width
                    visible: pageSettingsCalendar.editingAccount
                    spacing: units.gu(1.5)

                    Label {
                        width: parent.width - units.gu(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: i18n.tr("Connection")
                        color: "#FFFFFF"
                        font.pixelSize: units.gu(2.2)
                        font.bold: true
                    }

                    Rectangle {
                        width: settingsColumn.width - units.gu(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: connectionColumn.height + units.gu(3)
                        radius: units.gu(0.6)
                        color: "#1A1A1A"
                        border.width: 1
                        border.color: "#33FFFFFF"

                        Column {
                            id: connectionColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: units.gu(1.5)
                            spacing: units.gu(1.2)

                            Item {
                                width: parent.width
                                height: units.gu(4)

                                Label {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: i18n.tr("Account %1").arg(pageSettingsCalendar.selectedAccount + 1)
                                    color: "#FFFFFF"
                                    font.pixelSize: units.gu(1.7)
                                    font.bold: true
                                }

                                Icon {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: units.gu(2.5)
                                    height: width
                                    name: "close"
                                    color: "#AEA79F"
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: units.gu(-1)
                                        onClicked: pageSettingsCalendar.closeForm()
                                    }
                                }
                            }

                            Label {
                                text: i18n.tr("Server URL or CalDAV address")
                                color: "#FFFFFF"
                                font.pixelSize: units.gu(1.4)
                            }

                            Item {
                                width: parent.width
                                height: units.gu(4)

                                LauncherTextField {
                                    id: serverUrlField
                                    anchors.left: parent.left
                                    anchors.right: pasteUrlButton.left
                                    anchors.rightMargin: units.gu(1)
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    placeholderText: "https://cloud.example.com (or …/remote.php/dav)"
                                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                                    selectByMouse: true
                                    onTextChanged: pageSettingsCalendar.storeFields()
                                }
                                Button {
                                    id: pasteUrlButton
                                    anchors.right: clearUrlButton.left
                                    anchors.rightMargin: units.gu(1)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: units.gu(7)
                                    height: parent.height
                                    text: i18n.tr("Paste")
                                    onClicked: serverUrlField.paste()
                                }
                                Icon {
                                    id: clearUrlButton
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: units.gu(2.5)
                                    height: width
                                    name: "edit-clear"
                                    color: "#FFFFFF"
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: units.gu(-1)
                                        onClicked: serverUrlField.text = ""
                                    }
                                }
                            }

                            Label {
                                text: i18n.tr("Username")
                                color: "#FFFFFF"
                                font.pixelSize: units.gu(1.4)
                            }

                            Item {
                                width: parent.width
                                height: units.gu(4)

                                LauncherTextField {
                                    id: usernameField
                                    anchors.left: parent.left
                                    anchors.right: pasteUserButton.left
                                    anchors.rightMargin: units.gu(1)
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                    selectByMouse: true
                                    onTextChanged: pageSettingsCalendar.storeFields()
                                }
                                Button {
                                    id: pasteUserButton
                                    anchors.right: clearUserButton.left
                                    anchors.rightMargin: units.gu(1)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: units.gu(7)
                                    height: parent.height
                                    text: i18n.tr("Paste")
                                    onClicked: usernameField.paste()
                                }
                                Icon {
                                    id: clearUserButton
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: units.gu(2.5)
                                    height: width
                                    name: "edit-clear"
                                    color: "#FFFFFF"
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: units.gu(-1)
                                        onClicked: usernameField.text = ""
                                    }
                                }
                            }

                            Label {
                                text: i18n.tr("App password")
                                color: "#FFFFFF"
                                font.pixelSize: units.gu(1.4)
                            }

                            Item {
                                width: parent.width
                                height: units.gu(4)

                                LauncherTextField {
                                    id: appPasswordField
                                    anchors.left: parent.left
                                    anchors.right: pastePasswordButton.left
                                    anchors.rightMargin: units.gu(1)
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: parent.height
                                    echoMode: TextInput.Password
                                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                                    selectByMouse: true
                                    onTextChanged: pageSettingsCalendar.storeFields()
                                }
                                Button {
                                    id: pastePasswordButton
                                    anchors.right: clearPasswordButton.left
                                    anchors.rightMargin: units.gu(1)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: units.gu(7)
                                    height: parent.height
                                    text: i18n.tr("Paste")
                                    onClicked: appPasswordField.paste()
                                }
                                Icon {
                                    id: clearPasswordButton
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: units.gu(2.5)
                                    height: width
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
                                font.pixelSize: units.gu(1.2)
                                text: i18n.tr("Use an app password (Nextcloud → Settings → Security → Devices & sessions), not your main account password.")
                            }

                            Row {
                                width: parent.width
                                height: units.gu(4.5)
                                spacing: units.gu(1)

                                Button {
                                    width: (parent.width - units.gu(1)) / 2
                                    height: parent.height
                                    color: "#0E8420"
                                    text: i18n.tr("Save and load calendars")
                                    onClicked: pageSettingsCalendar.saveAndList()
                                }
                                Button {
                                    width: (parent.width - units.gu(1)) / 2
                                    height: parent.height
                                    text: i18n.tr("Close")
                                    onClicked: pageSettingsCalendar.closeForm()
                                }
                            }
                        }
                    }

                    Button {
                        width: settingsColumn.width - units.gu(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: units.gu(4)
                        color: "#C7162B"
                        text: i18n.tr("Remove this account")
                        visible: pageSettingsCalendar.accounts.length > 1
                        onClicked: pageSettingsCalendar.removeAccount()
                    }
                }

                // ----------------------------------------------------------
                // Calendars of the selected account
                // ----------------------------------------------------------
                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Calendars")
                    color: "#FFFFFF"
                    font.pixelSize: units.gu(2.2)
                    font.bold: true
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    color: "#AEA79F"
                    font.pixelSize: units.gu(1.4)
                    text: i18n.tr("Calendars shown by this page. Load them from the server, then select one or more.")
                }

                Button {
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.gu(4.5)
                    text: i18n.tr("Load calendars")
                    enabled: pageSettingsCalendar.selectedAccountConfigured()
                    onClicked: pageSettingsCalendar.loadCalendars()
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                    color: pageSettingsCalendar.statusIsError ? "#ED3146" : "#AEA79F"
                    text: pageSettingsCalendar.statusText
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                    color: "#ED3146"
                    text: NextcloudCalendarModel.lastError
                }

                Repeater {
                    model: NextcloudCalendarModel.calendars
                    Rectangle {
                        width: settingsColumn.width - units.gu(4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: units.gu(6)
                        radius: units.gu(0.5)
                        color: pageSettingsCalendar.isCalendarSelected(modelData.href)
                               ? "#26E95420" : "#10FFFFFF"
                        border.width: 1
                        border.color: pageSettingsCalendar.isCalendarSelected(modelData.href)
                                      ? "#E95420" : "#22FFFFFF"

                        Rectangle {
                            id: calendarCheck
                            anchors.left: parent.left
                            anchors.leftMargin: units.gu(1.5)
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(2.2)
                            height: width
                            radius: units.gu(0.3)
                            color: pageSettingsCalendar.isCalendarSelected(modelData.href)
                                   ? "#E95420" : "transparent"
                            border.width: 1
                            border.color: "#80FFFFFF"

                            Label {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: "#FFFFFF"
                                visible: pageSettingsCalendar.isCalendarSelected(modelData.href)
                            }
                        }

                        Label {
                            anchors.left: calendarCheck.right
                            anchors.leftMargin: units.gu(1.5)
                            anchors.right: parent.right
                            anchors.rightMargin: units.gu(1.5)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            color: "#FFFFFF"
                            text: modelData.displayName.length > 0
                                  ? modelData.displayName : modelData.href
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: pageSettingsCalendar.toggleCalendar(modelData.href,
                                                                          modelData.displayName)
                        }
                    }
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    wrapMode: Text.WordWrap
                    color: "#AEA79F"
                    visible: NextcloudCalendarModel.calendars.length === 0
                    text: i18n.tr("No calendar loaded yet. Use “Load calendars” above.")
                }

                // ----------------------------------------------------------
                // Synchronisation
                // ----------------------------------------------------------
                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Events")
                    color: "#FFFFFF"
                    font.pixelSize: units.gu(2.2)
                    font.bold: true
                }

                Button {
                    width: settingsColumn.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.gu(4.5)
                    text: i18n.tr("Synchronise now")
                    onClicked: NextcloudCalendarModel.refresh(60, 180)
                }

                Label {
                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    color: "#AEA79F"
                    font.pixelSize: units.gu(1.3)
                    text: i18n.tr("%1 events loaded").arg(NextcloudCalendarModel.events.count)
                }
            }
        }
    }
}
