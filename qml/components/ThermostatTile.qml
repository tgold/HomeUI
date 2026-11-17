import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""
    property string currentValue: ""

    readonly property real step: control.step !== undefined ? Number(control.step) : 0.5
    readonly property real minValue: control.min !== undefined ? Number(control.min) : 5
    readonly property real maxValue: control.max !== undefined ? Number(control.max) : 30
    readonly property color accent: control.accentColor || "#f97316"
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)

    readonly property real setpoint: {
        var raw = String(rawValue).trim()
        if (raw.length === 0) {
            return NaN
        }
        var match = raw.match(/^-?\d+(?:\.\d+)?/)
        if (!match) {
            return NaN
        }
        var n = Number(match[0])
        return isNaN(n) ? NaN : n
    }

    function nudge(delta) {
        if (!panel || !hasBinding) {
            return
        }
        var base = isNaN(setpoint) ? (minValue + maxValue) / 2 : setpoint
        var next = Math.max(minValue, Math.min(maxValue, base + delta))
        next = Math.round(next * 10) / 10
        panel.dispatchCommand(control, String(next))
    }

    implicitWidth: 160
    implicitHeight: 108
    radius: (dashboardConfig.lcars ? 18 : 12)
    color: (dashboardConfig.lcars ? "#000000" : "#172235")
    border.color: (dashboardConfig.lcars ? "#FF9966" : "#304158")
    border.width: (dashboardConfig.lcars ? 0 : 1)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.control.label || "Thermostat"
                color: (dashboardConfig.lcars ? "#FFCC99" : "#cbd5e1")
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.currentValue.length > 0 ? Fmt.temperature(root.currentValue) : ""
                color: (dashboardConfig.lcars ? "#CC9966" : "#94a3b8")
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 36
                Layout.fillHeight: true
                radius: dashboardConfig.lcars ? height / 2 : 8
                color: dashboardConfig.lcars
                       ? (minusArea.pressed ? "#FFCC66" : "#FF9966")
                       : (minusArea.pressed ? root.accent : "#1f2d44")
                border.color: "#304158"
                border.width: dashboardConfig.lcars ? 0 : 1

                Text {
                    anchors.centerIn: parent
                    text: "\u2212"
                    color: dashboardConfig.lcars ? "#000000" : (minusArea.pressed ? "#111827" : "#e2e8f0")
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: minusArea
                    anchors.fill: parent
                    enabled: root.hasBinding
                    onClicked: root.nudge(-root.step)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: dashboardConfig.lcars ? height / 2 : 8
                color: dashboardConfig.lcars ? "#000000" : "#0f1726"
                border.color: "#26364d"
                border.width: dashboardConfig.lcars ? 0 : 1

                Text {
                    anchors.centerIn: parent
                    text: isNaN(root.setpoint) ? "--.- \u00B0C"
                                               : Fmt.temperature(String(root.setpoint))
                    color: dashboardConfig.lcars ? "#FFFF99" : root.accent
                    font.pixelSize: 18
                    font.bold: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.fillHeight: true
                radius: dashboardConfig.lcars ? height / 2 : 8
                color: dashboardConfig.lcars
                       ? (plusArea.pressed ? "#FFCC66" : "#99CCFF")
                       : (plusArea.pressed ? root.accent : "#1f2d44")
                border.color: "#304158"
                border.width: dashboardConfig.lcars ? 0 : 1

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: dashboardConfig.lcars ? "#000000" : (plusArea.pressed ? "#111827" : "#e2e8f0")
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: plusArea
                    anchors.fill: parent
                    enabled: root.hasBinding
                    onClicked: root.nudge(root.step)
                }
            }
        }
    }
}
