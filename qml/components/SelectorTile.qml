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

    function _isActive(opt) {
        if (!opt) { return false }
        var value = opt.value !== undefined ? String(opt.value) : ""
        return value.length > 0 && value.toUpperCase() === currentValue.toUpperCase()
    }

    implicitWidth: Math.max(160, options.length * 78 + 24)
    implicitHeight: contentColumn.implicitHeight + 2 * contentColumn.anchors.margins
    radius: 12
    color: "#172235"
    border.color: "#304158"
    border.width: 1

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        Text {
            text: root.control.label || "Auswahl"
            color: "#cbd5e1"
            font.pixelSize: 12
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
                    implicitHeight: 28
                    radius: 6
                    color: active ? root.accent : "#0f1726"
                    border.color: active ? root.accent : "#304158"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: btn.opt && btn.opt.label !== undefined ? btn.opt.label : (btn.opt ? btn.opt.value : "")
                        color: btn.active ? "#111827" : "#cbd5e1"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !!(root.panel && root.control && (root.control.item || root.control.mqttTopic))
                        onClicked: {
                            if (root.panel && btn.opt && btn.opt.value !== undefined) {
                                root.panel.dispatchCommand(root.control, String(btn.opt.value))
                            }
                        }
                    }
                }
            }
        }
    }
}
