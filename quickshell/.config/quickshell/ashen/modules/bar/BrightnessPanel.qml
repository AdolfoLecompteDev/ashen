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
        width: 300
        height: 78
        x: Math.max(12, Math.min(parent.width - width - 12, Services.AppState.brightnessPillCenterX - width / 2))
        radius: 16
        color: Services.Colors.surfaceAlpha(0.95)
        border.width: 0

        opacity: Services.AppState.brightnessVisible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate {
            x: Services.AppState.brightnessVisible ? 0 : -24
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header: icon + label + value
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 18
                        color: Services.Colors.ghost
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Brightness"
                        color: Services.Colors.mist
                        font.pixelSize: 12
                        font.family: "JetBrainsMono NF"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Brightness.level + "%"
                    color: Services.Colors.snow
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "JetBrainsMono NF"
                }
            }

            // Slider
            Rectangle {
                id: track
                width: parent.width
                height: 10
                radius: 5
                color: Services.Colors.ghostAlpha(0.15)

                // -1 = follow the service value; otherwise the ratio being dragged
                property real dragRatio: -1
                readonly property real uiRatio: dragRatio >= 0 ? dragRatio : Services.Brightness.level / 100

                Rectangle {
                    id: fill
                    anchors.left: parent.left
                    height: parent.height
                    radius: 5
                    color: Services.Colors.ghost
                    width: track.width * track.uiRatio
                    // animate only when following the service, never while dragging
                    Behavior on width { enabled: track.dragRatio < 0; NumberAnimation { duration: 120 } }
                }

                Rectangle {
                    id: knob
                    width: 18; height: 18; radius: 9
                    color: Services.Colors.snow
                    border.color: Services.Colors.ghostAlpha(0.45)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(track.width - width, fill.width - width / 2))
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
                        win.setBrightness(r)
                    }
                    onPressed: mouse => apply(mouse.x)
                    onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
                    onReleased: track.dragRatio = -1
                    onCanceled: track.dragRatio = -1
                }
            }
        }
    }
}
