import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string detail: ""
    property bool warning: false

    implicitHeight: 40
    radius: 8
    color: "#121c2c"
    border.color: warning ? "#f59e0b" : "#25364c"
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: root.label
                color: "#93a4ba"
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.detail
                visible: root.detail.length > 0
                color: "#64748b"
                font.pixelSize: 9
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: root.value
            color: root.warning ? "#fbbf24" : "#e2e8f0"
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignRight
        }
    }
}
