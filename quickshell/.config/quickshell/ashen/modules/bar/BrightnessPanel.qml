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
    readonly property bool shown: Services.AppState.brightnessVisible
    visible: shown || closeDelay.running
    onShownChanged: if (!shown) closeDelay.restart()
    Timer { id: closeDelay; interval: 300 }

    function setBrightness(ratio) {
        ratio = Math.max(0.02, Math.min(1, ratio))
        let pct = Math.round(ratio * 100)
        Quickshell.execDetached(["sh", "-c", "brightnessctl set " + pct + "%"])
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Services.AppState.brightnessVisible = false
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: 64
        width: 190
        height: 56
        x: Math.max(12, Math.min(parent.width - width - 12, Services.AppState.brightnessPillCenterX - width / 2))
        radius: 14
        color: Services.Colors.surfaceAlpha(0.95)
        border.color: Services.Colors.ghostAlpha(0.2)
        border.width: 1

        opacity: Services.AppState.brightnessVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            x: Services.AppState.brightnessVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 18
                color: Services.Colors.ghost
            }

            Rectangle {
                id: track
                width: parent.width - 76
                height: 8
                anchors.verticalCenter: parent.verticalCenter
                radius: 4
                color: Services.Colors.ghostAlpha(0.15)

                Rectangle {
                    anchors.left: parent.left
                    height: parent.height
                    radius: 4
                    color: Services.Colors.ghost
                    width: parent.width * (Services.Brightness.level / 100)
                    Behavior on width { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => win.setBrightness(mouse.x / track.width)
                    onPositionChanged: mouse => { if (pressed) win.setBrightness(mouse.x / track.width) }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Brightness.level + "%"
                color: Services.Colors.snow
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }
        }
    }
}
