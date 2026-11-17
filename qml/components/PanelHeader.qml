import QtQuick
import QtQuick.Layouts

// Panel title row. The default skin is plain text. LCARS draws a colored
// pill bar with black caps, and puts the live detail (temperature, location)
// beside it in the data color.
Item {
    id: root

    property string title: ""
    property string detail: ""
    property string subtitle: ""

    implicitWidth: 160
    implicitHeight: Theme.lcars ? 30 : (subtitle.length > 0 ? 40 : 24)

    RowLayout {
        anchors.fill: parent
        spacing: 8
        visible: !Theme.lcars

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.title
                color: Theme.text
                font.pixelSize: 18
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.subtitle
                visible: root.subtitle.length > 0
                color: "#7d90aa"
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: root.detail
            visible: root.detail.length > 0
            color: Theme.value
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignRight
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10
        visible: Theme.lcars

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 14
            color: Theme.accentFor(root.title)

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                text: root.title
                color: Theme.onShape
                font.pixelSize: 15
                font.bold: true
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        Text {
            text: root.detail.length > 0 ? root.detail : root.subtitle
            visible: root.detail.length > 0 || root.subtitle.length > 0
            color: Theme.data
            font.pixelSize: 20
            font.bold: true
            font.family: Theme.fontFamily
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
