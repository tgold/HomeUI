import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var openhab: null
    property bool active: true
    property string title: "Bewaesserung"
    property string imageSource: ""
    property var zones: []
    property var sensors: []
    property string programItem: ""
    property string programStartCommand: "ON"
    property string programStopCommand: "OFF"
    property string useCisternItem: ""
    property string durationItem: ""
    property var durationOptions: [3, 30, 45, 60, 90]
    property var history: ({})
    property int stateRevision: openhab ? openhab.stateRevision : 0

    readonly property var influx: typeof influxHistoryClient !== "undefined" ? influxHistoryClient : null
    readonly property bool historyRequested: history && history.enabled === true
    readonly property bool historyEnabled: {
        if (!historyRequested) {
            return false
        }
        if (!influx) {
            return false
        }
        applyHistoryConfig()
        return influx.configured
    }
    readonly property string historyConfigHint: {
        if (!influx) {
            return "Influx-Client nicht verfügbar"
        }
        if (influx.usesInfluxV2) {
            return "HOMEUI_INFLUX_URL, TOKEN, ORG; Bucket in history.bucket"
        }
        return "HOMEUI_INFLUX_URL, USER, PASSWORD; DB in history.bucket"
    }
    readonly property int historyDays: {
        if (history && history.days !== undefined && history.days !== null) {
            var n = Number(history.days)
            if (!isNaN(n) && n > 0) {
                return n
            }
        }
        return 5
    }
    readonly property var chartableSensors: {
        var out = []
        if (!sensors || sensors.length === 0) {
            return out
        }
        for (var i = 0; i < sensors.length; ++i) {
            if (isChartableSensor(sensors[i])) {
                out.push(sensors[i])
            }
        }
        return out
    }

    function sensorChartX(sensor) {
        if (sensor && sensor.x !== undefined && sensor.x !== null) {
            var x = Number(sensor.x)
            if (!isNaN(x)) {
                return x
            }
        }
        return 0.2
    }

    readonly property var leftChartSensors: {
        var out = []
        for (var i = 0; i < chartableSensors.length; ++i) {
            if (sensorChartX(chartableSensors[i]) < 0.45) {
                out.push(chartableSensors[i])
            }
        }
        return out
    }

    readonly property var rightChartSensors: {
        var out = []
        for (var i = 0; i < chartableSensors.length; ++i) {
            if (sensorChartX(chartableSensors[i]) >= 0.45) {
                out.push(chartableSensors[i])
            }
        }
        return out
    }

    function chartTileHeight(sensorCount, columnHeight) {
        if (sensorCount <= 0 || columnHeight <= 0) {
            return 72
        }
        var gap = 8 * Math.max(0, sensorCount - 1)
        return Math.max(64, Math.floor((columnHeight - gap) / sensorCount))
    }

    property var historyCache: ({})
    property var historyLoading: ({})
    property var historyErrors: ({})

    readonly property string bundledFloorplanSource:
            "qrc:/qt/qml/HomeUI/assets/irrigation-floorplan.png"

    readonly property string resolvedImageSource: {
        if (!imageSource || imageSource.length === 0) {
            return bundledFloorplanSource
        }
        if (typeof dashboardConfig !== "undefined" && dashboardConfig.resolveAssetUrl) {
            var resolved = dashboardConfig.resolveAssetUrl(imageSource)
            if (resolved && resolved.length > 0) {
                return resolved
            }
        } else if (imageSource.indexOf("://") >= 0 || imageSource.indexOf("qrc:") === 0) {
            return imageSource
        }
        return bundledFloorplanSource
    }

    readonly property bool imageReady: floorplanImage.status === Image.Ready
            && floorplanImage.paintedWidth > 0
            && floorplanImage.paintedHeight > 0

    function itemState(itemName, fallback) {
        stateRevision
        if (openhab && itemName && itemName.length > 0) {
            return openhab.itemState(itemName, fallback)
        }
        return fallback
    }

    function send(itemName, command) {
        if (!openhab || !itemName || itemName.length === 0 || command === undefined || command === null) {
            return
        }
        openhab.sendCommand(itemName, String(command))
    }

    function normalized(state) {
        return String(state === undefined || state === null ? "" : state).trim().toUpperCase()
    }

    function isOnState(state) {
        var n = normalized(state)
        if (n === "ON" || n === "OPEN" || n === "DOWN" || n === "LOCKED" || n === "HOME") {
            return true
        }
        var value = Number(n.split(" ")[0])
        return !isNaN(value) && value > 0
    }

    function isActiveIrrigationState(state) {
        var n = normalized(state)
        return n.length > 0 && n !== "CLOSED" && n !== "OFF" && n !== "NULL" && n !== "UNDEF"
    }

    function zoneState(zone) {
        return itemState(zone && zone.activityItem ? zone.activityItem : "", "")
    }

    function zoneActive(zone) {
        return isActiveIrrigationState(zoneState(zone))
    }

    function zoneColor(zone) {
        return zoneActive(zone) ? "#22c55e" : "#334155"
    }

    function currentDurationNumber() {
        var raw = normalized(itemState(durationItem, ""))
        var number = Number(raw.split(" ")[0])
        return isNaN(number) ? -1 : number
    }

    function startProgram() {
        if (!programItem || programItem.length === 0) {
            return
        }
        send(programItem, programStartCommand || "ON")
    }

    function stopProgram() {
        if (!programItem || programItem.length === 0) {
            return
        }
        send(programItem, programStopCommand || "OFF")
    }

    function isChartableSensor(sensor) {
        if (!sensor || !sensor.item || String(sensor.item).length === 0) {
            return false
        }
        if (sensor.history === false) {
            return false
        }
        if (sensor.history === true) {
            return true
        }
        var fmt = sensor.format !== undefined && sensor.format !== null
                ? String(sensor.format).toLowerCase()
                : ""
        if (fmt === "temperature") {
            return true
        }
        var unit = sensor.unit !== undefined && sensor.unit !== null ? String(sensor.unit) : ""
        return unit === "%"
    }

    function applyHistoryConfig() {
        if (!influx) {
            return
        }
        if (history && history.bucket) {
            var db = String(history.bucket)
            influx.bucket = db
            influx.database = db
        }
        if (history && history.org) {
            influx.org = String(history.org)
        }
        if (history && history.retentionPolicy) {
            influx.retentionPolicy = String(history.retentionPolicy)
        }
    }

    function refreshHistory() {
        if (!root.active || !historyEnabled || !influx) {
            return
        }
        applyHistoryConfig()
        for (var i = 0; i < chartableSensors.length; ++i) {
            fetchSensorHistory(chartableSensors[i])
        }
    }

    function fetchSensorHistory(sensor) {
        if (!sensor || !sensor.item || !influx) {
            return
        }
        var item = String(sensor.item)
        var defaultMeasurement = history && history.measurement ? String(history.measurement) : ""
        var measurement = sensor.influxMeasurement !== undefined && sensor.influxMeasurement !== null
                ? String(sensor.influxMeasurement)
                : (defaultMeasurement.length > 0 ? defaultMeasurement : item)
        var filterByTag = measurement.length > 0 && measurement !== item
        var loading = {}
        for (var key in historyLoading) {
            loading[key] = historyLoading[key]
        }
        loading[item] = true
        historyLoading = loading
        influx.fetchDailyMeans(item, measurement, historyDays, filterByTag)
    }

    function overlayX(normX) {
        if (imageReady) {
            var painted = floorplanImage.paintedWidth
            var offset = floorplanImage.x + (floorplanImage.width - painted) / 2
            return offset + normX * painted
        }
        return normX * mapHost.width
    }

    function overlayY(normY) {
        if (imageReady) {
            var painted = floorplanImage.paintedHeight
            var offset = floorplanImage.y + (floorplanImage.height - painted) / 2
            return offset + normY * painted
        }
        return normY * mapHost.height
    }

    Component.onCompleted: {
        applyHistoryConfig()
        if (root.active) {
            refreshHistory()
        }
    }
    onHistoryChanged: applyHistoryConfig()
    onHistoryEnabledChanged: {
        if (historyEnabled && root.active) {
            refreshHistory()
        }
    }
    onActiveChanged: {
        if (root.active && root.historyEnabled) {
            refreshHistory()
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: root.active && root.historyEnabled
        repeat: true
        onTriggered: root.refreshHistory()
    }

    Connections {
        enabled: root.influx !== null
        target: root.influx
        function onDailyMeansReady(itemName, values, error) {
            var item = String(itemName)
            var cache = root.historyCache
            var loading = root.historyLoading
            var errors = root.historyErrors
            loading[item] = false
            if (error && String(error).length > 0) {
                errors[item] = String(error)
                cache[item] = []
            } else {
                errors[item] = ""
                cache[item] = values
            }
            root.historyLoading = loading
            root.historyErrors = errors
            root.historyCache = cache
        }
    }

    implicitWidth: 620
    implicitHeight: 520
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1
    clip: true

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
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                radius: 8
                color: root.isOnState(root.itemState(root.programItem, "OFF")) ? "#163924" : "#2b3343"
                border.color: root.isOnState(root.itemState(root.programItem, "OFF")) ? "#22c55e" : "#475569"
                border.width: 1
                implicitHeight: 28
                implicitWidth: 138

                Text {
                    anchors.centerIn: parent
                    text: "Programm: " + root.itemState(root.programItem, "OFF")
                    color: "#e2e8f0"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        RowLayout {
            id: chartRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            ColumnLayout {
                id: leftCharts
                Layout.preferredWidth: 172
                Layout.maximumWidth: 220
                Layout.fillHeight: true
                spacing: 8
                visible: root.historyEnabled && root.leftChartSensors.length > 0

                Repeater {
                    model: root.leftChartSensors

                    HistorySparkline {
                        required property var modelData
                        property string itemName: modelData && modelData.item ? String(modelData.item) : ""
                        label: modelData && modelData.label ? modelData.label : itemName
                        accentColor: modelData && modelData.accentColor ? modelData.accentColor : "#38bdf8"
                        format: modelData && modelData.format ? String(modelData.format) : ""
                        unit: modelData && modelData.unit !== undefined && modelData.unit !== null
                              ? String(modelData.unit) : ""
                        decimals: modelData && modelData.decimals !== undefined && modelData.decimals !== null
                                  ? Number(modelData.decimals) : -1
                        values: itemName.length > 0 && root.historyCache[itemName]
                                ? root.historyCache[itemName]
                                : []
                        loading: itemName.length > 0 && root.historyLoading[itemName] === true
                        error: itemName.length > 0 && root.historyErrors[itemName]
                                ? root.historyErrors[itemName]
                                : ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.chartTileHeight(
                                                  root.leftChartSensors.length,
                                                  leftCharts.height)
                    }
                }
            }

            Rectangle {
                id: mapHost
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 280
                radius: 14
                color: "#0b1220"
                clip: true

                Image {
                id: floorplanImage
                anchors.fill: parent
                source: root.resolvedImageSource
                asynchronous: true
                cache: true
                smooth: true
                fillMode: Image.PreserveAspectFit
                opacity: imageReady ? 0.92 : 0.35
            }

            Rectangle {
                anchors.fill: parent
                color: imageReady ? "#330f1726" : "#660f1726"
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: floorplanImage.status === Image.Error
                        || (floorplanImage.status === Image.Ready && !imageReady)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Grundriss konnte nicht geladen werden"
                    color: "#fbbf24"
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: mapHost.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.resolvedImageSource
                    color: "#94a3b8"
                    font.pixelSize: 10
                }
            }

            Repeater {
                model: root.sensors

                Rectangle {
                    required property var modelData
                    property var sensor: modelData
                    x: root.overlayX(sensor.x !== undefined ? sensor.x : 0.1) - width / 2
                    y: root.overlayY(sensor.y !== undefined ? sensor.y : 0.1) - height / 2
                    width: Math.max(120, sensor.width !== undefined ? sensor.width : 136)
                    height: 48
                    radius: 10
                    color: "#b80f1726"
                    border.color: sensor.accentColor || "#38bdf8"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 1

                        Text {
                            text: sensor.label || "Sensor"
                            color: "#8fa4bf"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: Fmt.apply(root.itemState(sensor.item || "", "--"), {
                                format: sensor.format,
                                unit: sensor.unit,
                                decimals: sensor.decimals,
                                scale: sensor.scale
                            })
                            color: "#f8fafc"
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }
            }

            Repeater {
                model: root.zones

                Item {
                    required property var modelData
                    property var zone: modelData
                    x: root.overlayX(zone.x !== undefined ? zone.x : 0.5) - width / 2
                    y: root.overlayY(zone.y !== undefined ? zone.y : 0.5) - height / 2
                    width: 92
                    height: 62

                    Rectangle {
                        id: zoneDot
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 20
                        height: 20
                        radius: 10
                        color: root.zoneColor(zone)
                        border.color: root.zoneActive(zone) ? "#86efac" : "#64748b"
                        border.width: 1
                    }

                    Rectangle {
                        anchors.top: zoneDot.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 88
                        height: 30
                        radius: 8
                        color: "#1e293b"
                        border.color: root.zoneActive(zone) ? "#22c55e" : "#475569"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: (zone.label || ("Zone " + (index + 1))) + "  " + root.zoneState(zone)
                            color: "#f1f5f9"
                            font.pixelSize: 10
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            width: parent.width - 8
                        }
                    }
                }
            }
        }

            ColumnLayout {
                id: rightCharts
                Layout.preferredWidth: 172
                Layout.maximumWidth: 220
                Layout.fillHeight: true
                spacing: 8
                visible: root.historyEnabled && root.rightChartSensors.length > 0

                Repeater {
                    model: root.rightChartSensors

                    HistorySparkline {
                        required property var modelData
                        property string itemName: modelData && modelData.item ? String(modelData.item) : ""
                        label: modelData && modelData.label ? modelData.label : itemName
                        accentColor: modelData && modelData.accentColor ? modelData.accentColor : "#38bdf8"
                        format: modelData && modelData.format ? String(modelData.format) : ""
                        unit: modelData && modelData.unit !== undefined && modelData.unit !== null
                              ? String(modelData.unit) : ""
                        decimals: modelData && modelData.decimals !== undefined && modelData.decimals !== null
                                  ? Number(modelData.decimals) : -1
                        values: itemName.length > 0 && root.historyCache[itemName]
                                ? root.historyCache[itemName]
                                : []
                        loading: itemName.length > 0 && root.historyLoading[itemName] === true
                        error: itemName.length > 0 && root.historyErrors[itemName]
                                ? root.historyErrors[itemName]
                                : ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.chartTileHeight(
                                                  root.rightChartSensors.length,
                                                  rightCharts.height)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            visible: root.historyRequested && !root.historyEnabled && root.chartableSensors.length > 0
            radius: 8
            color: "#1a2438"
            border.color: "#f59e0b"
            border.width: 1

            Text {
                anchors.fill: parent
                anchors.margins: 8
                text: "5-Tage-Verlauf: " + root.historyConfigHint
                color: "#fcd34d"
                font.pixelSize: 10
                wrapMode: Text.Wrap
                verticalAlignment: Text.AlignVCenter
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 140
                radius: 8
                color: root.isOnState(root.itemState(root.useCisternItem, "OFF")) ? "#1b3850" : "#2b3343"
                border.color: "#38bdf8"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Zisterne: " + root.itemState(root.useCisternItem, "OFF")
                    color: "#e0f2fe"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.durationOptions

                    Rectangle {
                        required property var modelData
                        readonly property int optionValue: Number(modelData)
                        width: 56
                        height: Fmt.actionButtonHeight
                        radius: 8
                        color: optionValue === root.currentDurationNumber() ? "#1d4ed8" : "#273449"
                        border.color: optionValue === root.currentDurationNumber() ? "#93c5fd" : "#475569"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: optionValue + "m"
                            color: "#f1f5f9"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.durationItem.length > 0
                            onClicked: root.send(root.durationItem, optionValue)
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: Fmt.actionButtonHeight
                radius: 8
                color: "#163924"
                border.color: "#22c55e"
                border.width: 1
                opacity: root.programItem.length > 0 ? 1 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: "Start"
                    color: "#dcfce7"
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.programItem.length > 0
                    onClicked: root.startProgram()
                }
            }

            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: Fmt.actionButtonHeight
                radius: 8
                color: "#451a1a"
                border.color: "#ef4444"
                border.width: 1
                opacity: root.programItem.length > 0 ? 1 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: "Stop"
                    color: "#fee2e2"
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.programItem.length > 0
                    onClicked: root.stopProgram()
                }
            }
        }
    }
}
