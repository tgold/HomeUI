import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "Energie"
    property var openhab: null
    property string pvItem: ""
    property string gridItem: ""
    property string consumptionItem: ""
    property string batteryItem: ""
    property string waterItem: ""
    property int stateRevision: openhab ? openhab.stateRevision : 0

    function itemState(itemName, fallback) {
        stateRevision
        if (openhab && itemName.length > 0) {
            return openhab.itemState(itemName, fallback)
        }
        return fallback
    }

    implicitWidth: 292
    implicitHeight: 250
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

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
            }

            Rectangle {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 28
                radius: 9
                color: "#172235"
                border.color: "#334155"

                Text {
                    anchors.centerIn: parent
                    text: "LIVE"
                    color: "#22c55e"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        MetricRow {
            label: "PV Erzeugung"
            value: root.itemState(root.pvItem, "2313.5 W")
            detail: "solar"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Netz"
            value: root.itemState(root.gridItem, "-1833.2 W")
            detail: "export"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Verbrauch"
            value: root.itemState(root.consumptionItem, "469.9 W")
            detail: "house"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Batterie"
            value: root.itemState(root.batteryItem, "100.0 %")
            detail: "+0.0 kW"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Wasser heute"
            value: root.itemState(root.waterItem, "137 kWh")
            detail: "thermal"
            warning: true
            Layout.fillWidth: true
        }
    }
}
