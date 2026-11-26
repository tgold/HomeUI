import QtQuick
import QtQuick.Layouts
import HomeUI 1.0
import "Format.js" as Fmt

Rectangle {
    id: root

    property string title: "Kamera"
    property string location: ""
    property string streamUrl: ""
    property string snapshotUrl: ""
    property int refreshInterval: 1000
    property string streamFormat: ""
    property bool ignoreSslErrors: false
    property bool active: true

    readonly property string effectiveFormat: {
        if (streamFormat && streamFormat.length > 0) {
            return streamFormat.toLowerCase()
        }
        if (streamUrl && streamUrl.length > 0) {
            return "mjpeg"
        }
        if (snapshotUrl && snapshotUrl.length > 0) {
            return "snapshot"
        }
        return "placeholder"
    }

    readonly property bool frameMode: dashboardConfig.lcars
    readonly property color backdrop: frameMode ? "#000000" : "#1e293b"

    function statusLabel() {
        switch (root.effectiveFormat) {
        case "mjpeg":
            if (mjpeg.lastError && mjpeg.lastError.length > 0) {
                return "MJPEG error: " + mjpeg.lastError
            }
            if (mjpeg.frameCount === 0) {
                return "MJPEG verbinden..."
            }
            return "MJPEG live"
        case "snapshot":
            if (snapshot.status === Image.Error) {
                return "Snapshot Fehler"
            }
            if (snapshot.status === Image.Loading) {
                return "Snapshot lade..."
            }
            return "Snapshot poll"
        default:
            return "Kein Stream konfiguriert"
        }
    }

    function statusRate() {
        if (root.effectiveFormat === "mjpeg") {
            return mjpeg.frameRate > 0 ? mjpeg.frameRate.toFixed(1) + " fps" : "--"
        }
        if (root.effectiveFormat === "snapshot") {
            return Math.max(250, root.refreshInterval) + " ms"
        }
        return "16:9"
    }

    function statusTone() {
        if (root.effectiveFormat === "mjpeg") {
            return mjpeg.active && mjpeg.frameCount > 0 ? "#99CC99" : "#FF9900"
        }
        if (root.effectiveFormat === "snapshot") {
            return snapshot.status === Image.Ready ? "#99CC99" : "#FF9900"
        }
        return "#CC9966"
    }

    implicitWidth: 420
    implicitHeight: 260
    radius: frameMode ? 0 : 18
    color: frameMode ? "#000000" : "#0f1726"
    border.color: frameMode ? "#000000" : "#26364d"
    border.width: frameMode ? 0 : 1
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Fmt.panelMargin
        spacing: Fmt.panelSpacing
        visible: !root.frameMode

        PanelHeader {
            Layout.fillWidth: true
            title: root.title
            detail: root.location
        }

        Rectangle {
            id: defaultWell
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            clip: true
            color: "#1e293b"
        }
    }

    // LCARS image frame. Colored rail, top cap, left notch, and the
    // segmented base wrap a black picture well. Same pieces as the
    // thelcars.com image frame, drawn to the tile.
    Item {
        id: frame
        anchors.fill: parent
        visible: root.frameMode

        readonly property color primary: "#ea9c72"
        readonly property color secondary: "#fcc19f"
        readonly property color accent: "#c47d69"
        readonly property color titleColor: "#edb378"
        readonly property color borderColor: "#fcc19f"
        readonly property int barH: Math.round(Math.max(22, Math.min(30, height * 0.08)))
        readonly property int railW: barH
        readonly property int baseH: Math.max(16, barH - 4)
        readonly property int spacer: Math.max(4, Math.round(barH * 0.18))
        readonly property int pad: Math.max(8, Math.round(barH * 0.42))
        readonly property int innerR: Math.round(barH * 0.7)
        readonly property int notchH: Math.round(barH * 1.8)
        readonly property int notchTop: Math.max(barH + spacer,
                                                  Math.min(Math.round(height * 0.62),
                                                           height - railW - notchH - baseH))
        // Measured from an unanchored label. The visible title is right-anchored,
        // and that anchor makes its own implicitWidth expand to the tile.
        readonly property real titleSlot: titleMeasure.implicitWidth + pad + spacer
        readonly property real capRight: width - titleSlot

        Item {
            x: 0
            y: 0
            width: frame.railW
            height: frame.railW
            clip: true

            Rectangle {
                width: frame.railW * 2
                height: frame.railW * 2
                radius: frame.railW
                color: frame.primary
            }
        }

        Rectangle {
            x: frame.railW - 1
            y: 0
            width: Math.max(0, frame.capRight - frame.barH / 2 - frame.railW)
            height: frame.barH
            color: frame.primary
            z: 3
        }

        Rectangle {
            x: frame.capRight - frame.barH
            y: 0
            width: frame.barH
            height: frame.barH
            radius: frame.barH / 2
            color: frame.primary
            z: 3
        }

        Text {
            id: titleMeasure
            visible: false
            text: root.title.toUpperCase()
            font.pixelSize: Math.max(15, frame.barH - 4)
            font.bold: true
            font.family: Theme.fontFamily
            font.letterSpacing: 1.2
        }

        Text {
            id: frameTitle
            anchors.right: parent.right
            anchors.rightMargin: frame.pad
            anchors.top: parent.top
            height: frame.barH
            verticalAlignment: Text.AlignVCenter
            text: root.title.toUpperCase()
            color: frame.titleColor
            font.pixelSize: Math.max(15, frame.barH - 4)
            font.bold: true
            font.family: Theme.fontFamily
            font.letterSpacing: 1.2
            z: 3
        }

        Rectangle {
            x: 0
            y: frame.railW - 1
            width: frame.railW
            height: Math.max(0, frame.notchTop - frame.railW + 1)
            color: frame.primary
        }

        Rectangle {
            x: 0
            y: frame.notchTop + frame.spacer
            width: frame.railW
            height: Math.max(0, frame.notchH - frame.spacer * 2)
            color: frame.secondary
        }

        Rectangle {
            x: 0
            y: frame.notchTop + frame.notchH
            width: frame.railW
            height: Math.max(0, parent.height - frame.railW - (frame.notchTop + frame.notchH))
            color: frame.secondary
        }

        Item {
            x: 0
            y: parent.height - frame.railW
            width: frame.railW
            height: frame.railW
            clip: true

            Rectangle {
                y: -frame.railW
                width: frame.railW * 2
                height: frame.railW * 2
                radius: frame.railW
                color: frame.secondary
            }
        }

        Rectangle {
            id: well
            x: frame.railW
            y: frame.barH
            width: parent.width - frame.railW
            height: parent.height - frame.barH - frame.baseH
            color: "#000000"
        }

        Item {
            x: well.x
            y: well.y
            width: frame.innerR
            height: frame.innerR
            clip: true

            Rectangle {
                anchors.fill: parent
                color: frame.primary
            }

            Rectangle {
                width: frame.innerR * 2
                height: frame.innerR * 2
                radius: frame.innerR
                color: "#000000"
            }
        }

        Item {
            x: well.x
            y: well.y + well.height - frame.innerR
            width: frame.innerR
            height: frame.innerR
            clip: true

            Rectangle {
                anchors.fill: parent
                color: frame.secondary
            }

            Rectangle {
                y: -frame.innerR
                width: frame.innerR * 2
                height: frame.innerR * 2
                radius: frame.innerR
                color: "#000000"
            }
        }

        Rectangle {
            id: pictureFrame
            x: frame.railW + frame.pad
            y: frame.barH + frame.pad
            width: Math.max(0, frame.width - frame.railW - frame.pad * 2)
            height: Math.max(0, frame.height - frame.barH - frame.baseH - frame.pad * 2)
            radius: Math.max(10, frame.innerR)
            color: "#000000"
            border.color: frame.borderColor
            border.width: 2
            z: 1

            Item {
                id: pictureClip
                anchors.fill: parent
                anchors.margins: 6
            }
        }

        Row {
            x: frame.railW + frame.spacer * 2
            y: parent.height - frame.baseH
            height: frame.baseH
            spacing: frame.spacer

            Rectangle {
                width: Math.max(18, (frame.width - frame.railW) * 0.16)
                height: frame.baseH
                color: frame.accent
            }
            Rectangle {
                width: Math.max(14, (frame.width - frame.railW) * 0.11)
                height: frame.baseH
                color: frame.secondary
            }
            Item {
                width: Math.max(14, frame.spacer * 3)
                height: frame.baseH

                Rectangle {
                    anchors.left: parent.left
                    width: 6
                    height: parent.height
                    color: frame.accent
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 6
                    height: parent.height
                    color: frame.secondary
                }
            }
            Rectangle {
                width: Math.max(16, (frame.width - frame.railW) * 0.13)
                height: frame.baseH
                color: frame.secondary
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: frame.pad
            anchors.bottom: parent.bottom
            height: frame.baseH
            spacing: 8

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 4
                color: root.statusTone()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.location
                visible: root.location.length > 0
                color: "#99CCFF"
                font.pixelSize: 12
                font.bold: true
                font.family: Theme.fontFamily
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.statusLabel()
                color: frame.titleColor
                font.pixelSize: 12
                font.bold: true
                font.family: Theme.fontFamily
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.statusRate()
                color: frame.titleColor
                font.pixelSize: 12
                font.bold: true
                font.family: Theme.fontFamily
            }
        }
    }

    Item {
        id: stage
        parent: root.frameMode ? pictureClip : defaultWell
        anchors.fill: parent
        clip: true

        MjpegView {
            id: mjpeg
            anchors.fill: parent
            visible: root.effectiveFormat === "mjpeg" && root.streamUrl.length > 0
            url: root.active && visible ? root.streamUrl : ""
            ignoreSslErrors: root.ignoreSslErrors
            backdropColor: root.backdrop
        }

        Connections {
            target: root
            function onActiveChanged() {
                if (!root.active || root.effectiveFormat !== "mjpeg" || root.streamUrl.length === 0) {
                    return
                }
                var stream = root.streamUrl
                mjpeg.url = ""
                mjpeg.url = stream
            }
        }

        Image {
            id: snapshot
            anchors.fill: parent
            visible: root.effectiveFormat === "snapshot" && root.snapshotUrl.length > 0
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            property int tick: 0
            source: visible && root.active && root.snapshotUrl.length > 0
                    ? root.snapshotUrl + (root.snapshotUrl.indexOf("?") >= 0 ? "&" : "?") + "_=" + tick
                    : ""
        }

        Timer {
            running: snapshot.visible && root.active
            repeat: true
            interval: Math.max(250, root.refreshInterval)
            onTriggered: snapshot.tick += 1
        }

        Item {
            anchors.fill: parent
            visible: root.effectiveFormat === "placeholder"

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
                color: (root.frameMode ? "#FFCC66" : "#e2e8f0")
                border.color: (root.frameMode ? "#CC9966" : "#94a3b8")
            }

            Rectangle {
                x: parent.width * 0.62
                y: parent.height * 0.18
                width: parent.width * 0.28
                height: parent.height * 0.26
                color: (root.frameMode ? "#FFFF99" : "#f8fafc")
                border.color: (root.frameMode ? "#CC9966" : "#94a3b8")
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
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            visible: !root.frameMode
            color: "#990f1726"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Fmt.tileMargin
                anchors.rightMargin: Fmt.tileMargin
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: {
                        if (root.effectiveFormat === "mjpeg") {
                            return mjpeg.active && mjpeg.frameCount > 0 ? "#22c55e" : "#fbbf24"
                        }
                        if (root.effectiveFormat === "snapshot") {
                            return snapshot.status === Image.Ready ? "#22c55e" : "#fbbf24"
                        }
                        return "#94a3b8"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    color: "#dbeafe"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    text: root.statusLabel()
                }

                Text {
                    color: "#93a4ba"
                    font.pixelSize: 11
                    text: root.statusRate()
                }
            }
        }
    }
}
