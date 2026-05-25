import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var panel: ({})
    property var openhab: null

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
            waterItem: root.value(["items", "water"], "")
        }
    }

    Component {
        id: cameraPanelComponent

        CameraTile {
            title: root.value(["title"], "Kamera")
            location: root.value(["location"], "")
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
            title: root.value(["title"], "Controls")
            controls: root.value(["controls"], [])
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
