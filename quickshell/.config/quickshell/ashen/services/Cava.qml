pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property var barValues: []
    property bool isActive: false

    Process {
        id: cavaProcess
        command: ["sh", "-c", "exec cava -p \"$HOME/.config/cava/ashen.conf\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                let parts = data.split(";").filter(s => s.length > 0).map(Number)
                if (parts.length === 0) return
                root.barValues = parts
                let maxV = Math.max.apply(null, parts)
                root.isActive = maxV > 2
            }
        }
        onRunningChanged: if (!running) running = true
    }
}
