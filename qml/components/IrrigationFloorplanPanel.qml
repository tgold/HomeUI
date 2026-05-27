import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property var openhab: null
    property string title: "Bewaesserung"
    property string imageSource: ""
    property var zones: []
    property var sensors: []
    property string programItem: ""
    property string useCisternItem: ""
    property string durationItem: ""
    property var durationOptions: [3, 30, 45, 60, 90]
    property int stateRevision: openhab ? openhab.stateRevision : 0

    property int selectedZoneIndex: -1

    readonly property string resolvedImageSource: {
        if (!imageSource || imageSource.length === 0) {
            return "qrc:/qt/qml/HomeUI/assets/irrigation-floorplan.png"
        }
        if (typeof dashboardConfig !== "undefined" && dashboardConfig.resolveAssetUrl) {
            var resolved = dashboardConfig.resolveAssetUrl(imageSource)
            if (resolved && resolved.length > 0) {
                return resolved
            }
        }
        return imageSource
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

    implicitWidth: 620
    implicitHeight: 520
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

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

        Rectangle {
            id: mapHost
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                        color: index === root.selectedZoneIndex ? "#2b3c58" : "#1e293b"
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

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.selectedZoneIndex = index
                    }
                }
            }

            Rectangle {
                id: actionStrip
                visible: root.selectedZoneIndex >= 0 && root.selectedZoneIndex < root.zones.length
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                height: 54
                radius: 10
                color: "#d20f1726"
                border.color: "#334155"
                border.width: 1

                property var selectedZone: visible ? root.zones[root.selectedZoneIndex] : null

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: actionStrip.selectedZone ? (actionStrip.selectedZone.label || "Zone") : ""
                        color: "#e2e8f0"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: 78
                        implicitHeight: 34
                        radius: 8
                        color: "#163924"
                        border.color: "#22c55e"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Start"
                            color: "#dcfce7"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: actionStrip.selectedZone && actionStrip.selectedZone.startItem
                            onClicked: root.send(actionStrip.selectedZone.startItem,
                                                 actionStrip.selectedZone.startCommand || "ON")
                        }
                    }

                    Rectangle {
                        implicitWidth: 78
                        implicitHeight: 34
                        radius: 8
                        color: "#451a1a"
                        border.color: "#ef4444"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Stop"
                            color: "#fee2e2"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: actionStrip.selectedZone && actionStrip.selectedZone.stopItem
                            onClicked: root.send(actionStrip.selectedZone.stopItem,
                                                 actionStrip.selectedZone.stopCommand || "ON")
                        }
                    }
                }
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
                        height: 30
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
        }
    }
}
