import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""
    property string powerValue: ""

    readonly property int minValue: control.min !== undefined ? control.min : 0
    readonly property int maxValue: control.max !== undefined ? control.max : 100
    readonly property int onLevel: control.onLevel !== undefined ? control.onLevel : maxValue
    readonly property real stepSize: control.step !== undefined ? Number(control.step) : 1
    readonly property bool hidePower: !!(control.hidePower)
    readonly property string unitSuffix: control.unit !== undefined ? String(control.unit) : "%"
    readonly property real currentValue: {
        var raw = String(rawValue).trim()
        if (raw.length === 0) {
            return 0
        }
        var match = raw.match(/^-?\d+(?:\.\d+)?/)
        if (!match) {
            return 0
        }
        var n = Number(match[0])
        return isNaN(n) ? 0 : n
    }
    readonly property bool hasPowerItem: !!(control.powerItem && control.powerItem.length > 0)
    readonly property bool isActive: {
        if (hidePower) {
            return false
        }
        if (hasPowerItem && panel) {
            return panel.isOnState(powerValue)
        }
        return currentValue > 0
    }
    readonly property color accent: control.accentColor || "#fbbf24"
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)

    function formatDisplayValue(value) {
        var rounded = Math.round(value)
        if (control.unit !== undefined) {
            return unitSuffix.length > 0 ? (rounded + " " + unitSuffix) : String(rounded)
        }
        return rounded + "%"
    }

    function powerControl() {
        return {
            item: control.powerItem || "",
            mqttTopic: control.powerMqttTopic || ""
        }
    }

    implicitWidth: 160
    implicitHeight: contentLayout.implicitHeight + 2 * Fmt.tileMargin
    radius: (dashboardConfig.lcars ? 18 : 12)
    color: (dashboardConfig.lcars ? "#000000" : (isActive ? "#26364d" : "#172235"))
    border.color: (dashboardConfig.lcars ? (isActive ? "#FFCC66" : "#FF9966") : (isActive ? accent : "#304158"))
    border.width: (dashboardConfig.lcars ? 0 : 1)
    clip: true

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: root.isActive ? root.accent : "#263449"

                Text {
                    anchors.centerIn: parent
                    text: root.control.iconText || "B"
                    color: root.isActive ? "#111827" : "#cbd5e1"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Text {
                text: root.control.label || "Dimmer"
                color: (dashboardConfig.lcars ? "#FFCC99" : "#cbd5e1")
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.formatDisplayValue(root.currentValue)
                color: (dashboardConfig.lcars ? "#FFFF99" : "#f8fafc")
                font.pixelSize: 11
                font.bold: true
            }
        }

        PowerButtons {
            Layout.fillWidth: true
            visible: !root.hidePower
            panel: root.panel
            targetControl: root.hasPowerItem ? root.powerControl() : root.control
            powerOn: root.isActive
            onCommand: root.hasPowerItem
                    ? (root.control.onCommand || "ON")
                    : String(root.onLevel)
            offCommand: root.hasPowerItem
                    ? (root.control.offCommand || "OFF")
                    : "0"
            accent: root.accent
            enabled: root.hasBinding || root.hasPowerItem
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            from: root.minValue
            to: root.maxValue
            stepSize: root.stepSize
            value: Math.max(root.minValue, Math.min(root.maxValue, root.currentValue))
            enabled: root.hasBinding
            live: false
            onPressedChanged: {
                if (!pressed && root.panel) {
                    root.panel.dispatchCommand(root.control, String(Math.round(value)))
                }
            }
        }
    }
}
