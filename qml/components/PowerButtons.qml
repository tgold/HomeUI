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
    property string label: ""

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

    function toggle() {
        if (root.powerOn) {
            root.sendOff()
        } else {
            root.sendOn()
        }
    }

    readonly property color lcarsFill: root.powerOn ? "#FFCC66" : "#FF9966"

    Rectangle {
        id: lcarsButton
        Layout.fillWidth: true
        Layout.preferredHeight: root.buttonHeight
        visible: dashboardConfig.lcars
        radius: height / 2
        color: root.lcarsFill
        clip: true

        readonly property int stateWidth: 76

        Text {
            anchors.left: parent.left
            anchors.right: separator.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            text: root.label
            color: "#000000"
            font.pixelSize: 14
            font.bold: true
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Rectangle {
            id: separator
            width: 2
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: lcarsButton.stateWidth
            color: "#000000"
        }

        Text {
            anchors.left: separator.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.powerOn ? "ON" : "OFF"
            color: "#000000"
            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            onClicked: root.toggle()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.buttonHeight
        visible: !dashboardConfig.lcars
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
        visible: !dashboardConfig.lcars
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
