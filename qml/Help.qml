import QtQuick 2.9
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.0
import Qt.labs.settings 1.0
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import "pages"

Page {
    id: pageHelp

    header: PageHeader {
        id: helpPage
        title: i18n.tr("Modular Launcher Help");
       StyleHints {
           foregroundColor: "#FFFFFF";
           backgroundColor: "#111111";
       }
            leadingActionBar.actions: 
                Action {
                    iconName: "back"
                    text: "Back"
                    onTriggered: {
                        pageStack.pop();
        }
     }
  }  

    Rectangle {
        id:rect1
        color: "#111111"
        anchors {
            fill: parent
            topMargin: units.gu(6)
        }

Item {
      width: parent.width
      height: parent.height

    Column {
        anchors {
            left: parent.left
            right: parent.right
        }
        
        ListItem.Header {
                text: "<font color=\"#ffffff\">"+i18n.tr("Widget Settings")+"</font>"
        }        
        
        Item {
            width: parent.width
            height: translators1Label.height + units.gu(2)
            Label {
                id: translators1Label
                text: i18n.tr("<br><b>Click and hold the widget and to change its settings.</b>")
                anchors.centerIn: parent
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - units.gu(12)
                color: "#ffffff"
            }
          }                                   
        }
      }
    }
// HELP PAGE    
}

