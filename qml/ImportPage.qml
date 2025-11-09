import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Content 1.3

Page {
    id: importPage
    signal cancel()

    property var activeTransfer
    property string currentFragment: "GlobalImportPage.qml"

    header: PageHeader {
        title: i18n.tr("Choose")
        leadingActionBar.actions: [
            Action {
                iconName: "back"
                text: "Back"
                onTriggered: {
                    pageStack.pop()
                }
            }
        ]
    }

    Loader {
        id: fragmentLoader
        anchors.fill: parent
        source: Qt.resolvedUrl(currentFragment)
        onLoaded: item.contentType = ContentType.Pictures
    }
    
    Connections {
        target: ContentHub
        onImportRequested: {
            var filePath = String(transfer.items[0].url).replace('file://', '')
            launchermodular.iconCustomUrl = filePath;
            pageStack.pop()
        }
    }
}
