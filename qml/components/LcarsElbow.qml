import QtQuick

// LCARS corner frame. A thick L sits on the top-left of a panel and a shorter
// inverse L closes the bottom-right. Both stay in the panel padding, except
// the rounded top-left block, which laps the title pill in the same color.
Item {
    id: root

    property string seed: ""

    readonly property int contentMargin: dashboardConfig.lcars ? 16 : 10
    readonly property int stroke: 12
    readonly property int cornerSize: 28
    readonly property color barColor: {
        var colors = ["#FF9966", "#FFCC66", "#99CCFF", "#CC99CC",
                      "#FFCC99", "#E7B08A", "#8EC8EA", "#F0D056"]
        var s = String(root.seed || "")
        var hash = 0
        for (var i = 0; i < s.length; ++i) {
            hash = (hash * 33 + s.charCodeAt(i)) >>> 0
        }
        return colors[hash % colors.length]
    }

    anchors.fill: parent
    visible: dashboardConfig.lcars
    z: 5

    Rectangle {
        x: 0
        y: 0
        width: root.cornerSize
        height: root.cornerSize
        radius: 16
        color: root.barColor
    }

    Rectangle {
        x: 0
        y: root.cornerSize - root.stroke
        width: root.stroke
        height: Math.max(root.stroke, Math.min(parent.height * 0.52, parent.height - root.cornerSize))
        radius: root.stroke / 2
        color: root.barColor
    }

    Rectangle {
        x: 0
        y: root.cornerSize - root.stroke
        width: root.stroke
        height: root.stroke
        color: root.barColor
    }

    Rectangle {
        x: parent.width - root.stroke
        y: parent.height - Math.min(78, parent.height * 0.36)
        width: root.stroke
        height: Math.min(78, parent.height * 0.36)
        radius: root.stroke / 2
        color: root.barColor
    }

    Rectangle {
        x: parent.width - Math.min(88, parent.width * 0.32)
        y: parent.height - root.stroke
        width: Math.min(88, parent.width * 0.32)
        height: root.stroke
        radius: root.stroke / 2
        color: root.barColor
    }

    Rectangle {
        x: parent.width - root.stroke
        y: parent.height - root.stroke
        width: root.stroke
        height: root.stroke
        color: root.barColor
    }
}
