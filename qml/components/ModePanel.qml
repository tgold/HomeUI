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

    LcarsElbow {
        id: lcarsElbow
        seed: "Betrieb"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: lcarsElbow.contentMargin
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
                    radius: dashboardConfig.lcars ? height / 2 : 10
                    color: dashboardConfig.lcars
                           ? (index === 0 ? "#FFCC66" : (index === 1 ? "#99CCFF" : "#CC99CC"))
                           : (index === 0 ? "#f59e0b" : "#1e293b")
                    border.color: "#334155"
                    border.width: dashboardConfig.lcars ? 0 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: dashboardConfig.lcars ? "#000000" : (index === 0 ? "#111827" : "#cbd5e1")
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
                    radius: dashboardConfig.lcars ? height / 2 : 10
                    color: dashboardConfig.lcars
                           ? (index === 1 ? "#FFCC66" : "#FF9966")
                           : (index === 1 ? "#f59e0b" : "#1e293b")
                    border.color: "#334155"
                    border.width: dashboardConfig.lcars ? 0 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: dashboardConfig.lcars ? "#000000" : (index === 1 ? "#111827" : "#cbd5e1")
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
        }
    }
}
