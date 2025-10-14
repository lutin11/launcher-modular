import QtQuick 2.4
import QtQuick.Controls 2.2
import Qt.labs.settings 1.0
import Ubuntu.Components 1.3

Page {
    id: picturePageSettingsPicture

    header: PageHeader {
        id: headerPictureSettings
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
        id:pictureMainSettings
        anchors.fill: parent
        color: "#111111"
        anchors.topMargin: units.gu(6)

        Flickable {
            id: flickablePictureSettings
            anchors.fill: parent
            contentHeight: pictureColumnSettings.height
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: pictureColumnSettings
                anchors {
                   fill: parent
                   top: parent.top
                   topMargin: units.gu(2)
                   leftMargin: units.gu(1)
                   rightMargin: units.gu(1)
                }

                Item {
                    id: pictureTemplateRow
                    width: parent.width
                    height: units.gu(4)

                    Label {
                        id: label
                        text: i18n.tr("Image path")
                        color:  "#FFFFFF"
                        width: pictureTemplateRow.titleWidth
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        font.weight: Font.Light
                    }

                    Row {
                        id: pictureContentRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: label.right
                        anchors.leftMargin: units.gu(2)
                        anchors.right: parent.right
                        spacing: units.gu(2)

                        TextField {
                            objectName: "textfield_standard"
                            width: parent.width
                            text: launchermodular.settings.folderimage
                            onTextChanged: { launchermodular.settings.folderimage = text }
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        }
                    }
                }

            } // column
        } //flickable
    } //rectangle settings
}
