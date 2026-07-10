import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/services" as Services

ColumnLayout {
    id: tab
    anchors.fill: parent
    anchors.margins: 28
    spacing: 14

    property string timeRemaining: "--"
    property var availableProfiles: []
    property string activeProfile: ""

    property real ramUsedMB: 0
    property real ramTotalMB: 0
    property real cpuPercent: 0
    property string cpuModel: "..."
    property string gpuInfo: "..."

    property real prevCpuTotal: 0
    property real prevCpuIdle: 0

    property real diskUsedGB: 0
    property real diskTotalGB: 0
    property int diskPercent: 0

    function setProfile(name) {
        if (!availableProfiles.includes(name)) return
        Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
        activeProfile = name
    }

    Component.onCompleted: {
        battProc.running = true
        profProc.running = true
        cpuModelProc.running = true
        gpuProc.running = true
        ramProc.running = true
        cpuProc.running = true
        diskProc.running = true
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: { ramProc.running = true; cpuProc.running = true }
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: diskProc.running = true
    }

    Process {
        id: battProc
        command: ["sh", "-c", "upower -i $(upower -e | grep BAT) 2>/dev/null | grep -E 'time to (empty|full)'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let line = text.trim()
                tab.timeRemaining = line.length > 0 ? line.split(":").slice(1).join(":").trim() : "--"
            }
        }
    }

    Process {
        id: profProc
        command: ["sh", "-c", "powerprofilesctl list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split("\n")
                let profiles = []
                let active = ""
                for (let line of lines) {
                    let m = line.match(/^\s*(\*?)\s*([\w-]+):$/)
                    if (m) { profiles.push(m[2]); if (m[1] === "*") active = m[2] }
                }
                tab.availableProfiles = profiles
                tab.activeProfile = active
            }
        }
    }

    Process {
        id: cpuModelProc
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]
        running: false
        stdout: StdioCollector { onStreamFinished: tab.cpuModel = text.trim() }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "lspci | grep -E 'VGA|3D controller'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n").filter(l => l.length > 0)
                tab.gpuInfo = lines.length > 0 ? lines.map(l => l.split(": ").pop()).join(" / ") : "Unknown"
            }
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -BG --output=used,size,pcent / | tail -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(/\s+/)
                if (parts.length === 3) {
                    tab.diskUsedGB = parseFloat(parts[0].replace("G", "")) || 0
                    tab.diskTotalGB = parseFloat(parts[1].replace("G", "")) || 0
                    tab.diskPercent = parseInt(parts[2].replace("%", "")) || 0
                }
            }
        }
    }

    Process {
        id: ramProc
        command: ["sh", "-c", "free -m | awk '/^Mem:/{print $3\",\"$2}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(",")
                if (parts.length === 2) {
                    tab.ramUsedMB = parseFloat(parts[0]) || 0
                    tab.ramTotalMB = parseFloat(parts[1]) || 0
                }
            }
        }
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "grep '^cpu ' /proc/stat"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(/\s+/).slice(1).map(Number)
                let idle = parts[3] + (parts[4] || 0)
                let total = parts.reduce((a, b) => a + b, 0)
                if (tab.prevCpuTotal > 0) {
                    let totalDiff = total - tab.prevCpuTotal
                    let idleDiff = idle - tab.prevCpuIdle
                    if (totalDiff > 0) tab.cpuPercent = Math.max(0, Math.min(100, 100 * (1 - idleDiff / totalDiff)))
                }
                tab.prevCpuTotal = total
                tab.prevCpuIdle = idle
            }
        }
    }

    Text {
        text: "System"
        color: Services.Colors.snow
        font.pixelSize: 20
        font.bold: true
        font.family: "JetBrainsMono NF"
    }

    RowLayout {
        spacing: 14
        Text {
            text: Services.Battery.level + "%"
            color: Services.Colors.snow
            font.pixelSize: 24
            font.bold: true
            font.family: "JetBrainsMono NF"
        }
        ColumnLayout {
            spacing: 2
            Text {
                text: Services.Battery.charging ? "Charging" : "On battery"
                color: Services.Colors.mist
                font.pixelSize: 11
                font.family: "JetBrainsMono NF"
            }
            Text {
                text: tab.timeRemaining !== "--" ? tab.timeRemaining : (Services.Battery.charging ? "Fully charged" : "Calculating...")
                color: Services.Colors.ash
                font.pixelSize: 10
                font.family: "JetBrainsMono NF"
            }
        }
    }

    Text {
        text: "Power Profile"
        color: Services.Colors.mist
        font.pixelSize: 11
        font.family: "JetBrainsMono NF"
    }

    RowLayout {
        spacing: 10
        Repeater {
            model: [
                { id: "power-saver", icon: "", label: "Saver" },
                { id: "balanced", icon: "", label: "Balanced" },
                { id: "performance", icon: "", label: "Performance" },
            ]
            delegate: Rectangle {
                required property var modelData
                property bool available: tab.availableProfiles.includes(modelData.id)
                width: 100; height: 64
                radius: 12
                color: tab.activeProfile === modelData.id ? Services.Colors.ghost : Services.Colors.ghostAlpha(0.12)
                opacity: available ? 1.0 : 0.35
                Behavior on color { ColorAnimation { duration: 150 } }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: modelData.icon
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                        color: tab.activeProfile === modelData.id ? Services.Colors.abyss : Services.Colors.mist
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: modelData.label
                        font.pixelSize: 10
                        font.family: "JetBrainsMono NF"
                        color: tab.activeProfile === modelData.id ? Services.Colors.abyss : Services.Colors.mist
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    enabled: parent.available
                    onClicked: tab.setProfile(modelData.id)
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Services.Colors.ghostAlpha(0.15); Layout.topMargin: 4 }

    Text {
        text: "Hardware"
        color: Services.Colors.mist
        font.pixelSize: 11
        font.family: "JetBrainsMono NF"
    }

    ColumnLayout {
        spacing: 12
        Layout.fillWidth: true

        RowLayout {
            spacing: 10
            Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: Services.Colors.ghost }
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text { text: "CPU  ·  " + tab.cpuModel; color: Services.Colors.snow; font.pixelSize: 12; font.family: "JetBrainsMono NF"; elide: Text.ElideRight; Layout.fillWidth: true }
                Rectangle {
                    Layout.fillWidth: true
                    height: 6; radius: 3
                    color: Services.Colors.ghostAlpha(0.15)
                    Rectangle {
                        height: parent.height; radius: 3
                        color: Services.Colors.ghost
                        width: parent.width * (tab.cpuPercent / 100)
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
                Text { text: tab.cpuPercent.toFixed(0) + "%"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
            }
        }

        RowLayout {
            spacing: 10
            Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: Services.Colors.ghost }
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text { text: "Memory"; color: Services.Colors.snow; font.pixelSize: 12; font.family: "JetBrainsMono NF" }
                Rectangle {
                    Layout.fillWidth: true
                    height: 6; radius: 3
                    color: Services.Colors.ghostAlpha(0.15)
                    Rectangle {
                        height: parent.height; radius: 3
                        color: Services.Colors.ghost
                        width: tab.ramTotalMB > 0 ? parent.width * (tab.ramUsedMB / tab.ramTotalMB) : 0
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
                Text { text: tab.ramUsedMB.toFixed(0) + " MB / " + tab.ramTotalMB.toFixed(0) + " MB"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
            }
        }

        RowLayout {
            spacing: 10
            Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: Services.Colors.ghost }
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text { text: "Graphics"; color: Services.Colors.snow; font.pixelSize: 12; font.family: "JetBrainsMono NF" }
                Text { text: tab.gpuInfo; color: Services.Colors.mist; font.pixelSize: 11; font.family: "JetBrainsMono NF"; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }

        RowLayout {
            spacing: 10
            Text { text: ""; font.family: "Material Symbols Rounded"; font.pixelSize: 18; color: Services.Colors.ghost }
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Text { text: "Storage"; color: Services.Colors.snow; font.pixelSize: 12; font.family: "JetBrainsMono NF" }
                Rectangle {
                    Layout.fillWidth: true
                    height: 6; radius: 3
                    color: Services.Colors.ghostAlpha(0.15)
                    Rectangle {
                        height: parent.height; radius: 3
                        color: tab.diskPercent >= 90 ? Services.Colors.error_ : Services.Colors.ghost
                        width: parent.width * (tab.diskPercent / 100)
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
                Text { text: tab.diskUsedGB.toFixed(0) + " GB / " + tab.diskTotalGB.toFixed(0) + " GB  (" + tab.diskPercent + "%)"; color: Services.Colors.ash; font.pixelSize: 10; font.family: "JetBrainsMono NF" }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
