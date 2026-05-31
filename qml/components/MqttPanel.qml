import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string title: "MQTT"
    property var items: []
    property var mqtt: null
    property int messageRevision: mqtt && mqtt.messageRevision !== undefined ? mqtt.messageRevision : 0

    function topicValue(topic, fallback) {
        messageRevision
        if (mqtt && mqtt.messageFor && topic && topic.length > 0) {
            return mqtt.messageFor(topic, fallback)
        }
        return fallback
    }

    implicitWidth: 292
    implicitHeight: 200
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.panelMargin
        spacing: Fmt.panelSpacing

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                color: "#e2e8f0"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 28
                radius: 9
                color: "#172235"
                border.color: "#334155"

                Text {
                    anchors.centerIn: parent
                    text: "MQTT"
                    color: root.mqtt && root.mqtt.connected ? "#22c55e" : "#94a3b8"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        Repeater {
            model: root.items

            MetricRow {
                label: modelData.label || modelData.topic || "topic"
                value: Fmt.smart(root.topicValue(modelData.topic || "", modelData.fallback || "--"))
                detail: modelData.detail || ""
                warning: modelData.warning === true
                Layout.fillWidth: true
            }
        }
    }
}
