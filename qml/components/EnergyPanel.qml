import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "Energie"

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
            value: "2313.5 W"
            detail: "solar"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Netz"
            value: "-1833.2 W"
            detail: "export"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Verbrauch"
            value: "469.9 W"
            detail: "house"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Batterie"
            value: "100.0 %"
            detail: "+0.0 kW"
            Layout.fillWidth: true
        }

        MetricRow {
            label: "Wasser heute"
            value: "137 kWh"
            detail: "thermal"
            warning: true
            Layout.fillWidth: true
        }
    }
}
