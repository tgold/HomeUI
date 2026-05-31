import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string title: "Sonos"
    property string accentColor: "#f59e0b"
    property int columnSpan: 1

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
    property var sonosClient: null
    property string host: ""
    property int stateRevision: openhab ? openhab.stateRevision : 0
    property int directRevision: 0
    readonly property bool usingDirectSonos: sonosClient && host.trim().length > 0
    // Wide panels (full-width footer or multi-column span): metadata left,
    // transport/volume right, favorites on a full-width row underneath.
    readonly property bool compactLayout: root.columnSpan >= 2 || width >= 560
    readonly property bool showFavorites: root.favorites && root.favorites.length > 0
    readonly property bool showFavoriteButtons: showFavorites && root._item("favorite").length > 0
    readonly property int artSize: compactLayout ? 72 : 96
    readonly property int favoriteColumns: compactLayout ? Math.min(6, Math.max(3, root.favorites.length)) : 3

    function _item(role) {
        if (!items || !items[role]) {
            return ""
        }
        return items[role]
    }

    function directStateValue(role, fallback) {
        directRevision
        if (!usingDirectSonos || !sonosClient) {
            return fallback
        }
        var state = sonosClient.zoneState(host)
        if (state && state[role] !== undefined && state[role] !== null && String(state[role]).length > 0) {
            return state[role]
        }
        return fallback
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

    function sendTransport(command) {
        if (usingDirectSonos && sonosClient) {
            sonosClient.sendTransport(host, String(command))
            return
        }
        root.sendCommand(root.controllerItem, command)
    }

    function setMuteState(muted) {
        if (usingDirectSonos && sonosClient) {
            sonosClient.setMuted(host, muted)
            return
        }
        root.sendCommand(root.muteItem, muted ? "ON" : "OFF")
    }

    function setVolumeValue(value) {
        if (usingDirectSonos && sonosClient) {
            sonosClient.setVolume(host, Math.round(value))
            return
        }
        root.sendCommand(root.volumeItem, Math.round(value))
    }

    readonly property string controllerItem: _item("controller")
    readonly property string volumeItem: _item("volume")
    readonly property string muteItem: _item("mute")
    readonly property string trackText: {
        return usingDirectSonos ? String(directStateValue("track", "")) : itemState(_item("track"), "")
    }
    readonly property string titleText: {
        return usingDirectSonos ? String(directStateValue("title", "")) : itemState(_item("title"), "")
    }
    readonly property string artistText: {
        return usingDirectSonos ? String(directStateValue("artist", "")) : itemState(_item("artist"), "")
    }
    readonly property string albumText: {
        return usingDirectSonos ? String(directStateValue("album", "")) : itemState(_item("album"), "")
    }
    readonly property string albumArtUrl: {
        var url = usingDirectSonos ? String(directStateValue("albumArt", "")) : itemState(_item("albumArt"), "")
        var raw = String(url).trim()
        if (raw.length === 0 || raw.toUpperCase() === "NULL" || raw.toUpperCase() === "UNDEF") {
            return ""
        }
        // Many Sonos bindings reuse a stable artwork URL. Append a lightweight
        // cache-buster so the Image reloads when track metadata changes.
        var fingerprint = root.titleText + "|" + root.artistText + "|" + root.albumText + "|" + root.trackText
        var separator = raw.indexOf("?") === -1 ? "?" : "&"
        return raw + separator + "_homeui=" + encodeURIComponent(fingerprint)
    }
    readonly property string stateText: {
        if (usingDirectSonos) {
            return String(directStateValue("state", "")).toUpperCase()
        }
        return String(itemState(_item("state"), "")).toUpperCase()
    }
    readonly property real volumeValue: {
        var raw = usingDirectSonos ? String(directStateValue("volume", "0")) : itemState(volumeItem, "")
        var match = String(raw).match(/^-?\d+(?:\.\d+)?/)
        if (!match) { return 0 }
        var n = Number(match[0])
        return isNaN(n) ? 0 : Math.max(0, Math.min(100, n))
    }
    readonly property bool isMuted: {
        if (usingDirectSonos) {
            return String(directStateValue("mute", "OFF")).toUpperCase() === "ON"
        }
        return String(itemState(muteItem, "")).toUpperCase() === "ON"
    }
    readonly property string normalizedState: root.stateText.trim().toUpperCase()
    readonly property bool isPlaying: {
        // "PAUSED_PLAYBACK" contains "PLAY"; treat pause/stop as not playing.
        if (root.normalizedState.length === 0) {
            return false
        }
        if (root.normalizedState.indexOf("PAUSE") !== -1 || root.normalizedState.indexOf("STOP") !== -1) {
            return false
        }
        return root.normalizedState.indexOf("PLAY") !== -1
    }

    implicitWidth: 480
    implicitHeight: contentLayout.implicitHeight + 2 * contentLayout.anchors.margins
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    Component.onCompleted: {
        if (usingDirectSonos && sonosClient) {
            sonosClient.ensureZone(host)
            directRevision = sonosClient.zoneRevision(host)
        }
    }
    onHostChanged: {
        if (usingDirectSonos && sonosClient) {
            sonosClient.ensureZone(host)
            directRevision = sonosClient.zoneRevision(host)
        }
    }

    Connections {
        target: sonosClient
        ignoreUnknownSignals: true
        function onZoneUpdated(updatedHost) {
            if (!root.usingDirectSonos || !updatedHost) {
                return
            }
            if (String(updatedHost).toLowerCase() === String(root.host).toLowerCase()) {
                root.directRevision = root.directRevision + 1
            }
        }
    }

    GridLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Fmt.panelMargin
        columns: root.compactLayout ? 2 : 1
        columnSpacing: Fmt.gridSpacing
        rowSpacing: Fmt.gridSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.columnSpan: root.compactLayout ? 2 : 1
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
            Layout.column: 0
            Layout.row: 1
            Layout.alignment: Qt.AlignTop
            spacing: 14

            Rectangle {
                Layout.preferredWidth: root.artSize
                Layout.preferredHeight: root.artSize
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

        ColumnLayout {
            id: controlsColumn
            Layout.fillWidth: true
            Layout.column: root.compactLayout ? 1 : 0
            Layout.row: root.compactLayout ? 1 : 2
            Layout.alignment: Qt.AlignTop
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.usingDirectSonos || root.controllerItem.length > 0 || root.muteItem.length > 0

                TransportButton {
                    label: "PREV"
                    onClicked: root.sendTransport("PREVIOUS")
                    enabled: root.usingDirectSonos || root.controllerItem.length > 0
                    active: root.isPlaying
                    Layout.fillWidth: true
                }
                TransportButton {
                    label: root.isPlaying ? "PAUSE" : "PLAY"
                    accent: root.isPlaying ? "#f59e0b" : "#22c55e"
                    onClicked: root.sendTransport(root.isPlaying ? "PAUSE" : "PLAY")
                    enabled: root.usingDirectSonos || root.controllerItem.length > 0
                    active: true
                    Layout.fillWidth: true
                }
                TransportButton {
                    label: "NEXT"
                    onClicked: root.sendTransport("NEXT")
                    enabled: root.usingDirectSonos || root.controllerItem.length > 0
                    active: root.isPlaying
                    Layout.fillWidth: true
                }
                TransportButton {
                    label: root.isMuted ? "UNMUTE" : "MUTE"
                    accent: root.isMuted ? "#ef4444" : "#475569"
                    onClicked: root.setMuteState(!root.isMuted)
                    enabled: root.usingDirectSonos || root.muteItem.length > 0
                    active: root.isMuted
                    Layout.fillWidth: true
                    visible: root.usingDirectSonos || root.muteItem.length > 0
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: root.usingDirectSonos || root.volumeItem.length > 0

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
                            root.setVolumeValue(value)
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
                columns: root.favoriteColumns
                columnSpacing: 8
                rowSpacing: 8
                visible: root.showFavoriteButtons && !root.compactLayout

                Repeater {
                    model: root.favorites
                    delegate: TransportButton {
                        label: modelData.label || modelData.command || "—"
                        accent: modelData.accentColor || "#475569"
                        onClicked: root.sendCommand(root._item("favorite"), modelData.command)
                        active: true
                        Layout.fillWidth: true
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.columnSpan: root.compactLayout ? 2 : 1
            Layout.row: root.compactLayout ? 2 : 3
            columns: root.favoriteColumns
            columnSpacing: 8
            rowSpacing: 8
            visible: root.showFavoriteButtons && root.compactLayout

            Repeater {
                model: root.favorites
                delegate: TransportButton {
                    label: modelData.label || modelData.command || "—"
                    accent: modelData.accentColor || "#475569"
                    onClicked: root.sendCommand(root._item("favorite"), modelData.command)
                    active: true
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
        property bool active: false
        signal clicked()

        implicitHeight: 36
        radius: 8
        color: !btn.enabled ? "#141e2c" : (btn.active ? "#223047" : "#1c2839")
        border.color: btn.accent
        border.width: btn.active ? 2 : 1
        opacity: btn.enabled ? 1.0 : 0.4

        Text {
            anchors.centerIn: parent
            text: btn.label
            color: btn.enabled ? (btn.active ? btn.accent : "#f8fafc") : "#64748b"
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
