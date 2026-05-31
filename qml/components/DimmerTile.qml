import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""

    readonly property int minValue: control.min !== undefined ? control.min : 0
    readonly property int maxValue: control.max !== undefined ? control.max : 100
    readonly property int onLevel: control.onLevel !== undefined ? control.onLevel : maxValue
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
    readonly property bool isActive: currentValue > 0
    readonly property color accent: control.accentColor || "#fbbf24"
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)

    implicitWidth: 160
    implicitHeight: 104
    radius: 12
    color: isActive ? "#26364d" : "#172235"
    border.color: isActive ? accent : "#304158"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.control.label || "Dimmer"
                color: "#cbd5e1"
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(root.currentValue) + " %"
                color: "#f8fafc"
                font.pixelSize: 14
                font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 8
                color: root.isActive ? root.accent : "#263449"

                Text {
                    anchors.centerIn: parent
                    text: root.control.iconText || "B"
                    color: root.isActive ? "#111827" : "#cbd5e1"
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasBinding
                    onClicked: {
                        if (!root.panel) {
                            return
                        }
                        root.panel.dispatchCommand(root.control,
                                                   root.isActive ? "0" : String(root.onLevel))
                    }
                }
            }

            Slider {
                id: slider
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                from: root.minValue
                to: root.maxValue
                stepSize: 1
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
}
