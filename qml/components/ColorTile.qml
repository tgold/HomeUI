import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var control: ({})
    property var panel: null
    property string rawValue: ""
    property string powerValue: ""

    readonly property var hsb: {
        var raw = String(rawValue).trim()
        if (raw.length === 0) {
            return { h: 0, s: 0, b: 0 }
        }
        if (raw.indexOf(",") !== -1) {
            var parts = raw.split(",")
            if (parts.length >= 3) {
                var h = Number(parts[0]); if (isNaN(h)) { h = 0 }
                var s = Number(parts[1]); if (isNaN(s)) { s = 0 }
                var b = Number(parts[2]); if (isNaN(b)) { b = 0 }
                return { h: h, s: s, b: b }
            }
        }
        var upper = raw.toUpperCase()
        if (upper === "ON")  { return { h: 0, s: 0, b: 100 } }
        if (upper === "OFF") { return { h: 0, s: 0, b: 0 } }
        var match = raw.match(/^-?\d+(?:\.\d+)?/)
        var n = match ? Number(match[0]) : 0
        return { h: 0, s: 0, b: isNaN(n) ? 0 : n }
    }

    readonly property real hue: hsb.h
    readonly property real saturation: hsb.s
    readonly property real brightness: hsb.b
    readonly property bool hasPowerItem: !!(control.powerItem && control.powerItem.length > 0)
    readonly property bool powerOn: {
        if (hasPowerItem && panel) {
            return panel.isOnState(powerValue)
        }
        return brightness > 0
    }
    readonly property bool hasBinding: !!(control.item || control.mqttTopic)
    readonly property color accent: control.accentColor || "#fbbf24"
    readonly property color currentColor: Qt.hsva(
        Math.max(0, Math.min(1, hue / 360)),
        Math.max(0.2, Math.min(1, saturation / 100)),
        Math.max(0.35, Math.min(1, brightness / 100)),
        1)

    function sendHsb(h, s, b) {
        if (!panel) { return }
        var hh = Math.max(0, Math.min(360, Math.round(h)))
        var ss = Math.max(0, Math.min(100, Math.round(s)))
        var bb = Math.max(0, Math.min(100, Math.round(b)))
        panel.dispatchCommand(control, hh + "," + ss + "," + bb)
    }

    function sendBrightness(b) {
        if (!panel) { return }
        panel.dispatchCommand(control, String(Math.max(0, Math.min(100, Math.round(b)))))
    }

    function powerControl() {
        return {
            item: control.powerItem || "",
            mqttTopic: control.powerMqttTopic || "",
            commandTopic: control.powerCommandTopic || ""
        }
    }

    function togglePower() {
        if (!panel) { return }
        if (hasPowerItem) {
            var on = control.onCommand || control.mqttOnPayload || "ON"
            var off = control.offCommand || control.mqttOffPayload || "OFF"
            panel.dispatchCommand(powerControl(), powerOn ? off : on)
            return
        }
        panel.dispatchCommand(control, powerOn ? "OFF" : "ON")
    }

    implicitWidth: 200
    implicitHeight: 96
    radius: 12
    color: powerOn ? "#26364d" : "#172235"
    border.color: powerOn ? currentColor : "#304158"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.tileMargin
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: root.powerOn ? (root.hasPowerItem ? root.accent : root.currentColor) : "#263449"
                border.color: root.powerOn ? "#f8fafc" : "#304158"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.control.iconText || (root.powerOn ? "ON" : "OFF")
                    color: root.powerOn ? "#111827" : "#cbd5e1"
                    font.pixelSize: 11
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasBinding || root.hasPowerItem
                    onClicked: root.togglePower()
                }
            }

            Text {
                text: root.control.label || "Licht"
                color: "#cbd5e1"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: Math.round(root.brightness) + "%"
                color: "#f8fafc"
                font.pixelSize: 11
                font.bold: true
            }
        }

        Rectangle {
            id: hueStrip
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            radius: 9
            border.color: "#304158"
            border.width: 1
            clip: true
            opacity: root.hasBinding ? 1 : 0.5

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.000; color: "#ff0000" }
                GradientStop { position: 0.167; color: "#ffff00" }
                GradientStop { position: 0.333; color: "#00ff00" }
                GradientStop { position: 0.500; color: "#00ffff" }
                GradientStop { position: 0.667; color: "#0000ff" }
                GradientStop { position: 0.833; color: "#ff00ff" }
                GradientStop { position: 1.000; color: "#ff0000" }
            }

            Rectangle {
                id: hueMarker
                width: 6
                height: parent.height + 4
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(-width / 2,
                            Math.min(parent.width - width / 2,
                                     (root.hue / 360) * parent.width - width / 2))
                color: "transparent"
                border.color: "#f8fafc"
                border.width: 2
                radius: 3
            }

            MouseArea {
                id: hueArea
                anchors.fill: parent
                enabled: root.hasBinding
                preventStealing: true
                property bool dragging: false

                onPressed: { dragging = true; updateLocal(mouse) }
                onPositionChanged: if (dragging) { updateLocal(mouse) }
                onReleased: { if (dragging) { commit(mouse) } dragging = false }
                onCanceled: dragging = false

                function updateLocal(mouse) {
                    var x = Math.max(0, Math.min(width, mouse.x))
                    hueMarker.x = x - hueMarker.width / 2
                }

                function commit(mouse) {
                    var x = Math.max(0, Math.min(width, mouse.x))
                    var h = (x / width) * 360
                    var s = root.saturation > 0 ? root.saturation : 100
                    var b = root.brightness > 0 ? root.brightness : 100
                    root.sendHsb(h, s, b)
                }
            }
        }

        Slider {
            id: brightnessSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            from: 0
            to: 100
            stepSize: 1
            value: Math.max(0, Math.min(100, root.brightness))
            enabled: root.hasBinding
            live: false
            onPressedChanged: {
                if (!pressed) {
                    root.sendBrightness(value)
                }
            }
        }
    }
}
