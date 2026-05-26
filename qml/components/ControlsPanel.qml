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

    function controlSecondary(control) {
        if (control.currentItem && control.currentItem.length > 0) {
            return itemState(control.currentItem, control.secondary || "")
        }
        return control.secondary || ""
    }

    function isOnState(state) {
        var normalized = String(state).trim().toUpperCase()
        if (normalized === "ON" || normalized === "OPEN" || normalized === "DOWN" || normalized === "LOCKED" || normalized === "HOME") {
            return true
        }
        var number = Number(normalized.split(" ")[0])
        return !isNaN(number) && number > 0
    }

    // Generic dispatch used by every tile kind. Sends an arbitrary command
    // either to MQTT (preferred when mqttTopic is set) or to OpenHAB.
    function dispatchCommand(control, command) {
        if (!control || command === undefined || command === null) {
            return
        }
        var payload = String(command)
        if (control.mqttTopic && control.mqttTopic.length > 0) {
            if (!mqtt || !mqtt.publish) {
                return
            }
            var qos = control.mqttQos !== undefined ? control.mqttQos : 0
            var retain = control.mqttRetain === true
            mqtt.publish(control.mqttTopic, payload, qos, retain)
            return
        }
        if (!openhab || !control.item || control.item.length === 0) {
            return
        }
        openhab.sendCommand(control.item, payload)
    }

    // Toggle helper used by the default switch tile. Honours `command` for
    // single-shot pushes (e.g. doorbell triggers).
    function toggleSwitch(control) {
        if (!control) {
            return
        }
        if (control.command) {
            dispatchCommand(control, control.command)
            return
        }
        if (control.mqttTopic && control.mqttTopic.length > 0
                && control.mqttPayload !== undefined && control.mqttPayload !== null) {
            dispatchCommand(control, control.mqttPayload)
            return
        }
        var currentState = controlValue(control)
        var on = control.onCommand
                || control.mqttOnPayload
                || "ON"
        var off = control.offCommand
                || control.mqttOffPayload
                || "OFF"
        dispatchCommand(control, isOnState(currentState) ? off : on)
    }

    function controlKind(control) {
        if (!control) {
            return "switch"
        }
        var kind = (control.kind || control.widget || "switch").toLowerCase()
        switch (kind) {
        case "switch":
        case "dimmer":
        case "shutter":
        case "thermostat":
        case "scene":
            return kind
        default:
            return "switch"
        }
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

                Loader {
                    id: tileLoader
                    readonly property var control: modelData
                    readonly property string kind: root.controlKind(modelData)
                    readonly property string rawValue: root.controlValue(modelData)
                    readonly property string currentValue: root.controlSecondary(modelData)

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1

                    sourceComponent: {
                        switch (kind) {
                        case "dimmer":
                            return dimmerComponent
                        case "shutter":
                            return shutterComponent
                        case "thermostat":
                            return thermostatComponent
                        case "scene":
                            return sceneComponent
                        default:
                            return switchComponent
                        }
                    }
                }
            }
        }
    }

    Component {
        id: switchComponent

        ControlTile {
            readonly property var control: parent.control
            readonly property string rawValue: parent.rawValue
            label: control.label || "Control"
            value: Fmt.smart(rawValue)
            secondary: parent.currentValue
            iconText: control.iconText || ""
            active: root.isOnState(rawValue)
            interactive: !!(control.item || control.mqttTopic)
            accentColor: control.accentColor || "#f59e0b"
            onClicked: root.toggleSwitch(control)
        }
    }

    Component {
        id: dimmerComponent

        DimmerTile {
            control: parent.control
            panel: root
            rawValue: parent.rawValue
        }
    }

    Component {
        id: shutterComponent

        ShutterTile {
            control: parent.control
            panel: root
            rawValue: parent.rawValue
        }
    }

    Component {
        id: thermostatComponent

        ThermostatTile {
            control: parent.control
            panel: root
            rawValue: parent.rawValue
            currentValue: parent.currentValue
        }
    }

    Component {
        id: sceneComponent

        SceneTile {
            control: parent.control
            panel: root
            rawValue: parent.rawValue
        }
    }
}
