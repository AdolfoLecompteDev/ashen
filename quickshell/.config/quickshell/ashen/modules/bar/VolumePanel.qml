import Quickshell
import Quickshell.Io
import QtQuick
import "root:/services" as Services

PanelWindow {
    id: win
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // stays mapped through the close animation, so the exit plays in reverse
    readonly property bool shown: Services.AppState.volumeVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    function setVolume(ratio) {
        ratio = Math.max(0, Math.min(1, ratio))
        let pct = Math.round(ratio * 100)
        Quickshell.execDetached(["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 && wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + pct + "%"])
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.volumeVisible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 64
        width: 300
        height: 152
        x: Math.max(12, Math.min(parent.width - width - 12, Services.AppState.volumePillCenterX - width / 2))
        radius: 16
        color: Services.Colors.surfaceAlpha(0.95)
        border.width: 0

        opacity: Services.AppState.volumeVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            x: Services.AppState.volumeVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Speaker ────────────────────────────
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Services.Audio.icon(Services.Audio.volume, Services.Audio.muted, Services.Audio.headphones)
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Services.Colors.ghost
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Volume"
                        color: Services.Colors.mist
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Audio.muted ? "Muted" : Services.Audio.volume + "%"
                    color: Services.Colors.snow
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            Rectangle {
                id: track
                width: parent.width
                height: 10
                radius: 5
                color: Services.Colors.ghostAlpha(0.15)

                property real dragRatio: -1
                readonly property real uiRatio: dragRatio >= 0 ? dragRatio : Services.Audio.volume / 100

                Rectangle {
                    id: volFill
                    anchors.left: parent.left
                    height: parent.height
                    radius: 5
                    color: Services.Colors.ghost
                    width: track.width * track.uiRatio
                    Behavior on width { enabled: track.dragRatio < 0; NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    id: volKnob
                    width: 18; height: 18; radius: 9
                    color: Services.Colors.snow
                    border.color: Services.Colors.ghostAlpha(0.45)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(track.width - width, volFill.width - width / 2))
                    Behavior on x { enabled: track.dragRatio < 0; NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -14
                    anchors.bottomMargin: -14
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function apply(mx) {
                        let r = Math.max(0, Math.min(1, mx / track.width))
                        track.dragRatio = r
                        win.setVolume(r)
                    }
                    onPressed: mouse => apply(mouse.x)
                    onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
                    onReleased: track.dragRatio = -1
                    onCanceled: track.dragRatio = -1
                }
            }

            // ── Divider ────────────────────────────
            Rectangle {
                width: parent.width
                height: 1
                color: Services.Colors.ghostAlpha(0.12)
            }

            // ── Microphone ─────────────────────────
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        id: micBtn
                        width: 28; height: 28
                        radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        color: Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghostAlpha(0.2)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: Services.Audio.micMuted ? "" : ""
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 16
                            color: Services.Audio.micMuted ? Services.Colors.snow : Services.Colors.ghost
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: parent.color = Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghostAlpha(0.35)
                            onExited: parent.color = Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghostAlpha(0.2)
                            onClicked: Services.Audio.toggleMicMute()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Microphone"
                        color: Services.Colors.mist
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Audio.micMuted ? "Muted" : Services.Audio.micVolume + "%"
                    color: Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.snow
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            Rectangle {
                id: micTrack
                width: parent.width
                height: 10
                radius: 5
                color: Services.Colors.ghostAlpha(0.15)
                opacity: Services.Audio.micMuted ? 0.4 : 1.0

                property real dragRatio: -1
                readonly property real uiRatio: dragRatio >= 0 ? dragRatio : Services.Audio.micVolume / 100

                Rectangle {
                    id: micFill
                    anchors.left: parent.left
                    height: parent.height
                    radius: 5
                    color: Services.Audio.micMuted ? Services.Colors.error_ : Services.Colors.ghost
                    width: micTrack.width * micTrack.uiRatio
                    Behavior on width { enabled: micTrack.dragRatio < 0; NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    id: micKnob
                    width: 18; height: 18; radius: 9
                    color: Services.Colors.snow
                    border.color: Services.Colors.ghostAlpha(0.45)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(micTrack.width - width, micFill.width - width / 2))
                    Behavior on x { enabled: micTrack.dragRatio < 0; NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -14
                    anchors.bottomMargin: -14
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    function apply(mx) {
                        let r = Math.max(0, Math.min(1, mx / micTrack.width))
                        micTrack.dragRatio = r
                        Services.Audio.setMicVolume(Math.round(r * 100))
                    }
                    onPressed: mouse => apply(mouse.x)
                    onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
                    onReleased: micTrack.dragRatio = -1
                    onCanceled: micTrack.dragRatio = -1
                }
            }
        }
    }
}
