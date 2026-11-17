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

    readonly property int railWidth: 118
    readonly property int contentLeft: 136
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

    function segmentColor(index) {
        var colors = ["#E7B08A", "#F0D056", "#FF9966", "#8EC8EA",
                      "#F0D056", "#E8B84A", "#D7A48A", "#CC99CC",
                      "#99CCFF", "#FFCC99"]
        var i = Math.abs(Math.floor(Number(index) || 0)) % colors.length
        return colors[i]
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.now = new Date()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        width: root.railWidth - 16
        spacing: root.gutter

        Repeater {
            model: root.pageCount

            Rectangle {
                required property int index
                readonly property bool active: index === root.pageIndex
                readonly property string code: (index + 1) < 10 ? ("0" + (index + 1)) : String(index + 1)

                width: root.railWidth - 16
                height: root.pageCount > 0
                        ? (root.height - 16 - (root.pageCount - 1) * root.gutter) / root.pageCount
                        : 0
                radius: Math.min(22, height / 2)
                color: root.segmentColor(index)

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: parent.active ? 8 : 18
                    anchors.bottomMargin: 8
                    anchors.topMargin: 8
                    text: parent.code + "\n" + root.pageTitle(parent.index)
                    color: "#000000"
                    font.pixelSize: parent.active ? 13 : 11
                    font.bold: true
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignBottom
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.pageIndexClicked(parent.index)
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
