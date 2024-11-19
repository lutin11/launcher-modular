import QtQuick 2.12
import Lomiri.Components 1.3
import QtGraphicalEffects 1.12
import CalculatorHelper 1.0

Column {
    id:widgetCalculatorRow
    height: culculResult.height
    visible: if(culculResult.text.length > 0){true}else{false}
    width: parent.width
    anchors {
        left: parent.left
        leftMargin: units.gu(2)
        right: parent.right
        rightMargin: units.gu(2)
    }

    Label {
        id:calculatorHeaderText
        anchors.leftMargin: units.gu(1)
        text: i18n.tr("Calcul result:")
        color: launchermodular.settings.textColor
    }
    Text{
        id: culculResult
        horizontalAlignment: Text.AlignHCenter
        anchors.topMargin: units.gu(1)
        anchors.horizontalCenter: parent.horizontalCenter
        font.pixelSize: units.gu(1.5)
        text: ""
        color: launchermodular.settings.textColor
    }
    
    Connections {
        target: CalculatorHelper
        onResultReady: function(result) {
            console.log("Signal received with result: " + result);
            if (result) {
                culculResult.text = result;
            }
        }
        onNoResult:function(){culculResult.text = "";}
    }
}