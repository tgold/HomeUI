import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""
    property string maxRawValue: {
        if (panel && panel.itemState && control && control.maxItem) {
            return panel.itemState(control.maxItem, "")
        }
        return ""
    }
    readonly property real scaleValue: control.scale !== undefined ? Number(control.scale) : 1
    readonly property bool invertValue: control.invert === true
    readonly property real invertBaseValue: {
        if (control.invertBase !== undefined) {
            return Number(control.invertBase)
        }
        if (control.max !== undefined) {
            return Number(control.max)
        }
        return 100
    }

    readonly property real minValue: control.min !== undefined ? Number(control.min) : 0
    readonly property real maxValue: control.max !== undefined ? Number(control.max) : 100
    readonly property real numericValue: {
        var raw = String(rawValue).trim()
        if (raw.length === 0) {
            return Number.NaN
        }
        var match = raw.match(/^-?\d+(?:\.\d+)?/)
        if (!match) {
            return Number.NaN
        }
        var n = Number(match[0])
        if (isNaN(n)) {
            return Number.NaN
        }
        var value = n * scaleValue
        if (invertValue) {
            value = invertBaseValue - value
        }
        return value
    }
    readonly property real maxNumericValue: {
        var raw = String(maxRawValue).trim()
        if (raw.length === 0) {
            return Number.NaN
        }
        var match = raw.match(/^-?\d+(?:\.\d+)?/)
        if (!match) {
            return Number.NaN
        }
        var n = Number(match[0])
        if (isNaN(n)) {
            return Number.NaN
        }
        return n * scaleValue
    }
    readonly property real progressFraction: {
        if (isNaN(numericValue)) {
            return 0
        }
        if (!isNaN(maxNumericValue) && maxNumericValue > 0) {
            return Math.max(0, Math.min(1, numericValue / maxNumericValue))
        }
        var span = maxValue - minValue
        if (span <= 0) {
            return 0
        }
        return Math.max(0, Math.min(1, (numericValue - minValue) / span))
    }
    readonly property color accent: control.accentColor || "#22c55e"

    function _formattedValue() {
        if (isNaN(numericValue)) {
            return Fmt.smart(rawValue)
        }
        var decimals = control.decimals !== undefined ? Number(control.decimals) : -1
        var unit = control.unit || ""
        if (unit.length === 0) {
            // If the raw state included a unit, preserve it via Fmt.smart.
            return Fmt.smart(rawValue)
        }
        if (decimals < 0) {
            decimals = (unit === "%" || unit === "W" || unit === "VA") ? 0 : 1
        }
        return numericValue.toFixed(decimals) + " " + unit
    }
    function _formattedMaxValue() {
        if (isNaN(maxNumericValue)) {
            return ""
        }
        var decimals = control.decimals !== undefined ? Number(control.decimals) : -1
        var unit = control.unit || ""
        if (unit.length === 0) {
            return String(maxNumericValue)
        }
        if (decimals < 0) {
            decimals = (unit === "%" || unit === "W" || unit === "VA") ? 0 : 1
        }
        return maxNumericValue.toFixed(decimals) + " " + unit
    }

    implicitWidth: 160
    implicitHeight: 78
    radius: 12
    color: "#172235"
    border.color: "#304158"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: root.control.label || "Wert"
                color: "#cbd5e1"
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: {
                    var maxText = root._formattedMaxValue()
                    if (maxText.length > 0) {
                        return root._formattedValue() + " / " + maxText
                    }
                    return root._formattedValue()
                }
                color: "#f8fafc"
                font.pixelSize: 14
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            radius: 5
            color: "#0b1322"
            border.color: "#26364d"
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 1
                width: Math.max(0, (parent.width - 2) * root.progressFraction)
                radius: 4
                color: root.accent
            }
        }

        Text {
            text: root.control && root.control.secondary !== undefined && root.control.secondary !== null
                  ? String(root.control.secondary)
                  : ""
            visible: text.length > 0
            color: "#94a3b8"
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
