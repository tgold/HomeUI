import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string label: ""
    property var values: []
    property color accentColor: "#38bdf8"
    property bool loading: false
    property string error: ""

    readonly property bool hasValues: values && values.length > 0
    readonly property real minValue: {
        if (!hasValues) {
            return 0
        }
        var min = Number(values[0])
        for (var i = 1; i < values.length; ++i) {
            var v = Number(values[i])
            if (!isNaN(v) && v < min) {
                min = v
            }
        }
        return isNaN(min) ? 0 : min
    }
    readonly property real maxValue: {
        if (!hasValues) {
            return 0
        }
        var max = Number(values[0])
        for (var i = 1; i < values.length; ++i) {
            var v = Number(values[i])
            if (!isNaN(v) && v > max) {
                max = v
            }
        }
        return isNaN(max) ? 0 : max
    }

    implicitWidth: 112
    implicitHeight: 52
    radius: 8
    color: "#172235"
    border.color: "#304158"
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        Text {
            text: root.label
            color: "#94a3b8"
            font.pixelSize: 9
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24

            Canvas {
                id: chart
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)

                    ctx.strokeStyle = "#334155"
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(0, height - 1)
                    ctx.lineTo(width, height - 1)
                    ctx.stroke()

                    if (root.loading) {
                        return
                    }

                    if (!root.hasValues) {
                        return
                    }

                    var min = root.minValue
                    var max = root.maxValue
                    var span = max - min
                    if (span < 1e-6) {
                        span = Math.max(Math.abs(max), 1)
                    }

                    var n = root.values.length
                    var stepX = n > 1 ? width / (n - 1) : 0

                    ctx.beginPath()
                    for (var i = 0; i < n; ++i) {
                        var val = Number(root.values[i])
                        if (isNaN(val)) {
                            val = min
                        }
                        var x = n > 1 ? i * stepX : width / 2
                        var y = height - 2 - ((val - min) / span) * (height - 4)
                        if (i === 0) {
                            ctx.moveTo(x, y)
                        } else {
                            ctx.lineTo(x, y)
                        }
                    }
                    ctx.strokeStyle = root.error.length > 0 ? "#64748b" : root.accentColor
                    ctx.lineWidth = 2
                    ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !root.loading && !root.hasValues
                text: root.error.length > 0 ? "—" : ""
                color: "#64748b"
                font.pixelSize: 11
            }
        }
    }

    onValuesChanged: chart.requestPaint()
    onLoadingChanged: chart.requestPaint()
    onErrorChanged: chart.requestPaint()
    onAccentColorChanged: chart.requestPaint()
    onWidthChanged: chart.requestPaint()
    onHeightChanged: chart.requestPaint()
}
