import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""
    property string temperatureValue: ""
    property string powerValue: ""

    readonly property int minValue: control.min !== undefined ? control.min : 0
    readonly property int maxValue: control.max !== undefined ? control.max : 100
    readonly property int onLevel: control.onLevel !== undefined ? control.onLevel : maxValue
    readonly property int temperatureMin: control.temperatureMin !== undefined ? control.temperatureMin : 0
    readonly property int temperatureMax: control.temperatureMax !== undefined ? control.temperatureMax : 100
    readonly property real currentValue: parseNumeric(rawValue)
    readonly property real currentTemperature: parseNumeric(temperatureValue)
    readonly property bool hasPowerItem: !!(control.powerItem && control.powerItem.length > 0)
    readonly property bool hasTemperatureItem: !!(control.temperatureItem && control.temperatureItem.length > 0)
    readonly property bool isActive: {
        if (hasPowerItem && panel) {
            return panel.isOnState(powerValue)
        }
        return currentValue > 0
    }
    readonly property color accent: control.accentColor || "#fbbf24"
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)

    function parseNumeric(raw) {
        var text = String(raw).trim()
        if (text.length === 0) {
            return 0
        }
        var match = text.match(/^-?\d+(?:\.\d+)?/)
        if (!match) {
            return 0
        }
        var n = Number(match[0])
        return isNaN(n) ? 0 : n
    }

    function powerControl() {
        return {
            item: control.powerItem || "",
            mqttTopic: control.powerMqttTopic || "",
            commandTopic: control.powerCommandTopic || ""
        }
    }

    function temperatureControl() {
        return {
            item: control.temperatureItem || "",
            commandItem: control.temperatureCommandItem || "",
            mqttTopic: control.temperatureMqttTopic || "",
            commandTopic: control.temperatureCommandTopic || ""
        }
    }

    function sendBrightness(value) {
        if (!panel) {
            return
        }
        panel.dispatchCommand(control, String(Math.round(value)))
    }

    function sendTemperature(value) {
        if (!panel || !hasTemperatureItem) {
            return
        }
        panel.dispatchCommand(temperatureControl(),
                              String(Math.round(Math.max(temperatureMin,
                                                         Math.min(temperatureMax, value)))))
    }

    implicitWidth: 200
    implicitHeight: contentLayout.implicitHeight + 2 * Fmt.tileMargin
    radius: 12
    color: isActive ? "#26364d" : "#172235"
    border.color: isActive ? accent : "#304158"
    border.width: 1
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
                    text: root.control.iconText || "L"
                    color: root.isActive ? "#111827" : "#cbd5e1"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Text {
                text: root.control.label || "Licht"
                color: "#cbd5e1"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(root.currentValue) + "%"
                color: "#f8fafc"
                font.pixelSize: 11
                font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.hasTemperatureItem

            Text {
                text: "Kalt"
                color: "#94a3b8"
                font.pixelSize: 9
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                radius: 9
                border.color: "#304158"
                border.width: 1
                clip: true
                opacity: root.hasTemperatureItem ? 1 : 0.5

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#93c5fd" }
                    GradientStop { position: 1.0; color: "#fdba74" }
                }

                Rectangle {
                    id: temperatureMarker
                    width: 6
                    height: parent.height + 4
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(-width / 2,
                                Math.min(parent.width - width / 2,
                                         ((root.currentTemperature - root.temperatureMin)
                                          / Math.max(1, root.temperatureMax - root.temperatureMin))
                                         * parent.width - width / 2))
                    color: "transparent"
                    border.color: "#f8fafc"
                    border.width: 2
                    radius: 3
                }

                MouseArea {
                    id: temperatureArea
                    anchors.fill: parent
                    enabled: root.hasTemperatureItem
                    preventStealing: true
                    property bool dragging: false

                    onPressed: { dragging = true; updateLocal(mouse) }
                    onPositionChanged: if (dragging) { updateLocal(mouse) }
                    onReleased: { if (dragging) { commit(mouse) } dragging = false }
                    onCanceled: dragging = false

                    function updateLocal(mouse) {
                        var x = Math.max(0, Math.min(width, mouse.x))
                        temperatureMarker.x = x - temperatureMarker.width / 2
                    }

                    function commit(mouse) {
                        var x = Math.max(0, Math.min(width, mouse.x))
                        var value = root.temperatureMin
                                + (x / width) * (root.temperatureMax - root.temperatureMin)
                        root.sendTemperature(value)
                    }
                }
            }

            Text {
                text: "Warm"
                color: "#94a3b8"
                font.pixelSize: 9
                font.bold: true
            }
        }

        Slider {
            id: brightnessSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            from: root.minValue
            to: root.maxValue
            stepSize: 1
            value: Math.max(root.minValue, Math.min(root.maxValue, root.currentValue))
            enabled: root.hasBinding
            live: false
            onPressedChanged: {
                if (!pressed) {
                    root.sendBrightness(value)
                }
            }
        }

        PowerButtons {
            Layout.fillWidth: true
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
    }
}
