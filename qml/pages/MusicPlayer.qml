import QtQuick 2.12
import QtQuick.Layouts 1.12
import Lomiri.Components 1.3

Rectangle {
    id: musicPlayer
    visible: false
    height: visible ? units.gu(10) : 0
    color: "#111111"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    property var playlist: []
    property int currentIndex: -1
    property bool isPlaying: false
    property string currentSongName: ""

    signal songChanged(string name, int index)
    signal playingChanged(bool playing)

    function play(songPath) {
        Qt.openUrlExternally(songPath)
        isPlaying = true
        visible = true
        playingChanged(true)
    }

    function playList(songs) {
        playlist = songs
        currentIndex = 0
        if (songs.length > 0) {
            play(songs[0].path)
            currentSongName = songs[0].name
            songChanged(currentSongName, currentIndex)
        }
    }

    function pause() {
        isPlaying = false
        playingChanged(false)
    }

    function resume() {
        if (currentIndex >= 0 && currentIndex < playlist.length) {
            play(playlist[currentIndex].path)
        }
    }

    function stop() {
        isPlaying = false
        visible = false
        currentIndex = -1
        currentSongName = ""
        playingChanged(false)
    }

    function next() {
        if (playlist.length === 0) return
        currentIndex = (currentIndex + 1) % playlist.length
        play(playlist[currentIndex].path)
        currentSongName = playlist[currentIndex].name
        songChanged(currentSongName, currentIndex)
    }

    function previous() {
        if (playlist.length === 0) return
        currentIndex = (currentIndex - 1 + playlist.length) % playlist.length
        play(playlist[currentIndex].path)
        currentSongName = playlist[currentIndex].name
        songChanged(currentSongName, currentIndex)
    }

    Column {
        anchors.fill: parent
        anchors.margins: units.gu(1)

        RowLayout {
            width: parent.width
            spacing: units.gu(2)

            Button {
                Layout.fillWidth: false
                width: units.gu(5)
                height: units.gu(4)
                text: "◄◄"
                onClicked: musicPlayer.previous()
            }

            Button {
                Layout.fillWidth: false
                width: units.gu(6)
                height: units.gu(4)
                text: musicPlayer.isPlaying ? "❚❚" : "▶"
                onClicked: {
                    if (musicPlayer.isPlaying) {
                        musicPlayer.pause()
                    } else {
                        musicPlayer.resume()
                    }
                }
            }

            Button {
                Layout.fillWidth: false
                width: units.gu(5)
                height: units.gu(4)
                text: "►►"
                onClicked: musicPlayer.next()
            }

            Label {
                Layout.fillWidth: true
                text: musicPlayer.currentSongName
                color: "#FFFFFF"
                elide: Text.ElideRight
                fontSize: "small"
            }

            Button {
                Layout.fillWidth: false
                width: units.gu(4)
                height: units.gu(4)
                text: "✕"
                onClicked: musicPlayer.stop()
            }
        }
    }
}
