import QtQuick 2.12
import QtQuick.Controls 2.12
import Lomiri.Components 1.3
import QtQuick.Window 2.10
import QtSensors 5.12
import QtSystemInfo 5.0 // for screen saver


Item {
    id: clock

    property real targetFontSize: launchermodular.settings.clockFontSize
    property int pixelDensityFactor: Screen.pixelDensity.toFixed(2) / 5.51

    // Font size in pixels that fits the current page. The setting is the
    // maximum; the window dimensions reduce it when the page is smaller, so
    // resizing the desktop window (or rotating the phone) resizes the clock
    // through the binding.
    readonly property real fittedFontSize: {
        var wanted = Math.max(10, targetFontSize * pixelDensityFactor)
        var byWidth = width > 0 ? width / 4.8 : wanted
        var byHeight = height > 0 ? height * 0.6 : wanted
        return Math.max(10, Math.min(wanted, byWidth, byHeight))
    }

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
              screenSaver.screenSaverEnabled = false
          } else {
              pageClockTimer.running = false
              screenSaver.screenSaverEnabled = true
          }
    }

    function randomTimeHHMM() {
        const h = Math.floor(Math.random() * 24)
        const m = Math.floor(Math.random() * 60)
        return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`
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
            font.pixelSize: clock.fittedFontSize
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

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
                Haptics.play();
                launchermodular.settings.fullScreen = !launchermodular.settings.fullScreen;
                WindowController.toggleFullScreen();
                Haptics.play();
            }
            onClicked: Haptics.play()
        }

    }
}
