import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""

    readonly property color accent: control.accentColor || "#a855f7"
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)
    readonly property bool pressed: pressArea.pressed
    readonly property color lcarsFill: {
        var colors = ["#FF9966", "#FFCC66", "#99CCFF", "#CC99CC", "#FFCC99", "#E7B08A"]
        var s = String(control.label || "")
        var hash = 0
        for (var i = 0; i < s.length; ++i) {
            hash = (hash * 33 + s.charCodeAt(i)) >>> 0
        }
        return colors[hash % colors.length]
    }

    implicitWidth: 140
    implicitHeight: 76
    radius: dashboardConfig.lcars ? height / 2 : 12
    color: dashboardConfig.lcars ? (pressed ? "#FFCC66" : lcarsFill) : (pressed ? root.accent : "#172235")
    border.color: pressed ? "#f8fafc" : root.accent
    border.width: dashboardConfig.lcars ? 0 : 1

    MouseArea {
        id: pressArea
        anchors.fill: parent
        enabled: root.hasBinding
        onClicked: {
            if (!root.panel) {
                return
            }
            var payload = root.control.command
            if (!payload && root.control.mqttPayload !== undefined) {
                payload = String(root.control.mqttPayload)
            }
            if (!payload) {
                payload = "ON"
            }
            root.panel.dispatchCommand(root.control, payload)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: dashboardConfig.lcars ? "#000000" : (root.pressed ? "#111827" : root.accent)

                Text {
                    anchors.centerIn: parent
                    text: root.control.iconText || "S"
                    color: dashboardConfig.lcars ? "#FFCC66" : (root.pressed ? root.accent : "#111827")
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: root.control.label || "Szene"
                    color: dashboardConfig.lcars ? "#000000" : (root.pressed ? "#0f172a" : "#e2e8f0")
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.control.secondary || ""
                    visible: !!root.control.secondary
                    color: dashboardConfig.lcars ? "#000000" : (root.pressed ? "#0f172a" : "#94a3b8")
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
