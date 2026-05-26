import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string title: "Controls"
    property var controls: []
    property var openhab: null
    property var mqtt: null
    property int stateRevision: openhab ? openhab.stateRevision : 0
    property int messageRevision: mqtt && mqtt.messageRevision !== undefined ? mqtt.messageRevision : 0

    // Number of tiles to render per row. 0 means auto: as many as fit at
    // ~140px per tile inside the panel width.
    property int tilesPerRow: 0
    property int minTileWidth: 140

    readonly property int effectiveColumns: {
        var count = controls ? controls.length : 0
        if (count === 0) {
            return 1
        }
        if (tilesPerRow > 0) {
            return Math.min(tilesPerRow, count)
        }
        var spacing = controlsGrid.columnSpacing
        var available = controlsGrid.width
        if (available <= 0) {
            return Math.min(count, 4)
        }
        var fit = Math.floor((available + spacing) / (minTileWidth + spacing))
        return Math.max(1, Math.min(fit, count))
    }

    function itemState(itemName, fallback) {
        stateRevision
        if (openhab && itemName && itemName.length > 0) {
            return openhab.itemState(itemName, fallback)
        }
        return fallback
    }

    function topicValue(topic, fallback) {
        messageRevision
        if (mqtt && mqtt.messageFor && topic && topic.length > 0) {
            return mqtt.messageFor(topic, fallback)
        }
        return fallback
    }

    function controlValue(control) {
        var fallback = control.value || ""
        if (control.mqttTopic && control.mqttTopic.length > 0) {
            return topicValue(control.mqttTopic, fallback)
        }
        return itemState(control.item || "", fallback)
    }

    function isOnState(state) {
        var normalized = String(state).trim().toUpperCase()
        if (normalized === "ON" || normalized === "OPEN" || normalized === "DOWN" || normalized === "LOCKED" || normalized === "HOME") {
            return true
        }
        var number = Number(normalized.split(" ")[0])
        return !isNaN(number) && number > 0
    }

    function sendControl(control) {
        if (control.mqttTopic && control.mqttTopic.length > 0) {
            sendMqtt(control)
            return
        }

        if (!openhab || !control.item || control.item.length === 0) {
            return
        }

        if (control.command) {
            openhab.sendCommand(control.item, control.command)
            return
        }

        var currentState = itemState(control.item, control.value || "OFF")
        var onCommand = control.onCommand || "ON"
        var offCommand = control.offCommand || "OFF"
        openhab.sendCommand(control.item, isOnState(currentState) ? offCommand : onCommand)
    }

    function sendMqtt(control) {
        if (!mqtt || !mqtt.publish || !control.mqttTopic || control.mqttTopic.length === 0) {
            return
        }
        var qos = control.mqttQos !== undefined ? control.mqttQos : 0
        var retain = control.mqttRetain === true

        if (control.mqttPayload !== undefined && control.mqttPayload !== null) {
            mqtt.publish(control.mqttTopic, String(control.mqttPayload), qos, retain)
            return
        }

        var currentState = topicValue(control.mqttTopic, control.value || "OFF")
        var onPayload = control.mqttOnPayload || control.onCommand || "ON"
        var offPayload = control.mqttOffPayload || control.offCommand || "OFF"
        mqtt.publish(control.mqttTopic, isOnState(currentState) ? offPayload : onPayload, qos, retain)
    }

    implicitWidth: 292
    implicitHeight: contentColumn.implicitHeight + 2 * contentColumn.anchors.margins
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: root.title
            color: "#e2e8f0"
            font.pixelSize: 18
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        GridLayout {
            id: controlsGrid
            Layout.fillWidth: true
            columnSpacing: 10
            rowSpacing: 10
            columns: root.effectiveColumns

            Repeater {
                model: root.controls

                ControlTile {
                    readonly property string rawValue: root.controlValue(modelData)
                    label: modelData.label || "Control"
                    value: Fmt.smart(rawValue)
                    secondary: modelData.secondary || ""
                    iconText: modelData.iconText || ""
                    active: root.isOnState(rawValue)
                    interactive: !!(modelData.item || modelData.mqttTopic)
                    accentColor: modelData.accentColor || "#f59e0b"
                    onClicked: root.sendControl(modelData)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                }
            }
        }
    }
}
