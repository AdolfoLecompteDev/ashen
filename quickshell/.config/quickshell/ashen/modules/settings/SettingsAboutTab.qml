import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

ColumnLayout {
    id: tab
    anchors.fill: parent
    anchors.margins: 28
    spacing: 10

    property string hostname: "..."
    property string kernel: "..."
    property string uptime: "..."

    Component.onCompleted: hostProc.running = true

    Process {
        id: hostProc
        command: ["sh", "-c", "echo \"$(hostnamectl hostname 2>/dev/null || hostname)|$(uname -r)|$(uptime -p)\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split("|")
                tab.hostname = parts[0] || ""
                tab.kernel = parts[1] || ""
                tab.uptime = parts[2] || ""
            }
        }
    }

    Text {
        text: "About"
        color: Services.Colors.snow
        font.pixelSize: 20
        font.bold: true
        font.family: "JetBrainsMono NF"
    }

    ColumnLayout {
        spacing: 6
        Text { text: "Hostname: " + tab.hostname; color: Services.Colors.mist; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
        Text { text: "Kernel: " + tab.kernel; color: Services.Colors.mist; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
        Text { text: "Uptime: " + tab.uptime; color: Services.Colors.mist; font.pixelSize: 13; font.family: "JetBrainsMono NF" }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Services.Colors.ghostAlpha(0.15); Layout.topMargin: 8; Layout.bottomMargin: 4 }

    ColumnLayout {
        spacing: 4
        Text {
            text: "ASHEN"
            color: Services.Colors.snow
            font.pixelSize: 26
            font.bold: true
            font.family: "JetBrainsMono NF"
            font.letterSpacing: 2
        }
        Text {
            text: "A monochrome Hyprland shell, built with Quickshell"
            color: Services.Colors.mist
            font.pixelSize: 12
            font.family: "JetBrainsMono NF"
        }
        Text {
            text: "by Adolfo Lecompte"
            color: Services.Colors.ash
            font.pixelSize: 11
            font.family: "JetBrainsMono NF"
            Layout.topMargin: 2
        }
    }

    Rectangle {
        Layout.topMargin: 12
        width: repoRow.implicitWidth + 24
        height: 40
        radius: 10
        color: Services.Colors.ghostAlpha(0.15)
        RowLayout {
            id: repoRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: Services.Colors.ghost
            }
            Text {
                text: "github.com/AdolfoLecompteDev/ashen"
                color: Services.Colors.snow
                font.pixelSize: 12
                font.family: "JetBrainsMono NF"
            }
            Text {
                text: ""
                font.family: "Material Symbols Rounded"
                font.pixelSize: 14
                color: Services.Colors.mist
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: parent.color = Services.Colors.ghostAlpha(0.25)
            onExited: parent.color = Services.Colors.ghostAlpha(0.15)
            onClicked: Quickshell.execDetached(["sh", "-c", "xdg-open https://github.com/AdolfoLecompteDev/ashen"])
        }
    }

    Item { Layout.fillHeight: true }
}
