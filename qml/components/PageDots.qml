import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property int count: 0
    property int currentIndex: 0

    signal dotClicked(int index)

    spacing: 8

    Repeater {
        model: root.count

        Item {
            Layout.preferredWidth: Math.max(28, dot.width + 8)
            Layout.preferredHeight: 28

            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: index === root.currentIndex ? 28 : 10
                height: 10
                radius: 5
                color: index === root.currentIndex ? "#f59e0b" : "#334155"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.dotClicked(index)
            }
        }
    }
}
