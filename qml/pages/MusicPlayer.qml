import QtQuick 2.12
import QtQuick.Layouts 1.12
import Lomiri.Components 1.3
import QtMultimedia 5.12
import Terminalaccess 1.0
import MySettings 1.0

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
    property string currentSongPath: ""
    property bool shuffleMode: false
    property string repeatMode: "none" // "none", "single", "all"
    property string tempCacheDir: MySettings.getHomeLocation() + "/.cache/launchermodular.lut11/"
    property string currentCacheFile: ""
    property int copyIndex: 0
    property bool copyInProgress: false
    property int nextTrackIndex: -1

    Component.onCompleted: {
        Terminalaccess.run("mkdir -p " + tempCacheDir)
        cleanupCache()
    }

    signal songChanged(string name, int index)
    signal playingChanged(bool playing)
    signal dismissed()

    Audio {
        id: audioPlayer

        onPlaybackStateChanged: {
            isPlaying = (playbackState === Audio.PlayingState)
            playingChanged(isPlaying)
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
                    if (nextTrackIndex >= 0 && !copyInProgress) {
                        onCopyFinished(currentCacheFile)
                    } else if (nextTrackIndex === -1) {
                        stop()
                    }
                } else if (repeatMode === "all") {
                    if (nextTrackIndex >= 0 && !copyInProgress) {
                        onCopyFinished(currentCacheFile)
                    } else if (nextTrackIndex === -1) {
                        currentIndex = 0
                        if (playlist.length > 0) {
                            playList(playlist)
                        }
                    }
                }
            }
        }

        onError: {
            console.log("Audio error:", errorString)
        }
    }

    Timer {
        id: copyTimer
        interval: 200
        repeat: true
        property string targetFile: ""
        property bool isNextTrackCopy: false

        onTriggered: {
            if (!copyInProgress) {
                copyTimer.stop()
                return
            }
            var finished = Terminalaccess.waitForFinished(0)
            if (finished) {
                copyInProgress = false
                copyTimer.stop()
                if (isNextTrackCopy && targetFile !== "") {
                    onCopyFinished(targetFile)
                }
            }
        }
    }

    function formatTime(ms) {
        var totalSeconds = Math.floor(ms / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function play(songPath) {
        deleteFromCache(currentCacheFile)
        var cachedPath = copyToCache(songPath, 0)
        copyIndex = 1
        currentCacheFile = cachedPath
        audioPlayer.source = cachedPath
        audioPlayer.play()
        currentSongPath = songPath
        visible = true
    }

    function playList(songs) {
        playlist = songs
        deleteFromCache(currentCacheFile)
        copyIndex = 0
        nextTrackIndex = -1
        copyInProgress = false
        copyTimer.stop()

        if (songs.length === 0) return

        var firstPath = songs[0].path
        var cachedPath = copyToCache(firstPath, copyIndex)
        copyIndex++
        currentCacheFile = cachedPath

        audioPlayer.source = cachedPath
        audioPlayer.play()

        currentIndex = 0
        currentSongName = songs[0].name
        currentSongPath = firstPath
        songChanged(currentSongName, currentIndex)
        visible = true

        if (songs.length > 1) {
            nextTrackIndex = 1
            var nextPath = songs[1].path
            var nextCachedPath = copyToCache(nextPath, copyIndex)
            copyIndex++
            copyInProgress = true
            copyTimer.targetFile = nextCachedPath
            copyTimer.isNextTrackCopy = true
            copyTimer.start()
        }
    }

    function pause() {
        audioPlayer.pause()
    }

    function resume() {
        audioPlayer.play()
    }

    function stop() {
        audioPlayer.stop()
        audioPlayer.source = ""
        deleteFromCache(currentCacheFile)
        isPlaying = false
        visible = false
        currentIndex = -1
        currentSongName = ""
        currentSongPath = ""
        currentCacheFile = ""
        nextTrackIndex = -1
        copyInProgress = false
        copyTimer.stop()
        playingChanged(false)
    }

    function next() {
        if (currentIndex < playlist.length - 1) {
            var nextIdx = currentIndex + 1
            var nextPath = playlist[nextIdx].path
            deleteFromCache(currentCacheFile)
            var cachedPath = copyToCache(nextPath, copyIndex)
            copyIndex++
            currentCacheFile = cachedPath
            audioPlayer.source = cachedPath
            audioPlayer.play()
            currentIndex = nextIdx
            currentSongName = playlist[nextIdx].name
            currentSongPath = nextPath
            songChanged(currentSongName, currentIndex)
        }
    }

    function previous() {
        if (currentIndex > 0) {
            var prevIdx = currentIndex - 1
            var prevPath = playlist[prevIdx].path
            deleteFromCache(currentCacheFile)
            var cachedPath = copyToCache(prevPath, copyIndex)
            copyIndex++
            currentCacheFile = cachedPath
            audioPlayer.source = cachedPath
            audioPlayer.play()
            currentIndex = prevIdx
            currentSongName = playlist[prevIdx].name
            currentSongPath = prevPath
            songChanged(currentSongName, currentIndex)
        }
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

    function onCopyFinished(filePath) {
        if (nextTrackIndex >= 0 && nextTrackIndex < playlist.length) {
            deleteFromCache(currentCacheFile)
            currentCacheFile = filePath

            audioPlayer.source = filePath
            audioPlayer.play()

            currentIndex = nextTrackIndex
            currentSongName = playlist[nextTrackIndex].name
            currentSongPath = playlist[nextTrackIndex].path
            songChanged(currentSongName, nextTrackIndex)

            var nextIdx = nextTrackIndex + 1
            if (nextIdx < playlist.length) {
                nextTrackIndex = nextIdx
                var nextPath = playlist[nextIdx].path
                var cachedPath = copyToCache(nextPath, copyIndex)
                copyIndex++
                copyInProgress = true
                copyTimer.targetFile = cachedPath
                copyTimer.isNextTrackCopy = true
                copyTimer.start()
            } else {
                nextTrackIndex = -1
            }
        }
    }

    function cleanupCache() {
        Terminalaccess.run("rm -f " + tempCacheDir + "*.mp3 " + tempCacheDir + "*.aac " + tempCacheDir + "*.ogg " + tempCacheDir + "*.wav " + tempCacheDir + "*.flac " + tempCacheDir + "*.m4a " + tempCacheDir + "*.alac")
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
        var sourceClean = sourcePath.replace(/'/g, "'\\''")
        var destClean = destPath.replace(/'/g, "'\\''")
        Terminalaccess.run("cp '" + sourceClean + "' '" + destClean + "'")
        Terminalaccess.outputUntilEnd()
        return destPath
    }

    function deleteFromCache(filePath) {
        if (filePath.indexOf(tempCacheDir) === 0) {
            var cleanPath = filePath.replace(/'/g, "'\\''")
            Terminalaccess.run("rm -f '" + cleanPath + "'")
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
                musicPlayer.dismissed()
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: units.gu(1)

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

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(3)
                    width: units.gu(3)
                    name: isPlaying ? "media-playback-pause" : "media-playback-start"
                    color: "#FFFFFF"
                }
            }

            // Next button
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
                onValueChanged: {
                    audioPlayer.seek(value)
                }
            }

            Label {
                text: formatTime(audioPlayer.duration)
                color: "#FFFFFF"
                fontSize: "small"
            }
        }

        RowLayout {
            width: parent.width
            spacing: units.gu(1)

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
                height: units.gu(3)
                text: "✕"
                onClicked: musicPlayer.stop()
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
