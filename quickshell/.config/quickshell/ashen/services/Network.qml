pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root
    property string wifiSsid: ""
    property int wifiSignal: 0
    property string ethConnection: ""
    readonly property bool online: wifiSsid !== "" || ethConnection !== ""
    property string btDevice: ""
    property bool btEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-e", "no", "-f", "TYPE,STATE,CONNECTION", "dev", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let ssid = ""
                let eth = ""
                for (let line of text.split("\n")) {
                    const f = line.split(":")
                    if (f.length < 3)
                        continue
                    const type = f[0]
                    const state = f[1]
                    const conn = f.slice(2).join(":").trim()
                    if (!state.startsWith("connected") || conn === "")
                        continue
                    if (type === "wifi")
                        ssid = conn
                    else if (type === "ethernet")
                        eth = conn
                }
                root.wifiSsid = ssid
                root.ethConnection = eth
                if (ssid !== "")
                    signalProc.running = true
                else
                    root.wifiSignal = 0
            }
        }
    }

    Process {
        id: signalProc
        command: ["nmcli", "-t", "-e", "no", "-f", "SSID,SIGNAL", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let best = 0
                for (let line of text.split("\n")) {
                    const sep = line.lastIndexOf(":")
                    if (sep < 1)
                        continue
                    if (line.substring(0, sep) !== root.wifiSsid)
                        continue
                    const lvl = parseInt(line.substring(sep + 1)) || 0
                    if (lvl > best)
                        best = lvl
                }
                root.wifiSignal = best
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: wifiProc.running = true
    }

    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl devices Connected | head -1 | cut -d' ' -f3-"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.btDevice = text.trim()
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }
}
