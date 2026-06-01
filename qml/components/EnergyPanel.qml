import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string title: "Energie"
    property var openhab: null
    property string pvItem: ""
    property string gridItem: ""
    property string consumptionItem: ""
    property string batteryItem: ""
    property string pvDayItem: ""
    property string consumptionDayItem: ""
    property int stateRevision: openhab ? openhab.stateRevision : 0

    readonly property bool hasDayMetrics: pvDayItem.length > 0 || consumptionDayItem.length > 0

    function itemState(itemName, fallback) {
        stateRevision
        if (openhab && itemName.length > 0) {
            return openhab.itemState(itemName, fallback)
        }
        return fallback
    }

    implicitWidth: 292
    implicitHeight: contentLayout.implicitHeight + 2 * Fmt.panelMargin
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    ColumnLayout {
        id: contentLayout
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

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Fmt.gridSpacing
            rowSpacing: Fmt.gridSpacing

            MetricRow {
                label: "PV Erzeugung"
                value: Fmt.power(root.itemState(root.pvItem, "2313.5 W"))
                detail: "live"
                Layout.fillWidth: true
            }

            MetricRow {
                label: "Netz"
                value: Fmt.power(root.itemState(root.gridItem, "-1833.2 W"))
                detail: "live"
                Layout.fillWidth: true
            }

            MetricRow {
                label: "Verbrauch"
                value: Fmt.power(root.itemState(root.consumptionItem, "469.9 W"))
                detail: "live"
                Layout.fillWidth: true
            }

            MetricRow {
                label: "Batterie"
                value: Fmt.fraction(root.itemState(root.batteryItem, "100.0 %"))
                detail: "live"
                Layout.fillWidth: true
            }

            MetricRow {
                visible: root.pvDayItem.length > 0
                label: "PV heute"
                value: Fmt.energy(root.itemState(root.pvDayItem, "12.3 kWh"))
                detail: "today"
                Layout.fillWidth: true
            }

            MetricRow {
                visible: root.consumptionDayItem.length > 0
                label: "Verbrauch heute"
                value: Fmt.energy(root.itemState(root.consumptionDayItem, "18.4 kWh"))
                detail: "today"
                Layout.fillWidth: true
            }
        }
    }
}
