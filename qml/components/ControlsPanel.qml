import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "Controls"
    property var controls: []
    property var openhab: null
    property int stateRevision: openhab ? openhab.stateRevision : 0

    function itemState(itemName, fallback) {
        stateRevision
        if (openhab && itemName && itemName.length > 0) {
            return openhab.itemState(itemName, fallback)
        }
        return fallback
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

    implicitWidth: 292
    implicitHeight: 118
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    ColumnLayout {
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: root.controls

                ControlTile {
                    label: modelData.label || "Control"
                    value: root.itemState(modelData.item || "", modelData.value || "")
                    secondary: modelData.secondary || ""
                    iconText: modelData.iconText || ""
                    active: root.isOnState(value)
                    interactive: !!modelData.item
                    accentColor: modelData.accentColor || "#f59e0b"
                    onClicked: root.sendControl(modelData)
                    Layout.fillWidth: true
                }
            }
        }
    }
}
