import QtQuick 2.12
import QtQuick.Layouts 1.12
import Lomiri.Components 1.3
import QtMultimedia 5.12
import Terminalaccess 1.0
import MySettings 1.0

Rectangle {
    id: musicPlayer
    visible: false
    height: currentSongName.length > 0 ? units.gu(16) : units.gu(11)
    color: "#111111"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    property var playlist: []
    property int currentIndex: -1
    property bool isPlaying: false
    property string currentSongName: ""
    property string currentSongPath: ""
    property bool shuffleMode: false
    property string repeatMode: "none" // "none", "single", "all"
    property string tempCacheDir: MySettings.getHomeLocation() + "/.cache/launchermodular.lut11/"
    property string currentCacheFile: ""
    property int copyIndex: 0
    property bool copyInProgress: false
    property int nextTrackIndex: -1
    property bool showingPlaylists: false

    Component.onCompleted: {
        Terminalaccess.makePath(tempCacheDir)
        cleanupCache()
    }

    enum PlaybackState { Stopped, Playing, Paused, Cleared }

    signal stateChanged(int newState)
    signal showPlaylists()
    signal hidePlaylists()

    Audio {
        id: audioPlayer

        onPlaybackStateChanged: {
            isPlaying = (playbackState === Audio.PlayingState)
            if (isPlaying) {
                stateChanged(MusicPlayer.Playing)
            } else if (playbackState === Audio.PausedState) {
                stateChanged(MusicPlayer.Paused)
            } else {
                stateChanged(MusicPlayer.Stopped)
            }
        }

        onPositionChanged: {
            if (!progressSlider.pressed) {
                progressSlider.value = position
            }
        }

        onDurationChanged: {
            progressSlider.maximumValue = duration
        }

        onStatusChanged: {
            if (status === Audio.EndOfMedia) {
                if (repeatMode === "single") {
                    audioPlayer.play()
                } else if (repeatMode === "none") {
                    advanceTrack()
                } else if (repeatMode === "all") {
                    advanceTrack()
                }
            }
        }

        onError: {
            console.log("Audio error:", errorString)
        }
    }

    function formatTime(ms) {
        if (!ms || isNaN(ms) || ms < 0) return "0:00"
        var totalSeconds = Math.floor(ms / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function advanceTrack() {
        if (currentIndex < playlist.length - 1) {
            next()
        } else if (repeatMode === "all") {
            currentIndex = 0
            playList(playlist)
        } else {
            stop()
        }
    }

    function play(songPath) {
        deleteFromCache(currentCacheFile)
        var cachedPath = copyToCache(songPath, 0)
        copyIndex = 1
        currentCacheFile = cachedPath
        audioPlayer.source = cachedPath
        audioPlayer.play()
        currentSongPath = songPath
        currentSongName = songPath.split("/").pop()
    }

    function addToPlaylist(filePath, fileName) {
        console.log("received addToPlaylist...")
        console.log(playlist.length)
        var newPlaylist = playlist.slice()
        newPlaylist.push({path: filePath, name: fileName})
        playlist = newPlaylist   // réassignation -> déclenche playlistChanged
        playList(playlist)
    }

    function removeFromPlaylist(filePath, fileName) {
        console.log("received removeFromPlaylist...")
        console.log(playlist.length)
        var idx = -1
        for (var i = 0; i < playlist.length; i++) {
            if (playlist[i].path === filePath) {
                idx = i
                break
            }
        }
        if (idx !== -1) {
            var newPlaylist = playlist.slice()
            newPlaylist.splice(idx, 1)
            playlist = newPlaylist   // réassignation -> déclenche playlistChanged
        }

        playList(playlist)
    }

    function loadTrack(index, autoPlay) {
        if (index < 0 || index >= playlist.length) return

        var path = playlist[index].path
        deleteFromCache(currentCacheFile)
        var cachedPath = copyToCache(path, copyIndex)
        copyIndex++
        currentCacheFile = cachedPath

        audioPlayer.source = cachedPath
        if (autoPlay) audioPlayer.play()

        currentIndex = index
        currentSongName = playlist[index].name
        currentSongPath = path
    }

    function resetPlayback() {
        audioPlayer.stop()
        audioPlayer.source = ""
        deleteFromCache(currentCacheFile)
        isPlaying = false
        currentIndex = -1
        currentSongName = ""
        currentSongPath = ""
        currentCacheFile = ""
        copyIndex = 0
    }

    function playList(songs) {
        playlist = songs
        resetPlayback()
        if (songs.length === 0) return
        loadTrack(0, false)
    }

    function pause() {
        audioPlayer.pause()
    }

    function resume() {
        audioPlayer.play()
    }

    function stop() {
        resetPlayback()
    }

    function clear() {
        resetPlayback()
        playlist = []
        stateChanged(MusicPlayer.Cleared)
    }

    function next() {
        if (currentIndex < playlist.length - 1) loadTrack(currentIndex + 1, true)
    }

    function previous() {
        if (currentIndex > 0) loadTrack(currentIndex - 1, true)
    }

    function toggleShuffle() {
        shuffleMode = !shuffleMode
    }

    function toggleRepeat() {
        if (repeatMode === "none") {
            repeatMode = "single"
        } else if (repeatMode === "single") {
            repeatMode = "all"
        } else {
            repeatMode = "none"
        }
    }

    function cleanupCache() {
        Terminalaccess.removeFilesWithExtensions(tempCacheDir, ["mp3", "aac", "ogg", "wav", "flac", "m4a", "alac"])
    }

    function sanitizeName(filename) {
        var dotIdx = filename.lastIndexOf(".")
        var name = dotIdx > 0 ? filename.substring(0, dotIdx) : filename
        var ext = dotIdx > 0 ? filename.substring(dotIdx) : ""
        return name.replace(/[^a-zA-Z0-9]/g, "_") + ext
    }

    function copyToCache(sourcePath, index) {
        var filename = sourcePath.split("/").pop()
        var cachedName = index + "_" + sanitizeName(filename)
        var destPath = tempCacheDir + cachedName
        Terminalaccess.copyFile(sourcePath, destPath)
        return destPath
    }

    function deleteFromCache(filePath) {
        if (filePath.indexOf(tempCacheDir) === 0) {
            Terminalaccess.removeFile(filePath)
        }
    }


    MouseArea {
        id: swipeArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: units.gu(2)
        property real startY: 0
        onPressed: {
            startY = mouseY
        }
        onReleased: {
            if (startY - mouseY > units.gu(3)) {
                musicPlayer.stop()
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: units.gu(1)

        RowLayout {
            width: parent.width
            spacing: units.gu(1)
            visible: currentSongName.length > 0
            height: units.gu(5)
            Label {
                Layout.fillWidth: true
                text: currentSongName
                color: "#FFFFFF"
                elide: Text.ElideRight
                fontSize: "small"
            }

        }

        RowLayout {
            width: parent.width
            spacing: units.gu(1)

            // Shuffle button
            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(4)
                height: units.gu(4)
                onClicked: toggleShuffle()

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(2)
                    width: units.gu(2)
                    name: "media-playlist-shuffle"
                    color: shuffleMode ? "#E95420" : "#FFFFFF"
                    opacity: shuffleMode ? 1 : 0.4
                }
            }

            // Previous button
            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(5)
                height: units.gu(4)
                enabled: currentIndex > 0
                onClicked: previous()

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(2.5)
                    width: units.gu(2.5)
                    name: "media-skip-backward"
                    color: parent.enabled ? "#FFFFFF" : "#666666"
                }
            }

            // Play/Pause button
            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(6)
                height: units.gu(5)
                onClicked: {
                    if (isPlaying) {
                        pause()
                    } else {
                        resume()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("(%1)").arg(playlist.length)
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                    fontSize: "small"
                }

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(3)
                    width: units.gu(3)
                    name: isPlaying ? "media-playback-pause" : "media-playback-start"
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(6)
                height: units.gu(5)
                onClicked: {
                    if (isPlaying || playlist.length === 0) {
                        stop()
                    } else {
                        clear()
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(3)
                    width: units.gu(3)
                    name: isPlaying || playlist.length === 0 ? "media-playback-stop" : "edit-delete"
                    color: "#FFFFFF"
                }
            }

            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(5)
                height: units.gu(4)
                enabled: currentIndex < playlist.length - 1
                onClicked: next()

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(2.5)
                    width: units.gu(2.5)
                    name: "media-skip-forward"
                    color: parent.enabled ? "#FFFFFF" : "#666666"
                }
            }

            // Repeat button
            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(4)
                height: units.gu(4)
                onClicked: toggleRepeat()

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(2)
                    width: units.gu(2)
                    name: repeatMode === "single" ? "media-playlist-repeat-one" : "media-playlist-repeat"
                    color: repeatMode !== "none" ? "#E95420" : "#FFFFFF"
                    opacity: repeatMode !== "none" ? 1 : 0.4
                }
            }

            MouseArea {
                Layout.fillWidth: false
                Layout.preferredWidth: units.gu(4)
                height: units.gu(4)
                onClicked: {
                    if (showingPlaylists) hidePlaylists()
                    else showPlaylists()
                }

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(2)
                    width: units.gu(2)
                    name: showingPlaylists ? "go-previous" : "media-playlist"
                    color: "#FFFFFF"
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: units.gu(1)

            Label {
                text: formatTime(audioPlayer.position)
                color: "#FFFFFF"
                fontSize: "small"
            }

            Slider {
                id: progressSlider
                Layout.fillWidth: true
                minimumValue: 0
                maximumValue: audioPlayer.duration
                value: audioPlayer.position
                onPressedChanged: {
                    if (!pressed) {
                        audioPlayer.seek(value)
                    }
                }
            }

            Label {
                text: formatTime(audioPlayer.duration)
                color: "#FFFFFF"
                fontSize: "small"
            }
        }
    }

    // Progress bar at the very bottom
    Rectangle {
        id: progressBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: units.gu(0.25)
        color: "#333333"

        Rectangle {
            id: progressBarFill
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: parent.height
            width: audioPlayer.duration > 0 ? (audioPlayer.position / audioPlayer.duration) * parent.width : 0
            color: "#E95420"
        }
    }
}
