import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    implicitWidth: 292
    implicitHeight: 210
    radius: dashboardConfig.lcars ? 0 : 18
    color: dashboardConfig.lcars ? "#000000" : "#0f1726"
    border.color: dashboardConfig.lcars ? "#000000" : "#26364d"
    border.width: dashboardConfig.lcars ? 0 : 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.panelMargin
        spacing: Fmt.panelSpacing

        PanelHeader {
            Layout.fillWidth: true
            title: "Betrieb"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Fmt.gridSpacing

            ControlTile {
                label: "Auto"
                value: "100.0%"
                secondary: "+0.0 kW"
                iconText: "A"
                active: true
                Layout.fillWidth: true
            }

            ControlTile {
                label: "Robi"
                value: "100.0%"
                secondary: "dock"
                iconText: "R"
                active: false
                accentColor: "#22c55e"
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Fmt.gridSpacing

            Repeater {
                model: ["PV", "Auto", "Fast"]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: index === 0 ? "#f59e0b" : "#1e293b"
                    border.color: "#334155"

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: index === 0 ? "#111827" : "#cbd5e1"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Fmt.gridSpacing

            Repeater {
                model: ["Clean", "Home"]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 10
                    color: index === 1 ? "#f59e0b" : "#1e293b"
                    border.color: "#334155"

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: index === 1 ? "#111827" : "#cbd5e1"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
        }
    }
}
