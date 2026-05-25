import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "Room"
    property string subtitle: ""
    property string temperature: "--.- C"
    property string humidity: "-- %"
    property bool lightOn: false
    property bool shutterClosed: false
    property string shutterPosition: "-- %"
    property var openhab: null
    property string temperatureItem: ""
    property string humidityItem: ""
    property string lightItem: ""
    property string hueItem: ""
    property string shutterItem: ""
    property int stateRevision: openhab ? openhab.stateRevision : 0
    readonly property string effectiveTemperature: itemState(temperatureItem, temperature)
    readonly property string effectiveHumidity: itemState(humidityItem, humidity)
    readonly property string effectiveLightState: itemState(lightItem, lightOn ? "ON" : "OFF")
    readonly property bool effectiveLightOn: isOnState(effectiveLightState)
    readonly property string effectiveHueState: itemState(hueItem, effectiveLightOn ? "100%" : "0%")
    readonly property string effectiveShutterState: itemState(shutterItem, shutterClosed ? "DOWN" : "UP")
    readonly property bool effectiveShutterClosed: isClosedState(effectiveShutterState)

    function itemState(itemName, fallback) {
        stateRevision
        if (openhab && itemName.length > 0) {
            return openhab.itemState(itemName, fallback)
        }
        return fallback
    }

    function isOnState(state) {
        var normalized = String(state).trim().toUpperCase()
        if (normalized === "ON" || normalized === "OPEN" || normalized === "DOWN") {
            return true
        }
        var number = Number(normalized.split(" ")[0])
        return !isNaN(number) && number > 0
    }

    function isClosedState(state) {
        var normalized = String(state).trim().toUpperCase()
        if (normalized === "DOWN" || normalized === "CLOSED") {
            return true
        }
        var number = Number(normalized.split(" ")[0])
        return !isNaN(number) && number > 50
    }

    function sendToggle(itemName, onCommand, offCommand, currentState) {
        if (!openhab || itemName.length === 0) {
            return
        }
        openhab.sendCommand(itemName, isOnState(currentState) ? offCommand : onCommand)
    }

    function sendShutterToggle() {
        if (!openhab || shutterItem.length === 0) {
            return
        }
        openhab.sendCommand(shutterItem, effectiveShutterClosed ? "UP" : "DOWN")
    }

    implicitWidth: 292
    implicitHeight: 250
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.title
                    color: "#e2e8f0"
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.subtitle
                    color: "#7d90aa"
                    font.pixelSize: 11
                    visible: root.subtitle.length > 0
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 70
                Layout.preferredHeight: 34
                radius: 10
                color: "#16243a"

                Text {
                    anchors.centerIn: parent
                    text: root.effectiveTemperature
                    color: "#f97316"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            ControlTile {
                label: "Licht"
                value: root.effectiveLightOn ? "ON" : "OFF"
                secondary: "main"
                iconText: "L"
                active: root.effectiveLightOn
                interactive: root.lightItem.length > 0
                onClicked: root.sendToggle(root.lightItem, "ON", "OFF", root.effectiveLightState)
                Layout.fillWidth: true
            }

            ControlTile {
                label: "Hue"
                value: root.effectiveHueState
                secondary: "scene"
                iconText: "H"
                active: root.isOnState(root.effectiveHueState)
                interactive: root.hueItem.length > 0
                onClicked: root.sendToggle(root.hueItem, "100", "0", root.effectiveHueState)
                accentColor: "#fbbf24"
                Layout.fillWidth: true
            }

            ControlTile {
                label: "Rollo"
                value: root.effectiveShutterClosed ? "DOWN" : "UP"
                secondary: root.itemState(root.shutterItem, root.shutterPosition)
                iconText: "R"
                active: root.effectiveShutterClosed
                interactive: root.shutterItem.length > 0
                onClicked: root.sendShutterToggle()
                accentColor: "#38bdf8"
                Layout.fillWidth: true
            }

            ControlTile {
                label: "Klima"
                value: root.effectiveHumidity
                secondary: "humidity"
                iconText: "C"
                active: false
                accentColor: "#22c55e"
                Layout.fillWidth: true
            }
        }
    }
}
