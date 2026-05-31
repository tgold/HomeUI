import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""

    readonly property real currentPosition: {
        var raw = String(rawValue).trim().toUpperCase()
        // For plain Switch shutters this codebase treats ON as "open / up" and
        // OFF as "closed / down" to match the KNX rules in this installation.
        // If your binding is wired the other way around, set `invertSwitch`
        // on the control – or just swap upCommand/downCommand.
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

    implicitWidth: 160
    implicitHeight: 104
    radius: 12
    color: isClosed ? "#26364d" : "#172235"
    border.color: isClosed ? accent : "#304158"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.control.label || "Rollo"
                color: "#cbd5e1"
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.positionLabel()
                color: "#f8fafc"
                font.pixelSize: 13
                font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.stopVisible
                       ? [
                           { id: "up",   icon: "\u25B2", cmd: root.upCommand },
                           { id: "stop", icon: "\u25A0", cmd: root.stopCommand },
                           { id: "down", icon: "\u25BC", cmd: root.downCommand }
                         ]
                       : [
                           { id: "up",   icon: "\u25B2", cmd: root.upCommand },
                           { id: "down", icon: "\u25BC", cmd: root.downCommand }
                         ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: 1
                    radius: 8
                    color: pressArea.pressed ? root.accent : "#1f2d44"
                    border.color: "#304158"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: pressArea.pressed ? "#111827" : "#e2e8f0"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    MouseArea {
                        id: pressArea
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
        }
    }
}
