import QtQuick 2.15
import QtQuick.Controls 2.12
import Ubuntu.Components 1.3
import QtQuick.Window 2.10
import QtSensors 5.12
import QtSystemInfo 5.0 // for screen saver


Item {
    id: clock

    property int currentOrientation: Qt.PrimaryOrientation
    property real targetFontSize: launchermodular.settings.clockFontSize
    property int pixelDensityFactor: Screen.pixelDensity.toFixed(2) / 5.51

    ScreenSaver {
        id: screenSaver
        screenSaverEnabled: true
    }

    function updateTime() {
        const date = new Date();
        let hours = date.getHours();
        let minutes = date.getMinutes();
        let seconds = date.getSeconds();

        digitalClock.text = launchermodular.settings.clockHHMMSS
                ? `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
                : `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    }

    onVisibleChanged: {
          if (visible) {
              pageClockTimer.running = true
              updateTime()
              adjustFontSize()
              screenSaver.screenSaverEnabled = false
          } else {
              pageClockTimer.running = false
              screenSaver.screenSaverEnabled = true
          }
      }

    function adjustFontSize() {
        targetFontSize = (OrientationReading.TopUp ||
                          OrientationReading.TopDow ||
                          (OrientationReading.FaceUp &&
                           currentOrientation === (OrientationReading.TopUp || OrientationReading.TopDow)
                           ))
                ? launchermodular.settings.clockFontSize * 0.95
                : (launchermodular.settings.clockFontSize * (Screen.width/Screen.height)* 0.95)
    }

    function randomTimeHHMM() {
        const h = Math.floor(Math.random() * 24)
        const m = Math.floor(Math.random() * 60)
        return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`
    }

    function onOrientationChanged(newOrientation) {
        currentOrientation = newOrientation
        adjustFontSize()
    }

    Timer {
        id: pageClockTimer
        interval: Math.max(0, launchermodular.settings.clockHHMMSS ? 1000 : 60000)
        running: true
        repeat: true
        onTriggered: {
            updateTime()
        }
    }

    OrientationSensor {
        id: orientationSensor
        active: true

        onReadingChanged: {
            const o = reading.orientation;
            clock.onOrientationChanged(o)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"

        Text {
            id: digitalClock
            anchors.centerIn: parent
            anchors.leftMargin: units.gu(1)
            anchors.rightMargin: units.gu(1)
            width:parent.width
            font.family: launchermodular.settings.clockFontFamily
            font.pixelSize: targetFontSize * pixelDensityFactor
            font.italic: launchermodular.settings.clockFontItalic
            font.weight: launchermodular.settings.clockFontWeight
            color: launchermodular.settings.clockFontColor
            text: if(launchermodular.settings.clockHHMMSS) {"88:88:88"} else {"88:88"}
            maximumLineCount: 1
            elide: Text.ElideMiddle
            wrapMode: Text.WrapAnywhere
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Behavior on font.pixelSize {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Component.onCompleted: adjustFontSize()

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
              launchermodular.settings.fullScreen = !launchermodular.settings.fullScreen;
              WindowController.toggleFullScreen();
            }
        }

    }
}
