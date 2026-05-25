import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "Room"
    property string subtitle: ""
    property string temperature: "--.- C"
    property string humidity: "-- %"
    property bool lightOn: false
    property bool shutterClosed: false
    property string shutterPosition: "-- %"

    implicitWidth: 292
    implicitHeight: 250
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.title
                    color: "#e2e8f0"
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.subtitle
                    color: "#7d90aa"
                    font.pixelSize: 11
                    visible: root.subtitle.length > 0
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.preferredWidth: 70
                Layout.preferredHeight: 34
                radius: 10
                color: "#16243a"

                Text {
                    anchors.centerIn: parent
                    text: root.temperature
                    color: "#f97316"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            ControlTile {
                label: "Licht"
                value: root.lightOn ? "ON" : "OFF"
                secondary: "main"
                iconText: "L"
                active: root.lightOn
                Layout.fillWidth: true
            }

            ControlTile {
                label: "Hue"
                value: root.lightOn ? "100%" : "0%"
                secondary: "scene"
                iconText: "H"
                active: root.lightOn
                accentColor: "#fbbf24"
                Layout.fillWidth: true
            }

            ControlTile {
                label: "Rollo"
                value: root.shutterClosed ? "DOWN" : "UP"
                secondary: root.shutterPosition
                iconText: "R"
                active: root.shutterClosed
                accentColor: "#38bdf8"
                Layout.fillWidth: true
            }

            ControlTile {
                label: "Klima"
                value: root.humidity
                secondary: "humidity"
                iconText: "C"
                active: false
                accentColor: "#22c55e"
                Layout.fillWidth: true
            }
        }
    }
}
