/*
 * PlaylistsView.qml - View and manage saved playlists
 *
 * Shows list of playlists with options to play, view tracks, or delete.
 */

import QtQuick 2.4
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import Lomiri.Content 1.3

Item {
    id: playlistsView

    property var playlists: []
    property var currentPlaylistTracks: []
    property string currentPlaylistName: ""
    property bool showingTracks: false

    // Components
    PlaylistManager { id: playlistManager }

    // Content Hub peer for sending music to Lomiri Music App
    ContentPeer {
        id: musicPeer
        contentType: ContentType.Music
        handler: ContentHandler.Source
        selectionType: ContentTransfer.Multiple
    }

    // Content item component for creating items
    Component {
        id: contentItemComponent
        ContentItem {}
    }

    Component.onCompleted: {
        refreshPlaylists()
    }

    function refreshPlaylists() {
        playlists = playlistManager.loadPlaylists()
    }

    function playPlaylist(name) {
        var tracks = playlistManager.loadPlaylist(name)
        if (tracks.length === 0) return

        var paths = []
        for (var i = 0; i < tracks.length; i++) {
            paths.push(tracks[i].path)
        }

        // Send to Music app
        var transfer = musicPeer.request()
        transfer.stateChanged.connect(function() {
            if (transfer.state === ContentTransfer.InProgress) {
                var items = []
                for (var i = 0; i < paths.length; i++) {
                    var path = paths[i]
                    if (!path.startsWith("file://")) {
                        path = "file://" + path
                    }
                    var contentItem = contentItemComponent.createObject(playlistsView, {url: path})
                    items.push(contentItem)
                }
                transfer.items = items
                transfer.state = ContentTransfer.Charged
                if (DEBUG_MODE) console.log("PlaylistsView: Sent", paths.length, "files to Music app")
            }
        })
    }

    function viewPlaylist(name) {
        currentPlaylistName = name
        currentPlaylistTracks = playlistManager.loadPlaylist(name)
        showingTracks = true
    }

    function deletePlaylist(name) {
        PopupUtils.open(deleteConfirmDialog, null, {playlistName: name})
    }

    function removeTrackFromPlaylist(playlistName, trackIndex) {
        // This would require adding a function to PlaylistManager
        // For now, we'll just refresh
        refreshPlaylists()
        if (showingTracks && currentPlaylistName === playlistName) {
            currentPlaylistTracks = playlistManager.loadPlaylist(playlistName)
        }
    }

    // Delete confirmation dialog
    Component {
        id: deleteConfirmDialog
        Dialog {
            id: deleteDialog
            property string playlistName
            title: i18n.tr("Delete Playlist")
            text: i18n.tr("Are you sure you want to delete '%1'?").arg(playlistName)
            Row {
                width: parent.width
                spacing: units.gu(1)
                Button {
                    text: i18n.tr("Delete")
                    width: parent.width / 2
                    background: Rectangle { color: "#CC0000"; radius: units.gu(1) }
                    onClicked: {
                        playlistManager.deletePlaylist(deleteDialog.playlistName)
                        refreshPlaylists()
                        showingTracks = false
                        PopupUtils.close(deleteDialog)
                    }
                }
                Button {
                    text: i18n.tr("Cancel")
                    width: parent.width / 2
                    onClicked: PopupUtils.close(deleteDialog)
                }
            }
        }
    }

    // Header
    Rectangle {
        id: header
        height: units.gu(5)
        width: parent.width
        color: "transparent"

        Rectangle {
            color: launchermodular.settings.backgroundColor
            radius: units.gu(1)
            opacity: 0.3
            anchors.fill: parent
        }

        // Back button (when viewing tracks)
        Icon {
            id: backIcon
            visible: showingTracks
            anchors {
                left: parent.left
                leftMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }
            height: units.gu(3)
            width: units.gu(3)
            name: "go-previous"
            color: launchermodular.settings.textColor

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    showingTracks = false
                    currentPlaylistTracks = []
                    currentPlaylistName = ""
                }
            }
        }

        // Title
        Text {
            anchors.centerIn: parent
            text: showingTracks ? currentPlaylistName : i18n.tr("Playlists")
            color: launchermodular.settings.textColor
            font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
            font.bold: true
        }

        // Refresh button
        Icon {
            anchors {
                right: parent.right
                rightMargin: units.gu(1)
                verticalCenter: parent.verticalCenter
            }
            height: units.gu(3)
            width: units.gu(3)
            name: "view-refresh"
            color: launchermodular.settings.textColor

            MouseArea {
                anchors.fill: parent
                onClicked: refreshPlaylists()
            }
        }
    }

    // Content
    ListView {
        id: playlistListView
        anchors {
            fill: parent
            topMargin: header.height + units.gu(1)
            leftMargin: units.gu(2)
            rightMargin: units.gu(2)
        }
        clip: true

        model: showingTracks ? currentPlaylistTracks : playlists

        delegate: Item {
            width: playlistListView.width
            height: units.gu(7)

            Rectangle {
                anchors.fill: parent
                color: "#111111"
                opacity: 0.9
                radius: units.gu(0.5)

                Row {
                    anchors.fill: parent
                    anchors.margins: units.gu(1)
                    spacing: units.gu(1)

                    // Icon
                    Icon {
                        height: units.gu(3)
                        width: units.gu(3)
                        anchors.verticalCenter: parent.verticalCenter
                        name: showingTracks ? "stock_music" : "media-playlist"
                        color: launchermodular.settings.musicFontColor
                    }

                    // Info
                    Column {
                        width: parent.width - units.gu(8)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: showingTracks ? modelData.name : modelData
                            color: launchermodular.settings.textColor
                            font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: showingTracks ? "" : i18n.tr("%1 tracks").arg(playlistManager.getPlaylistCount(modelData))
                            color: "#aaaaaa"
                            font.pixelSize: units.gu(launchermodular.settings.musicFontSize - 0.5)
                            visible: !showingTracks
                        }
                    }

                    // Action buttons
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.5)

                        // Play button
                        Icon {
                            height: units.gu(2.5)
                            width: units.gu(2.5)
                            name: "media-playback-start"
                            color: "#0E8420"

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (showingTracks) {
                                        // Play all tracks in current playlist
                                        var paths = []
                                        for (var i = 0; i < currentPlaylistTracks.length; i++) {
                                            paths.push(currentPlaylistTracks[i].path)
                                        }
                                        var transfer = musicPeer.request()
                                        transfer.stateChanged.connect(function() {
                                            if (transfer.state === ContentTransfer.InProgress) {
                                                var items = []
                                                for (var j = 0; j < paths.length; j++) {
                                                    var path = paths[j]
                                                    if (!path.startsWith("file://")) {
                                                        path = "file://" + path
                                                    }
                                                    var contentItem = contentItemComponent.createObject(playlistsView, {url: path})
                                                    items.push(contentItem)
                                                }
                                                transfer.items = items
                                                transfer.state = ContentTransfer.Charged
                                            }
                                        })
                                    } else {
                                        playPlaylist(modelData)
                                    }
                                }
                            }
                        }

                        // Delete button (only in playlist list view)
                        Icon {
                            height: units.gu(2.5)
                            width: units.gu(2.5)
                            name: "delete"
                            color: "#CC0000"
                            visible: !showingTracks

                            MouseArea {
                                anchors.fill: parent
                                onClicked: deletePlaylist(modelData)
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!showingTracks) {
                            viewPlaylist(modelData)
                        }
                    }
                    propagateComposedEvents: true
                }
            }
        }

        // Empty state
        Text {
            anchors.centerIn: parent
            text: i18n.tr("No playlists yet.\nSelect songs and tap Save to create a playlist.")
            color: "#aaaaaa"
            font.pixelSize: units.gu(launchermodular.settings.musicFontSize)
            visible: playlistListView.count === 0 && !showingTracks
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
