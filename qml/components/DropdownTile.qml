import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""

    readonly property var options: Fmt.asArray(control.options)
    readonly property color accent: control.accentColor || "#fbbf24"
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)

    function _optionCommand(opt) {
        if (!opt) {
            return ""
        }
        if (opt.command !== undefined && opt.command !== null) {
            return String(opt.command)
        }
        return opt.value !== undefined && opt.value !== null ? String(opt.value) : ""
    }

    // Normalise both the raw state and the option values so "2" and "2.0"
    // map to the same selection.
    function _normalize(v) {
        if (v === undefined || v === null) {
            return ""
        }
        var s = String(v).trim()
        if (s.length === 0) {
            return ""
        }
        var n = Number(s)
        if (!isNaN(n)) {
            return String(n)
        }
        return s.toUpperCase()
    }

    function _indexOfCurrent() {
        var key = _normalize(rawValue)
        for (var i = 0; i < options.length; ++i) {
            var opt = options[i]
            if (opt && _normalize(opt.value) === key) {
                return i
            }
            var activeValues = Fmt.asArray(opt ? opt.activeValues : [])
            for (var j = 0; j < activeValues.length; ++j) {
                if (_normalize(activeValues[j]) === key) {
                    return i
                }
            }
        }
        return -1
    }

    function _labelFor(value) {
        var key = _normalize(value)
        for (var i = 0; i < options.length; ++i) {
            var opt = options[i]
            if (opt && _normalize(opt.value) === key) {
                return opt.label !== undefined ? String(opt.label) : String(opt.value)
            }
        }
        return value === undefined || value === null ? "" : String(value)
    }

    readonly property string currentLabel: _labelFor(rawValue)

    implicitWidth: 200
    implicitHeight: 80
    radius: 12
    color: "#172235"
    border.color: "#304158"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 6

        Text {
            text: root.control.label || "Modus"
            color: "#cbd5e1"
            font.pixelSize: 12
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        ComboBox {
            id: comboBox
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            enabled: root.hasBinding && root.options.length > 0
            model: root.options
            textRole: "label"
            valueRole: "value"
            displayText: root.currentLabel.length > 0 ? root.currentLabel : "—"

            background: Rectangle {
                radius: 6
                color: "#0f1726"
                border.color: "#304158"
            }

            contentItem: Text {
                leftPadding: 8
                rightPadding: comboBox.indicator.width + comboBox.spacing
                text: comboBox.displayText
                color: "#f8fafc"
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            indicator: Text {
                x: comboBox.width - width - 8
                y: comboBox.topPadding + (comboBox.availableHeight - height) / 2
                text: "▾"
                color: "#94a3b8"
                font.pixelSize: 10
            }

            // Keep the popup selection in sync with the live OpenHAB / MQTT
            // state, but only while the popup is closed so a slow round-trip
            // does not yank a user-picked entry away mid-selection.
            currentIndex: root.options.length > 0 && !popup.visible
                          ? root._indexOfCurrent()
                          : currentIndex

            onActivated: function(index) {
                if (index < 0 || index >= root.options.length) {
                    return
                }
                var opt = root.options[index]
                var command = root._optionCommand(opt)
                if (root.panel && command.length > 0) {
                    root.panel.dispatchCommand(root.control, command)
                }
            }
        }
    }
}
