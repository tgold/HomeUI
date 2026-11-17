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
    radius: dashboardConfig.lcars ? 0 : 18
    color: dashboardConfig.lcars ? "#000000" : "#0f1726"
    border.color: dashboardConfig.lcars ? "#000000" : "#26364d"
    border.width: dashboardConfig.lcars ? 0 : 1

    LcarsElbow {
        id: lcarsElbow
        seed: root.title
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: lcarsElbow.contentMargin
        spacing: Fmt.panelSpacing

        RowLayout {
            Layout.fillWidth: true

            PanelHeader {
                Layout.fillWidth: true
                title: root.title
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
