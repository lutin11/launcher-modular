import QtQuick 2.12
import QtQuick.Controls 2.12
import Lomiri.Components 1.3
import QtQuick.Window 2.10
import QtSensors 5.12


Item {
    id: clock

    property real minFontSize: 10
    property real maxFontSize: 60
    property int currentOrientation: Qt.PrimaryOrientation
    property real targetFontSize: launchermodular.settings.clockFontSize

    function updateTime() {
        const date = new Date();
        let hours = date.getHours();
        let minutes = date.getMinutes();
        let seconds = date.getSeconds();

        // Format as hh:mm:ss
        digitalClock.text = launchermodular.settings.clockHHMMSS
                ? `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
                : `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    }

    onVisibleChanged: {
          if (visible) {
              console.log("Clock is now visible (active page)")
              pageClockTimer.running = true
              updateTime()
          } else {
              console.log("Clock is now hidden (inactive page)")
              pageClockTimer.running = false
          }
      }

    function orientationToString(o) {
        switch (o) {
        case OrientationReading.TopUp:
            return "normal portrait";
        case OrientationReading.TopDow:
            return "inverted portrait";
        case OrientationReading.LeftUp:
            return "landscape";
        case OrientationReading.RightUp:
            return "inverted landscape";
        case OrientationReading.FaceUp:
            return "face up screen";
        case OrientationReading.FaceDown:
            return "face back screen";
        }
        return "unknown";
    }

    function changeTextMetrics() {
        textMetrics.text = randomTimeHHMM()
        updateTime()
        Qt.callLater(() => adjustFontSize())
    }

    function adjustFontSize() {
        var w = textMetrics.width
        var availableWidth = digitalClock.width

        if (w <= 0)
            return

        var scale = availableWidth
        var newSize = digitalClock.font.pixelSize * scale * 0.95
        newSize = Math.max(minFontSize, Math.min(maxFontSize, newSize))
        targetFontSize = newSize
        digitalClock.font.pixelSize = targetFontSize
    }

    function randomTimeHHMM() {
        const h = Math.floor(Math.random() * 24)
        const m = Math.floor(Math.random() * 60)
        return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`
    }

    function onOrientationChanged(newOrientation) {
        maxFontSize = (OrientationReading.TopUp || OrientationReading.TopDow || (OrientationReading.FaceUp && currentOrientation == (OrientationReading.TopUp || OrientationReading.TopDow))) ? 169 : 300
        currentOrientation = newOrientation
        console.log("Clock orientation:", orientationToString(newOrientation), " - ", maxFontSize)
        changeTextMetrics()
    }

    Timer {
        id: pageClockTimer
        interval: if(launchermodular.settings.clockHHMMSS) {1000} else {60000}
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
            console.log("Sensor orientation:", o)
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
            font.pixelSize: targetFontSize
            font.bold: launchermodular.settings.clockFontBold
            font.italic: launchermodular.settings.clockFontItalic
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

        TextMetrics {
            id: textMetrics
            text: digitalClock.text
            font: digitalClock.font
        }

        onWidthChanged: adjustFontSize()
        onHeightChanged: adjustFontSize()

        Component.onCompleted: adjustFontSize()
    }
}
