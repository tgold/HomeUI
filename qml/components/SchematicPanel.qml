import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string title: "Schema"
    property string imageSource: ""
    property string backgroundStyle: "heatPump"
    property var labels: []
    property var controls: []
    property var openhab: null
    property var mqtt: null
    property int leftGutterWidth: 168
    property int rightGutterWidth: 172
    property int stateRevision: openhab ? openhab.stateRevision : 0

    readonly property string resolvedImageSource: {
        if (!imageSource || imageSource.length === 0) {
            return ""
        }
        if (typeof dashboardConfig !== "undefined" && dashboardConfig.resolveAssetUrl) {
            var resolved = dashboardConfig.resolveAssetUrl(imageSource)
            if (resolved && resolved.length > 0) {
                return resolved
            }
        } else if (imageSource.indexOf("://") >= 0 || imageSource.indexOf("qrc:") === 0) {
            return imageSource
        }
        return ""
    }
    readonly property bool hasImage: resolvedImageSource.length > 0
    readonly property bool imageReady: hasImage
            && schematicImage.status === Image.Ready
            && schematicImage.paintedWidth > 0
            && schematicImage.paintedHeight > 0

    function itemState(itemName, fallback) {
        stateRevision
        if (openhab && itemName && itemName.length > 0) {
            return openhab.itemState(itemName, fallback)
        }
        return fallback
    }

    function normalized(state) {
        return String(state === undefined || state === null ? "" : state).trim().toUpperCase()
    }

    function isOnState(state) {
        var n = normalized(state)
        if (n === "ON" || n === "OPEN" || n === "RUNNING" || n === "ACTIVE" || n === "HEATING") {
            return true
        }
        var value = Number(n.split(" ")[0])
        return !isNaN(value) && value > 0
    }

    function displayValue(labelData) {
        if (!labelData) {
            return ""
        }
        var raw = labelData.value !== undefined && labelData.value !== null
                ? labelData.value
                : itemState(labelData.item || "", labelData.fallback || "--")
        return Fmt.apply(raw, {
            format: labelData.format,
            unit: labelData.unit,
            decimals: labelData.decimals,
            scale: labelData.scale,
            valueMap: labelData.valueMap
        })
    }

    function rawValue(labelData) {
        if (!labelData) {
            return ""
        }
        if (labelData.value !== undefined && labelData.value !== null) {
            return labelData.value
        }
        return itemState(labelData.item || "", labelData.fallback || "")
    }

    function numericValue(object, key, fallback) {
        if (!object || object[key] === undefined || object[key] === null) {
            return fallback
        }
        var value = Number(object[key])
        return isFinite(value) ? value : fallback
    }

    function overlayX(normX) {
        if (imageReady) {
            var painted = schematicImage.paintedWidth
            var offset = schematicImage.x + (schematicImage.width - painted) / 2
            return offset + normX * painted
        }
        return normX * schematicHost.width
    }

    function overlayY(normY) {
        if (imageReady) {
            var painted = schematicImage.paintedHeight
            var offset = schematicImage.y + (schematicImage.height - painted) / 2
            return offset + normY * painted
        }
        return normY * schematicHost.height
    }

    function clamp(value, minValue, maxValue) {
        var high = Math.max(minValue, maxValue)
        return Math.max(minValue, Math.min(value, high))
    }

    function anchorFactor(labelData) {
        var anchorName = String(labelData && labelData.anchor ? labelData.anchor : "center").toLowerCase()
        if (anchorName === "left") {
            return 0
        }
        if (anchorName === "right") {
            return 1
        }
        return 0.5
    }

    function labelX(labelData, labelWidth) {
        var x = numericValue(labelData, "x", 0.5)
        return clamp(overlayX(x) - labelWidth * anchorFactor(labelData),
                     6,
                     schematicHost.width - labelWidth - 6)
    }

    function labelY(labelData, labelHeight) {
        var y = numericValue(labelData, "y", 0.5)
        var anchorName = String(labelData && labelData.anchorY ? labelData.anchorY : "center").toLowerCase()
        var factor = anchorName === "top" ? 0 : (anchorName === "bottom" ? 1 : 0.5)
        return clamp(overlayY(y) - labelHeight * factor,
                     6,
                     schematicHost.height - labelHeight - 6)
    }

    function gutterSide(controlData) {
        return String(controlData && controlData.gutter ? controlData.gutter : "").toLowerCase()
    }

    readonly property var leftGutterControls: {
        var result = []
        var list = controls || []
        for (var i = 0; i < list.length; ++i) {
            if (gutterSide(list[i]) === "left") {
                result.push(list[i])
            }
        }
        return result
    }
    readonly property var rightGutterControls: {
        var result = []
        var list = controls || []
        for (var i = 0; i < list.length; ++i) {
            if (gutterSide(list[i]) === "right") {
                result.push(list[i])
            }
        }
        return result
    }
    readonly property var overlayControls: {
        var result = []
        var list = controls || []
        for (var i = 0; i < list.length; ++i) {
            var side = gutterSide(list[i])
            if (side !== "left" && side !== "right") {
                result.push(list[i])
            }
        }
        return result
    }

    function controlComponentForKind(kind) {
        switch (kind) {
        case "dimmer":
            return schematicDimmerComponent
        case "color":
            return schematicColorComponent
        case "shutter":
            return schematicShutterComponent
        case "thermostat":
            return schematicThermostatComponent
        case "scene":
            return schematicSceneComponent
        case "progress":
            return schematicProgressComponent
        case "selector":
            return schematicSelectorComponent
        case "dropdown":
            return schematicDropdownComponent
        case "value":
            return schematicValueComponent
        default:
            return schematicSwitchComponent
        }
    }

    implicitWidth: 620
    implicitHeight: 420
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1
    clip: true

    ControlsPanel {
        id: controlMethods
        visible: false
        width: 1
        height: 1
        opacity: 0
        controls: []
        openhab: root.openhab
        mqtt: root.mqtt
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.panelMargin
        spacing: Fmt.panelSpacing

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.title
                color: "#e2e8f0"
                font.pixelSize: 18
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                radius: 8
                color: root.hasImage ? "#1a2b44" : "#172033"
                border.color: root.hasImage ? "#38bdf8" : "#475569"
                border.width: 1
                implicitWidth: root.hasImage ? 108 : 132
                implicitHeight: 28

                Text {
                    anchors.centerIn: parent
                    text: root.hasImage ? "Bild-Overlay" : "Abstrakt"
                    color: "#cbd5e1"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            ColumnLayout {
                id: leftGutterColumn
                Layout.preferredWidth: root.leftGutterWidth
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: 8
                visible: root.leftGutterControls.length > 0

                Repeater {
                    model: root.leftGutterControls

                    Loader {
                        required property var modelData
                        readonly property var control: modelData
                        readonly property string kind: controlMethods.controlKind(modelData)
                        readonly property string rawValue: controlMethods.controlValue(modelData)
                        readonly property string currentValue: controlMethods.controlSecondary(modelData)
                        readonly property string powerValue: modelData.powerItem
                                ? controlMethods.valueForItem(modelData.powerItem, "")
                                : ""
                        readonly property string sceneValue: modelData.sceneItem
                                ? controlMethods.valueForItem(modelData.sceneItem, "")
                                : ""
                        readonly property string footerValue: modelData.footerItem
                                ? controlMethods.valueForItem(modelData.footerItem, "")
                                : ""

                        Layout.fillWidth: true
                        Layout.preferredWidth: root.leftGutterWidth
                        Layout.preferredHeight: item ? item.implicitHeight : root.numericValue(modelData, "height", 84)

                        sourceComponent: root.controlComponentForKind(kind)
                    }
                }

                Item { Layout.fillHeight: true }
            }

            Rectangle {
            id: schematicHost
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 300
            radius: 14
            color: "#0b1220"
            border.color: "#1f2d44"
            border.width: 1
            clip: true

            Image {
                id: schematicImage
                anchors.fill: parent
                source: root.resolvedImageSource
                asynchronous: true
                cache: true
                smooth: true
                fillMode: Image.PreserveAspectFit
                visible: root.hasImage
                opacity: root.imageReady ? 0.92 : 0.35
            }

            Canvas {
                id: defaultSchematic
                anchors.fill: parent
                visible: !root.hasImage || schematicImage.status === Image.Error
                opacity: 0.96

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                function sx(value) { return value * width }
                function sy(value) { return value * height }

                function roundRect(ctx, x, y, w, h, r) {
                    ctx.beginPath()
                    ctx.moveTo(x + r, y)
                    ctx.lineTo(x + w - r, y)
                    ctx.quadraticCurveTo(x + w, y, x + w, y + r)
                    ctx.lineTo(x + w, y + h - r)
                    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
                    ctx.lineTo(x + r, y + h)
                    ctx.quadraticCurveTo(x, y + h, x, y + h - r)
                    ctx.lineTo(x, y + r)
                    ctx.quadraticCurveTo(x, y, x + r, y)
                    ctx.closePath()
                }

                function drawBox(ctx, x, y, w, h, radius, fill, stroke, title, subtitle) {
                    roundRect(ctx, x, y, w, h, radius)
                    ctx.fillStyle = fill
                    ctx.fill()
                    ctx.lineWidth = 2
                    ctx.strokeStyle = stroke
                    ctx.stroke()

                    ctx.fillStyle = "#e2e8f0"
                    ctx.font = "700 " + Math.max(12, width * 0.017) + "px sans-serif"
                    ctx.fillText(title, x + w * 0.08, y + h * 0.32)
                    if (subtitle && subtitle.length > 0) {
                        ctx.fillStyle = "#8fa4bf"
                        ctx.font = "600 " + Math.max(9, width * 0.012) + "px sans-serif"
                        ctx.fillText(subtitle, x + w * 0.08, y + h * 0.55)
                    }
                }

                function drawArrow(ctx, x1, y1, x2, y2, color, lineWidth) {
                    ctx.beginPath()
                    ctx.moveTo(x1, y1)
                    ctx.lineTo(x2, y2)
                    ctx.strokeStyle = color
                    ctx.lineWidth = lineWidth
                    ctx.lineCap = "round"
                    ctx.stroke()

                    var angle = Math.atan2(y2 - y1, x2 - x1)
                    var size = Math.max(8, lineWidth * 2.5)
                    ctx.beginPath()
                    ctx.moveTo(x2, y2)
                    ctx.lineTo(x2 - size * Math.cos(angle - Math.PI / 6),
                               y2 - size * Math.sin(angle - Math.PI / 6))
                    ctx.lineTo(x2 - size * Math.cos(angle + Math.PI / 6),
                               y2 - size * Math.sin(angle + Math.PI / 6))
                    ctx.closePath()
                    ctx.fillStyle = color
                    ctx.fill()
                }

                function drawPipe(ctx, points, color, lineWidth) {
                    if (points.length < 2) {
                        return
                    }
                    ctx.beginPath()
                    ctx.moveTo(points[0].x, points[0].y)
                    for (var i = 1; i < points.length; ++i) {
                        ctx.lineTo(points[i].x, points[i].y)
                    }
                    ctx.strokeStyle = color
                    ctx.lineWidth = lineWidth
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.stroke()
                    drawArrow(ctx, points[points.length - 2].x, points[points.length - 2].y,
                              points[points.length - 1].x, points[points.length - 1].y,
                              color, lineWidth)
                }

                function drawCaption(ctx, text, x, y, color) {
                    ctx.fillStyle = color || "#94a3b8"
                    ctx.font = "700 " + Math.max(10, width * 0.012) + "px sans-serif"
                    ctx.fillText(text, x, y)
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var grad = ctx.createLinearGradient(0, 0, width, height)
                    grad.addColorStop(0, "#111c2f")
                    grad.addColorStop(0.55, "#0b1220")
                    grad.addColorStop(1, "#111827")
                    ctx.fillStyle = grad
                    ctx.fillRect(0, 0, width, height)

                    var pipeWidth = Math.max(5, width * 0.008)

                    drawPipe(ctx, [
                                 { x: sx(0.08), y: sy(0.25) },
                                 { x: sx(0.27), y: sy(0.25) },
                                 { x: sx(0.34), y: sy(0.36) }
                             ], "#38bdf8", pipeWidth)
                    drawPipe(ctx, [
                                 { x: sx(0.34), y: sy(0.48) },
                                 { x: sx(0.22), y: sy(0.48) },
                                 { x: sx(0.08), y: sy(0.62) }
                             ], "#64748b", pipeWidth)
                    drawPipe(ctx, [
                                 { x: sx(0.44), y: sy(0.36) },
                                 { x: sx(0.62), y: sy(0.31) },
                                 { x: sx(0.82), y: sy(0.21) }
                             ], "#22c55e", pipeWidth)
                    drawPipe(ctx, [
                                 { x: sx(0.82), y: sy(0.36) },
                                 { x: sx(0.65), y: sy(0.44) },
                                 { x: sx(0.45), y: sy(0.49) }
                             ], "#ef4444", pipeWidth)
                    drawPipe(ctx, [
                                 { x: sx(0.48), y: sy(0.66) },
                                 { x: sx(0.67), y: sy(0.66) },
                                 { x: sx(0.84), y: sy(0.59) }
                             ], "#ef4444", pipeWidth)
                    drawPipe(ctx, [
                                 { x: sx(0.84), y: sy(0.75) },
                                 { x: sx(0.66), y: sy(0.78) },
                                 { x: sx(0.48), y: sy(0.75) }
                             ], "#f97316", pipeWidth)

                    drawBox(ctx, sx(0.29), sy(0.28), sx(0.18), sy(0.28), 16,
                            "#172033", "#38bdf8", "Lueftung", "Zu-/Abluft")
                    drawBox(ctx, sx(0.36), sy(0.58), sx(0.15), sy(0.18), 16,
                            "#241b33", "#a855f7", "WP", "Verdichter")
                    drawBox(ctx, sx(0.78), sy(0.15), sx(0.14), sy(0.25), 16,
                            "#162a24", "#22c55e", "Haus", "Zuluft")
                    drawBox(ctx, sx(0.78), sy(0.54), sx(0.14), sy(0.28), 16,
                            "#2b1d1b", "#ef4444", "Heizkreis", "Vorlauf")
                    drawBox(ctx, sx(0.56), sy(0.52), sx(0.13), sy(0.25), 999,
                            "#14243a", "#38bdf8", "WW", "Speicher")

                    ctx.beginPath()
                    ctx.arc(sx(0.435), sy(0.67), Math.max(18, width * 0.027), 0, Math.PI * 2)
                    ctx.fillStyle = "#1e293b"
                    ctx.fill()
                    ctx.lineWidth = 2
                    ctx.strokeStyle = "#a855f7"
                    ctx.stroke()
                    drawCaption(ctx, "Kompressor", sx(0.39), sy(0.86), "#a855f7")
                    drawCaption(ctx, "Aussenluft / Fortluft", sx(0.05), sy(0.17), "#94a3b8")
                    drawCaption(ctx, "Warmwasser", sx(0.56), sy(0.48), "#38bdf8")
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#240f1726"
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: root.hasImage && schematicImage.status === Image.Error

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Schema-Bild konnte nicht geladen werden"
                    color: "#fbbf24"
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: schematicHost.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.resolvedImageSource
                    color: "#94a3b8"
                    font.pixelSize: 10
                }
            }

            Repeater {
                model: root.overlayControls

                Item {
                    required property var modelData
                    property var controlData: modelData
                    width: root.numericValue(controlData, "width", 168)
                    height: root.numericValue(controlData, "height", 84)
                    x: root.labelX(controlData, width)
                    y: root.labelY(controlData, height)
                    z: 2

                    Loader {
                        anchors.fill: parent
                        readonly property var control: parent.controlData
                        readonly property string kind: controlMethods.controlKind(parent.controlData)
                        readonly property string rawValue: controlMethods.controlValue(parent.controlData)
                        readonly property string currentValue: controlMethods.controlSecondary(parent.controlData)
                        readonly property string powerValue: parent.controlData.powerItem
                                ? controlMethods.valueForItem(parent.controlData.powerItem, "")
                                : ""
                        readonly property string sceneValue: parent.controlData.sceneItem
                                ? controlMethods.valueForItem(parent.controlData.sceneItem, "")
                                : ""
                        readonly property string footerValue: parent.controlData.footerItem
                                ? controlMethods.valueForItem(parent.controlData.footerItem, "")
                                : ""

                        sourceComponent: root.controlComponentForKind(kind)
                    }
                }
            }

            Repeater {
                model: root.labels

                Rectangle {
                    required property var modelData
                    property var labelData: modelData
                    property string accent: labelData && labelData.accentColor ? String(labelData.accentColor) : "#38bdf8"
                    property bool statusLabel: labelData && labelData.status === true
                    property bool activeState: root.isOnState(root.rawValue(labelData))

                    width: Math.max(88, root.numericValue(labelData, "width", 132))
                    height: root.numericValue(labelData, "height", 50)
                    x: root.labelX(labelData, width)
                    y: root.labelY(labelData, height)
                    z: 1
                    radius: 10
                    color: statusLabel
                           ? (activeState ? "#d91c3b2b" : "#c0182433")
                           : "#d00f1726"
                    border.color: statusLabel
                                  ? (activeState ? accent : "#475569")
                                  : accent
                    border.width: statusLabel && activeState ? 2 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: 5
                            Layout.fillHeight: true
                            radius: 3
                            color: parent.parent.accent
                            opacity: parent.parent.statusLabel && !parent.parent.activeState ? 0.45 : 1
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: labelData && labelData.label ? labelData.label : "Wert"
                                color: "#8fa4bf"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.displayValue(labelData)
                                color: "#f8fafc"
                                font.pixelSize: root.numericValue(labelData, "fontSize", 13)
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
            }

            ColumnLayout {
                id: rightGutterColumn
                Layout.preferredWidth: root.rightGutterWidth
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: 8
                visible: root.rightGutterControls.length > 0

                Repeater {
                    model: root.rightGutterControls

                    Loader {
                        required property var modelData
                        readonly property var control: modelData
                        readonly property string kind: controlMethods.controlKind(modelData)
                        readonly property string rawValue: controlMethods.controlValue(modelData)
                        readonly property string currentValue: controlMethods.controlSecondary(modelData)
                        readonly property string powerValue: modelData.powerItem
                                ? controlMethods.valueForItem(modelData.powerItem, "")
                                : ""
                        readonly property string sceneValue: modelData.sceneItem
                                ? controlMethods.valueForItem(modelData.sceneItem, "")
                                : ""
                        readonly property string footerValue: modelData.footerItem
                                ? controlMethods.valueForItem(modelData.footerItem, "")
                                : ""

                        Layout.fillWidth: true
                        Layout.preferredWidth: root.rightGutterWidth
                        Layout.preferredHeight: item ? item.implicitHeight : root.numericValue(modelData, "height", 108)

                        sourceComponent: root.controlComponentForKind(kind)
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Component {
        id: schematicSwitchComponent

        SwitchTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
            secondary: parent.currentValue
        }
    }

    Component {
        id: schematicDimmerComponent

        DimmerTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
            powerValue: parent.powerValue
        }
    }

    Component {
        id: schematicColorComponent

        ColorTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
            powerValue: parent.powerValue
        }
    }

    Component {
        id: schematicShutterComponent

        ShutterTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
            sceneValue: parent.sceneValue
        }
    }

    Component {
        id: schematicThermostatComponent

        ThermostatTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
            currentValue: parent.currentValue
        }
    }

    Component {
        id: schematicSceneComponent

        SceneTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
        }
    }

    Component {
        id: schematicProgressComponent

        ProgressTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
            footerRawValue: parent.footerValue
        }
    }

    Component {
        id: schematicSelectorComponent

        SelectorTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
        }
    }

    Component {
        id: schematicDropdownComponent

        DropdownTile {
            control: parent.control
            panel: controlMethods
            rawValue: parent.rawValue
        }
    }

    Component {
        id: schematicValueComponent

        ControlTile {
            readonly property var control: parent.control
            readonly property string rawValue: parent.rawValue
            readonly property string statusAccent: controlMethods.statusAccentColor(control, rawValue)
            label: control.label || "Wert"
            value: Fmt.apply(rawValue, {
                format: control.format,
                unit: control.unit,
                decimals: control.decimals,
                scale: control.scale,
                valueMap: control.valueMap
            })
            secondary: control.secondary || ""
            iconText: control.iconText || ""
            accentColor: statusAccent.length > 0 ? statusAccent : (control.accentColor || "#f59e0b")
            active: controlMethods.isOnState(rawValue)
            interactive: !!(control.command || control.onCommand || control.offCommand)
            onClicked: controlMethods.toggleSwitch(control)
        }
    }
}
