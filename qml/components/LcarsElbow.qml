import QtQuick

// LCARS elbow. One thick leg drops from the left end of the title pill.
// The cap uses the same color as that pill and overlaps its left end, so the
// bar and the leg read as a single shape. There is no second hook on the right.
Item {
    id: root

    property string seed: ""

    readonly property int topMargin: dashboardConfig.lcars ? 8 : 10
    readonly property int bottomMargin: dashboardConfig.lcars ? 10 : 10
    readonly property int leftMargin: dashboardConfig.lcars ? 22 : 10
    readonly property int rightMargin: dashboardConfig.lcars ? 10 : 10
    readonly property int barY: 8
    readonly property int barH: 28
    readonly property int legW: 14
    readonly property int capW: 40
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

    // The leg is exactly half the bar, so its inner edge lands on the
    // center of the corner circle. One semicircle, then straight edges.
    readonly property int legReach: {
        var room = height - barY - barH / 2 - legW / 2 - 4
        var want = Math.max(48, height * 0.5)
        return Math.max(legW, Math.min(want, room))
    }

    anchors.fill: parent
    visible: false
    z: 2

    Rectangle {
        x: 0
        y: root.barY
        width: root.barH
        height: root.barH
        radius: root.barH / 2
        color: root.barColor
        antialiasing: true
    }

    Rectangle {
        x: root.barH / 2
        y: root.barY
        width: root.capW - root.barH / 2
        height: root.barH
        color: root.barColor
    }

    Rectangle {
        x: 0
        y: root.barY + root.barH / 2
        width: root.legW
        height: root.legReach
        color: root.barColor
    }

    Rectangle {
        x: 0
        y: root.barY + root.barH / 2 + root.legReach - root.legW / 2
        width: root.legW
        height: root.legW
        radius: root.legW / 2
        color: root.barColor
        antialiasing: true
    }
}
