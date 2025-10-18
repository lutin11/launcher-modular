import QtQuick 2.4
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.0
import Qt.labs.settings 1.0
import Ubuntu.Components 1.3
import AppHandler 1.0
import "../widgets"
import QtQuick.Controls 2.2
import Ubuntu.Components.Popups 1.3
import Terminalaccess 1.0
import LibertineLauncher 1.0
import CalculatorHelper 1.0
import Ubuntu.Components.ListItems 1.3 as ListItem
import Ubuntu.Components.Themes 1.3


Item {
    id: home

    Component {
        id: authenticationDialog
        Dialog {
            id: authentDialogue
            title: "Authentification needed"
            width: parent.width

            TextField {
                id:inp
                placeholderText: "Enter password (by defaut : phablet)"
                echoMode: TextInput.Password
            }
            Item {
                height: units.gu(5)
                width: parent.width
                Button {
                    height: units.gu(4)
                    width: (parent.width/2)-units.gu(2)
                    anchors.left: parent.left
                    id: okButton
                    text: i18n.tr("ok")
                    background: Rectangle {
                        radius: units.gu(1.5)
                        color: "#0E8420"
                    }
                    onClicked: {Terminalaccess.inputLine(inp.text, false);PopupUtils.close(authentDialogue)}
                }
                Button {
                    anchors.right: parent.right
                    id: cancelButton
                    height: units.gu(4)
                    width: (parent.width/2)-units.gu(2)
                    background: Rectangle {
                        radius: units.gu(1.5)
                        color: Theme.palette.normal.overlaySecondaryText
                    }
                    text: i18n.tr("Cancel")
                    onClicked: {
                        onClicked: PopupUtils.close(authentDialogue);
                    }
                }
            }
        }
    }

    Timer {
        id:refreshafteruninstall
        interval: 500; running: false; repeat: false
        onTriggered: {home.refreshHomePage();}
    }

    Connections {
        target: Terminalaccess
        onNeedSudoPassword: {PopupUtils.open(authenticationDialog)}
        onFinished: {
            PopupUtils.close(authenticationDialog);
            refreshafteruninstall.restart()
        }
    }

    property bool reloading: false

    function refreshHomePage() {
        home.reloading = true
        AppHandler.reload()
        AppHandler.permaFilter()
        AppHandler.permaFilter("NoDisplay", "^(?!true$).*$") //keep the one that have NOT NoDisplay=true
        AppHandler.permaFilter("package_name",  "^(?!launchermodular.lut11_).*$")
        AppHandler.permaFilter("Icon",  "/.*$")
        listCustomIcon.model = ""
        listCustomIcon.model = launchermodular.customIconModel
        AppHandler.sort()
        if (launchermodular.settings.widgetVisibleWeather){
            weatherWidget.modelWeather.reload()
            weatherWidget.modelWeatherNext.reload()
        }
        if (launchermodular.settings.widgetVisibleLastmessage) {
            widgetLastMessage.updateFilteredModelFunction();
        }
        if (launchermodular.settings.widgetVisibleLastcall) {
            widgetLastCall.updateFilteredModelFunction();
        }

        if (launchermodular.settings.widgetVisibleEvent) {
            widgetEvent.updateModel();
        }


        home.reloading = false
    }

    Flickable {
        id: homeFlickable
        anchors.fill: parent
        contentHeight: listColumn.childrenRect.height+units.gu(2)
        flickableDirection: Flickable.VerticalFlick
        clip: true
        maximumFlickVelocity : units.gu(10)*100
        flickDeceleration: 2500

        Behavior on contentY {
            NumberAnimation {
                duration: 1000
                easing.type: Easing.OutBounce
            }
        }

        PullToRefresh {
            parent: homeFlickable
            refreshing: home.reloading
            onRefresh: home.refreshHomePage();
        }

        Column {
            id: listColumn
            anchors.fill: parent
            anchors {
                topMargin: units.gu(2)
            }
            spacing: units.gu(2)

            Rectangle {
                id: search
                height: units.gu(5)
                width: parent.width
                color: "transparent"

                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                }

                Rectangle {
                    id: searchBackground
                    color: launchermodular.settings.backgroundColor
                    radius: units.gu(1)
                    opacity: 0.3
                    anchors.fill: parent
                }
                Icon {
                    id: iconSearch
                    anchors {
                        left: search.left
                        rightMargin: units.gu(1)
                        leftMargin: units.gu(1)
                    }
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height*0.5
                    width: height
                    name: {
                        if (searchField.text.length > 0) {
                            "edit-clear"
                        } else {
                            "find"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked:{
                            if(searchField.text.length > 0){
                               searchField.text = ""
                               searchField.focus = false
                               CalculatorHelper.processInput(searchField.text);// to force reset
                            }
                        }
                    }
                }
                TextField {
                    id: searchField
                    focus: false
                    anchors {
                        left: iconSearch.right
                        right: iconWebSearch.left
                    }
                    height: search.height
                    color: launchermodular.settings.textColor
                    background: Rectangle {
                      height: parent.height
                      color: "transparent"
                    }

                    placeholderText: ""
                    // Custom placeholder
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: units.gu(2)
                        verticalAlignment: Text.AlignVCenter
                        color: "#aaaaaa" // Light grey color for placeholder
                        text: i18n.tr("Search your phone and online sources")
                        visible: searchField.text.length == 0
                        font.pixelSize: units.gu(1.5)
                    }
                    inputMethodHints: Qt.ImhNoPredictiveText
                    onTextChanged: {
                        AppHandler.resetTempFilter()
                        if(text.length > 0) {
                            iconWebSearch.visible = true
                            AppHandler.tempFilter("Name;Name[];package_name", text)
                            rowWidgets.visible = false
                            rowWidgetsM.visible = false
                            CalculatorHelper.processInput(text)
                        } else {
                            iconWebSearch.visible = false
                            AppHandler.resetTempFilter()
                            AppHandler.sort()
                            rowWidgets.visible = true
                            rowWidgetsM.visible = true
                        }
                    }
                }

                Icon {
                    id: iconWebSearch
                    visible: false
                    anchors {
                        right: search.right
                        rightMargin: units.gu(1)
                        leftMargin: units.gu(1)
                    }
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height*0.5
                    width: height
                    source: "home/assets/websearch.svg"
                    MouseArea {
                        anchors.fill: parent
                        onClicked:{
                            if (searchField.text.toLowerCase().startsWith("http://") || searchField.text.toLowerCase().startsWith("https://")) {
                                Qt.openUrlExternally( searchField.text.toLowerCase() );
                            } else {
                                Qt.openUrlExternally( launchermodular.settings.searchEngine + encodeURIComponent(searchField.text.toLowerCase()) +"&t=h_&ia=web" );
                            }

                        }
                    }
                }

            }


            Row{
                id: rowWidgets
                width: childrenRect.width
                height: search.contentHeight
                anchors.horizontalCenter: parent.horizontalCenter

                Clock {
                    visible: launchermodular.settings.widgetVisibleClock
                    width: launchermodular.settings.widgetVisibleWeather ? listColumn.width/2 : listColumn.width
                }
                Weather { 
                    id: weatherWidget
                    visible: launchermodular.settings.widgetVisibleWeather 
                }

            }

            Row{
                id: rowWidgetsM
                width: parent.width
                height: search.contentHeight
                anchors {
                    right: parent.right
                    rightMargin: units.gu(2)
                    left: parent.left
                    leftMargin: units.gu(2)
                }

                Column{
                    id: widgetLM
                    spacing: units.gu(1)
                    width: search.contentWidth
                    Alarm {
                        id: widgetAlarm
                        visible: launchermodular.settings.widgetVisibleAlarm
                    }
                    Lastcall {
                        id: widgetLastCall
                        visible: launchermodular.settings.widgetVisibleLastcall
                    }
                    Lastmessage {
                        id: widgetLastMessage
                        visible: launchermodular.settings.widgetVisibleLastmessage
                    }

                }

                Event {
                  id: widgetEvent
                  visible: launchermodular.settings.widgetVisibleEvent
                }

            }

            Calculator {
                id: calculatorAppWidget
                width: parent.width
            }

            SearchContact {
                id: searchContactWidget
                width: parent.width
            }

            FavoriteApp {
                id: favoriteAppWidget
                width: parent.width
            }

            FavoriteContact {
                id: favoriteContactWidget
                width: parent.width
            }

            Item {
                id: listColumnApps
                height: gview.contentHeight
                width: parent.width
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    right: parent.right
                    rightMargin: units.gu(2)
                }

                function doAction(app) {
                    doLaunchAction(app.action, app.container);
                }

                function doLaunchAction(action, container) {
                    if (DEBUG_MODE) console.log("app:", JSON.stringify(action));
                    if(container.length > 0) {
                        LibertineLauncher.launchLibertineApp(container, action);
                    } else if(action.startsWith("application:///")) {
                        Qt.openUrlExternally(action);
                    } else if(action.startsWith("terminal:///")) {
                        var actionterm = action.replace(/^terminal:\/\/\//, "")
                        var actionsudo = actionterm.replace(/^sudo /, "sudo -S ")
                        Terminalaccess.run(actionsudo);
                    } else if(action.startsWith("browser:///")) {
                        Qt.openUrlExternally(action.replace(/^browser:\/\/\//, ""));
                    } else if(action.startsWith("internal:///")) {
                        pageStack.push(Qt.resolvedUrl(action.replace(/^internal:\/\/\//, "")))
                    }
                }

                GridView {
                    id: gview
                    anchors.fill: parent

                    cellHeight: iconbasesize+units.gu(5)
                    property real iconbasesize: units.gu(10)*launchermodular.settings.iconSize
                    cellWidth: Math.floor(width/Math.floor(width/iconbasesize))

                    focus: true
                    model: AppHandler.appsinfo.length
                    interactive: false

                    delegate: Item {
                        width: gview.cellWidth
                        height: gview.iconbasesize

                        Item {
                            id: itemApp
                            width: units.gu(8)*launchermodular.settings.iconSize
                            height: units.gu(8)*launchermodular.settings.iconSize
                            anchors.horizontalCenter: parent.horizontalCenter

                            Image {
                                id: imgIcons
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: parent.height
                                source: AppHandler.appsinfo[index].icon && (AppHandler.appsinfo[index].icon.endsWith(".png") || AppHandler.appsinfo[index].icon.endsWith(".svg"))
                                        ? AppHandler.appsinfo[index].icon
                                        : "../../assets/placeholder-app-icon.svg"
                                visible: if (launchermodular.settings.iconStyle == "none") { true;}else{ false;}
                            }

                            OpacityMask {
                                anchors.fill: imgIcons
                                source: launchermodular.settings.iconStyle == "rounded" ? imgIcons : undefined
                                maskSource: Rectangle {
                                    width: imgIcons.width
                                    height: imgIcons.height
                                    radius: units.gu(8)
                                    color: if (launchermodular.settings.iconStyle == "rounded") { "";} else { "transparent";}
                                    visible: if (launchermodular.settings.iconStyle == "rounded") { false;} else { true;}
                                }
                            }

                            UbuntuShape {
                                source: imgIcons
                                aspect: UbuntuShape.Flat
                                width: if (launchermodular.settings.iconStyle == "default") { parent.width;}else{ units.gu(0);}
                                height: if (launchermodular.settings.iconStyle == "default") { parent.height;}else{ units.gu(0);}
                                radius : "medium"
                            }

                            Component {
                                id: appsDialog
                                Dialog {
                                    id: appsDialogue

                                    title: AppHandler.appsinfo[index].name
                                    text: AppHandler.appsinfo[index].getProp("Comment")

                                    Item {
                                        height: units.gu(5)
                                        width: parent.width
                                        Button {
                                            anchors.left: parent.left
                                            id: uninstallButton
                                            text: AppHandler.appsinfo[index].getProp("package_name") ? i18n.tr("Uninstall") : i18n.tr("Remove")
                                            height: units.gu(4)
                                            width: (parent.width/2)-units.gu(2)
                                            contentItem: Text {
                                                text: uninstallButton.text
                                                font: uninstallButton.font
                                                color: "#ffffff"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                            }

                                            background: Rectangle {
                                                radius: units.gu(1.5)
                                                color: "#0E8420"
                                            }
                                            onClicked: {
                                                PopupUtils.close(appsDialogue);

                                                if (AppHandler.appsinfo[index].getProp("package_name")){

                                                    Terminalaccess.run("sudo -S click unregister --user=phablet "+AppHandler.appsinfo[index].getProp("package_name").split("_")[0])

                                                } else {
                                                    for (var i = 0; i < launchermodular.customIconModel.count; i++) {
                                                        if (AppHandler.appsinfo[index].name == launchermodular.customIconModel.get(i).name) {
                                                            launchermodular.customIconModel.remove(i)
                                                            launchermodular.getCustomIconArray()

                                                        }
                                                    }

                                                    launchermodular.settings.customIcon = launchermodular.getCustomIconArray();
                                                }

                                                home.refreshHomePage()

                                            }
                                        }
                                        Button{
                                            anchors.right: parent.right
                                            text: i18n.tr("Cancel")
                                            height: units.gu(4)
                                            width: (parent.width/2)-units.gu(2)
                                            background: Rectangle {
                                                radius: units.gu(1.5)
                                                color: Theme.palette.normal.overlaySecondaryText
                                            }
                                            onClicked: {
                                                onClicked: PopupUtils.close(appsDialogue);
                                            }
                                        }


                                    }

                                }
                            } // application:///$(app_id).desktop

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {

                                    listColumnApps.doAction(AppHandler.appsinfo[index])
                                }
                                onPressAndHold: {
                                    PopupUtils.open(appsDialog);
                                }
                            }

                        } // Item

                        Text{
                            anchors.top: itemApp.bottom
                            horizontalAlignment: Text.AlignHCenter
                            anchors.topMargin: units.gu(1)
                            width: parent.width
                            font.pixelSize: units.gu(1.5)
                            wrapMode: Text.Wrap
                            text: AppHandler.appsinfo[index].name;
                            color: launchermodular.settings.textColor
                         }

                    }// delegate

                }

                Repeater {
                    id: listCustomIcon
                    model: launchermodular.customIconModel
                    Loader {

                        AppInfo {
                            id: customButton
                            name: model.name
                            action: model.action
                            icon: model.icon == "../assets/placeholder-app-icon.svg" ? "../../assets/placeholder-app-icon.svg" : model.icon
                            Component.onCompleted:AppHandler.appsinfo.push(customButton)
                        }

                    }

                }

                Component.onCompleted: {
                    AppHandler.permaFilter()
                    AppHandler.permaFilter("NoDisplay", "^(?!true$).*$") //keep the one that have NOT NoDisplay=true
                    AppHandler.permaFilter("package_name",  "^(?!launchermodular.lut11_).*$")
                    AppHandler.permaFilter("Icon",  "/.*$")

                    //AppHandler.appsinfo.push(settingsButton)

                    AppHandler.sort()
                    if (DEBUG_MODE) console.log(AppHandler.appsinfo[0].name);
                    if (DEBUG_MODE) console.log(AppHandler.appsinfo[0].getProp("package_name"));
                    if (DEBUG_MODE) console.log(AppHandler.appsinfo[0].getProp("Icon"));
                    if (DEBUG_MODE) console.log(Qt.locale().name);

                }
            }

        }//Column
    } //Flickable
}
