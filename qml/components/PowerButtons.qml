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
        radius: dashboardConfig.lcars ? 18 : 8
        color: dashboardConfig.lcars ? (root.powerOn ? "#FFCC66" : "#000000") : (root.powerOn ? root.accent : "#0f1726")
        border.color: dashboardConfig.lcars ? "#FFCC66" : (root.powerOn ? root.accent : "#304158")
        border.width: dashboardConfig.lcars && root.powerOn ? 0 : 1

        Text {
            anchors.centerIn: parent
            text: "ON"
            color: dashboardConfig.lcars ? (root.powerOn ? "#000000" : "#FFCC66") : (root.powerOn ? "#111827" : "#cbd5e1")
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
        radius: dashboardConfig.lcars ? 18 : 8
        color: dashboardConfig.lcars ? (!root.powerOn ? "#CC99CC" : "#000000") : (!root.powerOn ? "#334155" : "#0f1726")
        border.color: dashboardConfig.lcars ? "#CC99CC" : (!root.powerOn ? "#64748b" : "#304158")
        border.width: dashboardConfig.lcars && !root.powerOn ? 0 : 1

        Text {
            anchors.centerIn: parent
            text: "OFF"
            color: dashboardConfig.lcars ? (!root.powerOn ? "#000000" : "#CC99CC") : (!root.powerOn ? "#f8fafc" : "#cbd5e1")
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
