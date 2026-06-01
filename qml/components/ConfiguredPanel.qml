import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panel: ({})
    property var openhab: null
    property var sonos: null
    property var mqtt: null

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    function value(path, fallback) {
        var current = panel
        for (var i = 0; i < path.length; ++i) {
            if (current === undefined || current === null || current[path[i]] === undefined || current[path[i]] === null) {
                return fallback
            }
            current = current[path[i]]
        }
        return current
    }

    function boolValue(path, fallback) {
        var result = value(path, fallback)
        return result === true || result === "true"
    }

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: {
            switch (root.panel.type) {
            case "room":
                return roomPanelComponent
            case "energy":
                return energyPanelComponent
            case "camera":
                return cameraPanelComponent
            case "mode":
                return modePanelComponent
            case "controls":
                return controlsPanelComponent
            case "mqtt":
                return mqttPanelComponent
            case "sonos":
                return sonosPanelComponent
            case "grafana":
                return grafanaPanelComponent
            case "irrigationFloorplan":
                return irrigationFloorplanPanelComponent
            default:
                return unsupportedPanelComponent
            }
        }
    }

    Component {
        id: roomPanelComponent

        RoomPanel {
            openhab: root.openhab
            title: root.value(["title"], "Room")
            subtitle: root.value(["subtitle"], "")
            temperature: root.value(["fallback", "temperature"], "--.- C")
            humidity: root.value(["fallback", "humidity"], "-- %")
            lightOn: root.boolValue(["fallback", "lightOn"], false)
            shutterClosed: root.boolValue(["fallback", "shutterClosed"], false)
            shutterPosition: root.value(["fallback", "shutterPosition"], "-- %")
            temperatureItem: root.value(["items", "temperature"], "")
            humidityItem: root.value(["items", "humidity"], "")
            lightItem: root.value(["items", "light"], "")
            hueItem: root.value(["items", "hue"], "")
            shutterItem: root.value(["items", "shutter"], "")
        }
    }

    Component {
        id: energyPanelComponent

        EnergyPanel {
            openhab: root.openhab
            title: root.value(["title"], "Energie")
            pvItem: root.value(["items", "pv"], "")
            gridItem: root.value(["items", "grid"], "")
            consumptionItem: root.value(["items", "consumption"], "")
            batteryItem: root.value(["items", "battery"], "")
            pvDayItem: root.value(["items", "pvDay"], "")
            consumptionDayItem: root.value(["items", "consumptionDay"], "")
        }
    }

    Component {
        id: cameraPanelComponent

        CameraTile {
            title: root.value(["title"], "Kamera")
            location: root.value(["location"], "")
            streamUrl: root.value(["streamUrl"], "")
            snapshotUrl: root.value(["snapshotUrl"], "")
            streamFormat: root.value(["format"], "")
            refreshInterval: root.value(["refreshInterval"], 1000)
            ignoreSslErrors: root.boolValue(["ignoreSslErrors"], false)
        }
    }

    Component {
        id: modePanelComponent

        ModePanel {}
    }

    Component {
        id: controlsPanelComponent

        ControlsPanel {
            openhab: root.openhab
            mqtt: root.mqtt
            title: root.value(["title"], "Controls")
            controls: root.value(["controls"], [])
            tilesPerRow: root.value(["tilesPerRow"], 0)
            minTileWidth: root.value(["minTileWidth"], 140)
        }
    }

    Component {
        id: mqttPanelComponent

        MqttPanel {
            mqtt: root.mqtt
            title: root.value(["title"], "MQTT")
            items: root.value(["items"], [])
        }
    }

    Component {
        id: sonosPanelComponent

        SonosPanel {
            openhab: root.openhab
            sonosClient: root.sonos
            title: root.value(["title"], "Sonos")
            columnSpan: root.value(["columnSpan"], 1)
            items: root.value(["items"], ({}))
            host: root.value(["host"], root.value(["items", "host"], ""))
            favorites: root.value(["favorites"], [])
            accentColor: root.value(["accentColor"], "#f59e0b")
        }
    }

    Component {
        id: grafanaPanelComponent

        GrafanaPanel {
            title: root.value(["title"], "Grafana")
            baseUrl: root.value(["baseUrl"], "")
            dashboardUid: root.value(["dashboardUid"], "")
            slug: root.value(["slug"], "dashboard")
            panelId: root.value(["panelId"], 0)
            orgId: root.value(["orgId"], 1)
            theme: root.value(["theme"], "dark")
            from: root.value(["from"], "now-2d")
            to: root.value(["to"], "now")
            timezone: root.value(["timezone"], "")
            refreshInterval: root.value(["refreshInterval"], 60)
            renderScale: root.value(["renderScale"], 1.0)
            extraParams: root.value(["extraParams"], ({}))
        }
    }

    Component {
        id: irrigationFloorplanPanelComponent

        IrrigationFloorplanPanel {
            openhab: root.openhab
            title: root.value(["title"], "Bewaesserung")
            imageSource: root.value(["imageSource"], "")
            zones: root.value(["zones"], [])
            sensors: root.value(["sensors"], [])
            programItem: root.value(["programItem"], "")
            programStartCommand: root.value(["programStartCommand"], "ON")
            programStopCommand: root.value(["programStopCommand"], "OFF")
            useCisternItem: root.value(["useCisternItem"], "")
            durationItem: root.value(["durationItem"], "")
            durationOptions: root.value(["durationOptions"], [3, 30, 45, 60, 90])
            history: root.value(["history"], ({}))
        }
    }

    Component {
        id: unsupportedPanelComponent

        Rectangle {
            implicitWidth: 292
            implicitHeight: 96
            radius: 18
            color: "#2a2230"
            border.color: "#f59e0b"

            Text {
                anchors.centerIn: parent
                text: "Unsupported panel: " + root.value(["type"], "<missing>")
                color: "#fbbf24"
                font.pixelSize: 13
                font.bold: true
            }
        }
    }
}
