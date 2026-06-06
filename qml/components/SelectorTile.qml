import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""

    readonly property var options: Fmt.asArray(control.options)
    readonly property color accent: control.accentColor || "#38bdf8"
    readonly property string currentValue: String(rawValue).trim()

    function _commandFor(opt) {
        if (!opt) { return "" }
        if (opt.command !== undefined && opt.command !== null) {
            return String(opt.command)
        }
        return opt.value !== undefined && opt.value !== null ? String(opt.value) : ""
    }

    function _isActive(opt) {
        if (!opt) { return false }
        var values = []
        if (opt.value !== undefined && opt.value !== null) {
            values.push(opt.value)
        }
        var aliases = Fmt.asArray(opt.activeValues)
        for (var aliasIndex = 0; aliasIndex < aliases.length; ++aliasIndex) {
            values.push(aliases[aliasIndex])
        }
        for (var i = 0; i < values.length; ++i) {
            var value = values[i] !== undefined && values[i] !== null ? String(values[i]) : ""
            if (value.length > 0 && value.toUpperCase() === currentValue.toUpperCase()) {
                return true
            }
        }
        return false
    }

    readonly property int buttonHeight: control.buttonHeight !== undefined
            ? Number(control.buttonHeight)
            : Fmt.selectorButtonHeight

    implicitWidth: Math.max(140, options.length * 72 + 20)
    implicitHeight: contentColumn.implicitHeight + 2 * contentColumn.anchors.margins
    radius: 12
    color: "#172235"
    border.color: "#304158"
    border.width: 1

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 4

        Text {
            text: root.control.label || "Auswahl"
            color: "#cbd5e1"
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.options

                Rectangle {
                    id: btn
                    readonly property var opt: modelData
                    readonly property bool active: root._isActive(modelData)

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.buttonHeight
                    radius: 8
                    color: active ? root.accent : "#0f1726"
                    border.color: active ? root.accent : "#304158"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: btn.opt && btn.opt.label !== undefined ? btn.opt.label : (btn.opt ? btn.opt.value : "")
                        color: btn.active ? "#111827" : "#cbd5e1"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !!(root.panel && root.control && (root.control.item || root.control.mqttTopic))
                        onClicked: {
                            var command = root._commandFor(btn.opt)
                            if (root.panel && command.length > 0) {
                                root.panel.dispatchCommand(root.control, command)
                            }
                        }
                    }
                }
            }
        }
    }
}
