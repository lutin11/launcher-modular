import QtQuick 2.12
import QtQuick.Controls 2.12
import Lomiri.Components 1.3
import QtQuick.Window 2.10


Item {
    id: clock

    function orientationToString(o) {
        switch (o) {
        case Qt.PrimaryOrientation:
            return "primary";
        case Qt.PortraitOrientation:
            return "portrait";
        case Qt.LandscapeOrientation:
            return "landscape";
        case Qt.InvertedPortraitOrientation:
            return "inverted portrait";
        case Qt.InvertedLandscapeOrientation:
            return "inverted landscape";
        }
        return "unknown";
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
            font.pixelSize: launchermodular.settings.clockFontSize
            font.bold: launchermodular.settings.clockFontBold
            font.italic: launchermodular.settings.clockFontItalic
            color: launchermodular.settings.clockFontColor
            text: "88:88:88"
            maximumLineCount: 1
            elide: Text.ElideMiddle
            wrapMode: Text.WrapAnywhere
            verticalAlignment: Text.AlignVCenter
        }

        Timer {
            interval: 1000 // 1 second in milliseconds
            running: true
            repeat: true
            onTriggered: {
                // Update the time
                const date = new Date();
                let hours = date.getHours();
                let minutes = date.getMinutes();
                let seconds = date.getSeconds();

                // Format as hh:mm:ss
                digitalClock.text = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
            }
        }
        TextMetrics {
            id: textMetrics
            text: digitalClock.text
            onWidthChanged: {
                let isPortrait = Screen.desktopAvailableWidth < Screen.desktopAvailableHeight
                let ratio = isPortrait ? 1 : Math.floor(Screen.desktopAvailableWidth / Screen.desktopAvailableHeight)
                digitalClock.font.pixelSize = launchermodular.settings.clockFontSize * ratio
            }
        }

        OrientationHelper {
            id: orientationHelper
        }

        // Grid {
        //     id: propertyGrid
        //     columns: 2
        //     spacing: 8
        //     x: spacing
        //     y: spacing
        //     anchors.bottom: parent.bottom

        //     Text {
        //         text: "Screen \"" + Screen.name + "\":"
        //         font.bold: true
        //     }
        //     Item { width: 1; height: 1 } // spacer

        //     Text { text: "manufacturer" }
        //     Text { text: Screen.manufacturer ? Screen.manufacturer : "unknown" }

        //     Text { text: "model" }
        //     Text { text: Screen.model ? Screen.model : "unknown" }

        //     Text { text: "serial number" }
        //     Text { text: Screen.serialNumber ? Screen.serialNumber : "unknown" }

        //     Text { text: "dimensions" }
        //     Text { text: Screen.width + "x" + Screen.height }

        //     Text { text: "pixel density" }
        //     Text { text: Screen.pixelDensity.toFixed(2) + " dots/mm (" + (Screen.pixelDensity * 25.4).toFixed(2) + " dots/inch)" }

        //     Text { text: "logical pixel density" }
        //     Text { text: Screen.logicalPixelDensity.toFixed(2) + " dots/mm (" + (Screen.logicalPixelDensity * 25.4).toFixed(2) + " dots/inch)" }

        //     Text { text: "device pixel ratio" }
        //     Text { text: Screen.devicePixelRatio.toFixed(2) }

        //     Text { text: "available virtual desktop" }
        //     Text { text: Screen.desktopAvailableWidth + "x" + Screen.desktopAvailableHeight }

        //     Text { text: "position in virtual desktop" }
        //     Text { text: Screen.virtualX + ", " + Screen.virtualY }

        //     Text { text: "orientation" }
        //     Text {
        //       text: clock.orientationToString(Screen.orientation) + " (" + Screen.orientation + ")"
        //       color: "black"
        //     }

        //     Text { text: "primary orientation" }
        //     Text { text: clock.orientationToString(Screen.primaryOrientation) + " (" + Screen.primaryOrientation + ")" }

        // }
    }
}
