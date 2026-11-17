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

    function accentFor(title) {
        var colors = ["#FF9966", "#FFCC66", "#99CCFF", "#CC99CC",
                      "#FFCC99", "#E7B08A", "#8EC8EA", "#F0D056"]
        var s = String(title || "")
        var hash = 0
        for (var i = 0; i < s.length; ++i) {
            hash = (hash * 33 + s.charCodeAt(i)) >>> 0
        }
        return colors[hash % colors.length]
    }

    implicitWidth: 160
    implicitHeight: dashboardConfig.lcars ? 30 : (subtitle.length > 0 ? 40 : 24)

    RowLayout {
        anchors.fill: parent
        spacing: 8
        visible: !dashboardConfig.lcars

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.title
                color: (dashboardConfig.lcars ? "#FFCC66" : "#e2e8f0")
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
            color: (dashboardConfig.lcars ? "#FFFF99" : "#f8fafc")
            font.pixelSize: 16
            font.bold: true
            horizontalAlignment: Text.AlignRight
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10
        visible: dashboardConfig.lcars

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 14
            color: root.accentFor(root.title)

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                text: root.title
                color: "#000000"
                font.pixelSize: 15
                font.bold: true
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        Text {
            text: root.detail.length > 0 ? root.detail : root.subtitle
            visible: root.detail.length > 0 || root.subtitle.length > 0
            color: (dashboardConfig.lcars ? "#99CCFF" : "#f8fafc")
            font.pixelSize: 20
            font.bold: true
            font.family: Theme.fontFamily
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
