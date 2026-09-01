import QtQuick 2.4
import Ubuntu.Components 1.3
import QtQuick.Controls 2.2

Item {
    id: playlistsView

    property var playlistManager
    property var musicPlayer

    signal playlistLoaded()

    function createPlaylist(name) {
        if (!name || name.length === 0) return
        if (!musicPlayer || musicPlayer.playlist.length === 0) return

        playlistManager.savePlaylist(name, musicPlayer.playlist)
    }

    ListView {
        id: playlists
        anchors.fill: parent

        header: Rectangle {
            id: newPlaylistHeader
            height: units.gu(5)
            width: parent.width
            color: "transparent"

            anchors {
                left: parent.left
                right: parent.right
            }

            Rectangle {
                id: colorHeader
                color: launchermodular.settings.backgroundColor
                radius: units.gu(1)
                opacity: 0.3
                anchors.fill: parent
            }

            Icon {
                id: iconNote
                anchors {
                    left: newPlaylistHeader.left
                    rightMargin: units.gu(1)
                    leftMargin: units.gu(1)
                }
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height * 0.5
                width: height
                name: "save"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        createPlaylist(playlistField.text)
                        playlistField.text = ""
                        playlistField.focus = false
                    }
                }
            }

            TextField {
                id: playlistField
                focus: false
                anchors {
                    left: iconNote.right
                    right: parent.right
                }
                height: newPlaylistHeader.height
                color: launchermodular.settings.textColor
                background: Rectangle {
                    height: parent.height
                    color: "transparent"
                }
                placeholderText: ""
                // Custom placeholder
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: units.gu(2)
                    verticalAlignment: Text.AlignVCenter
                    color: "#aaaaaa" // Light grey color for placeholder
                    text: i18n.tr("New playlist")
                    visible: playlistField.text.length == 0
                    font.pixelSize: units.gu(1.5)
                }
                inputMethodHints: Qt.ImhNoPredictiveText
                Keys.onReturnPressed: {
                    createPlaylist(playlistField.text)
                    playlistField.text = ""
                    playlistField.focus = false
                }
                maximumLength: 25
            }
        }

        model: playlistManager ? playlistManager.itemModel : null

        delegate: ListItem {
            height: layout.height + (divider.visible ? divider.height : 0)
            divider.visible: false

            ListItemLayout {
                id: layout
                title.text: name
                title.color: launchermodular.settings.textColor
                title.textSize: Label.Large
                subtitle.text: playlistManager ? i18n.tr("%1 tracks").arg(playlistManager.getPlaylistCount(name)) : ""

                Icon {
                    anchors.centerIn: parent
                    height: units.gu(3)
                    width: units.gu(3)
                    name: "media-playlist"
                    color: "#FFFFFF"
                }
            }

            leadingActions: ListItemActions {
                actions: [
                    Action {
                        id: actionDelete
                        text: i18n.tr("Delete")
                        iconName: "edit-delete"
                        onTriggered: {
                            playlistManager.deletePlaylist(model.name)
                        }
                    }
                ]
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var tracks = playlistManager.loadPlaylist(model.name)
                    musicPlayer.playList(tracks)
                    playlistLoaded()
                    musicPlayer.hidePlaylists()
                }
            }
        }
    }
}
