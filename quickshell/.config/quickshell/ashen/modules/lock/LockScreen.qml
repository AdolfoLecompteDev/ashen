import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    IpcHandler {
        target: "lockscreen"
        function lock() {
            sessionLock.locked = true
        }
    }

    WlSessionLock {
        id: sessionLock


        WlSessionLockSurface {
            id: surface

            property string currentTime: Qt.formatDateTime(new Date(), "hh:mm AP")
            property string currentSecs: Qt.formatDateTime(new Date(), "ss")
            property string currentDate: Qt.formatDateTime(new Date(), "MMMM d, yyyy")
            property string currentDay: Qt.locale().dayName(new Date().getDay())
            property string password: ""
            property string errorMsg: ""
            property bool checking: false
            property bool showPower: false
            property int battery: 0
            property bool charging: false
            property string wallpaper: ""
            property bool revealed: false
            property bool unlocking: false

            property var activePlayer: {
                let list = Mpris.players.values.filter(p => p.playbackState !== MprisPlaybackState.Stopped)
                if (list.length === 0) return null
                let playing = list.find(p => p.isPlaying)
                return playing !== undefined ? playing : list[0]
            }
            property bool hasPlayer: activePlayer !== null
            property string stableArtUrl: ""
            function updateArt() {
                if (!surface.hasPlayer) { surface.stableArtUrl = ""; return }
                if (surface.activePlayer.trackArtUrl !== "") surface.stableArtUrl = surface.activePlayer.trackArtUrl
            }
            onActivePlayerChanged: updateArt()
            Connections {
                target: surface.activePlayer
                ignoreUnknownSignals: true
                function onTrackArtUrlChanged() { surface.updateArt() }
            }

            property var availableProfiles: []
            property string activeProfile: ""
            function refreshProfiles() { profProc.running = true }
            function setProfile(name) {
                if (!surface.availableProfiles.includes(name)) return
                Quickshell.execDetached(["sh", "-c", "powerprofilesctl set " + name])
                surface.activeProfile = name
            }

            color: "#080809"

            Component.onCompleted: {
                surface.updateArt()
                surface.refreshProfiles()
                revealTimer.start()
            }

            Timer {
                id: revealTimer
                interval: 30
                onTriggered: surface.revealed = true
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    let now = new Date()
                    surface.currentTime = Qt.formatDateTime(now, "hh:mm AP")
                    surface.currentSecs = Qt.formatDateTime(now, "ss")
                    surface.currentDate = Qt.formatDateTime(now, "MMMM d, yyyy")
                    surface.currentDay = Qt.locale().dayName(now.getDay())
                }
            }

            Process {
                id: batProc
                command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity"]
                running: true
                stdout: StdioCollector { onStreamFinished: surface.battery = parseInt(text.trim()) || 0 }
            }
            Process {
                id: chargeProc
                command: ["sh", "-c", "cat /sys/class/power_supply/AC0/online"]
                running: true
                stdout: StdioCollector { onStreamFinished: surface.charging = text.trim() === "1" }
            }
            Process {
                id: wallpaperProc
                command: ["sh", "-c", "awww query | grep -o 'image: .*' | cut -d' ' -f2"]
                running: true
                stdout: StdioCollector { onStreamFinished: surface.wallpaper = text.trim() }
            }
            Timer {
                interval: 30000; running: true; repeat: true
                onTriggered: { batProc.running = true; chargeProc.running = true }
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
                            if (m) {
                                profiles.push(m[2])
                                if (m[1] === "*") active = m[2]
                            }
                        }
                        surface.availableProfiles = profiles
                        surface.activeProfile = active
                    }
                }
            }

            Process {
                id: authProc
                command: ["sh", "-c", "printf '%s' \"" + surface.password + "\" | su -s /bin/sh -c 'exit 0' adolf-arch 2>/dev/null && echo ok || echo fail"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        if (text.trim() === "ok") {
                            surface.checking = false
                            surface.unlocking = true
                            unlockTimer.start()
                        } else {
                            surface.errorMsg = "Incorrect password"
                            surface.password = ""
                            passInput.text = ""
                            surface.checking = false
                            errorTimer.restart()
                        }
                    }
                }
            }

            Timer {
                id: unlockTimer
                interval: 340
                onTriggered: sessionLock.locked = false
            }

            Timer {
                id: errorTimer
                interval: 2500
                onTriggered: surface.errorMsg = ""
            }

            function tryUnlock() {
                if (surface.password.length === 0) {
                    surface.errorMsg = "Please enter your password"
                    errorTimer.restart()
                    return
                }
                surface.checking = true
                surface.errorMsg = ""
                authProc.running = true
            }

            // ── Contenido principal (con animacion de entrada/salida) ──
            Item {
                id: content
                anchors.fill: parent
                opacity: surface.unlocking ? 0.0 : 1.0
                scale: surface.unlocking ? 0.96 : 1.0
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    color: "#080809"
                    Image {
                        anchors.fill: parent
                        source: surface.wallpaper !== "" ? ("file://" + surface.wallpaper) : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                        opacity: 0.35
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0x08/255, 0x08/255, 0x09/255, 0.5)
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 32

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 0
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 0
                                Text {
                                    text: surface.currentTime.split(" ")[0]
                                    color: "#e8e8ec"
                                    font.pixelSize: 96
                                    font.family: "JetBrainsMono NF"
                                    font.weight: Font.Bold
                                }
                                Column {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 16
                                    spacing: 2
                                    Text {
                                        text: surface.currentSecs
                                        color: Qt.rgba(0xe8/255, 0xe8/255, 0xec/255, 0.4)
                                        font.pixelSize: 28
                                        font.family: "JetBrainsMono NF"
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        text: surface.currentTime.split(" ")[1]
                                        color: Qt.rgba(0xe8/255, 0xe8/255, 0xec/255, 0.4)
                                        font.pixelSize: 14
                                        font.family: "JetBrainsMono NF"
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: surface.currentDay + "  ·  " + surface.currentDate
                                color: Qt.rgba(0xe8/255, 0xe8/255, 0xec/255, 0.5)
                                font.pixelSize: 16
                                font.family: "JetBrainsMono NF"
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 16
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 120; height: 120
                                radius: 20
                                color: Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.15)
                                border.color: Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.35)
                                border.width: 2
                                Image {
                                    id: faceImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: "file:///home/adolf-arch/.face"
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                    layer.enabled: visible
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: "#6e6e7a"
                                    font.pixelSize: 68
                                    font.family: "Material Symbols Rounded"
                                    visible: faceImg.status !== Image.Ready
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "adolf-arch"
                                color: "#e8e8ec"
                                font.pixelSize: 18
                                font.family: "JetBrainsMono NF"
                                font.weight: Font.Medium
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 320; height: 52
                                radius: 10
                                color: Qt.rgba(0x1c/255, 0x1c/255, 0x21/255, 0.85)
                                border.color: surface.errorMsg !== "" ? "#c87a7a"
                                    : passInput.activeFocus ? "#6e6e7a"
                                    : Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.25)
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12
                                    Text {
                                        text: ""
                                        color: surface.errorMsg !== "" ? "#c87a7a" : "#6e6e7a"
                                        font.pixelSize: 20
                                        font.family: "Material Symbols Rounded"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    Item {
                                        Layout.fillWidth: true
                                        height: 30
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Enter password..."
                                            color: "#4a4a54"
                                            font.pixelSize: 14
                                            font.family: "JetBrainsMono NF"
                                            visible: surface.password.length === 0
                                        }
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8
                                            visible: surface.password.length > 0
                                            Repeater {
                                                model: Math.min(surface.password.length, 24)
                                                delegate: Rectangle {
                                                    width: 8; height: 8
                                                    radius: 2
                                                    color: "#6e6e7a"
                                                }
                                            }
                                        }
                                        // Cursor visible (parpadeante) -- el TextInput real
                                        // esta fuera de pantalla, esto es la representacion visual
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 2; height: 18
                                            color: "#e8e8ec"
                                            visible: passInput.activeFocus
                                            SequentialAnimation on opacity {
                                                running: passInput.activeFocus
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 0.0; duration: 500 }
                                                NumberAnimation { to: 1.0; duration: 500 }
                                            }
                                        }
                                        TextInput {
                                            id: passInput
                                            width: 1; height: 1
                                            x: -9999; y: -9999
                                            echoMode: TextInput.Password
                                            color: "transparent"
                                            cursorVisible: true
                                            focus: true
                                            onTextChanged: surface.password = text
                                            Keys.onReturnPressed: surface.tryUnlock()
                                            Keys.onEscapePressed: {
                                                text = ""
                                                surface.errorMsg = ""
                                            }
                                        }
                                    }
                                    Text {
                                        text: ""
                                        color: surface.checking ? "#6e6e7a" : "#4a4a54"
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        SequentialAnimation on opacity {
                                            running: surface.checking
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.2; duration: 500 }
                                            NumberAnimation { to: 1.0; duration: 500 }
                                        }
                                    }
                                }
                            }
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 320
                                height: 16
                                Text {
                                    anchors.centerIn: parent
                                    text: surface.errorMsg
                                    color: "#c87a7a"
                                    font.pixelSize: 12
                                    font.family: "JetBrainsMono NF"
                                    opacity: surface.errorMsg !== "" ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                    }

                    // ── Reproductor de musica (abajo a la izquierda) ──
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 24
                        visible: surface.hasPlayer
                        width: 300
                        height: 76
                        radius: 14
                        color: Qt.rgba(0x1c/255, 0x1c/255, 0x21/255, 0.85)
                        border.color: Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.25)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Rectangle {
                                width: 52; height: 52
                                radius: 10
                                color: "#080809"
                                Image {
                                    id: lockArtImg
                                    anchors.fill: parent
                                    source: surface.stableArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: lockArtImg.status !== Image.Ready
                                    text: ""
                                    color: "#6e6e7a"
                                    font.pixelSize: 20
                                    font.family: "Material Symbols Rounded"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: surface.hasPlayer ? (surface.activePlayer.trackTitle || "Untitled") : ""
                                    color: "#e8e8ec"
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: surface.hasPlayer ? (surface.activePlayer.trackArtist || "") : ""
                                    color: "#9090a0"
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono NF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                RowLayout {
                                    spacing: 12
                                    Text {
                                        text: ""
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 14
                                        color: surface.hasPlayer && surface.activePlayer.canGoPrevious ? "#e8e8ec" : "#4a4a54"
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: surface.hasPlayer && surface.activePlayer.canGoPrevious
                                            onClicked: surface.activePlayer.previous()
                                        }
                                    }
                                    Text {
                                        text: surface.hasPlayer && surface.activePlayer.isPlaying ? "" : ""
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 16
                                        color: "#e8e8ec"
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: surface.hasPlayer
                                            onClicked: surface.activePlayer.togglePlaying()
                                        }
                                    }
                                    Text {
                                        text: ""
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 14
                                        color: surface.hasPlayer && surface.activePlayer.canGoNext ? "#e8e8ec" : "#4a4a54"
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: surface.hasPlayer && surface.activePlayer.canGoNext
                                            onClicked: surface.activePlayer.next()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Esquina inferior derecha: power options + bateria + perfiles ──
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 24
                        spacing: 8

                        Column {
                            anchors.right: parent.right
                            spacing: 6
                            opacity: surface.showPower ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Repeater {
                                model: [
                                    { icon: "", label: "Suspend",  cmd: "systemctl suspend",  color: "#9090a0" },
                                    { icon: "", label: "Reboot",   cmd: "systemctl reboot",   color: "#9090a0" },
                                    { icon: "", label: "Shutdown", cmd: "systemctl poweroff", color: "#c87a7a" },
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    anchors.right: parent.right
                                    width: optRow.implicitWidth + 20
                                    height: 38
                                    radius: 8
                                    color: Qt.rgba(0x1c/255, 0x1c/255, 0x21/255, 0.92)
                                    border.color: Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.25)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Row {
                                        id: optRow
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: modelData.icon
                                            color: modelData.color
                                            font.pixelSize: 18
                                            font.family: "Material Symbols Rounded"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.label
                                            color: modelData.color
                                            font.pixelSize: 12
                                            font.family: "JetBrainsMono NF"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onEntered: parent.color = Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.2)
                                        onExited: parent.color = Qt.rgba(0x1c/255, 0x1c/255, 0x21/255, 0.92)
                                        onClicked: Quickshell.execDetached(["sh", "-c", modelData.cmd])
                                    }
                                }
                            }
                        }

                        // Perfiles de energia (compactos, encima de la pildora)
                        Row {
                            anchors.right: parent.right
                            spacing: 6
                            opacity: surface.showPower ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Repeater {
                                model: [
                                    { id: "power-saver", icon: "" },
                                    { id: "balanced", icon: "" },
                                    { id: "performance", icon: "" },
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    property bool available: surface.availableProfiles.includes(modelData.id)
                                    width: 38; height: 38
                                    radius: 8
                                    color: surface.activeProfile === modelData.id ? "#6e6e7a" : Qt.rgba(0x1c/255, 0x1c/255, 0x21/255, 0.85)
                                    opacity: available ? 1.0 : 0.3
                                    border.color: Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.25)
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 16
                                        color: surface.activeProfile === modelData.id ? "#080809" : "#9090a0"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        enabled: parent.available
                                        onClicked: surface.setProfile(modelData.id)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            width: pillRow.implicitWidth + 20
                            height: 44
                            radius: 10
                            color: Qt.rgba(0x1c/255, 0x1c/255, 0x21/255, 0.85)
                            border.color: Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.25)
                            border.width: 1
                            Row {
                                id: pillRow
                                anchors.centerIn: parent
                                spacing: 10
                                Row {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: surface.charging ? "" : surface.battery >= 90 ? "" : surface.battery >= 50 ? "" : surface.battery >= 20 ? "" : ""
                                        color: surface.battery < 20 && !surface.charging ? "#c87a7a" : "#9090a0"
                                        font.pixelSize: 18
                                        font.family: "Material Symbols Rounded"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: surface.battery + "%"
                                        color: surface.battery < 20 && !surface.charging ? "#c87a7a" : "#9090a0"
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono NF"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Rectangle {
                                    width: 1; height: 24
                                    color: Qt.rgba(0x6e/255, 0x6e/255, 0x7a/255, 0.3)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: ""
                                    color: surface.showPower ? "#e8e8ec" : "#4a4a54"
                                    font.pixelSize: 20
                                    font.family: "Material Symbols Rounded"
                                    anchors.verticalCenter: parent.verticalCenter
                                    rotation: surface.showPower ? 0 : 180
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on rotation { NumberAnimation { duration: 200 } }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: surface.showPower = !surface.showPower
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
