import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: "Kamera"
    property string location: "Einfahrt"

    implicitWidth: 420
    implicitHeight: 260
    radius: 18
    color: "#0f1726"
    border.color: "#26364d"
    border.width: 1
    clip: true

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

            Text {
                text: root.location
                color: "#8fa4bf"
                font.pixelSize: 12
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            clip: true
            color: "#1e293b"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: parent.height * 0.45
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#7dd3fc" }
                    GradientStop { position: 1.0; color: "#bae6fd" }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.55
                color: "#64748b"
            }

            Rectangle {
                x: parent.width * 0.06
                y: parent.height * 0.22
                width: parent.width * 0.24
                height: parent.height * 0.22
                color: "#e2e8f0"
                border.color: "#94a3b8"
            }

            Rectangle {
                x: parent.width * 0.62
                y: parent.height * 0.18
                width: parent.width * 0.28
                height: parent.height * 0.26
                color: "#f8fafc"
                border.color: "#94a3b8"
            }

            Rectangle {
                x: parent.width * 0.20
                y: parent.height * 0.56
                width: parent.width * 0.62
                height: parent.height * 0.26
                radius: 10
                color: "#334155"
                rotation: -3
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 38
                color: "#990f1726"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: "#22c55e"
                    }

                    Text {
                        text: "Static camera placeholder"
                        color: "#dbeafe"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "16:9"
                        color: "#93a4ba"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
