import QtQuick 2.4
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItemHeader
import AppHandler 1.0
import Lomiri.Components.Popups 1.3
import Lomiri.Components.Themes 1.3

Page {
    id: pageSettingsHome

    header: PageHeader {
        id: headerHomeSettings
        title: i18n.tr("Settings Page");
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: "Back"
                onTriggered: {
                    launchermodular.settings.favoriteApps = launchermodular.getFavoriteAppsArray();
                    pageStack.pop();
                }
            }
        ]
        trailingActionBar {
            actions: [
                Action {
                    iconName: "add"
                    text: "add"
                    onTriggered: {
                        PopupUtils.open(listHomeAppDialog);
                    }
                }
           ]
           numberOfSlots: 2
        }
    }

    Component {
        id: listHomeAppDialog
        Dialog {
            id: listAppDialog
            ListView {

                model: AppHandler.appsinfo.length
                height: pageSettingsHome.height*0.65

                delegate: ListItem {
                    property var elem: AppHandler.appsinfo[index]

                    ListItemLayout {
                        height: homeListItemLayout.height + (divider.visible ? divider.height : 0)
                        id: homeListItemLayout
                        title.text: elem.name
                        LomiriShape {
                            source: Image {
                                id: screenshotAppFavorite
                                source: elem.icon
                                smooth: true
                            }
                            SlotsLayout.position: SlotsLayout.Leading;
                            width: units.gu(4)
                            height: width
                            radius : "medium"
                        }
                    }
                    divider.visible: false
                    onClicked: {
                        if (DEBUG_MODE) console.log("add fav app:", JSON.stringify(elem));
                        launchermodular.favoriteAppsModel.append({"name": elem.name, "icon": elem.icon, "action": elem.action, "container": elem.container});
                        PopupUtils.close(listAppDialog);
                    }
                }

            }

            Button{
                text: i18n.tr("Cancel")
                color: Theme.palette.normal.overlaySecondaryText
                onClicked: PopupUtils.close(listAppDialog);
            }

        }
    }

    Rectangle {
        id:homeMainsettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: homeFlickableSettings
            anchors.fill: parent
            contentHeight: homeSettingsColumn.childrenRect.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: homeSettingsColumn
                anchors.fill: parent
                spacing: units.gu(1)
                ListItemHeader.Header {
                    id: titleFavoriteAppsManagement
                    text: "<font color=\"#ffffff\">"+i18n.tr("Favorite apps management")+"</font>"
                }

                ListView {
                    id: homeListAppFavAdded
                    model: launchermodular.favoriteAppsModel
                    width: parent.width
                    height: contentHeight
                    delegate: ListItem {
                        divider.visible: false
                        height: modelLayout.height + (divider.visible ? divider.height : 0)
                        ListItemLayout {
                            id: modelLayout
                            title.text: "<font color=\"#ffffff\">"+name+"</font>"
                            LomiriShape {
                                source: Image {
                                    id: screenshotAppFavorite
                                    source: icon
                                    smooth: true
                                }
                                SlotsLayout.position: SlotsLayout.Leading;
                                width: units.gu(4)
                                height: width
                                radius : "medium"
                            }
                        }

                        leadingActions: ListItemActions {
                            actions: [
                                Action {
                                    id: actionDeleteFavorit
                                    text: i18n.tr("Delete")
                                    iconName: "edit-delete"
                                    onTriggered: launchermodular.favoriteAppsModel.remove(index)
                                }
                            ]
                        }
                        onPressAndHold: {
                            ListView.view.ViewItems.dragMode = !ListView.view.ViewItems.dragMode
                        }
                    }
                    ViewItems.onDragUpdated: {
                        if (event.status == ListItemDrag.Moving) {
                            model.move(event.from, event.to, 1);
                        }
                    }

                    moveDisplaced: Transition {
                        LomiriNumberAnimation {
                            property: "y"
                        }
                    }
                }
                ListItemHeader.Header {
                    id: titleGeneralSettings
                    text: "<font color=\"#ffffff\">"+i18n.tr("General")+"</font>"
                }

                property var iconStyleModel: [
                { title: "<font color=\"#ffffff\">"+i18n.tr("None")+"</font>", descr: "<font color=\"#ffffff\">"+i18n.tr("Unstyled icons")+"</font>", style:"none" },
                { title: "<font color=\"#ffffff\">"+i18n.tr("Rounded")+"</font>", descr: "<font color=\"#ffffff\">"+i18n.tr("Rounded icons")+"</font>", style:"rounded" }
                ]

                ListItemHeader.ItemSelector {
                    id: styleIconList
                    width: (parent.width-textStyleIcons.width)-units.gu(8)
                    colourImage: true
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(2)
                    model: homeSettingsColumn.iconStyleModel
                    delegate: OptionSelectorDelegate {
                        property var item: model.modelData ? model.modelData : model
                        text: item.title
                        subText: item.descr
                    }
                    onSelectedIndexChanged: {
                        launchermodular.settings.iconStyle = model[selectedIndex].style
                    }
                    Component.onCompleted: {
                        if ("rounded" == launchermodular.settings.iconStyle){selectedIndex = 1}
                        if ("none" == launchermodular.settings.iconStyle){selectedIndex = 0}
                    }

                    Text {
                      id: textStyleIcons
                      text: i18n.tr("Style Icons : ")
                      height: units.gu(5)
                      anchors.right: parent.left
                      anchors.rightMargin: units.gu(2)
                      color: "#ffffff"
                      verticalAlignment: Text.AlignVCenter
                    }

                }

                property var searchEngineModel: [
                    { name: "<font color=\"#ffffff\">Duckduckgo</font>", value: "https://duckduckgo.com/?q="},
                    { name: "<font color=\"#ffffff\">Ecosia</font>", value: "https://www.ecosia.org/search?q="},
                    { name: "<font color=\"#ffffff\">Qwant</font>", value: "https://www.qwant.com/?q="},
                    { name: "<font color=\"#ffffff\">Bing</font>", value: "https://www.bing.com/search?q="},
                    { name: "<font color=\"#ffffff\">Yahoo</font>", value: "https://search.yahoo.com/search?p="},
                    { name: "<font color=\"#ffffff\">Google</font>", value: "https://www.google.com/search?q="},
                ]

                ListItemHeader.ItemSelector {
                    id: searchEngineList
                    width: (parent.width-textStyleIcons.width)-units.gu(8)
                    colourImage: true
                    anchors.right: parent.right
                    anchors.rightMargin: units.gu(2)
                    model: homeSettingsColumn.searchEngineModel
                    delegate: OptionSelectorDelegate {
                        property var item: model.modelData ? model.modelData : model
                        text: item.name
                    }
                    onSelectedIndexChanged: {
                        launchermodular.settings.searchEngine = model[selectedIndex].value
                    }
                    Component.onCompleted: {
                        if ("https://duckduckgo.com/?q=" == launchermodular.settings.searchEngine){selectedIndex = 0}
                        else if ("https://www.ecosia.org/search?q=" == launchermodular.settings.searchEngine){selectedIndex = 1}
                        else if ("https://www.qwant.com/?q=" == launchermodular.settings.searchEngine){selectedIndex = 2}
                        else if ("https://www.bing.com/search?q=" == launchermodular.settings.searchEngine){selectedIndex = 3}
                        else if ("https://search.yahoo.com/search?p=" == launchermodular.settings.searchEngine){selectedIndex = 4}
                        else if ("https://www.google.com/search?q=" == launchermodular.settings.searchEngine){selectedIndex = 5}
                    }

                    Text {
                      id: searchEngineLabel
                      text: i18n.tr("Search engine : ")
                      height: units.gu(5)
                      anchors.right: parent.left
                      anchors.rightMargin: units.gu(2)
                      color: "#ffffff"
                      verticalAlignment: Text.AlignVCenter
                    }

                }

                ListItemHeader.Header {
                    text: "<font color=\"#ffffff\">"+i18n.tr("Widgets")+"</font>"
                }

                ListItemHeader.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Show clock")+"</font>"
                    control: Switch {
                        checked: launchermodular.settings.widgetVisibleClock
                        onClicked: launchermodular.settings.widgetVisibleClock = !launchermodular.settings.widgetVisibleClock
                    }
                }

                ListItemHeader.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Show weather")+"</font>"
                    control: Switch {
                        checked:
                        launchermodular.settings.widgetVisibleWeather
                        onClicked: launchermodular.settings.widgetVisibleWeather = !launchermodular.settings.widgetVisibleWeather
                    }
                }

                ListItemHeader.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Show alarms")+"</font>"
                    control: Switch {
                        checked: launchermodular.settings.widgetVisibleAlarm
                        onClicked: launchermodular.settings.widgetVisibleAlarm = !launchermodular.settings.widgetVisibleAlarm
                    }
                }

                ListItemHeader.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Show last call")+"</font>"
                    control: Switch {
                        checked: launchermodular.settings.widgetVisibleLastcall
                        onClicked: launchermodular.settings.widgetVisibleLastcall = !launchermodular.settings.widgetVisibleLastcall
                    }
                }

                ListItemHeader.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Show last message")+"</font>"
                    control: Switch {
                        checked: launchermodular.settings.widgetVisibleLastmessage
                        onClicked: launchermodular.settings.widgetVisibleLastmessage = !launchermodular.settings.widgetVisibleLastmessage
                    }
                }

                ListItemHeader.Standard {
                    showDivider: false
                    text: "<font color=\"#ffffff\">"+i18n.tr("Show events")+"</font>"
                    control: Switch {
                        checked: launchermodular.settings.widgetVisibleEvent
                        onClicked: launchermodular.settings.widgetVisibleEvent = !launchermodular.settings.widgetVisibleEvent
                    }
                }
            } // column
        } //flickable
    } //rectangle settings

    Component.onCompleted: {
        AppHandler.permaFilter()
        AppHandler.permaFilter("NoDisplay", "^(?!true$).*$") //keep the one that have NOT NoDisplay=true
        AppHandler.permaFilter("Icon",  "/.*$")
        AppHandler.sort()
    }

}
