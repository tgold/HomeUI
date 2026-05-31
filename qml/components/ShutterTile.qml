import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""
    property string sceneValue: ""

    readonly property var sceneOptions: Fmt.asArray(control.options)
    readonly property bool hasSceneButtons: sceneOptions.length > 0 && !!(control.sceneItem || control.commandItem)

    readonly property real currentPosition: {
        var raw = String(rawValue).trim().toUpperCase()
        switch (raw) {
        case "UP":
        case "OPEN":
        case "FULLUP":
            return 0
        case "ON":
            return control && control.invertSwitch === true ? 100 : 0
        case "OFF":
            return control && control.invertSwitch === true ? 0 : 100
        case "HALFDOWN":
        case "HALFUP":
            return 50
        case "DOWN":
        case "CLOSED":
        case "FULLDOWN":
            return 100
        case "FULLSTOP":
        case "STOP":
            return -1
        }
        var match = raw.match(/^-?\d+(?:\.\d+)?/)
        if (!match) {
            return -1
        }
        var n = Number(match[0])
        return isNaN(n) ? -1 : n
    }
    readonly property bool isClosed: currentPosition >= 50
    readonly property color accent: control.accentColor || "#38bdf8"
    readonly property bool hasBinding: !!(control.item || control.commandItem || control.mqttTopic || control.commandTopic)
    readonly property string upCommand: control.upCommand || "UP"
    readonly property string stopCommand: control.stopCommand || "STOP"
    readonly property string downCommand: control.downCommand || "DOWN"
    readonly property bool stopVisible: control.hideStop !== true
    readonly property string sceneState: String(sceneValue).trim()
    readonly property int buttonHeight: 28

    function positionLabel() {
        var pos = currentPosition
        if (pos < 0) {
            var raw = String(rawValue).trim()
            return raw.length > 0 ? raw : "--"
        }
        if (pos <= 0) {
            return "offen"
        }
        if (pos >= 100) {
            return "zu"
        }
        return Math.round(pos) + " %"
    }

    function sceneControl() {
        return {
            item: control.sceneItem || control.commandItem || "",
            mqttTopic: control.sceneMqttTopic || control.commandTopic || "",
            commandTopic: control.commandTopic || ""
        }
    }

    function _isSceneActive(opt) {
        if (!opt) {
            return false
        }
        var value = opt.value !== undefined ? String(opt.value) : ""
        return value.length > 0 && value.toUpperCase() === sceneState.toUpperCase()
    }

    implicitWidth: 160
    implicitHeight: contentLayout.implicitHeight + 2 * Fmt.tileMargin
    radius: 12
    color: isClosed ? "#26364d" : "#172235"
    border.color: isClosed ? accent : "#304158"
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

            Text {
                text: root.control.label || "Rollo"
                color: "#cbd5e1"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.positionLabel()
                color: "#94a3b8"
                font.pixelSize: 10
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.stopVisible
                       ? [
                           { icon: "\u25B2", cmd: root.upCommand },
                           { icon: "\u25A0", cmd: root.stopCommand },
                           { icon: "\u25BC", cmd: root.downCommand }
                         ]
                       : [
                           { icon: "\u25B2", cmd: root.upCommand },
                           { icon: "\u25BC", cmd: root.downCommand }
                         ]

                Rectangle {
                    Layout.preferredWidth: root.buttonHeight
                    Layout.preferredHeight: root.buttonHeight
                    radius: 6
                    color: movePress.pressed ? root.accent : "#1f2d44"
                    border.color: "#304158"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: movePress.pressed ? "#111827" : "#e2e8f0"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: movePress
                        anchors.fill: parent
                        enabled: root.hasBinding
                        onClicked: {
                            if (root.panel) {
                                root.panel.dispatchCommand(root.control, modelData.cmd)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.hasSceneButtons
            spacing: 4

            Repeater {
                model: root.sceneOptions

                Rectangle {
                    readonly property var opt: modelData
                    readonly property bool sceneActive: root._isSceneActive(modelData)

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.buttonHeight
                    radius: 6
                    color: sceneActive ? root.accent : "#0f1726"
                    border.color: sceneActive ? root.accent : "#304158"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 6
                        text: parent.opt && parent.opt.label !== undefined
                              ? parent.opt.label
                              : (parent.opt ? parent.opt.value : "")
                        color: parent.sceneActive ? "#111827" : "#cbd5e1"
                        font.pixelSize: 10
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hasSceneButtons && root.panel
                        onClicked: {
                            if (root.panel && parent.opt && parent.opt.value !== undefined) {
                                root.panel.dispatchCommand(root.sceneControl(),
                                                           String(parent.opt.value))
                            }
                        }
                    }
                }
            }
        }
    }
}
