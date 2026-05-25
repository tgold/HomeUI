import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string secondary: ""
    property string iconText: ""
    property bool active: false
    property bool interactive: false
    property color accentColor: "#f59e0b"
    signal clicked()

    implicitWidth: 132
    implicitHeight: 76
    radius: 12
    color: active ? "#26364d" : "#172235"
    border.color: active ? accentColor : "#304158"
    border.width: 1

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        onClicked: root.clicked()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        Text {
            text: root.label
            color: "#8fa4bf"
            font.pixelSize: 12
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: root.active ? root.accentColor : "#263449"

                Text {
                    anchors.centerIn: parent
                    text: root.iconText
                    color: root.active ? "#111827" : "#cbd5e1"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: root.value
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.secondary
                    visible: root.secondary.length > 0
                    color: "#94a3b8"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
