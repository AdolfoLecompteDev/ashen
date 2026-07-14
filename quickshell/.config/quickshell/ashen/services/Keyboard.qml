pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    // Everything comes from the main keyboard: `layout` is the whole configured
    // list ("latam,us") and `active_layout_index` says which one is live.
    property var layouts: []
    property int activeIndex: 0
    property string keymap: ""

    readonly property string code: activeIndex >= 0 && activeIndex < layouts.length
        ? layouts[activeIndex] : ""
    readonly property string label: code === "" ? "--" : code.toUpperCase()
    readonly property bool multiple: layouts.length > 1

    function refresh() { devProc.running = true }

    // `all`, not the device name: the laptop reports a dozen keyboards (wireless
    // dongle, power button, hotkeys) and switching only the main one desyncs them
    function setLayout(i) {
        if (i < 0 || i >= layouts.length || i === activeIndex) return
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)])
        refresh()
    }

    function cycle() {
        if (layouts.length < 2) return
        setLayout((activeIndex + 1) % layouts.length)
    }

    Process {
        id: devProc
        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let kbs = JSON.parse(text).keyboards || []
                    let main = kbs.find(k => k.main) || kbs[0]
                    if (!main) return
                    root.layouts = (main.layout || "").split(",").map(s => s.trim()).filter(s => s.length > 0)
                    root.activeIndex = main.active_layout_index || 0
                    root.keymap = main.active_keymap || ""
                } catch (e) {
                    // hyprctl not up yet; the next refresh will catch it
                }
            }
        }
    }

    // Hyprland announces every layout change, whoever caused it
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                root.refresh()
        }
    }
}
