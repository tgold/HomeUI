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

    // Each indicator: { label: string, state: "ok"|"warn"|"active"|"idle", tooltip?: string }
    // - "ok"/"warn"   : diagnostic indicators (system health)
    // - "active"/"idle": activity indicators (something is happening right now)
    property var indicators: [
        { "label": "OH", "state": root.openhabConnected ? "ok" : "warn" },
        { "label": "LIVE", "state": root.eventStreamConnected ? "ok" : "warn" }
    ]

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
            model: root.indicators

            Rectangle {
                readonly property string indicatorState: modelData && modelData.state ? modelData.state : "idle"
                readonly property var palette: {
                    switch (indicatorState) {
                    case "ok":     return { bg: "#12291d", border: "#22c55e", text: "#86efac" }
                    case "warn":   return { bg: "#2a2230", border: "#f59e0b", text: "#fbbf24" }
                    case "active": return { bg: "#0f2740", border: "#38bdf8", text: "#7dd3fc" }
                    case "idle":
                    default:       return { bg: "#141a25", border: "#243043", text: "#52617a" }
                    }
                }

                Layout.preferredWidth: Math.max(48, indicatorText.implicitWidth + 18)
                Layout.preferredHeight: 34
                radius: 10
                color: palette.bg
                border.color: palette.border

                Text {
                    id: indicatorText
                    anchors.centerIn: parent
                    text: modelData ? modelData.label : ""
                    color: palette.text
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
