import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""
    property string secondary: ""

    readonly property bool isOn: panel ? panel.isOnState(rawValue) : false
    readonly property color accent: control.accentColor || "#f59e0b"
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)
    readonly property string onCmd: control.onCommand || control.mqttOnPayload || "ON"
    readonly property string offCmd: control.offCommand || control.mqttOffPayload || "OFF"
    readonly property bool singleShot: !!(control.command
            || (control.mqttPayload !== undefined && control.mqttPayload !== null))

    implicitWidth: 160
    implicitHeight: contentLayout.implicitHeight + 2 * Fmt.tileMargin
    radius: 12
    color: isOn ? "#26364d" : "#172235"
    border.color: isOn ? accent : "#304158"
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
                color: root.isOn ? root.accent : "#263449"

                Text {
                    anchors.centerIn: parent
                    text: root.control.iconText || ""
                    color: root.isOn ? "#111827" : "#cbd5e1"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Text {
                text: root.control.label || "Control"
                color: "#cbd5e1"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: Fmt.smart(root.rawValue)
                color: "#94a3b8"
                font.pixelSize: 10
                Layout.alignment: Qt.AlignVCenter
            }
        }

        PowerButtons {
            Layout.fillWidth: true
            visible: !root.singleShot
            panel: root.panel
            targetControl: root.control
            powerOn: root.isOn
            onCommand: root.onCmd
            offCommand: root.offCmd
            accent: root.accent
            enabled: root.hasBinding
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Fmt.actionButtonHeight
            visible: root.singleShot
            radius: 8
            color: pressArea.pressed ? root.accent : "#0f1726"
            border.color: root.accent
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: root.control.commandLabel || root.control.label || "Senden"
                color: pressArea.pressed ? "#111827" : "#e2e8f0"
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                id: pressArea
                anchors.fill: parent
                enabled: root.hasBinding
                onClicked: {
                    if (root.panel) {
                        root.panel.toggleSwitch(root.control)
                    }
                }
            }
        }

        Text {
            text: root.secondary
            visible: root.secondary.length > 0
            color: "#94a3b8"
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
