import QtQuick

// LCARS frame: a left elbow rail (one block per page) and a gold masthead
// with stardate, clock, and a sweep bar in the active page color.
Item {
    id: root

    property string title: "HOME OPERATIONS"
    property string section: ""
    property string statusText: ""
    property bool openhabConnected: false
    property var indicators: []
    property bool showDebugButton: false
    property bool debugActive: false
    property int pageCount: 0
    property int pageIndex: 0
    property var pages: []

    signal debugClicked()
    signal pageIndexClicked(int index)

    readonly property int railWidth: 104
    readonly property int contentLeft: 120
    readonly property int contentTop: 118
    readonly property int gutter: 6
    property date now: new Date()

    function pageTitle(index) {
        var page = root.pages && root.pages[index]
        if (!page) {
            return ""
        }
        return page.title || page.id || ""
    }

    function stardate() {
        var year = root.now.getFullYear()
        var start = new Date(year, 0, 0)
        var day = (root.now.getTime() - start.getTime()) / 86400000
        var leap = (year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0))
        var yearDays = leap ? 366 : 365
        var value = (year - 1946) * 1000 + (day / yearDays) * 1000
        return value.toFixed(1)
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.now = new Date()
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        width: root.railWidth - 8
        spacing: root.gutter

        Repeater {
            model: root.pageCount

            Item {
                required property int index
                width: parent.width
                height: root.pageCount > 0
                        ? (root.height - (root.pageCount - 1) * root.gutter) / root.pageCount
                        : 0

                readonly property bool active: index === root.pageIndex
                readonly property color tone: Theme.barColor(index)

                Rectangle {
                    id: segment
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.active ? parent.width : parent.width - 14
                    height: parent.height
                    radius: Math.min(36, height / 2)
                    color: parent.tone

                    // Flat right edge: round cap on the outside, square where it meets the screen.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.radius
                        color: parent.color
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 8
                        text: {
                            var n = parent.parent.index + 1
                            var code = n < 10 ? ("0" + n) : String(n)
                            return code + "\n" + root.pageTitle(parent.parent.index)
                        }
                        color: Theme.onShape
                        font.pixelSize: parent.parent.active ? 12 : 11
                        font.bold: true
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.pageIndexClicked(parent.parent.index)
                    }
                }
            }
        }
    }

    Text {
        id: masthead
        x: root.contentLeft
        y: 2
        width: Math.max(120, parent.width - root.contentLeft - clockLabel.width - 28)
        text: root.title
        color: "#FFCC66"
        font.pixelSize: 34
        font.bold: true
        font.family: Theme.fontFamily
        font.letterSpacing: 1.5
        elide: Text.ElideRight
    }

    Text {
        id: clockLabel
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 6
        text: Qt.formatTime(root.now, "hh:mm")
        color: "#FFCC66"
        font.pixelSize: 32
        font.bold: true
        font.family: Theme.fontFamily
    }

    Text {
        x: root.contentLeft
        y: 42
        width: parent.width - root.contentLeft - 16
        text: "STARDATE " + root.stardate() + "   ·   " + Qt.formatDate(root.now, "dddd d MMMM yyyy")
        color: Theme.data
        font.pixelSize: 13
        font.bold: true
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Text {
        x: root.contentLeft
        y: 62
        width: parent.width - root.contentLeft - 16
        text: root.statusText
        color: root.openhabConnected ? "#99CC99" : "#FF9900"
        font.pixelSize: 11
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Rectangle {
        id: sweep
        x: root.contentLeft
        y: 86
        height: 22
        radius: 11
        width: Math.max(80, parent.width - root.contentLeft - endCaps.width - 22)
        color: Theme.barColor(root.pageIndex)

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            text: root.section
            color: Theme.onShape
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
    }

    Row {
        id: endCaps
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: sweep.top
        height: sweep.height
        spacing: 6

        Repeater {
            model: root.indicators

            Rectangle {
                required property var modelData
                readonly property string indicatorState: modelData && modelData.state ? modelData.state : "idle"
                readonly property color tone: {
                    switch (indicatorState) {
                    case "ok": return "#99CC99"
                    case "warn": return "#FF9900"
                    case "active": return "#99CCFF"
                    default: return "#CC99CC"
                    }
                }

                width: Math.max(46, capLabel.implicitWidth + 16)
                height: 22
                radius: 11
                color: tone

                Text {
                    id: capLabel
                    anchors.centerIn: parent
                    text: modelData ? modelData.label : ""
                    color: Theme.onShape
                    font.pixelSize: 11
                    font.bold: true
                    font.family: Theme.fontFamily
                }
            }
        }

        Rectangle {
            visible: root.showDebugButton
            width: 52
            height: 22
            radius: 11
            color: root.debugActive ? "#FFCC66" : "#FF9966"

            Text {
                anchors.centerIn: parent
                text: "LOG"
                color: Theme.onShape
                font.pixelSize: 11
                font.bold: true
                font.family: Theme.fontFamily
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.debugClicked()
            }
        }
    }
}
