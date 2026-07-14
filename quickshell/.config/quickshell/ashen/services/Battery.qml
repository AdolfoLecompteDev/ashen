pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int level: 0
    property bool charging: false

    Process {
        id: batProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.level = parseInt(text.trim()) || 0
        }
    }

    Process {
        id: chargeProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const status = text.trim()
                root.charging = status === "Charging" || status === "Full" || status === "Not charging"
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            batProc.running = true
            chargeProc.running = true
        }
    }
}
