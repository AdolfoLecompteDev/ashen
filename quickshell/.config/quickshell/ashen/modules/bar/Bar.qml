import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

Scope {
    id: root
    property string currentTime: ""
    property string currentDate: ""
    property string wifiSsid: "..."
    property string btDevice: "..."
    property int volume: 0

    // Reloj
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = Qt.formatDateTime(new Date(), "hh:mm AP")
            root.currentDate = Qt.formatDateTime(new Date(), "ddd, MMM d")
        }
    }

    // Wifi
    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split("\n")
                for (let line of lines) {
                    if (line.startsWith("yes:")) {
                        root.wifiSsid = line.split(":")[1]
                        return
                    }
                }
                root.wifiSsid = "off"
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: wifiProc.running = true
    }

    // Bluetooth
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl devices Connected | head -1 | cut -d' ' -f3-"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let name = text.trim()
                root.btDevice = name.length > 0 ? name : "off"
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    // Volumen
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d\", $2*100}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.volume = parseInt(text.trim()) || 0
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: volProc.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 48
            color: "transparent"
            exclusionMode: ExclusionMode.Exclusive

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // ── Izquierda ──────────────────────────
                RowLayout {
                    spacing: 6

                    // Launcher
                    Rectangle {
                        width: 36; height: 36
                        radius: 10
                        color: "#1d1d24"
                        border.color: "#24242d"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰍉"
                            color: "#6272a4"
                            font.pixelSize: 16
                            font.family: "JetBrainsMono NF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    // Workspaces
                    Rectangle {
                        height: 36
                        radius: 10
                        color: "#1d1d24"
                        border.color: "#24242d"
                        border.width: 1
                        width: wsRow.implicitWidth + 12

                        RowLayout {
                            id: wsRow
                            anchors.centerIn: parent
                            spacing: 4

                            Repeater {
                                model: 5
                                delegate: Rectangle {
                                    required property int index
                                    property int wsId: {
                                        let focused = Hyprland.focusedWorkspace
                                        if (!focused) return index + 1
                                        let base = Math.floor((focused.id - 1) / 5) * 5
                                        return base + index + 1
                                    }
                                    property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                                    property bool hasWindows: Hyprland.workspaces.values.find(w => w.id === wsId) !== undefined

                                    width: 28; height: 28
                                    radius: 8
                                    color: isActive ? "#6272a4" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: wsId
                                        color: parent.isActive ? "#0f0f12" : parent.hasWindows ? "#d4d4e0" : "#404052"
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono NF"
                                        font.bold: parent.isActive
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("workspace " + wsId)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Centro ─────────────────────────────
                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 36
                    width: clockCol.implicitWidth + 24
                    radius: 10
                    color: "#1d1d24"
                    border.color: "#24242d"
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Column {
                        id: clockCol
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentTime
                            color: "#d4d4e0"
                            font.pixelSize: 13
                            font.family: "JetBrainsMono NF"
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.currentDate
                            color: "#7878a0"
                            font.pixelSize: 10
                            font.family: "JetBrainsMono NF"
                        }
                    }
                }

                // ── Derecha ────────────────────────────
                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 36
                    radius: 10
                    color: "#1d1d24"
                    border.color: "#24242d"
                    border.width: 1
                    width: sysRow.implicitWidth + 16

                    RowLayout {
                        id: sysRow
                        anchors.centerIn: parent
                        spacing: 10

                        // Notificaciones
                        Text {
                            text: "󰂚"
                            color: "#d4d4e0"
                            font.pixelSize: 15
                            font.family: "JetBrainsMono NF"
                        }

                        Rectangle { width: 1; height: 20; color: "#24242d" }

                        // Wifi
                        RowLayout {
                            spacing: 4
                            Text {
                                text: root.wifiSsid === "off" ? "󰤭" : "󰤨"
                                color: root.wifiSsid === "off" ? "#8a5a5a" : "#d4d4e0"
                                font.pixelSize: 15
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                text: root.wifiSsid
                                color: "#d4d4e0"
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }
                        }

                        // Bluetooth
                        RowLayout {
                            spacing: 4
                            Text {
                                text: root.btDevice === "off" ? "󰂲" : "󰂯"
                                color: root.btDevice === "off" ? "#8a5a5a" : "#6272a4"
                                font.pixelSize: 15
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                visible: root.btDevice !== "off"
                                text: root.btDevice
                                color: "#d4d4e0"
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }
                        }

                        // Volumen
                        RowLayout {
                            spacing: 4
                            Text {
                                text: root.volume === 0 ? "󰝟" : root.volume < 50 ? "󰕾" : "󰕾"
                                color: "#d4d4e0"
                                font.pixelSize: 15
                                font.family: "JetBrainsMono NF"
                            }
                            Text {
                                text: root.volume + "%"
                                color: "#d4d4e0"
                                font.pixelSize: 11
                                font.family: "JetBrainsMono NF"
                            }
                        }

                        Rectangle { width: 1; height: 20; color: "#24242d" }

                        // System Tray
                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                required property SystemTrayItem modelData
                                width: 20; height: 20

                                Image {
                                    anchors.centerIn: parent
                                    source: modelData.icon
                                    width: 16; height: 16
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton)
                                            modelData.activate()
                                        else
                                            modelData.provideContext(Qt.point(x, y))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
