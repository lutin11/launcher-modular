import QtQuick 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import Qt.labs.folderlistmodel 2.12
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import MySettings 1.0
import AppHandler 1.0
import "pages"
import "components"
import QtQuick.Controls 2.2
import Lomiri.Components.Popups 1.3
import Lomiri.Components.Themes 1.3
import Platform 1.0
import "components"
import "helpers/PageRequirements.js" as PageRequirements

MainView {
    id: launchermodular
    objectName: 'mainView'
    applicationName: 'launchermodular.lut11'
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    property string appVersion : "2.5.0"
    property ListModel customIconModel :  ListModel { id: customIconModel }
    property ListModel pageModel :  ListModel { id: pageModel }
    property ListModel favoriteAppsModel :  ListModel { id: favoriteAppsModel }
    property variant datenow: new Date()
    property string iconCustomUrl: "../assets/placeholder-app-icon.svg"
    /// Set by the help page to replay the guided tour once back on the launcher
    property bool tutorialRequested: false


    function getCustomIconArray() {
        var customIcon = [], hMI_l = launchermodular.customIconModel.count;
        for (var i=0; i<hMI_l; i++){
            var itemIcon = launchermodular.customIconModel.get(i);
            customIcon.push({"name": itemIcon.name, "icon": itemIcon.icon, "action": itemIcon.action});
        }

        if (DEBUG_MODE) console.log("customIconModel to array, size : "+customIcon.length);
        return customIcon;
    }

    // Stable identifier of a page, used to store its configuration in
    // settings.pageConfigsJson. Generated once and kept with the page.
    function newPageUid() {
        return "p" + Date.now().toString(36) + Math.floor(Math.random() * 1679616).toString(36);
    }

    function getPageConfig(uid) {
        if (!uid) return ({});
        var all;
        try { all = JSON.parse(launchermodular.settings.pageConfigsJson || "{}"); } catch (error) { all = {}; }
        if (!all || typeof all !== "object")
            all = {};
        var config = all[uid];
        return (config && typeof config === "object") ? config : ({});
    }

    function setPageConfig(uid, config) {
        if (!uid) return;
        var all;
        try { all = JSON.parse(launchermodular.settings.pageConfigsJson || "{}"); } catch (error) { all = {}; }
        if (!all || typeof all !== "object")
            all = {};
        all[uid] = config;
        launchermodular.settings.pageConfigsJson = JSON.stringify(all);
    }

    function getPageArray() {
        var page = [], hM_l = launchermodular.pageModel.count;
        for (var i=0; i<hM_l; i++){
            var item = launchermodular.pageModel.get(i);
            page.push({"name": item.name, "icon": item.icon, "data":item.data, "directory":item.directory, "uid": item.uid});
        }

        if (DEBUG_MODE) console.log("pageModel to array, size : "+page.length);
        return page;
    }

    function getFavoriteAppsArray() {
        var favoriteApps = [], favAppsCount = launchermodular.favoriteAppsModel.count;
        for (var favAppIndex=0; favAppIndex<favAppsCount; favAppIndex++) {
            var itemApps = launchermodular.favoriteAppsModel.get(favAppIndex);
            favoriteApps.push({"name": itemApps.name, "icon": itemApps.icon, "action": itemApps.action, "container": itemApps.container});
        }

        if (DEBUG_MODE) console.log("favoriteAppsModel to array, size : "+favoriteApps.length);
        return favoriteApps;
    }

    readonly property int pageCount: launchermodular.pageModel.count
    // The page list is filled entry by entry at startup. Loading the pages
    // before it is complete re-created every Loader at each insertion (and
    // therefore reloaded the RSS feeds and other network pages several
    // times). The Repeater only builds the pages once the list is ready.
    property bool pagesReady: false

    // Circular paging. With more than one page the SwipeView holds two extra
    // entries: a clone of the last page at index 0 and a clone of the first at
    // index pageCount+1. The real page of a display index:
    function displayToReal(display) {
        if (pageCount <= 1)
            return 0
        if (display === 0)
            return pageCount - 1
        if (display === pageCount + 1)
            return 0
        return display - 1
    }

    // Icon of a page. Profiles created before the icon was stored, or entries
    // added without one, get the icon of the page directory instead of the
    // generic smiley.
    function pageIcon(page) {
        if (page && page.icon && page.icon.length > 0)
            return page.icon
        if (page && page.name)
            return "pages/" + page.name.replace(".qml", "").toLowerCase() + "/assets/icon.svg"
        return "../assets/happy-full.svg"
    }

    function realToDisplay(real) {
        return pageCount <= 1 ? 0 : real + 1
    }

    // The SwipeView resets its currentIndex when its content model changes
    // (a page added or removed). Remember the real page the user is on and put
    // it back once the layout has settled, so the circular jump and the
    // bottom-bar indicator always point at a real page. Without this the
    // index could become out of range (no orange icon, no swipe).
    property int lastRealIndex: 0
    property bool pageCountChanging: false

    function rememberRealIndex() {
        if (!view || pageCount <= 0 || pageCountChanging)
            return;
        var total = pageCount > 1 ? pageCount + 2 : pageCount;
        var index = view.currentIndex;
        if (index < 0 || index >= total)
            return;
        var real = displayToReal(index);
        if (real >= 0 && real < pageCount)
            lastRealIndex = real;
    }

    function clampViewIndex() {
        if (!view || pageCount <= 0)
            return;
        lastRealIndex = Math.max(0, Math.min(pageCount - 1, lastRealIndex));
        var target = realToDisplay(lastRealIndex);
        if (view.currentIndex !== target)
            view.currentIndex = target;
    }

    onPageCountChanged: {
        pageCountChanging = true;
        Qt.callLater(function() {
            clampViewIndex();
            pageCountChanging = false;
        });
    }

    function compareVersions(v1, v2) {
        const a = v1.split('.').map(Number);
        const b = v2.split('.').map(Number);

        const maxLength = Math.max(a.length, b.length);

        for (let i = 0; i < maxLength; i++) {
            const num1 = a[i] || 0;
            const num2 = b[i] || 0;

            if (num1 < num2) return -1;
            if (num1 > num2) return 1;
        }
        return 0;
    }

    // persistent app settings:
    property var settings: Settings {
        id:appSettings

        property bool firstRun: true
        property bool firstRunNew: true
        property bool tutorialSeen: false
        property bool developerModeEnabled: false
        property string version: '0'

        property string apiOpenWeatherMap: ''
        property string unitsFormat: '&units=metric'
        property string cityName: 'Paris'

        property string backgroundAnalogHours: ''

        property string iconStyle: 'rounded'
        property string iconSize: '0.866525720666956'

        property color textColor: '#FFFFFF'
        property color backgroundColor: '#000000'
        property real backgroundOpacity: 0.7
        property int backgroundBlur: 0

        property string folderImage: Platform.isTouch ? MySettings.getPicturesLocation()
                                              : Platform.picturesLocation()
        property bool reverseImagesSort: false
        property int imageSelectedSorting: FolderListModel.Time
        property bool openImageExternally: false

        property string folderMusic: MySettings.getMusicLocation()
        property string folderVideo: MySettings.getVideoLocation()
        property real videoFontSize: 2.0
        property real musicFontSize: 2.0
        property real folderFontSize: 2.0

        property var playlistNames: []
        property color musicFontColor: "#E95420"
        property color videoFontColor: "#E95420"
        property color folderFontColor: "#E95420"

        property string clockFontColor: "#E95420"
        property string clockFontFamily: "DSEG7Classic"
        property bool clockFontItalic: false
        property int clockFontWeight: Font.Normal
        property bool clockHHMMSS: true

        property string clockFontSize: "48"
        property string clockFontWordSpacing: "1.0"
        property string clockTimeFormat: "hh:mm:ss"
        property string formatHours: '24h'

        property string searchEngine: "https://duckduckgo.com/?q="

        property int limiteDaysCalendar: 31
        property int limiteDaysWidgetEvent: 31
        property int limiteItemWidgetEvent: 6

        property var page: []
        property var customIcon: []
        property var favoriteApps: []

        property bool newsBackgroundOpacity: false
        property string widgetMessageClick: 'message'
        property bool widgetMessageSummary: true
        property bool widgetMessageFilterOnReceivedMessages: true
        property int numberOfCallWidget: 3
        property int numberOfMessageWidget: 3
        property string widgetCallClick: 'dial'
        property string widgetFavoriteContactClick: 'tel'

        property bool widgetVisibleClock: true
        property bool widgetVisibleWeather: false
        property bool widgetVisibleAlarm: true
        property bool widgetVisibleLastcall: true
        property bool widgetVisibleLastmessage: true
        property bool widgetVisibleEvent: true
        property int itemsToLoadPerChannel: 7
        property var selectedCalendarIds: []
        property var selectedCalendarPageIds: []

        property int mainFeedSortAsc: 1

        property bool fullScreen: false

        property string nextcloudUser: ''
        property string nextcloudPassword: ''
        property string nextcloudUrl: ''
        property string nextcloudBasePath: '/'
        // Calendar chosen on the Nextcloud calendar page: path of the
        // collection on the server, and its display name for the UI.
        property string nextcloudCalendarHref: ''
        // Accounts of the Nextcloud calendar page(s), as JSON: nested lists in
        // the page data are not serialised by the settings backend.
        property string nextcloudAccountsJson: ''
        // Set when a feed is added in the RSS settings; the RSS page reloads.
        property bool rssFeedChanged: false
        // Per-page configurations, indexed by the stable page uid and stored as
        // JSON because the settings backend does not serialise nested maps.
        property string pageConfigsJson: '{}'
        property string nextcloudCalendarName: ''

    }//settings

    Timer {
        id: clockUpdater
        interval: Math.max(0, 60000-(launchermodular.datenow.getSeconds()*1000))
        running: true
        repeat: true
        onTriggered: {
            if (clockUpdater.interval !== 60000) { clockUpdater.interval = 60000 }
            launchermodular.datenow = new Date()
        }
    }

    PageStack {
        id: pageStack
        // The desktop title bar takes its height from the window, so that the
        // pages are never covered by it. On Ubuntu Touch it is invisible.
        anchors.topMargin: desktopTitleBar.visible ? desktopTitleBar.height : 0
        Page {
            id: pageLauncher
            anchors.fill: parent

            Component.onCompleted: {

                launchermodular.settings.fullScreen = false

                // A desktop package must not keep the pablet paths of the
                // click build: they do not exist and the pages stayed empty.
                if (!Platform.isTouch) {
                    if (launchermodular.settings.folderImage.indexOf("/home/phablet") === 0)
                        launchermodular.settings.folderImage = Platform.picturesLocation()
                    if (launchermodular.settings.folderMusic.indexOf("/home/phablet") === 0)
                        launchermodular.settings.folderMusic = MySettings.getMusicLocation()
                    if (launchermodular.settings.folderVideo.indexOf("/home/phablet") === 0)
                        launchermodular.settings.folderVideo = MySettings.getVideoLocation()
                }

                if(launchermodular.settings.firstRunNew){
                    launchermodular.settings.page = undefined
                    launchermodular.settings.firstRunNew = false
                }

                if(compareVersions(launchermodular.settings.version, appVersion) < 0) {
                    pageStack.push(Qt.resolvedUrl("ChangeLogs.qml"))
                    launchermodular.settings.version = appVersion;
                }

                // show the guided tour once, after the launcher has settled
                if (!launchermodular.settings.tutorialSeen) {
                    tutorialStart.start()
                }

                if (DEBUG_MODE) console.log("###### on Component completion #####")

                if (typeof launchermodular.settings.customIcon === 'undefined') {
                     launchermodular.settings.customIcon = [];
                }
                if (DEBUG_MODE) console.log("Retrieve custom icon with : "+ launchermodular.settings.customIcon.length +" elements");
                var customIcon_l = launchermodular.settings.customIcon.length
                for (var i=0; i<customIcon_l; i++){
                    var customIcon = launchermodular.settings.customIcon[i];
                    launchermodular.customIconModel.insert(i,{"name": customIcon.name, "icon": customIcon.icon, "action": customIcon.action})
                }

                if (typeof launchermodular.settings.favoriteApps === 'undefined') {
                     launchermodular.settings.favoriteApps = [];
                }
                if (DEBUG_MODE) console.log("Retrieve Favorite Apps with : "+ launchermodular.settings.favoriteApps.length +" elements");
                var favoriteApps_l = launchermodular.settings.favoriteApps.length
                for (var f=0; f<favoriteApps_l; f++){
                    var itemApps = launchermodular.settings.favoriteApps[f];
                    if (DEBUG_MODE) console.log("Insert Favorite Apps with : ", JSON.stringify(itemApps));
                    launchermodular.favoriteAppsModel.insert(f,{"name": itemApps.name, "icon": itemApps.icon, "action": itemApps.action, "container" : itemApps.container})
                }

                // An empty list (corrupted save, interrupted first run) must
                // not leave the launcher without any page: Home is required.
                if (typeof launchermodular.settings.page === 'undefined'
                        || !launchermodular.settings.page
                        || launchermodular.settings.page.length === 0) {
                    if (DEBUG_MODE) console.log("page is undefined or empty, let's create a new one");
                    launchermodular.settings.page = [{"name": "Home.qml", "icon": "pages/home/assets/icon.svg","data":{}, "directory": "pages/"}];
                }

                if (DEBUG_MODE) console.log("Retrieve page with : "+ launchermodular.settings.page.length +" elements");
                var page_l = launchermodular.settings.page.length
                for (var p=0; p<page_l; p++){
                    var itemPage = launchermodular.settings.page[p];
                    // Pages created before the uid existed get one now; it is
                    // written back with the page list on the next save.
                    var pageUid = (itemPage.uid && itemPage.uid.length > 0) ? itemPage.uid : newPageUid();
                    launchermodular.pageModel.insert(p,{"name": itemPage.name, "icon": itemPage.icon, "data":itemPage.data, "directory":itemPage.directory, "uid": pageUid})
                }

                // Store the identifiers now: a uid generated for a page created
                // before they existed must be the same on the next run, or the
                // configuration stored for it would be lost.
                launchermodular.settings.page = getPageArray();

                // The list is complete: the pages can be instantiated once.
                launchermodular.pagesReady = true;
            }

            Component.onDestruction: {
                if (DEBUG_MODE) console.log("####### On component destruction ###### ");
                launchermodular.settings.page = getPageArray();
                if (DEBUG_MODE) console.log("Store page with : "+ launchermodular.settings.page.length +" elements");

                launchermodular.settings.customIcon = getCustomIconArray();
                if (DEBUG_MODE) console.log("Store customIcon with : "+ launchermodular.settings.customIcon.length +" elements");

                launchermodular.settings.favoriteApps = getFavoriteAppsArray();
                if (DEBUG_MODE) console.log("Store favoriteApps with : "+ launchermodular.settings.favoriteApps.length +" elements");
            }

            header: PageHeader {
                id: header
                visible: false
            }

            Rectangle {
                id: topBorder
                height: units.gu(0.1)
                anchors.left: parent.left
                anchors.right: parent.right
                color: "#E95420"
                visible: !launchermodular.settings.fullScreen
            }

            Rectangle {
                id: background
                anchors {
                    left: parent.left
                    right: parent.right
                    top: topBorder.bottom
                    bottom: launchermodular.settings.fullScreen ? bottomBarLayout.bottom : bottomBarLayout.top
                }

                Image {
                    id: backgroundblur
                    anchors.fill: parent;
                    source: MySettings.getBackgroundFile()
                    smooth: true
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                FastBlur {
                    anchors.fill: backgroundblur
                    source: backgroundblur
                    radius: launchermodular.settings.backgroundBlur
                }

                Rectangle {
                    id: listAppBackground
                    anchors.fill: parent
                    color: launchermodular.settings.backgroundColor
                    opacity: launchermodular.settings.backgroundOpacity
                }

                Rectangle {
                    id: listApp
                    anchors.fill: parent
                    color: "transparent"

                    // Shown instead of a page that cannot be loaded, most of the
                    // time because an external module is missing.
                    Component {
                        id: pageUnavailableComponent
                        PageUnavailable { }
                    }

                    /* ******************************** LES PAGES COMMENCE ICI ******************************** */
                    SwipeView {
                        id: view
                        // Display order: [clone of the last page, real pages…,
                        // clone of the first page]; starting at 1 shows the
                        // first real page.
                        currentIndex: 1
                        anchors.fill: parent
                        interactive: !launchermodular.settings.fullScreen

                        Component.onCompleted: currentIndex = launchermodular.pageCount > 1 ? 1 : 0

                        // Once settled on a clone, jump to the real page it
                        // duplicates: the content is identical, so the switch is
                        // invisible and the swipe can wrap again.
                        onCurrentIndexChanged: {
                            launchermodular.rememberRealIndex()
                            if (launchermodular.pageCount <= 1)
                                return
                            // Defer the jump: changing currentIndex while the
                            // content model is being updated left the view on
                            // an out-of-range index.
                            if (currentIndex < 0
                                    || currentIndex >= launchermodular.pageCount + 2
                                    || currentIndex === 0
                                    || currentIndex === launchermodular.pageCount + 1)
                                Qt.callLater(launchermodular.clampViewIndex)
                        }

                        Repeater {
                            id: pageRepeater
                            // Two extra entries for the circular paging.
                            model: launchermodular.pagesReady
                                   ? (launchermodular.pageCount > 1 ? launchermodular.pageCount + 2
                                                                    : launchermodular.pageCount)
                                   : 0
                            Loader {
                                id: pageLoader
                                property int realIndex: launchermodular.displayToReal(index)
                                // The page and its two neighbours are created;
                                // the others wait until they come close. Every
                                // page used to be built at startup, which
                                // delayed the first frame. The circular paging
                                // makes the first and last pages neighbours.
                                readonly property int displayDistance: {
                                    if (launchermodular.pageCount <= 1)
                                        return index === view.currentIndex ? 0 : 1
                                    var total = launchermodular.pageCount + 2
                                    var distance = Math.abs(index - view.currentIndex)
                                    return Math.min(distance, total - distance)
                                }
                                active: displayDistance <= 1
                                visible: index === view.currentIndex
                                onLoaded: {
                                    if (item) {
                                        var page = launchermodular.pageModel.get(realIndex)
                                        item.visible = visible
                                        // Empty state: hand it what it must display
                                        if (typeof item.dependencies !== "undefined") {
                                            item.pageName = page.name
                                            item.dependencies = PageRequirements.missingModules(Platform, page.name)
                                        }
                                        // Injecte the data used for the curent page
                                        if (typeof item.pageData !== "undefined") {
                                            item.pageData = page.data
                                        }
                                        // Per-page settings need to find their own
                                        // entry in the page model.
                                        if (typeof item.pageIndex !== "undefined") {
                                            item.pageIndex = realIndex
                                        }
                                        // Per-page configuration is stored by
                                        // the stable uid, not by position: a
                                        // moved or reordered page keeps it.
                                        if (typeof item.pageUid !== "undefined") {
                                            item.pageUid = page.uid
                                        }
                                    }
                                }
                                onVisibleChanged: {
                                    if (item) item.visible = visible
                                }
                                sourceComponent: {
                                    var page = launchermodular.pageModel.get(realIndex)
                                    // A page that needs a missing module cannot be loaded at
                                    // all: show an empty state naming the missing module
                                    // instead of a blank page.
                                    if (page.directory === "pages/"
                                            && !PageRequirements.isAvailable(Platform, page.name)) {
                                        return pageUnavailableComponent
                                    }
                                    var comp = Qt.createComponent(page.directory + page.name);
                                    if (comp.status === Component.Error) {
                                        console.error("Failed to load component: " + page.directory + page.name + ", error: " + comp.errorString());
                                        return pageUnavailableComponent;
                                    }
                                    return comp;
                                }
                            }
                        }
                    }
                    /* ******************************** FIN DES PAGES ******************************** */
                }
            }

            /* ******************************** DEBUT DE LA BARRE EN BAS ******************************** */

            Rectangle {
                id: bottomBarLayout
                color: "#111111"
                height: units.gu(5)
                visible: !launchermodular.settings.fullScreen

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                Rectangle {
                    id: borderTop
                    height: units.gu(0.1)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: "#E95420"
                }

                MouseArea {
                    anchors.fill: parent
                    property real startMouseX
                    property real startMouseY
                    onPressed: {
                       startMouseX = mouseX
                       startMouseY = mouseY
                    }
                    onPositionChanged: {
                        var dx = mouseX - startMouseX
                        var dy = startMouseY - mouseY
                        if (dy > units.gu(2) && dy > Math.abs(dx)) {
                            // upward swipe: open the settings bar
                            bottomBarSettings.open()
                        } else if (dx > units.gu(4)) {
                            var nextReal = (launchermodular.displayToReal(view.currentIndex) + 1) % launchermodular.pageCount
                            view.setCurrentIndex(launchermodular.realToDisplay(nextReal))
                            startMouseX += units.gu(4)
                        } else if (-dx > units.gu(4)) {
                            var previousReal = (launchermodular.displayToReal(view.currentIndex) - 1 + launchermodular.pageCount) % launchermodular.pageCount
                            view.setCurrentIndex(launchermodular.realToDisplay(previousReal))
                            startMouseX -= units.gu(4)
                        }
                    }

                    onExited: {indicator.spacing = units.gu(2)}

                    PageIndicator {
                        id: indicator
                        // Real pages only: view.count includes the two clones of
                        // the circular paging, which have no page model entry
                        // and were displayed with the fallback (smiley) icon.
                        count: launchermodular.pageCount
                        currentIndex: launchermodular.displayToReal(view.currentIndex)
                        interactive: false //= dont intercept press
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(2)

                        delegate: Rectangle {
                            height: units.gu(4)
                            width: units.gu(3)
                            color: "transparent"
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                source: (index >= 0 && index < launchermodular.pageModel.count)
                                        ? launchermodular.pageIcon(launchermodular.pageModel.get(index))
                                        : "../assets/happy-full.svg"
                                height: units.gu(2)
                                width: units.gu(2)
                                color: index === launchermodular.displayToReal(view.currentIndex) ? "#E95420" : "#FFFFFF"
                                id: iconBottomBar
                                antialiasing: true
                                visible: false
                            }
                            ColorOverlay{
                                anchors.fill: iconBottomBar
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                source: iconBottomBar
                                color: index === launchermodular.displayToReal(view.currentIndex) ? "#E95420" : "#FFFFFF"
                                antialiasing: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onPressed: {
                                    mouse.accepted = false
                                    if(index !== launchermodular.displayToReal(view.currentIndex)) {
                                        view.setCurrentIndex(launchermodular.realToDisplay(index));
                                        iconBottomBar.source = (index >= 0 && index < launchermodular.pageModel.count)
                                           ? launchermodular.pageIcon(launchermodular.pageModel.get(index))
                                           : "../assets/happy-full.svg"
                                    }
                                }
                            }
                        }
                    }
                }
                // first time running
                Rectangle {
                    id: tutorialConfig
                    // the guided tour explains the same gesture
                    visible: launchermodular.settings.firstRun && !launchermodular.tutorialRequested
                    color:"#111111"
                    height: units.gu(5)

                    anchors {
                        top: bottomBarLayout.top
                        topMargin: 2
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    Icon {
                        anchors.right: staticText.left
                        anchors.rightMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(2)
                        height: units.gu(2)
                        name: "up"
                    }

                    Text {
                        id:staticText
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "darkgray"
                        text: i18n.tr("Swipe up to configure the launcher")
                    }

                    Icon {
                        anchors.left: staticText.right
                        anchors.leftMargin: units.gu(1)
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(2)
                        height: units.gu(2)
                        name: "up"
                    }

                }

                transform: Translate {
                    y: -(bottomBarSettings.position * bottomBarSettings.height)
                }

            }

            // Dim + dismiss layer of the settings bar (replaces the modal
            // behaviour of the former Drawer).
            Rectangle {
                anchors.fill: parent
                visible: bottomBarSettings.position > 0
                color: "#40000000"

                MouseArea {
                    anchors.fill: parent
                    onClicked: bottomBarSettings.close()
                }
            }

            // Full screen hides the bottom bar: keep a thin edge strip so the
            // settings bar can still be opened.
            MouseArea {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: units.gu(1.5)
                visible: launchermodular.settings.fullScreen
                property real startX: 0
                property real startY: 0
                onPressed: {
                    startX = mouseX
                    startY = mouseY
                }
                onPositionChanged: {
                    var dy = startY - mouseY
                    if (dy > units.gu(1.5) && dy > Math.abs(mouseX - startX)) {
                        bottomBarSettings.open()
                    }
                }
            }

            // Settings bar of the bottom edge. A plain item and not a
            // QtQuick.Controls Drawer: the Drawer is reparented into the window
            // overlay, which rotates its popups by 90° when the window is wider
            // than tall (QQuickOverlay + contentOrientation). The page content is
            // not rotated, so the bar showed up as a vertical strip along the
            // left edge and left a grey band at the bottom after a desktop
            // window resize. An item follows the page geometry.
            Item {
                id: bottomBarSettings
                anchors {
                    left: parent.left
                    right: parent.right
                }
                height: units.gu(9)
                // 0 = closed (below the page edge), 1 = fully open.
                property real position: 0
                y: parent.height - position * height

                function open() {
                    position = 1
                    launchermodular.settings.firstRun = false
                }

                function close() {
                    position = 0
                }

                Behavior on position {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "white"
                }

                // Swipe down on an empty part of the bar closes it; the entry
                // items have their own MouseArea and keep priority.
                MouseArea {
                    anchors.fill: parent
                    property real startY: 0
                    onPressed: startY = mouseY
                    onPositionChanged: {
                        if (mouseY - startY > units.gu(2)) {
                            bottomBarSettings.close()
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    height: units.gu(8)

                    Rectangle {
                        height: parent.height
                        Layout.fillWidth: true
                        Layout.minimumWidth:units.gu(3)
                        id: recAddIcon
                        Icon {
                            id: iconWidget
                            anchors.horizontalCenter: recAddIcon.horizontalCenter
                            anchors.top: recAddIcon.top
                            anchors.topMargin: 1
                            name: "view-expand"
                            height: units.gu(3)
                            width: units.gu(3)
                        }

                        Text {
                            anchors.top: iconWidget.bottom
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            text: i18n.tr("Add custom icon")
                            font.pointSize: units.gu(1)
                            wrapMode:Text.WordWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                customIconDialogue.visible = true
                                bottomBarSettings.close()
                            }
                        }
                    }

                    Rectangle {
                        height: parent.height
                        Layout.fillWidth: true
                        Layout.minimumWidth:units.gu(3)
                        id: recPage
                        Icon {
                            id: iconPage
                            anchors.horizontalCenter: recPage.horizontalCenter
                            anchors.top: recPage.top
                            anchors.topMargin: 6
                            name: "browser-tabs"
                            height: units.gu(3)
                            width: units.gu(3)
                        }

                        Text {
                            anchors.top: iconPage.bottom
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            text: i18n.tr("Manage pages")
                            font.pointSize: units.gu(1)
                            wrapMode:Text.WordWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                pageStack.push(Qt.resolvedUrl("Pagemanagement.qml"))
                                bottomBarSettings.close()
                            }
                        }
                    }

                    Rectangle {
                        height: parent.height
                        Layout.fillWidth: true
                        Layout.minimumWidth:units.gu(3)
                        id: recSettings
                        Icon {
                            id: iconSettings
                            anchors.horizontalCenter: recSettings.horizontalCenter
                            anchors.top: recSettings.top
                            anchors.topMargin: 6
                            name: "system-settings-symbolic"
                            height: units.gu(3)
                            width: units.gu(3)
                        }

                        Text {
                            anchors.top: iconSettings.bottom
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            text: i18n.tr("Configure Launcher")
                            font.pointSize: units.gu(1)
                            wrapMode:Text.WordWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                pageStack.push(Qt.resolvedUrl("Settings.qml"))
                                bottomBarSettings.close()
                            }
                        }
                    }

                    Rectangle {
                        height: parent.height
                        Layout.fillWidth: true
                        Layout.minimumWidth:units.gu(3)
                        id: recFlashAuto
                        Icon {
                            id: iconAuto
                            anchors.horizontalCenter: recFlashAuto.horizontalCenter
                            anchors.top: recFlashAuto.top
                            anchors.topMargin: 6
                            name: "flash-auto"
                            height: units.gu(3)
                            width: units.gu(3)
                        }

                        Text {
                            anchors.top: iconAuto.bottom
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            text: i18n.tr("Autostart")
                            font.pointSize: units.gu(1)
                            wrapMode:Text.WordWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                pageStack.push(Qt.resolvedUrl("Autostart.qml"))
                                bottomBarSettings.close()
                            }
                        }
                    }

                    Rectangle {
                        height: parent.height
                        Layout.fillWidth: true
                        Layout.minimumWidth:units.gu(3)
                        id: recHelp
                        Icon {
                            id: iconHelp
                            anchors.horizontalCenter: recHelp.horizontalCenter
                            anchors.top: recHelp.top
                            anchors.topMargin: 6
                            name: "help"
                            height: units.gu(3)
                            width: units.gu(3)
                        }

                        Text {
                            anchors.top: iconHelp.bottom
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            text: i18n.tr("Help")
                            font.pointSize: units.gu(1)
                            wrapMode:Text.WordWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                pageStack.push(Qt.resolvedUrl("Help.qml"))
                                bottomBarSettings.close()
                            }
                        }
                    }

                    Rectangle {
                        height: parent.height
                        Layout.fillWidth: true
                        Layout.minimumWidth:units.gu(3)
                        id: recInfo
                        Icon {
                            id: iconAbout
                            anchors.horizontalCenter: recInfo.horizontalCenter
                            anchors.top: recInfo.top
                            anchors.topMargin: 6
                            name: "info"
                            height: units.gu(3)
                            width: units.gu(3)
                        }

                        Text {
                            anchors.top: iconAbout.bottom
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                            text: i18n.tr("About")
                            font.pointSize: units.gu(1)
                            wrapMode:Text.WordWrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                pageStack.push(Qt.resolvedUrl("ChangeLogs.qml"))
                                bottomBarSettings.close()
                            }
                        }
                    }

                }
            }

            /* ******************************** FIN DE LA BARRE EN BAS ******************************** */

            Rectangle {
                id: customIconDialogue
                anchors.fill: parent
                opacity: 0.9
                color: Theme.palette.normal.overlay
                visible: false
                MouseArea {
                    anchors.fill: parent
                    onClicked: customIconDialogue.visible = false
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width*0.75
                    height: parent.height*0.65
                    radius: units.gu(2)
                    color: Theme.palette.normal.background
                    MouseArea {
                        anchors.fill: parent
                    }

                    Flickable {
                        id: flickable
                        anchors.fill: parent
                        anchors.topMargin: units.gu(2)
                        contentHeight: customIconColumn.height+units.gu(2)
                        flickableDirection: Flickable.VerticalFlick
                        clip: true
                        maximumFlickVelocity : units.gu(10)*100
                        flickDeceleration: 2500

                        Column {
                            id: customIconColumn
                            width: parent.width-units.gu(4)
                            spacing: units.gu(2)
                            anchors.horizontalCenter: parent.horizontalCenter
                            property var modelCustom: [
                              { title: "<font color=\""+Theme.palette.normal.backgroundText+"\">"+i18n.tr("Website")+"</font>", descr: "<font color=\""+Theme.palette.normal.baseText+"\">"+i18n.tr("Open this URL in the web browser")+"</font>", style:"website" },
                              { title: "<font color=\""+Theme.palette.normal.backgroundText+"\">"+i18n.tr("Terminal command")+"</font>", descr: "<font color=\""+Theme.palette.normal.baseText+"\">"+i18n.tr("Run a command in a terminal")+"</font>", style:"terminal" },
                              { title: "<font color=\""+Theme.palette.normal.backgroundText+"\">"+i18n.tr("Launch app")+"</font>", descr: "<font color=\""+Theme.palette.normal.baseText+"\">"+i18n.tr("Launch an app")+"</font>", style:"appid" }
                            ]

                            LomiriShape {
                                id: webAppIcon
                                source: Image {
                                    id: imageSource
                                    source: launchermodular.iconCustomUrl
                                }
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: units.gu(15)
                                height: width
                                color: Theme.palette.normal.base
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        // Picking an image goes through the content hub
                                        // (Lomiri.Content). Without that module the page
                                        // cannot open, so the click would do nothing.
                                        if (Platform.hasContentModule) {
                                            pageStack.push(Qt.resolvedUrl("ImportPage.qml"));
                                        } else {
                                            console.log("Icon picker unavailable: Lomiri.Content module missing")
                                        }
                                    }
                                }
                                Label {
                                    visible: imageSource.source === "../assets/placeholder-app-icon.svg"
                                    anchors.fill: parent
                                    anchors.margins: units.gu(1)
                                    anchors.topMargin: webAppIcon.height / 1.4
                                    text: i18n.tr("SVG or PNG icon. 1:1 ratio")
                                    wrapMode: Text.Wrap
                                }
                            }

                            TextField {
                                id: appTitle
                                width: parent.width
                                color: Theme.palette.normal.backgroundText
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                }
                                placeholderText: i18n.tr("The <b>title</b> to be shown in the app list")
                            }

                            ListItem.ItemSelector {
                                id: typeIconCustom
                                width: parent.width
                                model: customIconColumn.modelCustom
                                delegate: OptionSelectorDelegate {
                                    property var item: model.modelData ? model.modelData : model
                                    text: item.title
                                    subText: item.descr
                                }
                            }

                            TextField {
                                id: appAction
                                width: parent.width
                                color: Theme.palette.normal.backgroundText
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                }
                                inputMethodHints: Qt.ImhNoAutoUppercase
                                placeholderText: {
                                    if(typeIconCustom.model[typeIconCustom.selectedIndex].style === "website"){i18n.tr("<b>Action</b> example: ")+"https://forums.ubports.com/"}
                                    else if(typeIconCustom.model[typeIconCustom.selectedIndex].style === "terminal"){i18n.tr("<b>Action</b> example: ")+"sudo reboot"}
                                    else if(typeIconCustom.model[typeIconCustom.selectedIndex].style === "appid"){i18n.tr("<b>Action</b> example: ")+"dialer-app.desktop"}
                                    else ""
                                }
                            }

                            Item {
                                anchors.topMargin: units.gu(2)
                                anchors.top: parent.bottom
                                width: parent.width
                                Button {
                                    anchors.left: parent.left
                                    id: okButton
                                    text: i18n.tr("Create icon")
                                    height: units.gu(4)
                                    width: (parent.width/2)-units.gu(2)
                                    contentItem: Text {
                                        text: okButton.text
                                        font: okButton.font
                                        color: "#ffffff"
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    background: Rectangle {
                                        radius: units.gu(1.5)
                                        color: "#0E8420"
                                    }

                                    property string actionIcon: ""

                                    onClicked: {

                                        if(typeIconCustom.model[typeIconCustom.selectedIndex].style === "website"){ okButton.actionIcon = "browser:///"+appAction.text }
                                        if(typeIconCustom.model[typeIconCustom.selectedIndex].style === "terminal"){ okButton.actionIcon = "terminal:///"+appAction.text }
                                        if(typeIconCustom.model[typeIconCustom.selectedIndex].style === "appid"){ okButton.actionIcon = "application:///"+appAction.text  }
                                        launchermodular.customIconModel.append({"name": appTitle.text, "icon": launchermodular.iconCustomUrl, "action": okButton.actionIcon})
                                        launchermodular.settings.customIcon = launchermodular.getCustomIconArray()
                                        AppHandler.sort();

                                        launchermodular.iconCustomUrl = "../assets/placeholder-app-icon.svg"
                                        appTitle.text = ""
                                        okButton.actionIcon = ""
                                        appAction.text = ""

                                        customIconDialogue.visible = false

                                    }
                                }

                                Button{
                                    anchors.right: parent.right
                                    height: units.gu(4)
                                    width: (parent.width/2)-units.gu(2)
                                    contentItem: Text {
                                        text: i18n.tr("Cancel")
                                        font: okButton.font
                                        color: Theme.palette.normal.overlay
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                    background: Rectangle {
                                        radius: units.gu(1.5)
                                        color: Theme.palette.normal.overlaySecondaryText
                                    }

                                    onClicked: {
                                        launchermodular.iconCustomUrl = "../assets/placeholder-app-icon.svg"
                                        appTitle.text = ""
                                        okButton.actionIcon = ""
                                        appAction.text = ""
                                        customIconDialogue.visible = false
                                    }

                                }
                            }
                        }
                    }
                }
            }

            /* ******************************** LE MASQUE PEDAGOGIQUE ******************************** */

            Tutorial {
                id: tutorial

                anchors.fill: parent

                // asked for at the first run (Main.qml) or from the help page
                // (Help.qml), and shown only once back on the launcher itself.
                // The page of the launcher is never pushed on the stack, so
                // whatever covers it is the current page, and there is none
                // while the launcher is the screen the user sees
                visible: launchermodular.tutorialRequested && !pageStack.currentPage

                bottomBar: bottomBarLayout
                pageView: view
                pageRepeater: pageRepeater

                // the automatic tour is a one-off, from the first run on
                onVisibleChanged: {
                    if (visible) {
                        launchermodular.settings.tutorialSeen = true
                    }
                }

                onFinished: launchermodular.tutorialRequested = false
            }

            /* Gives the launcher the time to settle before the tour is asked
               for: a first run also opens the change log page, and the tour has
               to wait for it instead of flashing over it. The first page needs
               this time to load, as the tour points at its parts. */
            Timer {
                id: tutorialStart
                interval: 1500
                onTriggered: launchermodular.tutorialRequested = true
            }
        }
    }

    /* ******************************** BARRE DE FENETRE (DESKTOP) ******************************** */

    // The desktop packages are frameless (see main.cpp). This slim internal bar
    // replaces the window manager decoration: drag it to move the window, use
    // the buttons to minimize or close it. It is hidden under Ubuntu Touch,
    // where Lomiri manages the window, and then the pages keep their full
    // height (anchors.topMargin of the PageStack above).
    Rectangle {
        id: desktopTitleBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: units.gu(2.6)
        color: "#111111"
        visible: WindowController.frameless
        z: 100

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: WindowController.beginMove()
            onDoubleClicked: WindowController.toggleFullScreen()
        }

        Text {
            anchors {
                left: parent.left
                leftMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }
            text: i18n.tr("Launcher Modular")
            color: "#ffffff"
            opacity: 0.7
            font.pixelSize: units.dp(12)
        }

        Row {
            anchors {
                right: parent.right
                rightMargin: units.gu(0.6)
                verticalCenter: parent.verticalCenter
            }
            spacing: units.gu(0.4)

            Rectangle {
                width: units.gu(2.2)
                height: units.gu(2)
                radius: units.gu(0.2)
                color: minimizeArea.pressed ? "#333333" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "–"
                    color: "#ffffff"
                    font.pixelSize: units.dp(14)
                }

                MouseArea {
                    id: minimizeArea
                    anchors.fill: parent
                    onClicked: WindowController.minimize()
                }
            }

            Rectangle {
                width: units.gu(2.2)
                height: units.gu(2)
                radius: units.gu(0.2)
                color: closeArea.pressed ? "#c7162b" : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: "#ffffff"
                    font.pixelSize: units.dp(16)
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    onClicked: WindowController.closeWindow()
                }
            }
        }
    }

    // Resize handles of the frameless desktop window: four edges and four
    // corners. Each one starts a resize from the corresponding Qt::Edges mask
    // (TopEdge 1, LeftEdge 2, RightEdge 4, BottomEdge 8).
    Item {
        id: desktopResizeHandles
        anchors.fill: parent
        visible: WindowController.frameless
        z: 101

        MouseArea {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: units.gu(0.4)
            cursorShape: Qt.SizeVerCursor
            onPressed: WindowController.beginResize(1)
        }
        MouseArea {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: units.gu(0.4)
            cursorShape: Qt.SizeVerCursor
            onPressed: WindowController.beginResize(8)
        }
        MouseArea {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: units.gu(0.4)
            cursorShape: Qt.SizeHorCursor
            onPressed: WindowController.beginResize(2)
        }
        MouseArea {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: units.gu(0.4)
            cursorShape: Qt.SizeHorCursor
            onPressed: WindowController.beginResize(4)
        }
        MouseArea {
            anchors { top: parent.top; left: parent.left }
            width: units.gu(0.6)
            height: units.gu(0.6)
            cursorShape: Qt.SizeFDiagCursor
            onPressed: WindowController.beginResize(3)
        }
        MouseArea {
            anchors { top: parent.top; right: parent.right }
            width: units.gu(0.6)
            height: units.gu(0.6)
            cursorShape: Qt.SizeBDiagCursor
            onPressed: WindowController.beginResize(5)
        }
        MouseArea {
            anchors { bottom: parent.bottom; left: parent.left }
            width: units.gu(0.6)
            height: units.gu(0.6)
            cursorShape: Qt.SizeBDiagCursor
            onPressed: WindowController.beginResize(10)
        }
        MouseArea {
            anchors { bottom: parent.bottom; right: parent.right }
            width: units.gu(0.6)
            height: units.gu(0.6)
            cursorShape: Qt.SizeFDiagCursor
            onPressed: WindowController.beginResize(12)
        }
    }
}
