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
    readonly property color currentColor: colorForHue(hue)

    // Hue shown inside the picker. Kept separate so a drag is not snapped
    // back by the live OpenHAB state until the popup opens again.
    property real popupHue: 0

    function colorForHue(h) {
        return Qt.hsva(
            Math.max(0, Math.min(1, h / 360)),
            Math.max(0.2, Math.min(1, saturation / 100)),
            Math.max(0.35, Math.min(1, brightness / 100)),
            1)
    }

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

    readonly property string onCmd: control.onCommand || control.mqttOnPayload || "ON"
    readonly property string offCmd: control.offCommand || control.mqttOffPayload || "OFF"

    implicitWidth: 200
    implicitHeight: contentLayout.implicitHeight + 2 * Fmt.tileMargin
    radius: 12
    color: powerOn ? "#26364d" : "#172235"
    border.color: powerOn ? currentColor : "#304158"
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

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: root.powerOn ? (root.hasPowerItem ? root.accent : root.currentColor) : "#263449"
                border.color: root.powerOn ? "#f8fafc" : "#304158"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.control.iconText || "L"
                    color: root.powerOn ? "#111827" : "#cbd5e1"
                    font.pixelSize: 11
                    font.bold: true
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

            Rectangle {
                id: colorButton
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: width / 2
                color: root.currentColor
                border.color: "#f8fafc"
                border.width: 2
                opacity: root.hasBinding ? 1 : 0.5

                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasBinding
                    onClicked: huePopup.open()
                }
            }
        }

        PowerButtons {
            Layout.fillWidth: true
            panel: root.panel
            targetControl: root.hasPowerItem ? root.powerControl() : root.control
            powerOn: root.powerOn
            onCommand: root.onCmd
            offCommand: root.offCmd
            accent: root.accent
            enabled: root.hasBinding || root.hasPowerItem
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

    Popup {
        id: huePopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        width: Math.max(520, Math.min(880, (parent ? parent.width : 880) - 64))
        height: huePopupContent.implicitHeight + 36
        anchors.centerIn: parent

        onAboutToShow: root.popupHue = root.hue

        background: Rectangle {
            radius: 18
            color: "#0f1726"
            border.color: "#334155"
            border.width: 1
        }

        ColumnLayout {
            id: huePopupContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: (root.control.label || "Licht")
                    color: "#f8fafc"
                    font.pixelSize: 20
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 12
                    color: closeArea.pressed ? "#334155" : "#1e293b"
                    border.color: "#475569"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#f8fafc"
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        onClicked: huePopup.close()
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 104
                Layout.preferredHeight: 104
                radius: width / 2
                color: root.colorForHue(root.popupHue)
                border.color: "#f8fafc"
                border.width: 3
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Math.round(root.popupHue) + "°"
                color: "#cbd5e1"
                font.pixelSize: 16
                font.bold: true
            }

            Rectangle {
                id: hueBar
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: 42
                border.color: "#0b1220"
                border.width: 2
                clip: true

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
                    id: hueThumb
                    width: 68
                    height: 68
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: {
                        var travel = Math.max(0, parent.width - width)
                        return (Math.max(0, Math.min(360, root.popupHue)) / 360) * travel
                    }
                    color: root.colorForHue(root.popupHue)
                    border.color: "#f8fafc"
                    border.width: 4
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    function hueFromMouse(mouse) {
                        var travel = Math.max(1, width - hueThumb.width)
                        var left = Math.max(0, Math.min(travel, mouse.x - hueThumb.width / 2))
                        return (left / travel) * 360
                    }

                    onPressed: root.popupHue = hueFromMouse(mouse)
                    onPositionChanged: if (pressed) root.popupHue = hueFromMouse(mouse)
                    onReleased: {
                        var s = root.saturation > 0 ? root.saturation : 100
                        var b = root.brightness > 0 ? root.brightness : 100
                        root.sendHsb(root.popupHue, s, b)
                    }
                }
            }
        }
    }
}
