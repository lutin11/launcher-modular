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
    property int repeatMode: MusicPlayer.None // valeurs: MusicPlayer.None / Single / All
    property string tempCacheDir: MySettings.getHomeLocation() + "/.cache/launchermodular.lut11/"
    property string currentCacheFile: ""
    property int copyIndex: 0
    property bool showingPlaylists: false
    property var playHistory: []
    property int historyPosition: -1
    property var shuffleRemaining: []

    Component.onCompleted: {
        Terminalaccess.makePath(tempCacheDir)
        cleanupCache()
    }

    enum RepeatMode { None, Single, All }
    enum PlaybackState { Stopped, Playing, Paused, Cleared }

    signal stateChanged(int newState)
    signal showPlaylists()
    signal hidePlaylists()

    Audio {
        id: audioPlayer
        audioRole: "MusicRole"

        onPlaying: {
            isPlaying = true
            stateChanged(MusicPlayer.Playing)
            durationRefreshTimer.attempts = 0
            durationRefreshTimer.interval = 48
            durationRefreshTimer.restart()
        }

        onStopped: {
            isPlaying = false
            stateChanged(MusicPlayer.Stopped)
        }

        onPaused: {
            isPlaying = false
            stateChanged(MusicPlayer.Paused)
        }

        onPositionChanged: {
            if (!progressSlider.pressed && !progressSlider.seeking) {
                progressSlider.value = position
            }
        }

        onDurationChanged: {
            console.log("onDurationChanged:" + duration)
            if (duration > 0) {
                progressSlider.maximumValue = duration
            }
        }

        onStatusChanged: {
            if (status === Audio.EndOfMedia) {
                if (repeatMode === MusicPlayer.Single) {
                    audioPlayer.seek(0)
                    audioPlayer.play()
                } else {
                    advanceTrack()
                }
            } else if (status === Audio.Loaded || status === Audio.Buffered) {
                if (duration > 0) {
                    progressSlider.maximumValue = duration
                }
            }
        }

        onError: {
            console.log("Audio error:", errorString)
        }
    }

    // FIXME: Workaround for pad.lv/1494031 by querying gst as it does not
    // from lomiri-music-app
    // emit until it changes to the PLAYING state. But by asking for a
    // value we get gst to perform a query and return a result
    // However this has to be done once the source is set, hence the delay
    //
    // NOTE: This does not solve when the currentIndex is removed though
    Timer {
        id: durationRefreshTimer
        interval: 48
        repeat: false
        property int attempts: 0
        onTriggered: {
            if (audioPlayer.duration > 0) {
                progressSlider.maximumValue = audioPlayer.duration
            } else if (attempts < 5) {
                attempts++
                interval = interval * 2 // 48, 96, 192, 384, 768 ms
                restart()
            }
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
        if (shuffleMode) {
            var idx = nextShuffleIndex()
            if (idx < 0) {
                stop()
            } else {
                loadTrack(idx, true)
            }
        } else if (currentIndex < playlist.length - 1) {
            next()
        } else if (repeatMode === MusicPlayer.All) {
            loadTrack(0, true)
        } else {
            stop()
        }
    }

    function nextShuffleIndex() {
        if (historyPosition < playHistory.length - 1) {
            return playHistory[historyPosition + 1]
        }
        return drawRandomShuffleIndex()
    }

    function resetShuffleCycle(excludeIndex) {
        var remaining = []
        for (var i = 0; i < playlist.length; i++) {
            if (i !== excludeIndex) remaining.push(i)
        }
        shuffleRemaining = remaining // réassignation -> déclenche shuffleRemainingChanged
    }

    function drawRandomShuffleIndex() {
        if (shuffleRemaining.length === 0) {
            if (repeatMode === MusicPlayer.All) {
                // Tout le cycle a été joué : nouveau cycle, en excluant la piste
                // courante pour ne pas la relire consécutivement.
                resetShuffleCycle(currentIndex)
            } else {
                return -1
            }
        }
        if (shuffleRemaining.length === 0) return -1 // playlist à une seule piste

        var randPos = Math.floor(Math.random() * shuffleRemaining.length)
        var chosen = shuffleRemaining[randPos]
        var remaining = shuffleRemaining.slice()
        remaining.splice(randPos, 1)
        shuffleRemaining = remaining // réassignation -> déclenche shuffleRemainingChanged
        return chosen
    }

    function recordHistory(index) {
        if (!shuffleMode) return

        if (historyPosition >= 0 && historyPosition < playHistory.length && playHistory[historyPosition] === index) {
            return // déjà la piste courante
        }
        if (historyPosition < playHistory.length - 1 && playHistory[historyPosition + 1] === index) {
            historyPosition++
            return
        }

        var isFreshStart = playHistory.length === 0
        var newHistory = playHistory.slice(0, historyPosition + 1)
        newHistory.push(index)
        playHistory = newHistory // réassignation -> déclenche playHistoryChanged
        historyPosition = playHistory.length - 1

        if (isFreshStart) {
            resetShuffleCycle(index)
        } else {
            var pos = shuffleRemaining.indexOf(index)
            if (pos !== -1) {
                var remaining = shuffleRemaining.slice()
                remaining.splice(pos, 1)
                shuffleRemaining = remaining // réassignation -> déclenche shuffleRemainingChanged
            }
        }
    }

    function addToPlaylist(filePath, fileName) {
        var newPlaylist = playlist.slice()
        newPlaylist.push({path: filePath, name: fileName})
        playlist = newPlaylist // réassignation -> déclenche playlistChanged

        if (currentIndex === -1) {
            playList(playlist)
            return
        }

        if (shuffleMode) {
            var remaining = shuffleRemaining.slice()
            remaining.push(newPlaylist.length - 1) // append : les index existants ne bougent pas
            shuffleRemaining = remaining
        }
    }

    function removeFromPlaylist(filePath, fileName) {
        var idx = -1
        for (var i = 0; i < playlist.length; i++) {
            if (playlist[i].path === filePath) {
                idx = i
                break
            }
        }
        if (idx === -1) return

        var newPlaylist = playlist.slice()
        newPlaylist.splice(idx, 1)

        if (newPlaylist.length === 0) {
            playlist = newPlaylist
            resetPlayback()
            return
        }

        var removingCurrent = (idx === currentIndex)
        var wasPlaying = isPlaying

        // La suppression décale tous les index suivants de -1.
        var newCurrentIndex = (idx < currentIndex) ? currentIndex - 1 : currentIndex

        playlist = newPlaylist

        if (removingCurrent) {
            var nextIdx = Math.min(idx, newPlaylist.length - 1)
            loadTrack(nextIdx, wasPlaying)
        } else {
            currentIndex = newCurrentIndex
        }

        if (shuffleMode) {
            playHistory = currentIndex >= 0 ? [currentIndex] : []
            historyPosition = playHistory.length - 1
            if (currentIndex >= 0) resetShuffleCycle(currentIndex)
        }
    }

    function loadTrack(index, autoPlay) {
        if (index < 0 || index >= playlist.length) return

        if (index === currentIndex && currentCacheFile !== "") {
            if (autoPlay) audioPlayer.play()
            return
        }

        recordHistory(index)

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
        playHistory = []
        historyPosition = -1
        shuffleRemaining = []
        durationRefreshTimer.stop()
        progressSlider.value = 0
        progressSlider.maximumValue = 0
    }

    function playList(songs) {
        playlist = songs
        resetPlayback()
        if (songs.length === 0) return
        var startIndex = shuffleMode ? Math.floor(Math.random() * songs.length) : 0
        loadTrack(startIndex, false)
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
        if (shuffleMode) {
            var idx = nextShuffleIndex()
            if (idx < 0) return
            loadTrack(idx, true)
        } else if (currentIndex < playlist.length - 1) {
            loadTrack(currentIndex + 1, true)
        }
    }

    function previous() {
        if (shuffleMode) {
            if (historyPosition > 0) {
                historyPosition--
                loadTrack(playHistory[historyPosition], true)
            }
        } else if (currentIndex > 0) {
            loadTrack(currentIndex - 1, true)
        }
    }

    function startPlayback() {
        if (playlist.length === 0) return
        playList(playlist)
        resume()
    }

    function toggleShuffle() {
        shuffleMode = !shuffleMode
        if (shuffleMode) {
            // Start a new cycle from where it is
            playHistory = currentIndex >= 0 ? [currentIndex] : []
            historyPosition = playHistory.length - 1
            if (currentIndex >= 0) resetShuffleCycle(currentIndex)
        } else {
            playHistory = []
            historyPosition = -1
            shuffleRemaining = []
        }
    }

    function toggleRepeat() {
        if (repeatMode === MusicPlayer.None) {
            repeatMode = MusicPlayer.Single
        } else if (repeatMode === MusicPlayer.Single) {
            repeatMode = MusicPlayer.All
        } else {
            repeatMode = MusicPlayer.None
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
                enabled: shuffleMode ? historyPosition > 0 : currentIndex > 0
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
                    } else if (currentIndex === -1) {
                        startPlayback()
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
                enabled: shuffleMode ? (historyPosition < playHistory.length - 1 || shuffleRemaining.length > 0 || repeatMode === MusicPlayer.All) : currentIndex < playlist.length - 1
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
                    name: repeatMode === MusicPlayer.Single ? "media-playlist-repeat-one" : "media-playlist-repeat"
                    color: repeatMode !== MusicPlayer.None ? "#E95420" : "#FFFFFF"
                    opacity: repeatMode !== MusicPlayer.None? 1 : 0.4
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
                enabled: audioPlayer.duration > 0
                minimumValue: 0
                maximumValue: audioPlayer.duration
                value: audioPlayer.position
                // Empêche onPositionChanged d'écraser la valeur qu'on vient de cliquer
                // avec un signal transitoire encore basé sur l'ancienne position.
                property bool seeking: false

                onPressedChanged: {
                    if (!pressed) {
                        seeking = true
                        audioPlayer.seek(value)
                        seekGuardTimer.restart()
                    }
                }

                Timer {
                    id: seekGuardTimer
                    interval: 500
                    onTriggered: progressSlider.seeking = false
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
