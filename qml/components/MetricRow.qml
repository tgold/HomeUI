import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string detail: ""
    property bool warning: false

    implicitHeight: dashboardConfig.lcars ? 36 : 40
    radius: dashboardConfig.lcars ? 0 : 8
    color: dashboardConfig.lcars ? "transparent" : "#121c2c"
    border.color: dashboardConfig.lcars ? "transparent" : (warning ? "#f59e0b" : "#25364c")
    border.width: dashboardConfig.lcars ? 0 : 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Fmt.tileMargin
        anchors.rightMargin: Fmt.tileMargin
        spacing: Fmt.gridSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: root.label
                color: dashboardConfig.lcars ? "#FF9966" : "#93a4ba"
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.detail
                visible: root.detail.length > 0
                color: dashboardConfig.lcars ? (dashboardConfig.lcars ? "#CC9966" : "#94a3b8") : "#64748b"
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: root.value
            color: root.warning ? "#fbbf24" : (dashboardConfig.lcars ? (dashboardConfig.lcars ? "#99CCFF" : "#f8fafc") : "#e2e8f0")
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignRight
        }
    }
}
