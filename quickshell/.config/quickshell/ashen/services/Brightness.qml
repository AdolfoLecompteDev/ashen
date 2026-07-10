pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int level: 100

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: brightnessProc.running = true
    }

    Process {
        id: brightnessProc
        command: ["sh", "-c", "brightnessctl -m"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = text.trim().split(",")
                if (parts.length > 3) {
                    let pctStr = parts[3].replace("%", "")
                    let pct = parseInt(pctStr)
                    if (!isNaN(pct)) root.level = pct
                }
            }
        }
    }
}
