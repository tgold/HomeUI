import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property int count: 0
    property int currentIndex: 0

    spacing: 8

    Repeater {
        model: root.count

        Rectangle {
            Layout.preferredWidth: index === root.currentIndex ? 28 : 10
            Layout.preferredHeight: 10
            radius: 5
            color: index === root.currentIndex ? "#f59e0b" : "#334155"
        }
    }
}
