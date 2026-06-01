import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

RowLayout {
    id: root

    property var panel: null
    property var targetControl: ({})
    property bool powerOn: false
    property string onCommand: "ON"
    property string offCommand: "OFF"
    property color accent: "#fbbf24"
    property bool enabled: true

    spacing: 4

    readonly property int buttonHeight: Fmt.actionButtonHeight

    function sendOn() {
        if (root.panel && root.enabled) {
            root.panel.dispatchCommand(root.targetControl, root.onCommand)
        }
    }

    function sendOff() {
        if (root.panel && root.enabled) {
            root.panel.dispatchCommand(root.targetControl, root.offCommand)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.buttonHeight
        radius: 8
        color: root.powerOn ? root.accent : "#0f1726"
        border.color: root.powerOn ? root.accent : "#304158"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "ON"
            color: root.powerOn ? "#111827" : "#cbd5e1"
            font.pixelSize: 12
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: root.sendOn()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.buttonHeight
        radius: 8
        color: !root.powerOn ? "#334155" : "#0f1726"
        border.color: !root.powerOn ? "#64748b" : "#304158"
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "OFF"
            color: !root.powerOn ? "#f8fafc" : "#cbd5e1"
            font.pixelSize: 12
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: root.sendOff()
        }
    }
}
