import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "OPENHAB"
    property string section: "RAUME EG"
    property string nowText: Qt.formatTime(new Date(), "hh:mm")
    property bool openhabConnected: false
    property bool eventStreamConnected: false
    property int itemCount: 0
    property string statusText: "OpenHAB not connected"

    height: 72
    color: "#0b1220"
    border.color: "#1f2b3d"
    border.width: 1

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.nowText = Qt.formatTime(new Date(), "hh:mm")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                spacing: 10

                Text {
                    text: root.title
                    color: "#dbeafe"
                    font.pixelSize: 18
                    font.bold: true
                }

                Text {
                    text: root.nowText
                    color: "#93c5fd"
                    font.pixelSize: 18
                }
            }

            Text {
                text: root.section
                color: "#8fa4bf"
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: root.statusText + (root.itemCount > 0 ? " · " + root.itemCount + " items" : "")
                color: root.openhabConnected ? "#86efac" : "#fbbf24"
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Repeater {
            model: [
                { "label": "OH", "ok": root.openhabConnected },
                { "label": "EV", "ok": root.eventStreamConnected },
                { "label": "LAN", "ok": true },
                { "label": "PV", "ok": true },
                { "label": "BAT", "ok": true },
                { "label": "CAM", "ok": false }
            ]

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 34
                radius: 10
                color: modelData.ok ? "#12291d" : "#2a2230"
                border.color: modelData.ok ? "#22c55e" : "#f59e0b"

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: modelData.ok ? "#86efac" : "#fbbf24"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
