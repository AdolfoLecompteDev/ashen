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
        // IN-USE marks the AP we're actually associated with ("*"). Its SIGNAL is
        // the only reliable value: when several APs share the SSID (mesh/repeaters)
        // the strongest visible one is NOT necessarily ours, so matching by name
        // overstated the level. Its SSID is also the real network name — the
        // CONNECTION field from `dev status` is the NM profile name, which gets a
        // " 1" suffix on duplicate profiles (that stray "1" in the pill).
        command: ["nmcli", "-t", "-e", "no", "-f", "IN-USE,SIGNAL,SSID", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let level = 0
                for (let line of text.split("\n")) {
                    if (line.charAt(0) !== "*")
                        continue
                    const f = line.split(":")
                    if (f.length < 3)
                        continue
                    level = parseInt(f[1]) || 0
                    const ssid = f.slice(2).join(":").trim()
                    if (ssid !== "")
                        root.wifiSsid = ssid
                    break
                }
                root.wifiSignal = level
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
