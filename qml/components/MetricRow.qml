import QtQuick
import QtQuick.Layouts
import "Format.js" as Fmt

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string detail: ""
    property bool warning: false

    implicitHeight: Theme.lcars ? 36 : 40
    radius: Theme.lcars ? 0 : 8
    color: Theme.lcars ? "transparent" : "#121c2c"
    border.color: Theme.lcars ? "transparent" : (warning ? "#f59e0b" : "#25364c")
    border.width: Theme.lcars ? 0 : 1

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
                color: Theme.lcars ? "#FF9966" : "#93a4ba"
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.detail
                visible: root.detail.length > 0
                color: Theme.lcars ? Theme.muted : "#64748b"
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: root.value
            color: root.warning ? "#fbbf24" : (Theme.lcars ? Theme.data : "#e2e8f0")
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignRight
        }
    }
}
