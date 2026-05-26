import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string title: "Sonos"
    property string accentColor: "#f59e0b"

    // Item bindings - all optional.
    // - controllerItem: Player item, accepts PLAY/PAUSE/NEXT/PREVIOUS
    // - volumeItem:     Dimmer item (0..100)
    // - muteItem:       Switch item (ON/OFF)
    // - trackItem:      String item, fallback display when no title/artist
    // - titleItem:      String item with the current title
    // - artistItem:     String item with the current artist
    // - albumItem:      String item with the current album
    // - albumArtItem:   String item containing the album-art URL
    // - stateItem:      String item that reports PLAY/PAUSE/STOP for icon hint
    // - favoriteItem:   String item that triggers favourite playback
    property var items: ({})

    // Favourites: array of { label, command } objects. When pressed the
    // command (a station / favourite name) is sent to `items.favorite`.
    property var favorites: []

    property var openhab: null
    property int stateRevision: openhab ? openhab.stateRevision : 0

    function _item(role) {
        if (!items || !items[role]) {
            return ""
        }
        return items[role]
    }

    function itemState(name, fallback) {
        stateRevision
        if (openhab && name && name.length > 0) {
            return openhab.itemState(name, fallback)
        }
        return fallback
    }

    function sendCommand(name, command) {
        if (!openhab || !name || name.length === 0 || command === undefined || command === null) {
            return
        }
        openhab.sendCommand(name, String(command))
    }

    readonly property string controllerItem: _item("controller")
    readonly property string volumeItem: _item("volume")
    readonly property string muteItem: _item("mute")
    readonly property string trackText: itemState(_item("track"), "")
    readonly property string titleText: itemState(_item("title"), "")
    readonly property string artistText: itemState(_item("artist"), "")
    readonly property string albumText: itemState(_item("album"), "")
    readonly property string albumArtUrl: {
        var url = itemState(_item("albumArt"), "")
        var raw = String(url).trim()
        if (raw.length === 0 || raw.toUpperCase() === "NULL" || raw.toUpperCase() === "UNDEF") {
            return ""
        }
        return raw
    }
    readonly property string stateText: String(itemState(_item("state"), "")).toUpperCase()
    readonly property real volumeValue: {
        var raw = itemState(volumeItem, "")
        var match = String(raw).match(/^-?\d+(?:\.\d+)?/)
        if (!match) { return 0 }
        var n = Number(match[0])
        return isNaN(n) ? 0 : Math.max(0, Math.min(100, n))
    }
    readonly property bool isMuted: String(itemState(muteItem, "")).toUpperCase() === "ON"
    readonly property bool isPlaying: stateText.indexOf("PLAY") !== -1

    implicitWidth: 480
    implicitHeight: contentColumn.implicitHeight + 2 * contentColumn.anchors.margins
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: root.title
                color: "#e2e8f0"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Rectangle {
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: root.isPlaying ? "#22c55e" : "#475569"
                visible: root.stateText.length > 0
            }
            Text {
                text: root.stateText
                visible: root.stateText.length > 0
                color: "#94a3b8"
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: 10
                color: "#0b1322"
                border.color: "#1f2a3d"
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: root.albumArtUrl
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    visible: status === Image.Ready
                    asynchronous: true
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    text: "MUSIC"
                    visible: root.albumArtUrl.length === 0
                    color: "#475569"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "TRACK"
                    color: "#64748b"
                    font.pixelSize: 10
                    font.bold: true
                }
                Text {
                    text: {
                        if (root.titleText.length > 0 && root.artistText.length > 0) {
                            return root.artistText + " – " + root.titleText
                        }
                        if (root.titleText.length > 0) {
                            return root.titleText
                        }
                        if (root.trackText.length > 0) {
                            return root.trackText
                        }
                        return "—"
                    }
                    color: root.accentColor
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    text: root.albumText
                    visible: root.albumText.length > 0
                    color: "#94a3b8"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.controllerItem.length > 0 || root.muteItem.length > 0

            TransportButton {
                label: "PREV"
                onClicked: root.sendCommand(root.controllerItem, "PREVIOUS")
                enabled: root.controllerItem.length > 0
                Layout.fillWidth: true
            }
            TransportButton {
                label: root.isPlaying ? "PAUSE" : "PLAY"
                accent: root.isPlaying ? "#f59e0b" : "#22c55e"
                onClicked: root.sendCommand(root.controllerItem, root.isPlaying ? "PAUSE" : "PLAY")
                enabled: root.controllerItem.length > 0
                Layout.fillWidth: true
            }
            TransportButton {
                label: "NEXT"
                onClicked: root.sendCommand(root.controllerItem, "NEXT")
                enabled: root.controllerItem.length > 0
                Layout.fillWidth: true
            }
            TransportButton {
                label: root.isMuted ? "UNMUTE" : "MUTE"
                accent: root.isMuted ? "#ef4444" : "#475569"
                onClicked: root.sendCommand(root.muteItem, root.isMuted ? "OFF" : "ON")
                enabled: root.muteItem.length > 0
                Layout.fillWidth: true
                visible: root.muteItem.length > 0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.volumeItem.length > 0

            Text {
                text: "VOL"
                color: "#94a3b8"
                font.pixelSize: 11
                font.bold: true
            }
            Slider {
                id: volumeSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 1
                value: root.volumeValue
                live: false
                onPressedChanged: {
                    if (!pressed) {
                        root.sendCommand(root.volumeItem, Math.round(value))
                    }
                }
            }
            Text {
                text: Math.round(root.volumeValue) + "%"
                color: "#f8fafc"
                font.pixelSize: 13
                font.bold: true
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 44
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            visible: root.favorites && root.favorites.length > 0 && root._item("favorite").length > 0

            Repeater {
                model: root.favorites
                delegate: TransportButton {
                    label: modelData.label || modelData.command || "—"
                    accent: modelData.accentColor || "#475569"
                    onClicked: root.sendCommand(root._item("favorite"), modelData.command)
                    Layout.fillWidth: true
                }
            }
        }
    }

    component TransportButton: Rectangle {
        id: btn
        property string label: ""
        property color accent: "#475569"
        property bool enabled: true
        signal clicked()

        implicitHeight: 36
        radius: 8
        color: btn.enabled ? "#1c2839" : "#141e2c"
        border.color: btn.accent
        border.width: 1
        opacity: btn.enabled ? 1.0 : 0.4

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.enabled ? "#f8fafc" : "#64748b"
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.fill: parent
            enabled: btn.enabled
            onClicked: btn.clicked()
        }
    }
}
